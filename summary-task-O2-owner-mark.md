# Task O2: the Owner mark for everyone (decision F5-D1)

Branch `o2-owner-mark`, pull request #9 (not merged): https://github.com/adriatic/triad-feedbox/pull/9. Head: `1e653ff3519fd6637259ff52d984c874f27d8713`.
Nothing ran against feedbox-preview or feedbox-prod. No dashboard setting changed. The Feedbox v1 migration is untouched.

## Is TRIAD ready? (run first, on main at ed9b1fb)

`/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh`, exit code 0:

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit ed9b1fb A1: the Feedbox architecture description (docs/ARCHITECTURE.md) (#8). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 142 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 843cf26).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit ed9b1fb, 2026-11-18T20:54:39Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
```

## What changed

- **Database: a new migration, `supabase/migrations/20261118000000_board_owner_ids.sql`.**
  - It adds `public.board_owner_ids(p_board_id uuid) returns setof uuid`: the user ids of that board's owners and nothing else (no email, no name, no other column).
  - Security definer, `search_path = ''`, stable.
  - Execute is revoked from public, anon and authenticated, then granted to anon and authenticated.
  - `board_owners` and its policy `board_owners_read` are unchanged.
  - The migration is pinned by its sha256 in `tests/sql-files.test.ts` (`e5b84fb52cea9182e085778f421ced8ec956e7d8dfe755d4be73ca81828cfa52`), the same way as the v1 migration. From now on it is never edited.
- **The app: `getOwnerIds` in `lib/supabase/data.ts`.**
  - It calls `board_owner_ids` for every viewer, visitors included. It no longer asks who is signed in (one Auth call less per idea page).
  - **If the function is missing** (before the migration has run in a project), or the call fails for any other reason, the idea page still loads and shows no Owner mark. The server log then reads: `Feedbox: no Owner mark on comments, because the board's owners could not be read (board_owner_ids: PGRST202 Could not find the function public.board_owner_ids(p_board_id) in the schema cache). Has the migration 20261118000000_board_owner_ids.sql run in this project?`
  - **How I made sure of that:**
    1. A unit test (`lib/supabase/data.test.ts`) gives `getOwnerIds` PostgREST's "function not found" error (PGRST202). It checks that the result is no owners and that the reason is logged once.
    2. A test by hand, on the Mac, with the real app and the local database:
       - I dropped the function from the local database and built and started the app.
       - The idea page "Dark mode for the editor" answered **HTTP 200** with its 3 comments and no Owner mark, and the server log showed exactly the line quoted above.
       - After the local database was rebuilt with the function, the same page showed "Owner" next to Ana's comment to a visitor.
- **SQL that Nik runs (SQL is code).** Four new files in two pairs, preview and prod:
  - **`supabase/apply/preview-board-owner-ids.sql` and `supabase/apply/prod-board-owner-ids.sql`: the migration as Nik pastes it.**
    - One do-block, so it is all or nothing.
    - It refuses, and changes nothing, in these cases:
      - in a project with no marker or another marker;
      - when the function already exists ("has run before");
      - when it was pasted twice into one query ("pasted twice …", found by comparing the function row's `xmin` with the current transaction);
      - unless the database has the reviewed Feedbox v1 migration, by the same fingerprint as the checks.
    - Its section 4 is the migration's statements word for word, and a unit test keeps them identical to the migration file. A new folder, `supabase/apply/`, holds these files, because they are neither a production-only script nor a check.
  - **`supabase/checks/preview-board-owner-ids.sql` and `supabase/checks/prod-board-owner-ids.sql`: the read-only check, PASS or FAIL in plain words.** Its rows:
    1. the project;
    2. the database is the v1 migration plus the O2 migration, both unchanged (fingerprint `ea60181fdd11e237aa19ee5d6d6c186d`);
    3. the function exists;
    4. it is security definer with `search_path=""`, stable, and returns `SETOF uuid`;
    5. anon and authenticated may execute it, and public may not;
    6. for every board it returns exactly that board's owners, with at least one owner in the project;
    7. it returns nothing for an unknown board.
  - **The preview and prod files differ only in the project they are for** (a unit test checks this). The prod versions are for the merge task only.
- **`docs/ARCHITECTURE.md`** (diff below) and **CLAUDE.md**: the Layout line for `supabase/` names `apply/`.

## Tests

- **pgTAP, `supabase/tests/11_board_owner_ids.sql` (new):**
  - The function exists, returns `setof uuid`, is security definer and stable, has `search_path=""`, and public may not execute it.
  - A visitor and a member each get exactly the two owners of board b1, and only the one owner of b2 for b2. A visitor gets nothing for an unknown board.
  - An owner of b2 gets b1's owners.
  - `board_owners` itself is unchanged:
    - a visitor gets "permission denied";
    - a member sees no row;
    - an owner of b1 still reads both rows.
  - With an owner's id, a visitor reads only the display name and still cannot read the email address.
- **pgTAP, `01_structure.sql`:** `board_owner_ids` is added to the list of what anon and authenticated may call (both: yes). Its "security definer function … sets search_path to empty" row covers the new function by itself.
- **All pgTAP:** 11 files, 243 tests, all pass, locally and in CI.
- **SQL scripts, `scripts/test-sql-checks.sh`:** all **114** expectations met, locally and in CI (job `db`).
  - Sections A to F, the states before O2, now start from the v1 migration only (`supabase db reset --version 20261113000000`).
  - **New section G, feedbox-prod with Nik as owner:**
    - the check FAILs before the script;
    - the preview script is refused;
    - the prod script is refused when the v1 migration was changed, when the tables are missing, and when it is pasted twice, each time with nothing changed;
    - after one run the check PASSes, and the preview check FAILs there (wrong project);
    - the check FAILs after each of these tampers: wrong marker, `grant … to public`, `revoke … from anon`, `search_path` reset, `security invoker`, no owners, a body that leaks other boards' owners, a changed table grant, and the function dropped;
    - a second run is refused.
  - **New section H, feedbox-preview with Lumen:** the same, plus the older check `preview-seed` PASSes before and FAILs after (see "After this migration").
  - **New section I, the database as `supabase db reset` builds it:** the preview check PASSes, so the migration file gives exactly the database the pasted script gives.
- **Unit:** 147 tests pass.
  - New in `lib/supabase/data.test.ts` (3 tests): `getOwnerIds` calls the function and asks nobody who is signed in; with the function missing it returns no owners and logs why; a board with no owner gives none.
  - New in `tests/sql-files.test.ts`:
    - the new migration's sha256;
    - the apply scripts hold its statements word for word;
    - they use the shared fingerprint block;
    - preview and prod files differ only in the project;
    - the new files have their header and footer lines.
  - `vitest.config.mts` learned the `@/` imports of `tsconfig.json` so that a test can load `data.ts`.
- **e2e:** 13 pass, locally and in CI. One test in `e2e/screens.spec.ts` is rewritten: "everyone sees the Owner mark on an owner's comment: owner, member and visitor (task O2, decision F5-D1)". On "Dark mode for the editor", the owner, then the same person as a member, then a visitor (signed out) each see "Owner" next to Ana's comment, and not next to Tom R.'s; for the member and the visitor it is the only mark. Run against the old `data.ts`, the test fails ("Owner" not found).

## Images remade

- **`screenshots/F5/`:** the 8 images of `idea-visitor` and `idea-signed-in` (light and dark, 1280 and 390) were recaptured; they now show "Owner" next to Ana. The "Check your email" images differed only in the test address with its timestamp and were left as they were. All the others came out identical. Still 68 images.
- **`/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/Idea.png`:** remade, and it came out **byte for byte identical**. The design `Idea.dc.html` shows the page signed in as owner ("Signed in as owner"), so the side-by-side uses the owner's state, which already had the mark. The other five also came out identical.

## Results

- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/9
- **Head:** `1e653ff3519fd6637259ff52d984c874f27d8713` on `o2-owner-mark`
- **CI on 1e653ff:**

  | Check | push run 44413036085 | pull request run 44413078799 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on 1e653ff, "Deployment has completed".
- **Preview:** https://triad-feedbox-git-o2-owner-mark-nikolaj-ivancics-projects.vercel.app

## The order (migration first, then merge): I agree

The order in the task is right: Nik runs the migration and its check on feedbox-preview now, checks the Preview, and only in the merge task runs the same two scripts on feedbox-prod, before the pull request is merged. The database then always has the function before any code that calls it is deployed there.

The app adds a safety net. If the order were ever broken, Production would not fail: it would only show no Owner mark, and the server log would say why. Two additions make it safer still:
1. **In the merge task, the check script `prod-board-owner-ids.sql` must PASS right before the merge** (the same session, not hours earlier). The merge task stops if it does not.
2. **After the merge,** one step on Production as a visitor: open an idea with a comment by Nik, and see "Owner" next to it. If there is no such comment yet, skip this step; the check script has already shown that the function returns Nik's id.

The migration only adds a function and changes nothing in the tables, so running it on feedbox-prod before the merge has no effect on the Production app of today.

## After this migration: the older check scripts no longer PASS

These check scripts compare the database with the fingerprint of the v1 migration alone:
- `preview-seed.sql`
- `prod-after-migration.sql`
- `prod-ready-for-board.sql`
- `prod-board.sql`
- `prod-owner.sql`

On a project where the O2 migration has run, they FAIL on row 2 ("does not match the reviewed Feedbox v1 migration", fingerprint `ea60181fdd11e237aa19ee5d6d6c186d`), as section H of the tests shows. They belong to past moments (M3, O1) and are not run again. From O2 on, the new checks are the ones to use. No decision is needed. A later task that needs one of those checks again should give it the new fingerprint.

## The SQL, in full

All links are pinned to the head commit `1e653ff3519fd6637259ff52d984c874f27d8713`.

### `supabase/migrations/20261118000000_board_owner_ids.sql` (38 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/migrations/20261118000000_board_owner_ids.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/migrations/20261118000000_board_owner_ids.sql

```sql
-- =============================================================================
-- Feedbox O2: who owns a board, readable by everyone (decision F5-D1, Nik,
-- 2026-11-18 1:08 PM). Task O2.
--
-- * Adds ONE function, public.board_owner_ids(p_board_id), that returns the
--   user ids of the board's owners and nothing else: no email, no name, no
--   other column. The app uses it to show the "Owner" mark next to a comment
--   written by an owner, for every viewer (visitors and members too).
-- * public.board_owners and its policy board_owners_read are NOT changed: a
--   direct read of the table still shows an owner every owner, and anyone
--   else at most their own row.
-- * Security definer, so it can read board_owners past row-level security;
--   search_path is '' and every name is written in full. Stable: it only reads.
-- * Execute is revoked from public, anon and authenticated (the hosted projects
--   grant new functions automatically), then granted to anon and authenticated.
-- * The Feedbox v1 migration (20261113000000) is never edited; this is a new
--   migration. Nik pastes it on a hosted project through the guarded copy in
--   supabase/apply/ (task O2), which runs exactly the statements below.
-- =============================================================================

create function public.board_owner_ids(p_board_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.user_id
  from public.board_owners o
  where o.board_id = p_board_id
  order by o.user_id;
$$;

comment on function public.board_owner_ids(uuid) is
  'The user ids of the owners of one board, and nothing else. Readable by everyone (decision F5-D1, task O2).';

revoke all on function public.board_owner_ids(uuid) from public, anon, authenticated;
grant execute on function public.board_owner_ids(uuid) to anon, authenticated;
```

### `supabase/apply/preview-board-owner-ids.sql` (161 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/apply/preview-board-owner-ids.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/apply/preview-board-owner-ids.sql

```sql
-- supabase/apply/preview-board-owner-ids.sql | 161 lines | last line: -- end of preview-board-owner-ids.sql
-- =============================================================================
-- Applies the migration supabase/migrations/20261118000000_board_owner_ids.sql
-- on feedbox-preview only (task O2, decision F5-D1). CHANGES the database: adds ONE
-- function, public.board_owner_ids, and its grants. Nothing else.
-- Run once in the Supabase SQL Editor of feedbox-preview, in task O2, before the pull request is merged.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-preview; the function does not exist yet; and the
--   reviewed Feedbox v1 migration is present unchanged (the same fingerprint
--   as the check scripts). If the script was pasted twice into one query, the
--   message says so.
-- * Section 4 is the migration's statements word for word;
--   tests/sql-files.test.ts keeps them identical to the migration file.
-- * Check afterwards with supabase/checks/preview-board-owner-ids.sql.
-- =============================================================================

do $o2$
declare
  v_project  text;
  v_md5      text;
  v_same_txn boolean;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-preview. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-preview' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-preview. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse to run twice (also when pasted twice into one query).
  if to_regprocedure('public.board_owner_ids(uuid)') is not null then
    select p.xmin::text = (pg_current_xact_id()::xid)::text into v_same_txn
    from pg_proc p where p.oid = to_regprocedure('public.board_owner_ids(uuid)');
    if v_same_txn then
      raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
    end if;
    raise exception 'Refused: the function public.board_owner_ids already exists in this project, so this script has run before. Nothing was changed by this copy. Run supabase/checks/preview-board-owner-ids.sql to see its state.';
  end if;

  -- 3. Refuse unless the reviewed Feedbox v1 migration is present unchanged.
  if to_regclass('public.boards') is null or to_regclass('public.board_owners') is null then
    raise exception 'Refused: the Feedbox migration is not applied in this project (no table public.boards or public.board_owners). Nothing was changed.';
  end if;
  with
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
  fp as (select a.md5 from mig_all a)
  select fp.md5 into v_md5 from fp;
  if v_md5 is distinct from '160138805f7dcd5baa26b543b24aede3' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 migration (fingerprint %, expected 160138805f7dcd5baa26b543b24aede3). Nothing was changed.', v_md5;
  end if;

  -- 4. The migration 20261118000000_board_owner_ids.sql, word for word.
-- migration:begin
create function public.board_owner_ids(p_board_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.user_id
  from public.board_owners o
  where o.board_id = p_board_id
  order by o.user_id;
$$;

comment on function public.board_owner_ids(uuid) is
  'The user ids of the owners of one board, and nothing else. Readable by everyone (decision F5-D1, task O2).';

revoke all on function public.board_owner_ids(uuid) from public, anon, authenticated;
grant execute on function public.board_owner_ids(uuid) to anon, authenticated;
-- migration:end
end;
$o2$;
-- end of preview-board-owner-ids.sql
```

### `supabase/checks/preview-board-owner-ids.sql` (210 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/checks/preview-board-owner-ids.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/checks/preview-board-owner-ids.sql

```sql
-- supabase/checks/preview-board-owner-ids.sql | 210 lines | last line: -- end of preview-board-owner-ids.sql
-- =============================================================================
-- READ-ONLY check (task O2). Changes nothing: one SELECT.
-- For: feedbox-preview. When: right after supabase/apply/preview-board-owner-ids.sql.
-- It checks that this is feedbox-preview (project marker); that the database is the
-- Feedbox v1 migration plus the O2 migration, both unchanged; that the function
-- public.board_owner_ids exists, is security definer with search_path '' and
-- returns user ids only; that anon (visitors) and authenticated (signed-in
-- people) may execute it and nobody else may; and that for every board it
-- returns exactly that board's owners, and nothing for an unknown board.
-- Result: rows (n, check_name, result, message). Row 0 is the overall result.
-- =============================================================================

with
-- shared:project:begin (the project marker; never fails if it is missing)
project as (
  select (xpath('/table/row/name/text()',
           query_to_xml('select name from triad.project', false, false, '')))[1]::text as name
  where to_regclass('triad.project') is not null
),
-- shared:project:end
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
-- shared:counts:begin (rows per Feedbox table; NULL if the table does not exist)
counts as (
  select t.name,
         case when to_regclass('public.' || t.name) is not null then
           (xpath('/table/row/n/text()',
                  query_to_xml(format('select count(*) as n from public.%I', t.name), false, false, '')))[1]::text::bigint
         end as n
  from unnest(array['boards', 'profiles', 'board_owners', 'ideas', 'votes', 'comments',
                    'changelog_entries', 'changelog_items']) as t (name)
),
people as (
  select count(*) as all_people,
         count(*) filter (where u.email like '%@lumen.example') as lumen_people
  from auth.users u
),
-- shared:counts:end
fn as (
  select p.prosecdef as secdef,
         coalesce(array_to_string(p.proconfig, ','), '') as config,
         p.provolatile::text as volatility,
         pg_get_function_result(p.oid) as result_type,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
         (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0)) as public_exec
  from pg_proc p
  where p.oid = to_regprocedure('public.board_owner_ids(uuid)')
),
owner_ids as (
  select (xpath('/table/row/boards/text()', x))[1]::text::int as boards,
         (xpath('/table/row/owners/text()', x))[1]::text::int as owners,
         (xpath('/table/row/mismatched/text()', x))[1]::text::int as mismatched,
         (xpath('/table/row/unknown/text()', x))[1]::text::int as unknown
  from (select query_to_xml(
                 'select (select count(*) from public.boards) as boards,
                         (select count(*) from public.board_owners) as owners,
                         (select count(*) from public.boards b
                           where array(select f.id from public.board_owner_ids(b.id) as f (id) order by f.id)
                                 is distinct from
                                 array(select o.user_id from public.board_owners o where o.board_id = b.id order by o.user_id)) as mismatched,
                         (select count(*) from public.board_owner_ids(gen_random_uuid())) as unknown', false, false, '') as x
         where to_regprocedure('public.board_owner_ids(uuid)') is not null
           and to_regclass('public.boards') is not null and to_regclass('public.board_owners') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-preview',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-preview.'
              else format('this project is marked %s; this check is for feedbox-preview.', (select name from project)) end
  union all
  select 2, 'migrations', a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d',
         case when a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d'
              then 'the Feedbox v1 migration and the O2 migration are present and unchanged (fingerprint ea60181fdd11e237aa19ee5d6d6c186d).'
              when a.md5 = '160138805f7dcd5baa26b543b24aede3'
              then 'the database is the Feedbox v1 migration WITHOUT the O2 migration (fingerprint 160138805f7dcd5baa26b543b24aede3, expected ea60181fdd11e237aa19ee5d6d6c186d). Run supabase/apply/preview-board-owner-ids.sql first.'
              else format('the database does not match the Feedbox v1 migration plus the O2 migration (fingerprint %s, expected ea60181fdd11e237aa19ee5d6d6c186d).', a.md5) end
  from mig_all a
  union all
  select 3, 'function exists', exists (select 1 from fn),
         case when exists (select 1 from fn) then 'the function public.board_owner_ids(uuid) exists.'
              else 'the function public.board_owner_ids(uuid) is MISSING.' end
  union all
  select 4, 'safe function', coalesce((select secdef and config = 'search_path=""' and volatility = 's'
                                               and result_type = 'SETOF uuid' from fn), false),
         case when not exists (select 1 from fn) then 'there is no function to look at.'
              else (select format('security definer: %s (expected yes); settings: %s (expected search_path=""); stable: %s (expected yes); returns: %s (expected SETOF uuid, user ids only).',
                                  case when secdef then 'yes' else 'no' end, coalesce(nullif(config, ''), 'none'),
                                  case when volatility = 's' then 'yes' else 'no' end, result_type) from fn) end
  union all
  select 5, 'who may call it', coalesce((select anon_exec and auth_exec and not public_exec from fn), false),
         case when not exists (select 1 from fn) then 'there is no function to look at.'
              else (select format('visitors (anon) may call it: %s; signed-in people (authenticated): %s; everyone else (public): %s. Expected yes, yes, no.',
                                  case when anon_exec then 'yes' else 'no' end, case when auth_exec then 'yes' else 'no' end,
                                  case when public_exec then 'yes' else 'no' end) from fn) end
  union all
  select 6, 'returns the owners', coalesce((select owners >= 1 and mismatched = 0 from owner_ids), false),
         case when not exists (select 1 from owner_ids) then 'the function or the Feedbox tables are missing, so nothing could be asked.'
              else (select format('%s boards with %s owners in all (expected at least 1); boards where the function does not return exactly the board''s owners: %s (expected 0).',
                                  boards, owners, mismatched) from owner_ids) end
  union all
  select 7, 'unknown board', coalesce((select unknown = 0 from owner_ids), false),
         case when not exists (select 1 from owner_ids) then 'the function or the Feedbox tables are missing, so nothing could be asked.'
              else (select format('for a board that does not exist it returns %s ids (expected 0).', unknown) from owner_ids) end
),
-- shared:result:begin (row 0 is the overall result; every check depends on check 1, the project)
gated as (
  select c.n, c.check_name,
         coalesce(c.ok, false) and (c.n = 1 or p.ok) as ok,
         case when c.n = 1 or p.ok then c.detail
              else 'not checked, because check 1 (project) failed.' end as detail
  from checks c
  cross join (select coalesce(bool_and(k.ok), false) as ok from checks k where k.n = 1) p
)
select 0 as n, 'overall' as check_name,
       case when bool_and(g.ok) then 'PASS' else 'FAIL' end as result,
       case when bool_and(g.ok) then format('PASS: all %s checks passed.', count(*))
            else format('FAIL: %s of %s checks failed. Stop here and send this result to Claude.ai.',
                        count(*) filter (where not g.ok), count(*)) end as message
from gated g
union all
select g.n, g.check_name,
       case when g.ok then 'PASS' else 'FAIL' end,
       case when g.ok then 'PASS: ' else 'FAIL: ' end || g.detail
from gated g
order by 1;
-- shared:result:end
-- end of preview-board-owner-ids.sql
```

### `supabase/apply/prod-board-owner-ids.sql` (162 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/apply/prod-board-owner-ids.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/apply/prod-board-owner-ids.sql

```sql
-- supabase/apply/prod-board-owner-ids.sql | 162 lines | last line: -- end of prod-board-owner-ids.sql
-- =============================================================================
-- Applies the migration supabase/migrations/20261118000000_board_owner_ids.sql
-- on feedbox-prod only (task O2, decision F5-D1). CHANGES the database: adds ONE
-- function, public.board_owner_ids, and its grants. Nothing else.
-- Run once in the Supabase SQL Editor of feedbox-prod, in the merge task of O2, BEFORE the pull request is merged, so that Production
--   never runs code that calls a function its database does not have.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-prod; the function does not exist yet; and the
--   reviewed Feedbox v1 migration is present unchanged (the same fingerprint
--   as the check scripts). If the script was pasted twice into one query, the
--   message says so.
-- * Section 4 is the migration's statements word for word;
--   tests/sql-files.test.ts keeps them identical to the migration file.
-- * Check afterwards with supabase/checks/prod-board-owner-ids.sql.
-- =============================================================================

do $o2$
declare
  v_project  text;
  v_md5      text;
  v_same_txn boolean;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-prod. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-prod' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-prod. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse to run twice (also when pasted twice into one query).
  if to_regprocedure('public.board_owner_ids(uuid)') is not null then
    select p.xmin::text = (pg_current_xact_id()::xid)::text into v_same_txn
    from pg_proc p where p.oid = to_regprocedure('public.board_owner_ids(uuid)');
    if v_same_txn then
      raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
    end if;
    raise exception 'Refused: the function public.board_owner_ids already exists in this project, so this script has run before. Nothing was changed by this copy. Run supabase/checks/prod-board-owner-ids.sql to see its state.';
  end if;

  -- 3. Refuse unless the reviewed Feedbox v1 migration is present unchanged.
  if to_regclass('public.boards') is null or to_regclass('public.board_owners') is null then
    raise exception 'Refused: the Feedbox migration is not applied in this project (no table public.boards or public.board_owners). Nothing was changed.';
  end if;
  with
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
  fp as (select a.md5 from mig_all a)
  select fp.md5 into v_md5 from fp;
  if v_md5 is distinct from '160138805f7dcd5baa26b543b24aede3' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 migration (fingerprint %, expected 160138805f7dcd5baa26b543b24aede3). Nothing was changed.', v_md5;
  end if;

  -- 4. The migration 20261118000000_board_owner_ids.sql, word for word.
-- migration:begin
create function public.board_owner_ids(p_board_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.user_id
  from public.board_owners o
  where o.board_id = p_board_id
  order by o.user_id;
$$;

comment on function public.board_owner_ids(uuid) is
  'The user ids of the owners of one board, and nothing else. Readable by everyone (decision F5-D1, task O2).';

revoke all on function public.board_owner_ids(uuid) from public, anon, authenticated;
grant execute on function public.board_owner_ids(uuid) to anon, authenticated;
-- migration:end
end;
$o2$;
-- end of prod-board-owner-ids.sql
```

### `supabase/checks/prod-board-owner-ids.sql` (210 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/checks/prod-board-owner-ids.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/checks/prod-board-owner-ids.sql

```sql
-- supabase/checks/prod-board-owner-ids.sql | 210 lines | last line: -- end of prod-board-owner-ids.sql
-- =============================================================================
-- READ-ONLY check (task O2). Changes nothing: one SELECT.
-- For: feedbox-prod. When: right after supabase/apply/prod-board-owner-ids.sql.
-- It checks that this is feedbox-prod (project marker); that the database is the
-- Feedbox v1 migration plus the O2 migration, both unchanged; that the function
-- public.board_owner_ids exists, is security definer with search_path '' and
-- returns user ids only; that anon (visitors) and authenticated (signed-in
-- people) may execute it and nobody else may; and that for every board it
-- returns exactly that board's owners, and nothing for an unknown board.
-- Result: rows (n, check_name, result, message). Row 0 is the overall result.
-- =============================================================================

with
-- shared:project:begin (the project marker; never fails if it is missing)
project as (
  select (xpath('/table/row/name/text()',
           query_to_xml('select name from triad.project', false, false, '')))[1]::text as name
  where to_regclass('triad.project') is not null
),
-- shared:project:end
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
-- shared:counts:begin (rows per Feedbox table; NULL if the table does not exist)
counts as (
  select t.name,
         case when to_regclass('public.' || t.name) is not null then
           (xpath('/table/row/n/text()',
                  query_to_xml(format('select count(*) as n from public.%I', t.name), false, false, '')))[1]::text::bigint
         end as n
  from unnest(array['boards', 'profiles', 'board_owners', 'ideas', 'votes', 'comments',
                    'changelog_entries', 'changelog_items']) as t (name)
),
people as (
  select count(*) as all_people,
         count(*) filter (where u.email like '%@lumen.example') as lumen_people
  from auth.users u
),
-- shared:counts:end
fn as (
  select p.prosecdef as secdef,
         coalesce(array_to_string(p.proconfig, ','), '') as config,
         p.provolatile::text as volatility,
         pg_get_function_result(p.oid) as result_type,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
         (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0)) as public_exec
  from pg_proc p
  where p.oid = to_regprocedure('public.board_owner_ids(uuid)')
),
owner_ids as (
  select (xpath('/table/row/boards/text()', x))[1]::text::int as boards,
         (xpath('/table/row/owners/text()', x))[1]::text::int as owners,
         (xpath('/table/row/mismatched/text()', x))[1]::text::int as mismatched,
         (xpath('/table/row/unknown/text()', x))[1]::text::int as unknown
  from (select query_to_xml(
                 'select (select count(*) from public.boards) as boards,
                         (select count(*) from public.board_owners) as owners,
                         (select count(*) from public.boards b
                           where array(select f.id from public.board_owner_ids(b.id) as f (id) order by f.id)
                                 is distinct from
                                 array(select o.user_id from public.board_owners o where o.board_id = b.id order by o.user_id)) as mismatched,
                         (select count(*) from public.board_owner_ids(gen_random_uuid())) as unknown', false, false, '') as x
         where to_regprocedure('public.board_owner_ids(uuid)') is not null
           and to_regclass('public.boards') is not null and to_regclass('public.board_owners') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-prod',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-prod.'
              else format('this project is marked %s; this check is for feedbox-prod.', (select name from project)) end
  union all
  select 2, 'migrations', a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d',
         case when a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d'
              then 'the Feedbox v1 migration and the O2 migration are present and unchanged (fingerprint ea60181fdd11e237aa19ee5d6d6c186d).'
              when a.md5 = '160138805f7dcd5baa26b543b24aede3'
              then 'the database is the Feedbox v1 migration WITHOUT the O2 migration (fingerprint 160138805f7dcd5baa26b543b24aede3, expected ea60181fdd11e237aa19ee5d6d6c186d). Run supabase/apply/prod-board-owner-ids.sql first.'
              else format('the database does not match the Feedbox v1 migration plus the O2 migration (fingerprint %s, expected ea60181fdd11e237aa19ee5d6d6c186d).', a.md5) end
  from mig_all a
  union all
  select 3, 'function exists', exists (select 1 from fn),
         case when exists (select 1 from fn) then 'the function public.board_owner_ids(uuid) exists.'
              else 'the function public.board_owner_ids(uuid) is MISSING.' end
  union all
  select 4, 'safe function', coalesce((select secdef and config = 'search_path=""' and volatility = 's'
                                               and result_type = 'SETOF uuid' from fn), false),
         case when not exists (select 1 from fn) then 'there is no function to look at.'
              else (select format('security definer: %s (expected yes); settings: %s (expected search_path=""); stable: %s (expected yes); returns: %s (expected SETOF uuid, user ids only).',
                                  case when secdef then 'yes' else 'no' end, coalesce(nullif(config, ''), 'none'),
                                  case when volatility = 's' then 'yes' else 'no' end, result_type) from fn) end
  union all
  select 5, 'who may call it', coalesce((select anon_exec and auth_exec and not public_exec from fn), false),
         case when not exists (select 1 from fn) then 'there is no function to look at.'
              else (select format('visitors (anon) may call it: %s; signed-in people (authenticated): %s; everyone else (public): %s. Expected yes, yes, no.',
                                  case when anon_exec then 'yes' else 'no' end, case when auth_exec then 'yes' else 'no' end,
                                  case when public_exec then 'yes' else 'no' end) from fn) end
  union all
  select 6, 'returns the owners', coalesce((select owners >= 1 and mismatched = 0 from owner_ids), false),
         case when not exists (select 1 from owner_ids) then 'the function or the Feedbox tables are missing, so nothing could be asked.'
              else (select format('%s boards with %s owners in all (expected at least 1); boards where the function does not return exactly the board''s owners: %s (expected 0).',
                                  boards, owners, mismatched) from owner_ids) end
  union all
  select 7, 'unknown board', coalesce((select unknown = 0 from owner_ids), false),
         case when not exists (select 1 from owner_ids) then 'the function or the Feedbox tables are missing, so nothing could be asked.'
              else (select format('for a board that does not exist it returns %s ids (expected 0).', unknown) from owner_ids) end
),
-- shared:result:begin (row 0 is the overall result; every check depends on check 1, the project)
gated as (
  select c.n, c.check_name,
         coalesce(c.ok, false) and (c.n = 1 or p.ok) as ok,
         case when c.n = 1 or p.ok then c.detail
              else 'not checked, because check 1 (project) failed.' end as detail
  from checks c
  cross join (select coalesce(bool_and(k.ok), false) as ok from checks k where k.n = 1) p
)
select 0 as n, 'overall' as check_name,
       case when bool_and(g.ok) then 'PASS' else 'FAIL' end as result,
       case when bool_and(g.ok) then format('PASS: all %s checks passed.', count(*))
            else format('FAIL: %s of %s checks failed. Stop here and send this result to Claude.ai.',
                        count(*) filter (where not g.ok), count(*)) end as message
from gated g
union all
select g.n, g.check_name,
       case when g.ok then 'PASS' else 'FAIL' end,
       case when g.ok then 'PASS: ' else 'FAIL: ' end || g.detail
from gated g
order by 1;
-- shared:result:end
-- end of prod-board-owner-ids.sql
```

## docs/ARCHITECTURE.md changes

The changed parts:
- the short names at the top: "the O2 migration" added;
- 1.3: Postgres and the functions;
- 3.6, step 5;
- 3.10, step 4;
- 6: the SQL folders, with `supabase/apply/` added;
- 7: F5-D1 decided and done.

```diff
diff --git a/docs/ARCHITECTURE.md b/docs/ARCHITECTURE.md
index b9567f6..7c5258b 100644
--- a/docs/ARCHITECTURE.md
+++ b/docs/ARCHITECTURE.md
@@ -2,9 +2,10 @@
 
 How the parts of Feedbox connect, written from the code at commit `1a13023` (tag `f5`, task A1).
 
-Every statement names the file it comes from, so it can be checked line by line. Line numbers refer to `1a13023`. Two short names are used throughout:
+Every statement names the file it comes from, so it can be checked line by line. Line numbers refer to `1a13023`, except in the parts updated by task O2 (the Owner mark for everyone), which say so. Three short names are used throughout:
 
-- **the migration** means `supabase/migrations/20261113000000_feedbox_v1.sql`;
+- **the migration** means `supabase/migrations/20261113000000_feedbox_v1.sql`, the Feedbox v1 migration;
+- **the O2 migration** means `supabase/migrations/20261118000000_board_owner_ids.sql` (task O2, decision F5-D1);
 - **data.ts** means `lib/supabase/data.ts`.
 
 If this file and the code disagree, the code is right and this file has a fault. CLAUDE.md requires every task that changes how the parts connect to update this file in the same pull request.
@@ -57,7 +58,7 @@ Next.js 16, App Router (`package.json`). It has five kinds of server code:
 
 Each hosted project has two parts the app uses: Postgres and Supabase Auth.
 
-**Postgres.** Everything is created by the migration.
+**Postgres.** Everything is created by the migration, except the function `board_owner_ids`, which the O2 migration adds.
 
 - **Eight tables** (migration lines 36-148): `boards`, `profiles`, `board_owners`, `ideas`, `votes`, `comments`, `changelog_entries`, `changelog_items`.
 - **Row-level security (RLS):** it is on for every table (lines 804-811), with policies at lines 813-928. The grants first revoke everything from `anon` and `authenticated` and then grant back only what is needed, column by column for writes (lines 726-797).
@@ -65,9 +66,10 @@ Each hosted project has two parts the app uses: Postgres and Supabase Auth.
   - `is_board_owner` (lines 172-185);
   - `has_display_name` (lines 190-203);
   - `similar_ideas` (lines 687-717);
+  - `board_owner_ids` (O2 migration lines 21-38): the user ids of one board's owners, and nothing else, for everyone. It is security definer with `search_path` set to `''`, stable, and only `anon` and `authenticated` may execute it (`supabase/tests/11_board_owner_ids.sql`);
   - the owner functions `set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment` and `publish_changelog_entry` (lines 463-677).
 
-  Today the app calls only `is_board_owner` (data.ts:44) and `similar_ideas` (data.ts:173, 199). The owner functions wait for F6.
+  Today the app calls only `is_board_owner` (data.ts:44), `similar_ideas` (data.ts:173, 199) and, since O2, `board_owner_ids` (`getOwnerIds` in data.ts). The owner functions wait for F6.
 - **Triggers** (lines 235-453):
   - a profile for every new user (5a);
   - rate limits of 5 ideas, 30 comments and 100 votes per person per hour (5b);
@@ -253,7 +255,7 @@ flowchart LR
    - **Rate limit:** 30 comments an hour (5b).
    - **Count:** a trigger keeps `comment_count` (5f).
 4. The action refreshes the idea page (`revalidatePath`, line 25). The comments are listed oldest first, flat (data.ts:118-136).
-5. The **Owner** mark appears next to a comment only when the viewer may read who the owners are (data.ts:138-151). See 3.10 and decision F5-D1.
+5. The **Owner** mark appears next to a comment written by an owner of the board, for every viewer: visitors, members and owners (task O2, decision F5-D1). `getOwnerIds` in data.ts asks `board_owner_ids` for the owners' ids; if that fails, for example in a project where the O2 migration has not run yet, the page still loads without the mark and the server logs the reason (`lib/supabase/data.test.ts`). See 3.10.
 
 ### 3.7 Signing in by email link
 
@@ -319,8 +321,9 @@ flowchart LR
 3. **Hidden ideas and comments:** an owner also sees them, marked "Hidden" (`app/page.tsx:36, 99`; `app/ideas/[id]/page.tsx:30, 51, 74`).
    - RLS lets owners read them (migration lines 836-838, 866-874).
    - Search and similar ideas still leave hidden ideas out (`similar_ideas`, line 713).
-4. **The Owner mark:** an owner sees **Owner** next to comments written by any owner of the board. The policy `board_owners_read` lets an owner read all owners of the board; anyone else reads at most their own row (migration lines 830-832; data.ts:138-151).
-   - So visitors and members never see the mark. This is decision F5-D1.
+4. **The Owner mark:** since task O2 (decision F5-D1, decided by Nik on 2026-11-18), everyone sees **Owner** next to comments written by any owner of the board, not only owners.
+   - The ids come from the function `board_owner_ids` (O2 migration lines 21-38), which returns the owners' user ids only, never an email or another column (`supabase/tests/11_board_owner_ids.sql`; `e2e/screens.spec.ts`, "everyone sees the Owner mark").
+   - The table `board_owners` and its policy `board_owners_read` are unchanged: reading the table directly, an owner sees all owners of the board and anyone else at most their own row (migration lines 830-832).
 5. **No owner tools in the app yet:** the database already has the owner functions (status, merge, hide and unhide, publish), but no page calls them. They arrive in F6.
 
 ## 4. Keys: which key is used where
@@ -370,7 +373,7 @@ Each rule names the test or check that guards it.
   - `NEXT_PUBLIC_SITE_URL` is optional, read in `lib/supabase/site.ts:10`.
   - In Vercel they are set per environment (CLAUDE.md, "App settings on Vercel"). Locally and in CI they come from `npx supabase status` (`playwright.config.ts:30-34`).
 - **Local Supabase settings:** `supabase/config.toml`. Where they differ from hosted, the difference is on purpose (CLAUDE.md, "Local Supabase against these settings").
-- **SQL that Nik runs on a hosted project:** files in `supabase/checks/`, `supabase/marker/` and `supabase/production/`, each reviewed and tested (CLAUDE.md, "SQL is code").
+- **SQL that Nik runs on a hosted project:** files in `supabase/checks/`, `supabase/marker/`, `supabase/production/` and, since task O2, `supabase/apply/` (a migration as Nik pastes it, guarded by the project marker), each reviewed and tested (CLAUDE.md, "SQL is code").
 
 ## 7. Not built yet, and open decisions
 
@@ -380,7 +383,7 @@ Each rule names the test or check that guards it.
 
 The database functions for all of these exist (migration lines 457-677) and are tested (`supabase/tests/06_owner_functions.sql`, `07_merge.sql`, `08_changelog.sql`).
 
-**Open decisions** (from the F5 report; not repeated here):
-- **F5-D1:** whether everyone may read who the board's owners are, so that the Owner mark shows for every viewer (see 3.10).
-- **F5-D2:** whether to build an end-to-end runner against the hosted Preview (`playwright.config.ts:4-7`).
+**Decisions** (from the F5 and A1 reports):
+- **F5-D1 (decided 2026-11-18, done in task O2):** everyone may read who the board's owners are, so the Owner mark shows for every viewer (see 3.6 and 3.10).
+- **F5-D2 (open):** whether to build an end-to-end runner against the hosted Preview (`playwright.config.ts:4-7`).
 - **A1-D2 (decided 2026-11-18, fixed later):** the search limit of 20 applies to the whole board before the tab is chosen (see 3.2); it is fixed later, with F6's database work or when a board grows, not now.
```

## Steps for Nik

These steps run the O2 migration and its check on **feedbox-preview only**, then check the Preview of pull request #9. Everything happens on the Mac, in Chrome. Do not run anything on feedbox-prod: its two scripts come in the merge task.

**O2-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://supabase.com/dashboard/project/qrbeiveyomidfafivuta/sql/new

Expected: the Supabase SQL Editor opens. The project name at the top of the page reads **feedbox-preview**, and the address bar contains `qrbeiveyomidfafivuta` and does NOT contain `imlitxtkpvrcmijgdsrw` (that is feedbox-prod). If either is not so, stop here: you are not in feedbox-preview. Nothing has been changed.

Result

**O2-2** In the same tab (SQL Editor of **feedbox-preview**), clear every existing query. At the top of the SQL Editor, click an "Untitled query" tab: its orange dot turns into an ×. Click the ×, which deletes that query. Repeat until no query tab is left.

Expected: no query tab is left in the SQL Editor, and the top of the page still reads **feedbox-preview**.

Result

**O2-3** (CHANGES the database of feedbox-preview: adds one function.) On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/apply/preview-board-owner-ids.sql
Click into the page, press ⌘A, then ⌘C. Go back to the Supabase tab, check that the top of the page reads **feedbox-preview**, click **+ New query**, click into the empty editor and press ⌘V. Before clicking Run, check that the first line is `-- supabase/apply/preview-board-owner-ids.sql | 161 lines | last line: -- end of preview-board-owner-ids.sql`, and, scrolled to the end, that the last line with text is `-- end of preview-board-owner-ids.sql` at line 161. If either does not match, close that query tab with its × and paste again. Then click **Run**.

Expected: **"Success. No rows returned."** If it says "Refused: …", stop: nothing was changed, as the message says. Copy the message into this note and send it to Claude.ai. If any other error appears, stop and do not run it again: nothing was changed, because the script is all or nothing. Copy the whole message into this note.

Result

**O2-4** (read-only, must PASS.) On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/1e653ff3519fd6637259ff52d984c874f27d8713/supabase/checks/preview-board-owner-ids.sql
Click into the page, press ⌘A, then ⌘C. Go back to the Supabase tab, check that the top of the page reads **feedbox-preview**, click **+ New query**, click into the empty editor and press ⌘V. Before clicking Run, check that the first line is `-- supabase/checks/preview-board-owner-ids.sql | 210 lines | last line: -- end of preview-board-owner-ids.sql`, and that the last line with text is `-- end of preview-board-owner-ids.sql` at line 210. If either does not match, close that query tab with its × and paste again. Then click **Run**, and take a screenshot of the result (⌘⇧4, then drag over the rows) into this note.

Expected: 8 rows (n 0 to 7). Row 0 reads **"PASS: all 7 checks passed."** Row 2 names the fingerprint `ea60181fdd11e237aa19ee5d6d6c186d`, and row 6 says "boards where the function does not return exactly the board's owners: 0". If row 0 says FAIL, stop: this check changed nothing. Send all rows to Claude.ai and change nothing on your own.

Result

**O2-5** On the Mac, in Chrome (where you are signed in to Vercel), open a new tab (⌘T) and go to https://triad-feedbox-git-o2-owner-mark-nikolaj-ivancics-projects.vercel.app

Expected: the board "What should Lumen do next?". If the top right reads "Signed in as …", click **Sign out** there. Afterwards the top right reads **"Viewing as visitor"** with a **Sign in** button.

Result

**O2-6** In the same tab, as a visitor, click the tab **Planned** below the board's title, then click the idea **Dark mode for the editor**.

Expected: the page "Dark mode for the editor" with its comments. The comment by **Ana** reads "Planned for the December release. …" and has a small mark **Owner** next to her name. The comments by Tom R. and Sam P. have no mark, and the top right still reads "Viewing as visitor".

Result

**O2-7** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

No new decision. F5-D1 is decided and done in this pull request. F5-D2 stays open as written in the F5 report.
