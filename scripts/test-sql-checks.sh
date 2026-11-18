#!/usr/bin/env bash
# Tests the SQL scripts Nik pastes (task F3c), against the LOCAL Supabase
# database in Docker only (container supabase_db_triad-feedbox). Never a
# hosted project. Used by `npm run test:checks` and by the CI job `db`.
#
# Each script is sent the way the Supabase SQL Editor sends a pasted query:
# the whole text as ONE query string (psql -c), so all its statements run in
# one transaction. "Pasted twice" means the file's text twice in one query.
#
# It walks the database through the real states (Lumen preview, empty prod,
# prod after the migration, prod with its board, prod with Nik as its owner,
# then the O2 migration on prod and on preview), runs every check where it
# should PASS and where it should FAIL, and every changing script where it
# should refuse, and confirms that a refusal changed nothing.
# It resets the local database at the start and at the end.
set -uo pipefail

cd "$(dirname "$0")/.."
CONTAINER=supabase_db_triad-feedbox
FAILURES=0
CHECKS=0

sql() { # one query string, as the SQL Editor sends it
  docker exec -i "$CONTAINER" psql -U postgres -d postgres -X -q -At -F'|' -v ON_ERROR_STOP=1 -c "$1" 2>&1
}
twice() { cat "$1" "$1"; }

ok()   { CHECKS=$((CHECKS + 1)); echo "  ok   $1"; }
bad()  { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); echo "  FAIL $1"; }

# expect_check <check file> <PASS|FAIL> [sql to run first, in the same rolled-back transaction]
expect_check() {
  local file="supabase/checks/$1.sql" want="$2" setup="${3:-}" out overall
  if [[ -n "$setup" ]]; then
    out=$(sql "begin; $setup; $(cat "$file") rollback;")
  else
    out=$(sql "$(cat "$file")")
  fi
  overall=$(printf '%s\n' "$out" | grep '^0|overall|' | cut -d'|' -f3)
  if [[ "$overall" == "$want" ]]; then
    ok "$1 -> $want${setup:+ (after: $setup)}"
  else
    bad "$1 -> expected $want, got '${overall:-an error}'"
  fi
  # Show the overall row and every failing row, so the log explains a FAIL.
  printf '%s\n' "$out" | grep -E '^0\||\|FAIL\||ERROR' | grep -v 'not checked, because check 1' | sed 's/^/         /'
}

# digest: what a refusal must leave unchanged. It reads triad.project and the
# Feedbox tables only through guarded query_to_xml, so it works in every state.
digest() {
  sql "select concat_ws(' ',
    'marker=' || coalesce(case when to_regclass('triad.project') is not null then
        (xpath('/table/row/name/text()', query_to_xml('select name from triad.project', false, false, '')))[1]::text end, 'none'),
    'boards_table=' || coalesce(to_regclass('public.boards')::text, 'none'),
    'private=' || coalesce(to_regnamespace('private')::text, 'none'),
    'people=' || (select count(*) from auth.users),
    'functions=' || (select count(*) from pg_proc where pronamespace = 'public'::regnamespace),
    'rows=' || coalesce(case when to_regclass('public.boards') is not null then
        (xpath('/table/row/n/text()', query_to_xml(
          'select (select count(*) from public.boards) + (select count(*) from public.ideas)
                + (select count(*) from public.votes) + (select count(*) from public.comments)
                + (select count(*) from public.profiles) + (select count(*) from public.board_owners) as n',
          false, false, '')))[1]::text end, 'none'))"
}

# expect_refusal <label> <sql text> <phrase in the error message>
expect_refusal() {
  local label="$1" text="$2" phrase="$3" before after out
  before=$(digest)
  out=$(sql "$text")
  after=$(digest)
  if printf '%s' "$out" | grep -q "ERROR:.*$phrase" && [[ "$before" == "$after" ]]; then
    ok "$label -> refused with an error, nothing changed"
  else
    bad "$label -> expected a refusal containing '$phrase' and no change"
    echo "         before: $before"; echo "         after:  $after"
  fi
  printf '%s\n' "$out" | grep -o 'ERROR:.*' | head -1 | sed 's/^/         /'
}

