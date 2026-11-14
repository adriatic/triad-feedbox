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
# prod after the migration, prod with its board), runs every check where it
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
                + (select count(*) from public.profiles) as n', false, false, '')))[1]::text end, 'none'))"
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

echo "== A. Local database with the Lumen seed (marker: local)"
reset
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

echo "== B. An empty project, like feedbox-prod tonight (migration undone, no marker)"
reset --no-seed
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

echo "== E. Back to the normal local database"
reset
echo
if [[ $FAILURES -eq 0 ]]; then
  echo "SQL checks: all $CHECKS expectations met."
else
  echo "SQL checks: $FAILURES of $CHECKS expectations NOT met."
  exit 1
fi
