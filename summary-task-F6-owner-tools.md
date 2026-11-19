# Task F6: owner tools and the changelog editor

Branch `f6-owner-tools`, pull request #10 (not merged): https://github.com/adriatic/triad-feedbox/pull/10. Head: `5cca3a06533e26ad3b765a4d1f0abe1ee143af74`.

- **No migration and no database change:** every owner action uses the owner functions that were already in the Feedbox v1 migration.
- No dashboard setting changed.
- Nothing ran against feedbox-preview or feedbox-prod.

## Is TRIAD ready? (run first, on main at fb1d8e3)

`/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh`, exit code 0:

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit fb1d8e3 O2: the Owner mark for everyone (decision F5-D1) (#9). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 144 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 6fa7a7a).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit fb1d8e3, 2026-11-18T23:18:50Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
```

## What was built

### Idea detail: the Owner tools (owners only, as in `Idea.dc.html`)

- **The box "Owner tools"** sits under the idea, with a dashed border as in the design. It holds:
  - the **Status** list (Open, Planned, Building, Shipped) with a **Change status** button. It calls `set_idea_status`. Any change is allowed except setting the same status again. An idea that is in a changelog entry stays Shipped, so then the list is disabled and a note says why (the rules of `checkStatusChange` in `lib/feedbox`, enforced by the database).
  - **Merge into another idea.** It opens a panel inside the box:
    - The owner picks the target from the visible, unmerged ideas, most votes first.
    - Before the button, the panel says **what will happen**: everyone who voted for this idea gets a vote on the target unless they already have one, and the target's count moves from N to between X and Y votes. It also says how many comments move, and that the idea leaves the board and its address leads to the target.
    - In bold, on the warning colour: **"There is no undo. A wrong merge can only be repaired by hand in the database."**
    - The button reads **Merge into "<target>"**. It calls `merge_ideas`.
  - **Hide idea / Unhide idea.** It calls `hide_idea` or `unhide_idea`.
- **Each comment**, for owners only: **Hide comment / Unhide comment** (`hide_comment`, `unhide_comment`).
- **How every tool works:** each is a form that calls a server action (`app/ideas/[id]/owner-actions.ts`), which calls one owner function with the owner's own session. The browser never calls Supabase.
  - A success is said in words, for example "The status is now Planned." or "The idea is hidden. Only owners see it now."
  - A refusal is said in words too. For a rule, the database's own sentence is shown, for example "The idea is already Planned." (`ownerRefusalMessage` in `lib/feedbox/screens.ts`).
- **Hidden items:**
  - An owner sees hidden ideas in the board's lists and on their page, and hidden comments, each marked **Hidden**.
  - Visitors and members never see them: the database does not return them, and a hidden idea's page answers "This page could not be found."
- **A merged idea's address** now leads to `/ideas/<target>?merged=<source>`. The target says: "“<source>” was merged into this idea. Its votes and comments are here now: N votes in all."
  - The note shows only when the source really was merged into that idea.
  - The redirect is no longer permanent (it was 308), because a wrong merge can be repaired by hand.
  - Moved comments read **From the merged idea “<title>”** (F1 section 5).

### The changelog editor, `/changelog/new` (owners only; F1 section 8)

- **The way in:** owners see a **Write a changelog entry** button on `/changelog`. Nobody else does.
- **Who may use it:** a visitor is sent to sign in, and a member reads "Only the owners of Lumen can write the changelog."
- **The form** reuses the Post an idea layout (no design exists):
  - **Title**;
  - **Release date**, which starts as today where the owner is;
  - "Shipped ideas not in the changelog yet", all ticked, each with one line to write;
  - **Publish** and **Cancel**.
  - The right-hand column, where Post an idea lists similar ideas, says how the changelog works.
- **Publish:**
  - It checks the title, date and lines with the core library.
  - It writes the entry and its lines with the owner's session, then calls `publish_changelog_entry`.
  - The owner lands on `/changelog`, where the entry shows at once.
  - These are three requests, not one transaction. If a later one fails, the action deletes the entry it just made, so no half-made draft is left.
- **When nothing is shipped:** with no Shipped idea waiting, the page says so and shows no form.

### Files

- **New:**
  - `app/ideas/[id]/OwnerTools.tsx`, `app/ideas/[id]/owner-actions.ts`;
  - `app/changelog/new/ChangelogForm.tsx`, `app/changelog/new/actions.ts`;
  - `e2e/owner.spec.ts`, `e2e/fixtures.ts`;
  - `supabase/preview/owner-nik.sql`, `supabase/checks/preview-owner-nik.sql`;
  - `supabase/people/remove-person.sql`, `supabase/checks/person-removal.sql`.
- **Changed:**
  - the app: `app/ideas/[id]/page.tsx`, `app/changelog/page.tsx`, `app/changelog/new/page.tsx`, `app/globals.css`, `lib/supabase/data.ts` (moved-from titles, `isInChangelog`);
  - the core library: `lib/feedbox/merge.ts` (`mergePreview`, `mergeTargets`), `lib/feedbox/screens.ts` (`ownerRefusalMessage`), and their tests;
  - the SQL tests: `scripts/sql-files.ts` (two new folders), `scripts/test-sql-checks.sh`, `tests/sql-files.test.ts`;
  - the other e2e files: `e2e/auth.spec.ts`, `e2e/screens.spec.ts`, `e2e/screenshots.spec.ts`;
  - `README.md`, `lib/supabase/env.ts`, `lib/supabase/env.test.ts`, `CLAUDE.md`, `docs/ARCHITECTURE.md`.

### README

- **Owners** (new section): what an owner can do (status, merge with "no undo", hide and unhide, the changelog editor). It also says how a person becomes an owner: only with reviewed SQL, made for one board and one person and checked afterwards, linking `supabase/production/owner-nik.sql` and `supabase/preview/owner-nik.sql` with their checks.
- **Privacy** (new section):
  - what is stored and where: Supabase Auth (email, sign-in times and log), the Feedbox tables (display name, ideas, votes, comments, and what an owner hid), the browser (only the session cookies; no analytics or tracking), Resend and Vercel logs;
  - what is public;
  - how a person is **removed on request**, linking the template `supabase/people/remove-person.sql` and its check.
- **The A1 leftovers (finding 5):**
  - `README.md` line 7 now reads "Status: version 1. …" instead of "every page is still bare";
  - the comment in `lib/supabase/env.ts` now says that only the server reads the settings;
  - the test name in `lib/supabase/env.test.ts` is now "the proxy and the server client read the Supabase settings only through env.ts".

### Removing a person on request (SQL is code)

- **The template:** `supabase/people/remove-person.sql` (changing) and `supabase/checks/person-removal.sql` (read-only) are templates. As they are, they refuse ("this is the template") or FAIL.
- **One request:** a task copies both to `supabase/people/remove-<date>.sql` and `supabase/checks/person-removal-<date>.sql`, changing only the two values in their block "request": the project and the person's **User UID** from the Supabase dashboard. Never the email address, since the repository is public.
- **The unit test** `tests/sql-files.test.ts` refuses any copy that differs from its template outside that block, or that has an "@" in it.
- **The check, before the removal,** says what will go (name, ideas, votes, comments, and other people's votes and comments on their ideas). After the removal it must PASS.
- **The removal script** is guarded like the others: the project marker, the v1 + O2 fingerprint, the person must exist, and it is safe if pasted twice (the second copy finds no person, and the whole query is undone).
- **It refuses for:**
  - a person who owns a board (they are removed as an owner first, with its own script);
  - a person someone else's idea was merged into, because `merged_into_id` has no cascade and that idea would point at nothing.
- **What deleting `auth.users` removes,** through the database's own cascades: the profile, the person's ideas (with all votes, comments and changelog lines on them), their votes and their comments. The counts follow.
- **Nik runs nothing for this now:** it is used only when a request comes.

## Tests

- **e2e, `e2e/owner.spec.ts` (new, 3 tests).** Owner flows, with test ideas owned by a test owner; the Lumen seed ideas are never changed:
  1. **Status and merge:**
     - Open to Planned; the same status again is refused with "The idea is already Planned.".
     - The duplicate (2 votes, 1 comment) is merged into the target (1 vote). The preview says "goes from 1 vote to between 2 and 3 votes" and "1 comment move", plus "There is no undo.".
     - After the merge: the note "… 2 votes in all"; the database holds `vote_count` 2 and `comment_count` 1; the moved comment reads "From the merged idea …"; the old address leads to the target; the duplicate has left the board.
  2. **Hide and unhide:**
     - The owner hides a comment and the idea; the owner's board list marks it "Hidden".
     - For a member and a visitor, the idea is gone from the board and its page is "This page could not be found.".
     - After unhiding the idea it is back, but the hidden comment is still missing for them ("0 comments"), and they have no Owner tools and no Hide buttons.
     - After unhiding the comment, a visitor sees it again.
  3. **The changelog:**
     - The owner ships an idea, opens the editor from **Write a changelog entry**, and the idea is offered and ticked.
     - A missing line is refused; then the entry is published.
     - `/changelog` shows the entry, its line and "See the idea, 1 vote". The idea's status list is now disabled.
     - A member and a visitor see the entry and no editor button. On `/changelog/new` the member reads "Only the owners …", and the visitor is sent to sign in.
- **The browser-never-calls-Supabase guard (A1 finding 4):**
  - It is now the shared fixture `e2e/fixtures.ts`, used by `auth.spec.ts`, `owner.spec.ts` and `screens.spec.ts`.
  - A temporary test that makes the browser call the local Supabase API failed with "requests from the browser straight to Supabase", as it must. It was then removed.
- **Unit (164 tests):**
  - `mergePreview` and `mergeTargets` (3 tests) and `ownerRefusalMessage` (4);
  - the new SQL files (header and footer, the fingerprint block, the templates' empty request, and the copy rule; I checked by hand that a valid copy passes and a changed one fails).
- **SQL scripts, `npm run test:checks`:** all **149** expectations met (114 before F6).
  - **New section J (Nik as an owner of lumen on a local copy of feedbox-preview):**
    - the check FAILs before the script;
    - the script refuses in these cases, each with nothing changed:
      - no "Nik I.";
      - a Lumen person renamed "Nik I." (it does not count);
      - the project marked feedbox-prod;
      - a changed migration;
      - no board lumen;
      - two people named "Nik I.";
      - a double paste;
    - after one run the check PASSes, and FAILs again after each of these tampers: wrong marker, Nik's owner row removed, Nik renamed, a third owner, a changed grant;
    - a second run is refused.
  - **New section K (removing a person):**
    - the template refuses, and its check FAILs;
    - a copy's check shows what will go;
    - the copy refuses in these cases: the copy made for feedbox-prod, a changed migration, the person owning a board, an idea merged into theirs, a double paste;
    - after one run the check PASSes;
    - the vote and comment counts of the seed idea "Offline mode" are back to what they were;
    - a second run is refused.
- **pgTAP:** no database change, so no new pgTAP test. All 243 still pass.
- **Local runs:** lint, typecheck, unit (164), pgTAP (243), SQL scripts (149) and e2e (16) all pass.

## Images remade

- **`screenshots/F5/`:**
  - `idea-owner` was recaptured (light and dark, 1280 and 390): it now shows the Owner tools and the Hide comment buttons.
  - Two new states, 8 new images: **`idea-owner-merge`** (the merge panel open, with a target picked and the preview; nothing is merged) and **`changelog-new-owner`** (the editor). Every Shipped idea of the Lumen seed is already in an entry, so the editor's capture adds two Shipped ideas just for that capture and deletes them right after; no other screen changes.
  - The "Check your email" images differed only in the test address with its timestamp and were left as they were. All the others came out identical. Now 76 images.
- **`/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/`:**
  - **`Idea.png`** was remade: the design beside the owner's screen, both with the Owner tools box. Its caption reads "Built (F6)".
  - **`ChangelogEditor.png`** is new: `PostIdea.dc.html` beside the changelog editor.
  - The other five came out byte for byte identical.

### Known differences from the design, with reasons

1. **A "Change status" button next to the Status list.** The design shows the list alone. A list that acts as soon as it changes can change a status by accident: in some browsers the arrow keys change it while it is closed. A separate button makes each change deliberate.
2. **"Hide comment" on every comment** (owners only). The design shows no comment tools, but F1 section 6 asks for hiding comments.
3. **The merge panel** opens inside the Owner tools box. The design shows only the button.
4. **The header** shows Changelog, the pill and Sign out, not the design's email address. That is unchanged since F5: Feedbox never shows an email address.
5. **The changelog editor has no design.** It follows the Post an idea layout: a form on the left and a column on the right, which explains the changelog instead of listing similar ideas.
6. **On the phone,** the Owner tools wrap onto several rows (screenshot `idea-owner-merge-dark-390`).

## Results

- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/10
- **Head:** `5cca3a06533e26ad3b765a4d1f0abe1ee143af74` on `f6-owner-tools`
- **CI on 5cca3a0:** all green.

  | Check | push run 44424705924 | pull request run 44424734025 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass (2nd attempt) |
  | e2e | pass | pass |

  In the pull request run, the first attempt of `db` failed before any test ran. The runner could not start the database container, because port 55422 was already in use on that machine ("failed to bind host port 0.0.0.0:55422/tcp: address already in use"). I re-ran only that job, with no change: it passed, with "SQL checks: all 149 expectations met." and pgTAP "Result: PASS". The same job passed at the first attempt in the push run.
- **Vercel:** success on 5cca3a0, "Deployment has completed".
- **Preview:** https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app

## The SQL you run, in full

You run only these two, on feedbox-preview (steps F6-3 and F6-4). They are pinned to the head commit.

### `supabase/preview/owner-nik.sql` (173 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/preview/owner-nik.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/preview/owner-nik.sql

```sql
-- supabase/preview/owner-nik.sql | 173 lines | last line: -- end of owner-nik.sql
-- =============================================================================
-- Makes Nik an owner of the Lumen board, on feedbox-preview only (task F6), so
-- he can check the owner tools on the Preview. CHANGES the database: adds ONE
-- row to public.board_owners. Run once in the Supabase SQL Editor of
-- feedbox-preview.
--
-- Nik's email address and id are not written here. His person is found the
-- way task O1 found him on feedbox-prod: by what the database already holds.
-- feedbox-preview has 221 invented Lumen people (emails ending in
-- @lumen.example, from supabase/seed.sql). Nik is the ONE person outside them
-- whose display name is "Nik I.". If there is no such person, or more than
-- one, the script refuses.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-preview; the database is the Feedbox v1
--   migration plus the O2 migration, unchanged (the same fingerprint as the
--   check scripts); the board "lumen" exists; exactly one person outside the
--   Lumen people is named "Nik I."; and that person is not yet an owner of the
--   board. If the script was pasted twice into one query, the message says so.
-- * Check afterwards with supabase/checks/preview-owner-nik.sql.
-- =============================================================================

do $owner$
declare
  v_project  text;
  v_md5      text;
  v_board    uuid;
  v_matches  bigint;
  v_person   uuid;
  v_same_txn boolean;
  v_since    timestamptz;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-preview. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-preview' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-preview. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse unless the reviewed migrations (Feedbox v1 and O2) are present unchanged.
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
  if v_md5 is distinct from 'ea60181fdd11e237aa19ee5d6d6c186d' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 and O2 migrations (fingerprint %, expected ea60181fdd11e237aa19ee5d6d6c186d). Nothing was changed.', v_md5;
  end if;

  -- 3. Refuse unless the board "lumen" exists.
  select b.id into v_board from public.boards b where b.slug = 'lumen';
  if v_board is null then
    raise exception 'Refused: this project has no board "lumen". Nothing was changed.';
  end if;

  -- 4. Find Nik: the one person outside the Lumen people named "Nik I.".
  select count(*) into v_matches
  from auth.users u join public.profiles p on p.id = u.id
  where p.display_name = 'Nik I.' and coalesce(u.email, '') not like '%@lumen.example';
  if v_matches = 0 then
    raise exception 'Refused: no person outside the Lumen people has the display name "Nik I." in this project. Sign in once on the Preview and set that name first. Nothing was changed.';
  end if;
  if v_matches > 1 then
    raise exception 'Refused: % people outside the Lumen people have the display name "Nik I.", so this script cannot tell which one is Nik. Nothing was changed.', v_matches;
  end if;
  select u.id into v_person
  from auth.users u join public.profiles p on p.id = u.id
  where p.display_name = 'Nik I.' and coalesce(u.email, '') not like '%@lumen.example';

  -- 5. Refuse to run twice (also when pasted twice into one query).
  select o.xmin::text = (pg_current_xact_id()::xid)::text, o.created_at
    into v_same_txn, v_since
  from public.board_owners o
  where o.board_id = v_board and o.user_id = v_person;
  if v_same_txn then
    raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
  end if;
  if v_since is not null then
    raise exception 'Refused: "Nik I." is already an owner of the board "lumen" (since %). This script has run before, or was pasted twice into one query. Nothing was changed by this copy.', v_since;
  end if;

  insert into public.board_owners (board_id, user_id) values (v_board, v_person);
end;
$owner$;
-- end of owner-nik.sql
```

### `supabase/checks/preview-owner-nik.sql` (188 lines)

- Pinned (raw, to paste): https://raw.githubusercontent.com/adriatic/triad-feedbox/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/checks/preview-owner-nik.sql
- On GitHub: https://github.com/adriatic/triad-feedbox/blob/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/checks/preview-owner-nik.sql

```sql
-- supabase/checks/preview-owner-nik.sql | 188 lines | last line: -- end of preview-owner-nik.sql
-- =============================================================================
-- READ-ONLY check (task F6). Changes nothing: one SELECT.
-- For: feedbox-preview. When: right after supabase/preview/owner-nik.sql.
-- It checks that this is feedbox-preview (project marker); that the database
-- is the Feedbox v1 and O2 migrations, unchanged; that the board "lumen"
-- exists; that exactly one person outside the 221 Lumen people is named
-- "Nik I."; that this person is an owner of "lumen"; and that the owners of
-- "lumen" are exactly "Ana" (from the seed) and "Nik I.".
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
owners as (
  select (xpath('/table/row/boards/text()', x))[1]::text::int as boards,
         (xpath('/table/row/niks/text()', x))[1]::text::int as niks,
         (xpath('/table/row/nik_owner/text()', x))[1]::text::int as nik_owner,
         (xpath('/table/row/names/text()', x))[1]::text as names
  from (select query_to_xml(
                 'select (select count(*) from public.boards b where b.slug = ''lumen'') as boards,
                         (select count(*) from auth.users u join public.profiles p on p.id = u.id
                           where p.display_name = ''Nik I.'' and coalesce(u.email, '''') not like ''%@lumen.example'') as niks,
                         (select count(*) from public.board_owners o
                            join public.boards b on b.id = o.board_id and b.slug = ''lumen''
                            join public.profiles p on p.id = o.user_id
                            join auth.users u on u.id = o.user_id
                           where p.display_name = ''Nik I.'' and coalesce(u.email, '''') not like ''%@lumen.example'') as nik_owner,
                         (select string_agg(coalesce(p.display_name, ''(no name)''), '', '' order by p.display_name)
                            from public.board_owners o join public.boards b on b.id = o.board_id
                            left join public.profiles p on p.id = o.user_id
                           where b.slug = ''lumen'') as names', false, false, '') as x
         where to_regclass('public.boards') is not null and to_regclass('public.board_owners') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-preview',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-preview.'
              else format('this project is marked %s; this check is for feedbox-preview.', (select name from project)) end
  union all
  select 2, 'migrations', a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d',
         case when a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d'
              then 'the Feedbox v1 and O2 migrations are present and unchanged (fingerprint ea60181fdd11e237aa19ee5d6d6c186d).'
              else format('the database does not match the Feedbox v1 and O2 migrations (fingerprint %s, expected ea60181fdd11e237aa19ee5d6d6c186d).', a.md5) end
  from mig_all a
  union all
  select 3, 'board', (select boards from owners) = 1,
         case when (select boards from owners) = 1 then 'the board "lumen" exists.'
              else 'the board "lumen" is MISSING.' end
  union all
  select 4, 'one Nik I.', (select niks from owners) = 1,
         format('people outside the Lumen people named "Nik I.": %s (expected exactly 1).', coalesce((select niks from owners)::text, 'none'))
  union all
  select 5, 'Nik I. is an owner', (select nik_owner from owners) = 1,
         case when (select nik_owner from owners) = 1 then '"Nik I." is an owner of the board "lumen".'
              else '"Nik I." is NOT an owner of the board "lumen".' end
  union all
  select 6, 'owners of lumen', (select names from owners) = 'Ana, Nik I.',
         format('the owners of "lumen" are: %s (expected exactly "Ana, Nik I.").', coalesce((select names from owners), 'nobody'))
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
-- end of preview-owner-nik.sql
```

The removal templates (not run now):
- https://github.com/adriatic/triad-feedbox/blob/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/people/remove-person.sql
- https://github.com/adriatic/triad-feedbox/blob/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/checks/person-removal.sql

## docs/ARCHITECTURE.md changes

These sections changed:
- the introduction: line numbers for the F6 parts;
- 1.2: the server actions;
- 1.3: the owner functions are now called;
- 3.6: steps 6 and 7, hidden comments and moved comments;
- 3.9: steps 5 and 6, the editor;
- 3.10, renamed "What an owner sees and does": hidden items, the Owner tools, the merge and its redirect, what guards them;
- 5: rule 1 now names the shared fixture, and new rules 17, 18 and 19;
- 6: the new SQL folders;
- 7: what F6 built, what is not built in version 1, and F6-D1.

```diff
diff --git a/docs/ARCHITECTURE.md b/docs/ARCHITECTURE.md
index 7c5258b..f7c648c 100644
--- a/docs/ARCHITECTURE.md
+++ b/docs/ARCHITECTURE.md
@@ -2,7 +2,7 @@
 
 How the parts of Feedbox connect, written from the code at commit `1a13023` (tag `f5`, task A1).
 
-Every statement names the file it comes from, so it can be checked line by line. Line numbers refer to `1a13023`, except in the parts updated by task O2 (the Owner mark for everyone), which say so. Three short names are used throughout:
+Every statement names the file it comes from, so it can be checked line by line. Line numbers refer to `1a13023`, except in the parts updated by task O2 (the Owner mark for everyone) and task F6 (the owner tools and the changelog editor), which name files and functions instead. Three short names are used throughout:
 
 - **the migration** means `supabase/migrations/20261113000000_feedbox_v1.sql`, the Feedbox v1 migration;
 - **the O2 migration** means `supabase/migrations/20261118000000_board_owner_ids.sql` (task O2, decision F5-D1);
@@ -45,7 +45,7 @@ Next.js 16, App Router (`package.json`). It has five kinds of server code:
 | Kind | Files | What it does |
 |---|---|---|
 | Pages (server components) | `app/page.tsx` (the board), `app/ideas/[id]/page.tsx`, `app/ideas/new/page.tsx`, `app/changelog/page.tsx`, `app/changelog/new/page.tsx`, `app/sign-in/page.tsx`, `app/auth/confirm/page.tsx`, `app/welcome/page.tsx`, `app/not-found.tsx`, `app/layout.tsx` | Read from Supabase on the server and render HTML |
-| Server actions (`"use server"`) | `app/ideas/new/actions.ts` (`postIdea`, `findSimilar`), `app/ideas/[id]/actions.ts` (`addComment`), `components/vote-action.ts` (`vote`), `app/sign-in/actions.ts` (`sendLink`), `app/auth/confirm/actions.ts` (`finishSignIn`), `app/welcome/actions.ts` (`saveDisplayName`) | Called by the browser's forms and buttons; they run on the server and call Supabase |
+| Server actions (`"use server"`) | `app/ideas/new/actions.ts` (`postIdea`, `findSimilar`), `app/ideas/[id]/actions.ts` (`addComment`), `app/ideas/[id]/owner-actions.ts` (`changeStatus`, `mergeInto`, `setIdeaHidden`, `setCommentHidden`; task F6), `app/changelog/new/actions.ts` (`publishEntry`; task F6), `components/vote-action.ts` (`vote`), `app/sign-in/actions.ts` (`sendLink`), `app/auth/confirm/actions.ts` (`finishSignIn`), `app/welcome/actions.ts` (`saveDisplayName`) | Called by the browser's forms and buttons; they run on the server and call Supabase |
 | Route handler | `app/auth/sign-out/route.ts` | `POST` signs out; `GET` answers 405 |
 | Proxy (Next.js 16's name for middleware) | `proxy.ts` | Runs before every page request: refreshes the session cookies and sends a person without a display name to /welcome |
 | Server-side Supabase access | `lib/supabase/server.ts` (the client), data.ts (all reads, and the vote write), `lib/supabase/env.ts` (settings), `lib/supabase/site.ts` (the site's own address) | The only way the app reaches Supabase |
@@ -69,7 +69,7 @@ Each hosted project has two parts the app uses: Postgres and Supabase Auth.
   - `board_owner_ids` (O2 migration lines 21-38): the user ids of one board's owners, and nothing else, for everyone. It is security definer with `search_path` set to `''`, stable, and only `anon` and `authenticated` may execute it (`supabase/tests/11_board_owner_ids.sql`);
   - the owner functions `set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment` and `publish_changelog_entry` (lines 463-677).
 
-  Today the app calls only `is_board_owner` (data.ts:44), `similar_ideas` (data.ts:173, 199) and, since O2, `board_owner_ids` (`getOwnerIds` in data.ts). The owner functions wait for F6.
+  The app calls `is_board_owner` (data.ts:44), `similar_ideas` (data.ts:173, 199), since O2 `board_owner_ids` (`getOwnerIds` in data.ts), and since F6 every owner function, each from one server action (3.10).
 - **Triggers** (lines 235-453):
   - a profile for every new user (5a);
   - rate limits of 5 ideas, 30 comments and 100 votes per person per hour (5b);
@@ -256,6 +256,8 @@ flowchart LR
    - **Count:** a trigger keeps `comment_count` (5f).
 4. The action refreshes the idea page (`revalidatePath`, line 25). The comments are listed oldest first, flat (data.ts:118-136).
 5. The **Owner** mark appears next to a comment written by an owner of the board, for every viewer: visitors, members and owners (task O2, decision F5-D1). `getOwnerIds` in data.ts asks `board_owner_ids` for the owners' ids; if that fails, for example in a project where the O2 migration has not run yet, the page still loads without the mark and the server logs the reason (`lib/supabase/data.test.ts`). See 3.10.
+6. **Hidden comments (task F6):** an owner has **Hide comment** or **Unhide comment** on every comment (`CommentHideButton` in `app/ideas/[id]/OwnerTools.tsx`, server action `setCommentHidden` in `app/ideas/[id]/owner-actions.ts`, database functions `hide_comment` and `unhide_comment`). A hidden comment is marked "Hidden" for owners; for everyone else RLS leaves it out (migration lines 866-874) and it does not count in `comment_count` (5f).
+7. **Moved comments (task F6):** a comment that a merge moved here reads "From the merged idea “<title>”" (`moved_from_idea_id`, read by `getComments` with `getIdeaTitles` in data.ts).
 
 ### 3.7 Signing in by email link
 
@@ -312,19 +314,31 @@ flowchart LR
 2. `publishedChangelog` (`lib/feedbox/changelog.ts:23-50`) keeps only published entries and orders them newest release first. It drops lines whose idea is hidden and entries left with no lines.
 3. Each release date is a calendar date, shown as written in any time zone (`formatDate`, `lib/feedbox/format.ts:26-31`).
 4. Each line links to its idea. On /changelog the header reads "<board> Changelog" with **Back to the board**, and neither the header nor the footer links to /changelog (`components/Header.tsx:19-55`, `components/Footer.tsx:10-21`).
-5. `/changelog/new` is a bare page for owners that lists drafts. The editor arrives in F6 (`app/changelog/new/page.tsx`).
+5. **Owners** see the button **Write a changelog entry**, which leads to the editor `/changelog/new` (`app/changelog/page.tsx`, task F6). Nobody else sees it.
+6. **The editor** (`app/changelog/new/page.tsx` and `ChangelogForm.tsx`, task F6; no design exists, so it reuses the Post an idea layout):
+   - a visitor is sent to sign in; a member reads "Only the owners of <board> can write the changelog.";
+   - it offers the Shipped, visible, unmerged ideas that are in no entry yet (`ideasReadyForChangelog`, `lib/feedbox/changelog.ts`), all ticked, each with one line to write; the release date starts as the owner's own today;
+   - **Publish** calls the server action `publishEntry` (`app/changelog/new/actions.ts`). It checks the title, date and lines with the core library (`validateChangelogTitle`, `validateReleaseDate`, `validateChangelogNote`, `checkChangelogPicks`), then, with the owner's session, inserts the entry (policy `changelog_entries_insert_owner`), its lines (policy `changelog_items_insert_owner`; the trigger 5g accepts only Shipped ideas of the same board), and calls `publish_changelog_entry`;
+   - these are three requests, not one transaction: if a later one fails, the action deletes the entry it made (policy `changelog_entries_delete_owner`; its lines go with it), so no half-made draft stays;
+   - afterwards the owner lands on `/changelog`, where the entry shows at once.
 
-### 3.10 What an owner sees today
+### 3.10 What an owner sees and does
 
 1. **Who is an owner:** a person listed in `board_owners` for this board. Rows are added by reviewed SQL only, for example `supabase/production/owner-nik.sql`; there is no insert policy (migration lines 828-832). `getViewer` calls `is_board_owner` (data.ts:43-46).
 2. **The header** reads "Signed in as owner" (`viewerStateLabel`, `lib/feedbox/permissions.ts:49-53`).
-3. **Hidden ideas and comments:** an owner also sees them, marked "Hidden" (`app/page.tsx:36, 99`; `app/ideas/[id]/page.tsx:30, 51, 74`).
+3. **Hidden ideas and comments:** an owner also sees them, marked "Hidden", in the board's lists and on the idea page (`app/page.tsx:36, 99`; `app/ideas/[id]/page.tsx`). Visitors and members never see them: RLS does not return them, and a hidden idea's page answers "This page could not be found." (`canSeeIdea`, `lib/feedbox/permissions.ts`).
    - RLS lets owners read them (migration lines 836-838, 866-874).
    - Search and similar ideas still leave hidden ideas out (`similar_ideas`, line 713).
 4. **The Owner mark:** since task O2 (decision F5-D1, decided by Nik on 2026-11-18), everyone sees **Owner** next to comments written by any owner of the board, not only owners.
    - The ids come from the function `board_owner_ids` (O2 migration lines 21-38), which returns the owners' user ids only, never an email or another column (`supabase/tests/11_board_owner_ids.sql`; `e2e/screens.spec.ts`, "everyone sees the Owner mark").
    - The table `board_owners` and its policy `board_owners_read` are unchanged: reading the table directly, an owner sees all owners of the board and anyone else at most their own row (migration lines 830-832).
-5. **No owner tools in the app yet:** the database already has the owner functions (status, merge, hide and unhide, publish), but no page calls them. They arrive in F6.
+5. **The Owner tools** (task F6, as in `Idea.dc.html`): on every idea page an owner sees the box **Owner tools** (`OwnerTools` in `app/ideas/[id]/OwnerTools.tsx`). Visitors and members never get it: the page renders it only for the role `owner`, and every function behind it checks `is_board_owner` again (42501 otherwise). Each tool is a form that calls one server action in `app/ideas/[id]/owner-actions.ts`, which calls one owner function with the owner's own session; the browser never calls Supabase. Refusals come back in words (`ownerRefusalMessage`, `lib/feedbox/screens.ts`: the database's own message for 23514).
+   - **Status:** a list of Open, Planned, Building and Shipped and **Change status** → `changeStatus` → `set_idea_status`. Any change but "the same again" is allowed; an idea in a changelog entry stays Shipped, so the list is disabled with a note (`isInChangelog` in data.ts; trigger 5c in the database).
+   - **Merge into another idea:** opens a panel. The owner picks the target from the visible, unmerged ideas (`mergeTargets`, `lib/feedbox/merge.ts`), and the panel says what will happen before the button: the target's new vote count as a range, since a person's votes are readable only by that person (`mergePreview`), the comments that move, that the idea leaves the board, and "There is no undo." The button → `mergeInto` → `merge_ideas` (migration lines 493-559): votes copied without double counting, comments moved with `moved_from_idea_id`, the idea marked `merged_into_id`.
+   - **After a merge:** the owner lands on the target at `/ideas/<target>?merged=<source>`, which says "“<source>” was merged into this idea. Its votes and comments are here now: N votes in all." The source's own address leads there too (a temporary redirect, since a wrong merge can be repaired by hand); the note shows only when the source really was merged into this idea.
+   - **Hide idea / Unhide idea:** → `setIdeaHidden` → `hide_idea` or `unhide_idea`.
+6. **The changelog editor:** see 3.9.
+7. **Guarded by:** `e2e/owner.spec.ts` (status, merge with its counts, hide and unhide of an idea and a comment, publishing; a member and a visitor never see the panel, the hidden items or the editor) and, in the database, `supabase/tests/06_owner_functions.sql`, `07_merge.sql` and `08_changelog.sql`.
 
 ## 4. Keys: which key is used where
 
@@ -348,7 +362,7 @@ Each rule names the test or check that guards it.
 
 | # | Never… | Guarded by |
 |---|---|---|
-| 1 | The browser never calls Supabase itself; every read and write goes through the app's server | `e2e/screens.spec.ts:11-26`: every test in that file aborts and records any browser request to the local Supabase API, and fails if there was one (task F5b). `lib/supabase/env.test.ts:31` checks that only `env.ts` reads the Supabase settings |
+| 1 | The browser never calls Supabase itself; every read and write goes through the app's server | `e2e/fixtures.ts` (since task F6; before, only `e2e/screens.spec.ts`): every test in `auth.spec.ts`, `owner.spec.ts` and `screens.spec.ts` aborts and records any browser request to the local Supabase API, and fails if there was one (task F5b). `lib/supabase/env.test.ts` checks that only `env.ts` reads the Supabase settings |
 | 2 | No secret key in the app, on the Mac or in a commit | CLAUDE.md, "Three rules" 1 and 3; `.gitignore` excludes every `.env*`; `e2e/local-supabase.ts:26-28` refuses any Supabase address but 127.0.0.1 |
 | 3 | A table never goes without row-level security, and anon and authenticated never get more than the listed grants | `supabase/tests/01_structure.sql`: RLS on every table, exact table and column privileges, and `search_path=''` on every security definer function |
 | 4 | Never more than one vote per person per idea | The primary key on `votes` (migration lines 98-103); `supabase/tests/04_votes.sql` (a second vote fails with 23505; nobody votes as someone else); `e2e/screens.spec.ts:288` (a double click, a reload and a second insert through the API give one vote) |
@@ -364,6 +378,9 @@ Each rule names the test or check that guards it.
 | 14 | A profile never holds an email address, and a display name never contains "@" | `profiles` has no email column; check `profiles_display_name_check` (migration lines 53-59); `supabase/tests/01_structure.sql`; `e2e/auth.spec.ts:68` |
 | 15 | A migration is never edited after it ran on feedbox-preview | `tests/sql-files.test.ts:68-74` pins the file's sha256 |
 | 16 | The tests never touch a hosted project | `e2e/local-supabase.ts:26-28`; `ci.yml` (no secrets; local Supabase only); CLAUDE.md, "Three rules" 2 |
+| 17 | Only an owner of the board changes a status, merges, hides or unhides, or publishes the changelog, and only through the owner functions | The functions check `is_board_owner` (migration section 6); no grant lets anyone write `status`, `merged_into_id`, `hidden_at` or `published_at` (rule 5); the app calls them only from server actions; `supabase/tests/06_owner_functions.sql`, `07_merge.sql`, `08_changelog.sql`; `e2e/owner.spec.ts` |
+| 18 | Visitors and members never see the Owner tools, hidden ideas or comments, or the changelog editor | RLS (migration lines 836-838, 866-874, 888-890); the pages render the tools only for owners; `e2e/owner.spec.ts` (task F6) |
+| 19 | A person becomes an owner, or is removed, only by a reviewed script, never from the app | No insert policy on `board_owners`; `supabase/production/owner-nik.sql`, `supabase/preview/owner-nik.sql`, `supabase/people/remove-person.sql`, each with its check and tested in `scripts/test-sql-checks.sh`; a removal copy may change only its block "request" (`tests/sql-files.test.ts`) |
 
 ## 6. Where settings live
 
@@ -373,17 +390,16 @@ Each rule names the test or check that guards it.
   - `NEXT_PUBLIC_SITE_URL` is optional, read in `lib/supabase/site.ts:10`.
   - In Vercel they are set per environment (CLAUDE.md, "App settings on Vercel"). Locally and in CI they come from `npx supabase status` (`playwright.config.ts:30-34`).
 - **Local Supabase settings:** `supabase/config.toml`. Where they differ from hosted, the difference is on purpose (CLAUDE.md, "Local Supabase against these settings").
-- **SQL that Nik runs on a hosted project:** files in `supabase/checks/`, `supabase/marker/`, `supabase/production/` and, since task O2, `supabase/apply/` (a migration as Nik pastes it, guarded by the project marker), each reviewed and tested (CLAUDE.md, "SQL is code").
+- **SQL that Nik runs on a hosted project:** files in `supabase/checks/`, `supabase/marker/`, `supabase/production/`, since task O2 `supabase/apply/` (a migration as Nik pastes it, guarded by the project marker), and since task F6 `supabase/preview/` (scripts for feedbox-preview only) and `supabase/people/` (removing a person on request: a template, copied per request), each reviewed and tested (CLAUDE.md, "SQL is code").
 
 ## 7. Not built yet, and open decisions
 
-**Not built yet (task F6):**
-- The owner tools on the idea page: change status, merge, hide and unhide ideas and comments (`app/ideas/[id]/page.tsx:11`).
-- The changelog editor (`app/changelog/new/page.tsx:5, 30`).
+**Built in task F6:** the owner tools on the idea page and the changelog editor (3.6, 3.9, 3.10).
 
-The database functions for all of these exist (migration lines 457-677) and are tested (`supabase/tests/06_owner_functions.sql`, `07_merge.sql`, `08_changelog.sql`).
+**Not built in version 1 (F1, section 11):** undoing a merge, CAPTCHA, many boards per deployment, and editing or unpublishing a changelog entry in the app (the database allows both for owners; no screen offers them). The check of the hosted Preview is task P1.
 
 **Decisions** (from the F5 and A1 reports):
 - **F5-D1 (decided 2026-11-18, done in task O2):** everyone may read who the board's owners are, so the Owner mark shows for every viewer (see 3.6 and 3.10).
 - **F5-D2 (open):** whether to build an end-to-end runner against the hosted Preview (`playwright.config.ts:4-7`).
-- **A1-D2 (decided 2026-11-18, fixed later):** the search limit of 20 applies to the whole board before the tab is chosen (see 3.2); it is fixed later, with F6's database work or when a board grows, not now.
+- **A1-D2 (decided 2026-11-18, fixed later):** the search limit of 20 applies to the whole board before the tab is chosen (see 3.2); it is fixed later, with F6's database work or when a board grows, not now. F6 needed no database change; see the F6 report, decision F6-D2.
+- **F6-D1 (open):** whether owners should find hidden ideas by the board's search (`similar_ideas` leaves them out, migration line 713).
```

## Steps for Nik

These steps make you an owner of the Lumen board on **feedbox-preview only**, then check the owner tools on the Preview of pull request #10. Everything happens on the Mac, in Chrome (where you are signed in to Vercel). Change only your own two test ideas, "F5b check: sync over the local network" and "Sync notes", and your own comment. Do not merge, hide or change any Lumen idea.

**F6-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://supabase.com/dashboard/project/qrbeiveyomidfafivuta/sql/new

Expected: the Supabase SQL Editor opens. The project name at the top of the page reads **feedbox-preview**, and the address bar contains `qrbeiveyomidfafivuta` and does NOT contain `imlitxtkpvrcmijgdsrw` (that is feedbox-prod). If either is not so, stop here: you are not in feedbox-preview. Nothing has been changed.

Result

**F6-2** In the same tab (SQL Editor of **feedbox-preview**), clear every existing query. At the top of the SQL Editor, click an "Untitled query" tab: its orange dot turns into an ×. Click the ×, which deletes that query. Repeat until no query tab is left.

Expected: no query tab is left in the SQL Editor, and the top of the page still reads **feedbox-preview**.

Result

**F6-3** (CHANGES the database of feedbox-preview: adds one owner row.) On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/preview/owner-nik.sql
Click into the page, press ⌘A, then ⌘C. Go back to the Supabase tab, check that the top of the page reads **feedbox-preview**, click **+ New query**, click into the empty editor and press ⌘V. Before clicking Run, check that the first line is `-- supabase/preview/owner-nik.sql | 173 lines | last line: -- end of owner-nik.sql`, and, scrolled to the end, that the last line with text is `-- end of owner-nik.sql` at line 173. If either does not match, close that query tab with its × and paste again. Then click **Run**.

Expected: **"Success. No rows returned."** If it says "Refused: …", stop: nothing was changed, as the message says. Copy the message into this note. If any other error appears, stop and do not run it again: nothing was changed, because the script is all or nothing. Copy the whole message into this note.

Result

**F6-4** (read-only, must PASS.) On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/5cca3a06533e26ad3b765a4d1f0abe1ee143af74/supabase/checks/preview-owner-nik.sql
Click into the page, press ⌘A, then ⌘C. Go back to the Supabase tab, check that the top of the page reads **feedbox-preview**, click **+ New query**, click into the empty editor and press ⌘V. Before clicking Run, check that the first line is `-- supabase/checks/preview-owner-nik.sql | 188 lines | last line: -- end of preview-owner-nik.sql`, and that the last line with text is `-- end of preview-owner-nik.sql` at line 188. If either does not match, close that query tab with its × and paste again. Then click **Run**, and take a screenshot of the result (⌘⇧4, then drag over the rows) into this note.

Expected: 7 rows (n 0 to 6). Row 0 reads **"PASS: all 6 checks passed."**, and row 6 reads "the owners of "lumen" are: Ana, Nik I. (expected exactly "Ana, Nik I.")". If row 0 says FAIL, stop: this check changed nothing. Send all rows to Claude.ai and change nothing on your own.

Result

**F6-5** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app

Expected: the board "What should Lumen do next?". If the top right already reads **"Signed in as owner"**, go on to F6-6. If it reads "Signed in as Nik I.", click **Sign out**, then sign in as described next. If it reads "Viewing as visitor", sign in like this:
- Click **Sign in**, type your own email address in **Email address**, and click **Send me a link**.
- In Mac Mail, open the new email from **Feedbox <feedbox@pactresearch.net>** with the subject **Your Feedbox sign-in link**, Control-click its link **Sign in to Feedbox** and choose **Copy Link**.
- Go back to this Chrome tab, click the address bar, press ⌘V and press Return. The page shows the button **Finish signing in**; click it.

Afterwards the top right reads **"Signed in as owner"**.

Result

**F6-6** In the same tab, on the board's **Open** tab, click your idea **F5b check: sync over the local network**. Below the idea, in the box **Owner tools**, choose **Planned** in the **Status** list, then click **Change status**.

Expected: the box shows "The status is now Planned.", and the chip next to the idea's title reads **Planned**.

Result

**F6-7** In the same tab, click **← All ideas**, then the tab **Open**, and click your idea **Sync notes**. In **Owner tools**, click **Merge into another idea**. In the list **Merge “Sync notes” into**, choose **F5b check: sync over the local network**. Read the text under **What will happen**, then click the button **Merge into “F5b check: sync over the local network”**.

Expected: before the click, the panel says how many votes and comments move, that "Sync notes" leaves the board, and, on an orange background, "There is no undo. A wrong merge can only be repaired by hand in the database." After the click, the page "F5b check: sync over the local network" opens with a blue note at the top: "“Sync notes” was merged into this idea. Its votes and comments are here now: N votes in all." Write N into this note. If only you voted for both ideas, N is 1, because your vote counts once. Any comments that were on "Sync notes" now read "From the merged idea “Sync notes”".

Result

**F6-8** On the same page ("F5b check: sync over the local network"), scroll to **Add a comment**, type `F6 check: a comment to hide` and click **Post comment**. Then, on that new comment, click **Hide comment**. Then click **Unhide comment** on it. Then click **Hide comment** on it once more.

Expected: after the first **Hide comment**, the comment shows an orange **Hidden** chip and the link reads **Unhide comment**. After **Unhide comment**, the chip is gone. After the last click, the chip **Hidden** is back. Leave it hidden for F6-11.

Result

**F6-9** On the same page, in **Owner tools**, choose **Shipped** in the **Status** list and click **Change status**.

Expected: "The status is now Shipped.", and the chip next to the title reads **Shipped**.

Result

**F6-10** In the same tab, click **Changelog** at the top right, then the button **Write a changelog entry**. In **Title**, type `F6 check`. Leave **Release date** as it is (today). Under "Shipped ideas not in the changelog yet", check that **F5b check: sync over the local network** is ticked, and type `Checked the owner tools on the Preview.` into the box under it. Then click **Publish**.

Expected: the editor lists the Shipped ideas that are in no entry yet, all ticked; F5b check is among them (it should be the only one). After **Publish**, the page "What shipped in Lumen" opens. Its first entry is today's date with "F6 check", and below it "F5b check: sync over the local network", the line "Checked the owner tools on the Preview." and "See the idea, N votes".

Result

**F6-11** At the top right, click **Sign out**. Then, as a visitor, click **Changelog**, then **Back to the board**, then the tab **Shipped**, and click **F5b check: sync over the local network**.

Expected:
- the top right reads "Viewing as visitor";
- the changelog shows the entry "F6 check" and has no button **Write a changelog entry**;
- on the idea's page there is no **Owner tools** box, no **Hide comment** link, and no comment "F6 check: a comment to hide".

Result

**F6-12** In the same tab, click **← All ideas**, then the tab **Open**.

Expected: "Sync notes" is not in the list, because it was merged.

Result

**F6-13** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

F5-D2 stays open as written in the F5 report. Four new ones:

**F6-D1, your decision: should owners find hidden ideas by search and similar ideas?** (A1 finding 3, question (a))
- **Today:** `similar_ideas` always leaves hidden ideas out (migration line 713). So an owner sees hidden ideas in the board's lists, but the search box never finds them. Changing that needs a new migration (a new version of `similar_ideas`).
- **Options:**
  1. Leave it.
  2. Owners also find hidden ideas with the board's search box, marked "Hidden".
  3. The same, and also in Post an idea's similar ideas.
- **My recommendation: option 1 for now, and never option 3.**
  - Post an idea should never suggest a hidden idea, not even to an owner. Its purpose is to stop duplicates of visible ideas.
  - For the board's search, an owner can already find hidden ideas in the tab lists, marked "Hidden". With small boards that is enough.
  - If it is ever wanted, do it in the same migration as F6-D2.

**F6-D2, your decision: is now the time to fix A1-D2, the search limit of 20 before the tab?** (question (b))
- F6 needed no database change, so there is no migration to add it to.
- The fault can only show when more than 20 ideas on one board match a search. The Lumen board has 10 ideas plus test ideas, and the Feedbox board on Production has none.
- **My recommendation: not now.** Fix it together with F6-D1 option 2, in one migration, when a board passes about 100 ideas or when you first see a search miss an idea.

**F6-D3, your decision: should the merge panel show the exact new vote count instead of a range?**
- The app cannot see who voted for what: a person's votes are readable by that person only. So the panel says "between X and Y votes", and the target's page shows the exact count right after the merge.
- An exact count before the merge needs a new read-only database function (security definer) that counts the voters of both ideas. That is a migration.
- **My recommendation: no.** The range is honest, the exact number comes one click later, and it saves a function that would read every voter.

**F6-D4, your decision: the way a person is removed on request** (README, "Privacy").
- As built, each request becomes a small task. Claude Code copies the two templates with the person's **User UID** (never the email address) and the project; Claude.ai reviews the copy; you run it from its pinned link.
- So each removed person's User UID ends up in the public repository. A UID is a random number that says nothing about the person without the database, and the person no longer exists in the database after the removal.
- The alternative is to keep the per-request copies out of the repository. But then they would not be reviewed and pinned like every other SQL ("SQL is code").
- **My recommendation: keep it as built.**