# expect_success <label> <sql text>
expect_success() {
  local out
  out=$(sql "$2")
  if printf '%s' "$out" | grep -q 'ERROR'; then
    bad "$1 -> expected success"; printf '%s\n' "$out" | sed 's/^/         /'
  else
    ok "$1 -> success"
  fi
}

reset() { npx supabase db reset "$@" >/dev/null 2>&1 || { echo "db reset failed"; exit 1; }; }
# The states before task O2 have only the Feedbox v1 migration.
V1=20261113000000
reset_v1() { reset --version "$V1" "$@"; }

# person <name>: one signed-up person, the way Supabase Auth adds one (the
# trigger on auth.users creates the profile, with no display name yet).
person() {
  printf '%s' "insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token,
    email_change_token_new, email_change, email_change_token_current, reauthentication_token,
    phone_change, phone_change_token)
  values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
    '$1@feedbox.test', now(), '{}'::jsonb, '{}'::jsonb, now(), now(),
    '', '', '', '', '', '', '', '')"
}
OWNER=supabase/production/owner-nik.sql
APPLY_PREVIEW=supabase/apply/preview-board-owner-ids.sql
APPLY_PROD=supabase/apply/prod-board-owner-ids.sql

echo "== A. Local database with the Lumen seed (marker: local), Feedbox v1 migration only"
reset_v1
expect_check preview-seed FAIL
echo "   Marking it as feedbox-preview (test only), so it looks like feedbox-preview tonight:"
sql "update triad.project set name = 'feedbox-preview'" >/dev/null
expect_check preview-seed PASS
expect_check preview-seed FAIL "delete from public.votes where ctid = (select ctid from public.votes limit 1)"
expect_check preview-seed FAIL "grant insert on public.ideas to anon"
expect_check prod-before-migration FAIL
expect_check prod-after-migration FAIL
expect_check prod-ready-for-board FAIL
expect_check prod-board FAIL
expect_refusal "seed again" "$(cat supabase/seed.sql)" "already exists"
expect_refusal "seed pasted twice" "$(twice supabase/seed.sql)" "pasted twice"
expect_refusal "migration again" "$(cat supabase/migrations/20261113000000_feedbox_v1.sql)" "already exists"
expect_refusal "marker feedbox-preview again" "$(cat supabase/marker/feedbox-preview.sql)" "already marked as feedbox-preview"
expect_refusal "marker feedbox-prod in preview" "$(cat supabase/marker/feedbox-prod.sql)" "already marked as feedbox-preview"
expect_refusal "board script in preview" "$(cat supabase/production/board-feedbox.sql)" "marked feedbox-preview"
expect_refusal "undo in preview" "$(cat supabase/production/undo-feedbox-v1.sql)" "has rows"
expect_check prod-owner FAIL
expect_refusal "owner script in preview" "$(cat $OWNER)" "marked feedbox-preview"

echo "== B. An empty project, like feedbox-prod tonight (migration undone, no marker)"
reset_v1 --no-seed
expect_success "undo on the empty migration" "$(cat supabase/production/undo-feedbox-v1.sql)"
expect_check prod-before-migration FAIL
expect_refusal "marker feedbox-preview in prod" "$(cat supabase/marker/feedbox-preview.sql)" "no Feedbox tables"
expect_refusal "seed in prod (no Feedbox tables)" "$(cat supabase/seed.sql)" "does not exist"
expect_refusal "marker feedbox-prod pasted twice" "$(twice supabase/marker/feedbox-prod.sql)" "pasted twice"
expect_success "marker feedbox-prod" "$(cat supabase/marker/feedbox-prod.sql)"
expect_refusal "marker feedbox-prod again" "$(cat supabase/marker/feedbox-prod.sql)" "already marked as feedbox-prod"
expect_check prod-before-migration PASS
expect_check prod-before-migration FAIL "create table public.boards (id int)"
expect_check prod-after-migration FAIL
expect_check prod-ready-for-board FAIL
expect_check prod-board FAIL
expect_check preview-seed FAIL
expect_refusal "board script before the migration" "$(cat supabase/production/board-feedbox.sql)" "not applied"
expect_refusal "undo when already undone" "$(cat supabase/production/undo-feedbox-v1.sql)" "already run"

