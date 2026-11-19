#!/usr/bin/env bash
# Race tests (task F6b): a merge or an undo while other people vote, unvote and
# comment, and two owners at the same moment. Against the LOCAL Supabase
# database in Docker only (container supabase_db_triad-feedbox), never a hosted
# project. Used by `npm run test:races` and by the CI job `db`.
#
# Each case runs two database sessions at the same time, the way two people's
# requests reach the database:
#   * session 1 (the "slow" one) does its work in a transaction and then holds
#     it open, with every lock it took, for PAUSE seconds before it commits;
#   * session 2 starts 1 second later, while session 1 still holds its locks,
#     and runs to the end.
# The harness records whether session 2 had to wait for session 1, what each
# session was told, and then reads what is in the database.
# Session 2 always acts through the API role (authenticated) with a person's
# id, like the app's server does with that person's session.
# It resets the local database at the start and at the end.

set -uo pipefail

cd "$(dirname "$0")/.."
CONTAINER=supabase_db_triad-feedbox
PAUSE=3
FAILURES=0
CHECKS=0

sql() { # one query string, as one request sends it
  docker exec -i "$CONTAINER" psql -U postgres -d postgres -X -q -At -F'|' -v ON_ERROR_STOP=1 -c "$1" 2>&1
}
ok()  { CHECKS=$((CHECKS + 1)); echo "  ok   $1"; }
bad() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); echo "  FAIL $1"; }

# expect <label> <actual> <expected>
expect() {
  if [[ "$2" == "$3" ]]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi
}
# expect_has <label> <text> <phrase>
expect_has() {
  if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1: \"$3\""; else bad "$1: expected \"$3\" in: $2"; fi
}
# expect_ok <label> <text>: no error
expect_ok() {
  if printf '%s' "$2" | grep -q 'ERROR'; then bad "$1: expected no error, got: $2"; else ok "$1: no error"; fi
}

reset() { npx supabase db reset "$@" >/dev/null 2>&1 || { echo "db reset failed"; exit 1; }; }

uid() { sql "select id from auth.users where email = '$1@feedbox.test'"; }

# person <handle> <display name>: a signed-up person with a name.
person() {
  sql "insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token,
    email_change_token_new, email_change, email_change_token_current, reauthentication_token,
    phone_change, phone_change_token)
  values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
    '$1@feedbox.test', now(), '{}'::jsonb, '{}'::jsonb, now(), now(), '', '', '', '', '', '', '', '');
  update public.profiles set display_name = '$2' where id = (select id from auth.users where email = '$1@feedbox.test')" >/dev/null
}

# as <handle>: the rest of the transaction runs as that person, through the API role.
as() {
  printf "select set_config('request.jwt.claims', json_build_object('sub', '%s', 'role', 'authenticated')::text, true); set local role authenticated;" "$(uid "$1")"
}

# idea <title>: a new idea on the Lumen board by "r-author" (whose vote it gets); prints its id.
idea() {
  sql "insert into public.ideas (board_id, author_id, title)
       select b.id, u.id, '$1' from public.boards b, auth.users u
       where b.slug = 'lumen' and u.email = 'r-author@feedbox.test' returning id" | head -1
}
vote()    { sql "$(as "$1") insert into public.votes (idea_id) values ($2)" >/dev/null; }
merge()   { sql "$(as r-own1) select public.merge_ideas($1, $2)" >/dev/null; }
merge_id() { sql "select max(id) from public.idea_merges where source_id = $1"; }

# The state of one idea: votes/comments, merged into (or -), and its voters by name.
state() {
  sql "select i.vote_count || ' votes, ' || i.comment_count || ' comments, merged into ' || coalesce(i.merged_into_id::text, '-')
              || ', voters: ' || coalesce((select string_agg(p.display_name, ',' order by p.display_name)
                                             from public.votes v join public.profiles p on p.id = v.user_id
                                            where v.idea_id = i.id), 'none')
       from public.ideas i where i.id = $1"
}
voters() {
  sql "select coalesce(string_agg(p.display_name, ',' order by p.display_name), 'none')
       from public.votes v join public.profiles p on p.id = v.user_id where v.idea_id = $1"
}

# race <label> <session 1 sql> <session 2 sql>: sets SLOW, FAST and WAITED (seconds session 2 waited).
race() {
  local slow_file start end pid
  slow_file=$(mktemp)
  sql "begin; $2; select 'session 1 holds its locks'; select pg_sleep($PAUSE); commit;" > "$slow_file" &
  pid=$!
  sleep 1
  start=$(date +%s)
  FAST=$(sql "begin; $3; commit;")
  end=$(date +%s)
  wait "$pid"
  SLOW=$(cat "$slow_file"); rm -f "$slow_file"
  WAITED=$((end - start))
  echo "   [$1] session 2 waited ${WAITED}s"
  [[ -n "$FAST" ]] && printf '%s\n' "$FAST" | grep -v '^$' | grep -v '^{"sub"' | sed 's/^/         session 2: /'
  printf '%s\n' "$SLOW" | grep ERROR | sed 's/^/         session 1: /'
}
# race3 <label> <gate sql> <session 1 sql> <session 2 sql>: a third session (the
# gate) holds one lock for PAUSE+1 seconds; session 1 starts 1 second later,
# session 2 one second after that, so both queue behind the gate in that order.
# Sets ONE, TWO (what sessions 1 and 2 were told).
race3() {
  local gate_file one_file pid_gate pid_one
  gate_file=$(mktemp); one_file=$(mktemp)
  sql "begin; $2; select pg_sleep($((PAUSE + 1))); commit;" > "$gate_file" &
  pid_gate=$!
  sleep 1
  sql "begin; $3; commit;" > "$one_file" &
  pid_one=$!
  sleep 1
  TWO=$(sql "begin; $4; commit;")
  wait "$pid_one"; wait "$pid_gate"
  ONE=$(cat "$one_file"); rm -f "$gate_file" "$one_file"
  printf '%s\n' "$ONE" | grep ERROR | sed "s/^/         [$1] session 1: /"
  printf '%s\n' "$TWO" | grep ERROR | sed "s/^/         [$1] session 2: /"
}
waited() { # session 2 had to wait for session 1's locks
  if (( WAITED >= 1 )); then ok "$1: session 2 waited ${WAITED}s for session 1"; else bad "$1: session 2 did not wait (${WAITED}s): the race did not happen"; fi
}

echo "== Setup: the Lumen database, two owners, an author and voters"
reset
person r-own1 "Owner One"; person r-own2 "Owner Two"; person r-author "Author"
for v in A B C D E F G H; do person "r-$(printf %s "$v" | tr A-Z a-z)" "Voter $v"; done
sql "insert into public.board_owners (board_id, user_id)
     select b.id, u.id from public.boards b, auth.users u
     where b.slug = 'lumen' and u.email in ('r-own1@feedbox.test', 'r-own2@feedbox.test')" >/dev/null

echo "== a1. A vote on the SOURCE while a merge runs"
S=$(idea "R a1 source"); T=$(idea "R a1 target")
race a1 "$(as r-own1) select public.merge_ideas($S, $T)" "$(as r-a) insert into public.votes (idea_id) values ($S)"
waited a1
expect_has "a1 the voter is told, in words" "$FAST" "This idea was just merged into “R a1 target”. Vote there."
expect "a1 the merged idea holds no vote" "$(state "$S")" "0 votes, 0 comments, merged into $T, voters: none"
expect "a1 the target: the author once, nobody lost or counted twice" "$(state "$T")" "1 votes, 0 comments, merged into -, voters: Author"
vote r-a "$T"
expect "a1 the voter then votes on the target, as told" "$(voters "$T")" "Author,Voter A"

echo "== a2. An unvote on the SOURCE while a merge runs"
S=$(idea "R a2 source"); T=$(idea "R a2 target"); vote r-b "$S"
race a2 "$(as r-own1) select public.merge_ideas($S, $T)" "$(as r-b) select public.remove_my_vote($S)"
waited a2
expect_has "a2 the person is told, in words" "$FAST" "This idea was just merged into “R a2 target”. Your vote moved there with it; remove it there if you wish."
expect "a2 the vote moved with the merge and is counted once" "$(state "$T")" "2 votes, 0 comments, merged into -, voters: Author,Voter B"
sql "$(as r-b) select public.remove_my_vote($T)" >/dev/null
expect "a2 the person then removes it on the target, as told" "$(voters "$T")" "Author"

echo "== b. A comment on the SOURCE while a merge runs"
S=$(idea "R b source"); T=$(idea "R b target")
race b "$(as r-own1) select public.merge_ideas($S, $T)" "$(as r-c) insert into public.comments (idea_id, body) values ($S, 'R b: written during the merge')"
waited b
expect_has "b the person is told, in words" "$FAST" "This idea was just merged into “R b target”. Post your comment there."
expect "b no comment is hidden away on the merged idea" "$(sql "select count(*) from public.comments where body = 'R b: written during the merge'")" "0"
expect "b the counts" "$(state "$S") / $(state "$T")" "0 votes, 0 comments, merged into $T, voters: none / 1 votes, 0 comments, merged into -, voters: Author"

echo "== b2. A comment on the TARGET while a merge runs"
S=$(idea "R b2 source"); T=$(idea "R b2 target")
race b2 "$(as r-own1) select public.merge_ideas($S, $T)" "$(as r-c) insert into public.comments (idea_id, body) values ($T, 'R b2: on the target during the merge')"
waited b2
expect_ok "b2 the comment goes through" "$FAST"
expect "b2 it stays on the target" "$(sql "select idea_id from public.comments where body = 'R b2: on the target during the merge'")" "$T"