echo "== C. feedbox-prod after the migration (M3)"
expect_refusal "migration pasted twice (no guard in the migration: Postgres's own error)" "$(twice supabase/migrations/20261113000000_feedbox_v1.sql)" "already exists"
expect_check prod-before-migration PASS
expect_success "migration" "$(cat supabase/migrations/20261113000000_feedbox_v1.sql)"
expect_check prod-after-migration PASS
expect_check prod-ready-for-board PASS
expect_refusal "seed pasted twice into one query, on a fresh migration" "$(twice supabase/seed.sql)" "pasted twice into one query. Nothing was changed: the whole query is undone"
expect_check prod-ready-for-board PASS
expect_check prod-after-migration FAIL "grant update (status) on public.ideas to authenticated"
expect_check prod-after-migration FAIL "alter table public.votes disable row level security"
expect_check prod-after-migration FAIL "create or replace function public.has_display_name() returns boolean language sql set search_path = '' as \$f\$ select true \$f\$"
expect_check prod-before-migration FAIL
expect_check prod-board FAIL
expect_check preview-seed FAIL
expect_refusal "migration again" "$(cat supabase/migrations/20261113000000_feedbox_v1.sql)" "already exists"
expect_refusal "undo pasted twice" "$(twice supabase/production/undo-feedbox-v1.sql)" "pasted twice"
expect_check prod-after-migration PASS

echo "== D. feedbox-prod with its board (M3)"
expect_refusal "board script pasted twice" "$(twice supabase/production/board-feedbox.sql)" "pasted twice"
expect_check prod-ready-for-board PASS
expect_success "board script" "$(cat supabase/production/board-feedbox.sql)"
expect_check prod-board PASS
expect_check prod-board FAIL "update public.boards set tagline = 'Something else'"
expect_check prod-board FAIL "insert into public.boards (slug, name) values ('other', 'Other')"
expect_check prod-ready-for-board FAIL
expect_check prod-after-migration FAIL
expect_refusal "board script again" "$(cat supabase/production/board-feedbox.sql)" "already has a board"
expect_refusal "undo with the board" "$(cat supabase/production/undo-feedbox-v1.sql)" "has rows"

echo "== F. feedbox-prod with its board: Nik signs in, then becomes its owner (O1)"
expect_check prod-owner FAIL
expect_refusal "owner script with no person" "$(cat $OWNER)" "no person yet"
expect_success "Nik signs in for the first time (test person, no display name yet)" "$(person o1-nik)"
expect_refusal "owner script before the display name is set" "$(cat $OWNER)" "(none yet)"
expect_success "Nik sets his display name" "update public.profiles set display_name = 'Nikolaj Ivancic'"
expect_check prod-owner FAIL
expect_refusal "owner script, project marked feedbox-preview" "update triad.project set name = 'feedbox-preview'; $(cat $OWNER)" "marked feedbox-preview"
expect_refusal "owner script, migration changed" "grant insert on public.ideas to anon; $(cat $OWNER)" "does not match the reviewed Feedbox v1 migration"
expect_refusal "owner script, no board" "delete from public.boards; $(cat $OWNER)" "no board"
expect_refusal "owner script, two people" "$(person o1-other); $(cat $OWNER)" "has 2 people"
expect_refusal "owner script, another display name" "update public.profiles set display_name = 'Someone Else'; $(cat $OWNER)" "Someone Else"
expect_refusal "owner script pasted twice" "$(twice $OWNER)" "pasted twice into one query. Nothing was changed: the whole query is undone"
expect_check prod-owner FAIL
expect_success "owner script" "$(cat $OWNER)"
expect_check prod-owner PASS
expect_check prod-owner FAIL "update public.profiles set display_name = 'Someone Else'"
expect_check prod-owner FAIL "$(person o1-other); insert into public.board_owners (board_id, user_id) select b.id, u.id from public.boards b, auth.users u where u.email = 'o1-other@feedbox.test'"
expect_check prod-owner FAIL "delete from public.board_owners"
expect_check prod-owner FAIL "update triad.project set name = 'feedbox-preview'"
expect_check prod-owner FAIL "grant insert on public.ideas to anon"
expect_check prod-board PASS
expect_refusal "owner script again" "$(cat $OWNER)" "already an owner"