echo "== c1. A vote on the TARGET while an undo runs"
S=$(idea "R c1 source"); T=$(idea "R c1 target"); vote r-d "$S"; merge "$S" "$T"; M=$(merge_id "$S")
race c1 "$(as r-own1) select public.undo_merge($M)" "$(as r-e) insert into public.votes (idea_id) values ($T)"
waited c1
expect_ok "c1 the vote goes through" "$FAST"
expect "c1 the vote stays on the target; the source is as before the merge" \
  "$(voters "$T") / $(voters "$S")" "Author,Voter E / Author,Voter D"

echo "== c2. An unvote on the TARGET while an undo runs (the undo first)"
S=$(idea "R c2 source"); T=$(idea "R c2 target"); vote r-f "$S"; merge "$S" "$T"; M=$(merge_id "$S")
race c2 "$(as r-own1) select public.undo_merge($M)" "$(as r-f) select public.remove_my_vote($T)"
waited c2
expect_ok "c2 no error" "$FAST"
expect "c2 the undo came first: the vote is back on the source, and there was none left on the target to remove" \
  "$(voters "$S") / $(voters "$T")" "Author,Voter F / Author"

echo "== c3. An unvote on the TARGET while an undo runs (the unvote first)"
S=$(idea "R c3 source"); T=$(idea "R c3 target"); vote r-g "$S"; merge "$S" "$T"; M=$(merge_id "$S")
race c3 "$(as r-g) select public.remove_my_vote($T)" "$(as r-own1) select public.undo_merge($M)"
waited c3
expect_ok "c3 the undo goes through after the unvote" "$FAST"
expect "c3 the unvote came first: removed in the meantime, so not added back on either idea" \
  "$(voters "$S") / $(voters "$T")" "Author / Author"

echo "== c4. A vote on the SOURCE while an undo runs"
S=$(idea "R c4 source"); T=$(idea "R c4 target"); merge "$S" "$T"; M=$(merge_id "$S")
race c4 "$(as r-own1) select public.undo_merge($M)" "$(as r-h) insert into public.votes (idea_id) values ($S)"
waited c4
expect_ok "c4 the vote goes through once the idea is back" "$FAST"
expect "c4 the vote stays on the source" "$(voters "$S") / $(voters "$T")" "Author,Voter H / Author"

echo "== c5. A comment on the SOURCE and one on the TARGET while an undo runs"
S=$(idea "R c5 source"); T=$(idea "R c5 target"); merge "$S" "$T"; M=$(merge_id "$S")
race c5 "$(as r-own1) select public.undo_merge($M)" "$(as r-c) insert into public.comments (idea_id, body) values ($S, 'R c5: on the source during the undo'), ($T, 'R c5: on the target during the undo')"
waited c5
expect_ok "c5 both comments go through" "$FAST"
expect "c5 each stays where it was written" \
  "$(sql "select string_agg(idea_id::text, ',' order by body) from public.comments where body like 'R c5:%'")" "$S,$T"

echo "== d1. Two owners merge the same source into two targets at the same moment"
S=$(idea "R d1 source"); T1=$(idea "R d1 target one"); T2=$(idea "R d1 target two"); vote r-a "$S"
race d1 "$(as r-own1) select public.merge_ideas($S, $T1)" "$(as r-own2) select public.merge_ideas($S, $T2)"
waited d1
expect_has "d1 the second owner is told, in words" "$FAST" "This idea has already been merged."
expect "d1 merged once, into the first target; the second target is untouched" \
  "$(state "$S") / $(voters "$T1") / $(voters "$T2")" "0 votes, 0 comments, merged into $T1, voters: none / Author,Voter A / Author"
expect "d1 one merge in the log" "$(sql "select count(*) from public.idea_merges where source_id = $S")" "1"

echo "== d2. Two owners undo the same merge at the same moment"
S=$(idea "R d2 source"); T=$(idea "R d2 target"); vote r-b "$S"; merge "$S" "$T"; M=$(merge_id "$S")
race d2 "$(as r-own1) select public.undo_merge($M)" "$(as r-own2) select public.undo_merge($M)"
waited d2
expect_has "d2 the second owner is told, in words" "$FAST" "This merge has already been undone."
expect "d2 undone once: both ideas exactly as before" "$(voters "$S") / $(voters "$T")" "Author,Voter B / Author"