echo "== G. feedbox-prod with Nik as owner: the O2 migration (board_owner_ids)"
expect_check prod-board-owner-ids FAIL
expect_refusal "O2 preview script in prod" "$(cat $APPLY_PREVIEW)" "only for feedbox-preview"
expect_refusal "O2 prod script, migration changed" "grant insert on public.ideas to anon; $(cat $APPLY_PROD)" "does not match the reviewed Feedbox v1 migration"
expect_refusal "O2 prod script, no Feedbox tables" "drop table public.changelog_items, public.changelog_entries, public.comments, public.votes, public.ideas, public.board_owners, public.profiles, public.boards cascade; $(cat $APPLY_PROD)" "not applied"
expect_refusal "O2 prod script pasted twice" "$(twice $APPLY_PROD)" "pasted twice into one query. Nothing was changed: the whole query is undone"
expect_check prod-owner PASS
expect_success "O2 prod script" "$(cat $APPLY_PROD)"
expect_check prod-board-owner-ids PASS
expect_check preview-board-owner-ids FAIL
expect_check prod-board-owner-ids FAIL "update triad.project set name = 'feedbox-preview'"
expect_check prod-board-owner-ids FAIL "grant execute on function public.board_owner_ids(uuid) to public"
expect_check prod-board-owner-ids FAIL "revoke execute on function public.board_owner_ids(uuid) from anon"
expect_check prod-board-owner-ids FAIL "alter function public.board_owner_ids(uuid) reset search_path"
expect_check prod-board-owner-ids FAIL "alter function public.board_owner_ids(uuid) security invoker"
expect_check prod-board-owner-ids FAIL "delete from public.board_owners"
expect_check prod-board-owner-ids FAIL "create or replace function public.board_owner_ids(p_board_id uuid) returns setof uuid language sql stable security definer set search_path = '' as \$f\$ select o.user_id from public.board_owners o \$f\$"
expect_check prod-board-owner-ids FAIL "grant insert on public.ideas to anon"
expect_check prod-board-owner-ids FAIL "drop function public.board_owner_ids(uuid)"
expect_refusal "O2 prod script again" "$(cat $APPLY_PROD)" "already exists"
expect_refusal "O2 prod script, function dropped and project marked feedbox-preview" "drop function public.board_owner_ids(uuid); update triad.project set name = 'feedbox-preview'; $(cat $APPLY_PROD)" "only for feedbox-prod"
expect_check prod-board-owner-ids PASS

echo "== H. feedbox-preview (Lumen) before and after the O2 migration"
reset_v1
sql "update triad.project set name = 'feedbox-preview'" >/dev/null
expect_check preview-seed PASS
expect_check preview-board-owner-ids FAIL
expect_refusal "O2 prod script in preview" "$(cat $APPLY_PROD)" "only for feedbox-prod"
expect_refusal "O2 preview script pasted twice" "$(twice $APPLY_PREVIEW)" "pasted twice into one query. Nothing was changed: the whole query is undone"
expect_success "O2 preview script" "$(cat $APPLY_PREVIEW)"
expect_check preview-board-owner-ids PASS
expect_check prod-board-owner-ids FAIL
expect_check preview-board-owner-ids FAIL "revoke execute on function public.board_owner_ids(uuid) from authenticated"
expect_check preview-board-owner-ids FAIL "grant insert on public.ideas to anon"
expect_refusal "O2 preview script again" "$(cat $APPLY_PREVIEW)" "already exists"
echo "   After O2 the older checks no longer match (the fingerprint now includes board_owner_ids):"
expect_check preview-seed FAIL

echo "== I. The local database as supabase db reset builds it (both migrations)"
reset
sql "update triad.project set name = 'feedbox-preview'" >/dev/null
echo "   The migration file gives the same database as the pasted script:"
expect_check preview-board-owner-ids PASS
expect_refusal "O2 preview script on the full local database" "$(cat $APPLY_PREVIEW)" "already exists"

echo "== J. feedbox-preview: Nik becomes an owner of lumen (task F6)"
NIK=supabase/preview/owner-nik.sql
expect_check preview-owner-nik FAIL
expect_refusal "preview owner script with no Nik I." "$(cat $NIK)" "no person outside the Lumen people"
expect_success "Nik signs in on the Preview (test person)" "$(person j-nik)"
expect_success "Nik sets his display name" "update public.profiles set display_name = 'Nik I.' where id = (select id from auth.users where email = 'j-nik@feedbox.test')"
expect_refusal "preview owner script, a Lumen person named Nik I. does not count twice" "update public.profiles set display_name = 'Nik I.' where id = (select id from auth.users where email like '%@lumen.example' order by email limit 1); update public.profiles set display_name = 'Nik J.' where id = (select id from auth.users where email = 'j-nik@feedbox.test'); $(cat $NIK)" "no person outside the Lumen people"
expect_refusal "preview owner script, project marked feedbox-prod" "update triad.project set name = 'feedbox-prod'; $(cat $NIK)" "only for feedbox-preview"
expect_refusal "preview owner script, migration changed" "grant insert on public.ideas to anon; $(cat $NIK)" "does not match the reviewed Feedbox v1 and O2 migrations"
expect_refusal "preview owner script, no board lumen" "update public.boards set slug = 'other' where slug = 'lumen'; $(cat $NIK)" "no board"
expect_refusal "preview owner script, two people named Nik I." "$(person j-nik2); update public.profiles set display_name = 'Nik I.' where id = (select id from auth.users where email = 'j-nik2@feedbox.test'); $(cat $NIK)" "2 people outside the Lumen people"
expect_refusal "preview owner script pasted twice" "$(twice $NIK)" "pasted twice into one query. Nothing was changed: the whole query is undone"
expect_check preview-owner-nik FAIL
expect_success "preview owner script" "$(cat $NIK)"
expect_check preview-owner-nik PASS
expect_check preview-owner-nik FAIL "update triad.project set name = 'feedbox-prod'"
expect_check preview-owner-nik FAIL "delete from public.board_owners where user_id = (select id from auth.users where email = 'j-nik@feedbox.test')"
expect_check preview-owner-nik FAIL "update public.profiles set display_name = 'Nik J.' where id = (select id from auth.users where email = 'j-nik@feedbox.test')"
expect_check preview-owner-nik FAIL "insert into public.board_owners (board_id, user_id) select b.id, u.id from public.boards b, auth.users u where b.slug = 'lumen' and u.email = 'sam@lumen.example'"
expect_check preview-owner-nik FAIL "grant insert on public.ideas to anon"
expect_check preview-board-owner-ids PASS
expect_refusal "preview owner script again" "$(cat $NIK)" "already an owner"