echo "== d3. An undo and a merge of its target at the same moment (the merge first)"
S=$(idea "R d3 source"); T=$(idea "R d3 target"); U=$(idea "R d3 other"); merge "$S" "$T"; M=$(merge_id "$S")
race d3 "$(as r-own2) select public.merge_ideas($T, $U)" "$(as r-own1) select public.undo_merge($M)"
waited d3
expect_has "d3 the undo is refused, in words" "$FAST" "“R d3 target” has itself been merged into another idea since. Undo that merge first"
expect "d3 the source follows its target into the other idea" "$(state "$S")" "0 votes, 0 comments, merged into $U, voters: none"

echo "== d4. An undo and a merge of its target at the same moment (the undo first)"
S=$(idea "R d4 source"); T=$(idea "R d4 target"); U=$(idea "R d4 other"); merge "$S" "$T"; M=$(merge_id "$S")
race d4 "$(as r-own1) select public.undo_merge($M)" "$(as r-own2) select public.merge_ideas($T, $U)"
waited d4
expect_ok "d4 the merge goes through after the undo" "$FAST"
expect "d4 the source is back on the board and is not dragged along" "$(state "$S")" "1 votes, 0 comments, merged into -, voters: Author"
expect "d4 the target is merged into the other idea" "$(sql "select merged_into_id from public.ideas where id = $T")" "$U"

echo "== d5. Lock order: an undo and a merge that both touch an idea merged earlier (no deadlock)"
# A was merged into S, S into T. One owner undoes S->T while another merges T into U:
# both must touch A, S and T, and both take them in id order, so neither deadlocks.
A=$(idea "R d5 older"); S=$(idea "R d5 source"); T=$(idea "R d5 target"); U=$(idea "R d5 other")
merge "$A" "$S"; merge "$S" "$T"; M=$(merge_id "$S")
race d5 "$(as r-own1) select public.undo_merge($M)" "$(as r-own2) select public.merge_ideas($T, $U)"
waited d5
expect_ok "d5 no deadlock, and the merge goes through after the undo" "$FAST$SLOW"
expect "d5 the older idea points at the source again, the source is back" \
  "$(sql "select merged_into_id from public.ideas where id = $A") / $(sql "select coalesce(merged_into_id::text, '-') from public.ideas where id = $S")" "$S / -"

echo "== d6. An undo and a merge of its target queue behind a third request on the source (queue order)"
# The gate holds the source's row (as a vote on it would). The undo of S->T
# queues for it first; the merge of T into U starts after it. Now every idea
# both change is locked in one statement in id order, so they go in the order
# they queued: the undo, then the merge. (Before task F6b the merge did not
# lock the source first, went ahead of the undo, and the undo was refused.)
S=$(idea "R d6 source"); T=$(idea "R d6 target"); U=$(idea "R d6 other"); merge "$S" "$T"; M=$(merge_id "$S")
race3 d6 "select 1 from public.ideas where id = $S for key share" \
  "$(as r-own1) select public.undo_merge($M)" "$(as r-own2) select public.merge_ideas($T, $U)"
expect "d6 neither owner hits a deadlock" "$(printf '%s %s' "$ONE" "$TWO" | grep -c 'deadlock detected')" "0"
expect_ok "d6 the undo, which came first, goes through" "$ONE"
expect_ok "d6 then the merge goes through" "$TWO"
expect "d6 the source is back on the board; the target is merged into the other idea" \
  "$(sql "select coalesce(merged_into_id::text, '-') from public.ideas where id = $S") / $(sql "select merged_into_id from public.ideas where id = $T")" "- / $U"

echo "== d7. A merge and an undo queue behind a third request on the target (the deadlock case)"
# The gate holds the target's row. The merge of T into U queues for it first;
# the undo of S->T starts after it. Before task F6b the undo took S at once and
# then waited for T, while the merge, once it had T, waited for S to point it
# at U: a deadlock, and Postgres cancelled one of the two with an error.
S=$(idea "R d7 source"); T=$(idea "R d7 target"); U=$(idea "R d7 other"); merge "$S" "$T"; M=$(merge_id "$S")
race3 d7 "select 1 from public.ideas where id = $T for key share" \
  "$(as r-own2) select public.merge_ideas($T, $U)" "$(as r-own1) select public.undo_merge($M)"
expect "d7 neither owner hits a deadlock" "$(printf '%s %s' "$ONE" "$TWO" | grep -c 'deadlock detected')" "0"
expect_ok "d7 the merge, which came first, goes through" "$ONE"
expect_has "d7 the undo is then refused, in words" "$TWO" "“R d7 target” has itself been merged into another idea since. Undo that merge first"
expect "d7 the source follows its target into the other idea" "$(sql "select merged_into_id from public.ideas where id = $S")" "$U"

echo "== Back to the normal local database"
reset
echo
if [[ $FAILURES -eq 0 ]]; then
  echo "Race tests: all $CHECKS expectations met."
else
  echo "Race tests: $FAILURES of $CHECKS expectations NOT met."
  exit 1
fi