echo "== K. Removing a person on request (task F6): the template, and a copy for one request"
REMOVE=supabase/people/remove-person.sql
COPIES=$(mktemp -d)
trap 'rm -rf "$COPIES" supabase/checks/zz-person-removal-test.sql' EXIT
OFFLINE_BASE=$(sql "select vote_count || '/' || comment_count from public.ideas where title = 'Offline mode'")
# A copy for one request: only the two values in the block "request" change (tests/sql-files.test.ts).
copy_for() { # <template> <project> <person id> <out>
  sed -e "s/'none'/'$2'/" -e "s/'00000000-0000-0000-0000-000000000000'/'$3'/" "$1" > "$4"
}
expect_success "Del signs in and writes (test person)" "$(person k-del); update public.profiles set display_name = 'Del E.' where id = (select id from auth.users where email = 'k-del@feedbox.test');
  insert into public.ideas (board_id, author_id, title) select b.id, u.id, 'K idea by Del' from public.boards b, auth.users u where b.slug = 'lumen' and u.email = 'k-del@feedbox.test';
  insert into public.votes (idea_id, user_id) select i.id, u.id from public.ideas i, auth.users u where i.title = 'Offline mode' and u.email = 'k-del@feedbox.test';
  insert into public.comments (idea_id, author_id, body) select i.id, u.id, 'K comment by Del' from public.ideas i, auth.users u where i.title = 'Offline mode' and u.email = 'k-del@feedbox.test';
  insert into public.comments (idea_id, author_id, body) select i.id, u.id, 'K comment by Nik on Del''s idea' from public.ideas i, auth.users u where i.title = 'K idea by Del' and u.email = 'j-nik@feedbox.test'"
DEL=$(sql "select id from auth.users where email = 'k-del@feedbox.test'")
copy_for "$REMOVE" feedbox-preview "$DEL" "$COPIES/remove.sql"
copy_for supabase/checks/person-removal.sql feedbox-preview "$DEL" supabase/checks/zz-person-removal-test.sql
copy_for "$REMOVE" feedbox-prod "$DEL" "$COPIES/remove-prod.sql"
expect_refusal "removal template as it is" "$(cat $REMOVE)" "this is the template"
expect_check person-removal FAIL
echo "   Before the removal, the copy of the check says what is still there:"
expect_check zz-person-removal-test FAIL
expect_refusal "removal copy for feedbox-prod, run in feedbox-preview" "$(cat $COPIES/remove-prod.sql)" "only for feedbox-prod"
expect_refusal "removal copy, migration changed" "grant insert on public.ideas to anon; $(cat $COPIES/remove.sql)" "does not match the reviewed Feedbox v1 and O2 migrations"
expect_refusal "removal copy, the person owns a board" "insert into public.board_owners (board_id, user_id) select b.id, '$DEL' from public.boards b where b.slug = 'lumen'; $(cat $COPIES/remove.sql)" "owns 1 board"
expect_refusal "removal copy, another idea was merged into the person's idea" "insert into public.ideas (board_id, author_id, title) select b.id, u.id, 'K merged into Del' from public.boards b, auth.users u where b.slug = 'lumen' and u.email = 'j-nik@feedbox.test'; update public.ideas set merged_into_id = (select id from public.ideas where title = 'K idea by Del') where title = 'K merged into Del'; $(cat $COPIES/remove.sql)" "merged into ideas by this person"
expect_refusal "removal copy pasted twice" "$(twice $COPIES/remove.sql)" "pasted twice into one query: then nothing was changed"
expect_success "removal copy" "$(cat $COPIES/remove.sql)"
expect_check zz-person-removal-test PASS
OFFLINE_AFTER=$(sql "select vote_count || '/' || comment_count from public.ideas where title = 'Offline mode'")
if [[ -n "$OFFLINE_BASE" && "$OFFLINE_AFTER" == "$OFFLINE_BASE" ]]; then
  ok "the counts follow: Offline mode is back to $OFFLINE_BASE votes/comments without Del's vote and comment"
else
  bad "the counts on Offline mode: $OFFLINE_AFTER after the removal (expected $OFFLINE_BASE, as before Del)"
fi
expect_check zz-person-removal-test FAIL "update triad.project set name = 'feedbox-prod'"
expect_check preview-owner-nik PASS
expect_refusal "removal copy again" "$(cat $COPIES/remove.sql)" "no person with the id"
rm -rf "$COPIES" supabase/checks/zz-person-removal-test.sql

echo "== E. Back to the normal local database"
reset
echo
if [[ $FAILURES -eq 0 ]]; then
  echo "SQL checks: all $CHECKS expectations met."
else
  echo "SQL checks: $FAILURES of $CHECKS expectations NOT met."
  exit 1
fi
