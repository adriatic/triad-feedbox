DO NOT RUN ANY SQL YET. Claude.ai reads the scripts first.

# Task F3c: SQL is code (check scripts that verify where they run and report PASS or FAIL)

Date: 2026-11-13. Branch `f3-database`, pull request #2 (still open, not merged). Nothing was run against any hosted database.

**New head of `f3-database`: `f65d62355695c33c8fcbff4a9b6c849467a626d8`** (previous head `fb13cc76dcbd9e8dedfe98518b83cbe37a328786`).

## The migration is unchanged (correction of 9:31 PM)

- **What happened:** before the correction arrived, I had edited `supabase/migrations/20261113000000_feedbox_v1.sql` in the working copy only. I had added a header line, a guard block and a footer line.
- **Restored, never committed:** I restored the file to exactly its content at `423572c` before committing, so no commit on `f3-database` ever held the edited file. At the new head the migration is byte-for-byte the file applied on feedbox-preview:
  - `git diff 423572c HEAD -- supabase/migrations` is empty;
  - sha256 `25077cb5974b0810601816af39297a082cdd5b97a350e842a9832970d6795384`;
  - 937 lines; last line `  on conflict (id) do nothing;`.
- **Kept that way by CI:** a new unit test (`tests/sql-files.test.ts`) pins that sha256, so `unit` fails if the migration is ever edited. CLAUDE.md now says a migration is never edited after it has run on feedbox-preview.

## Decisions Nik must make

1. **F3c-D1. Should the migration get a double-paste guard? My recommendation: no, and nothing was changed.**
   - I tested a double paste of the unchanged migration locally, as one query (see the CI and local results below). The second copy stops on Postgres's own error `type "idea_status" already exists`, and the whole query is undone: nothing changed.
   - Running it a second time later gives the same error and changes nothing.
   - The clear messages come from `prod-before-migration.sql`, which Nik runs first and which FAILs if any Feedbox object exists, and from the header and line checks in the steps.
2. **F3c-D2. Should the seed refuse outside feedbox-preview? My recommendation: not now.**
   - The correction allowed only the header, footer and the clearer double-paste message in the seed, so the seed does not read the project marker.
   - It cannot run on feedbox-prod today: there are no Feedbox tables there, so it stops with `relation "public.boards" does not exist` (tested).
   - After M3 it could run there. The steps never link it for feedbox-prod, and a later task could add a marker check if you want one.
3. **F3c-D3, for your information: one assumption that Claude.ai should know about.**
   - **The assumption:** the double-paste messages rely on the SQL Editor running a pasted text as one transaction, so that an error in the second copy undoes the first.
   - **What it rests on:** I found no Supabase documentation that says so. It rests on what happened tonight: when the old seed failed at its 8th statement on feedbox-preview, the people inserted by its 2nd statement were not saved (0 people at lumen.example).
   - **How the messages are worded:** where the script can tell that the first copy ran in the same query, the message says so. That case is detected with `xmin = pg_current_xact_id()`. Otherwise the message says "this script has run before, or was pasted twice into one query. Nothing was changed by this copy". That wording is true either way.

## How a script knows which project it is in

- **Supabase offers no documented way:** I found no documented function or setting that gives a SQL script the project's name or ref.
  - Every project's database is named `postgres`.
  - The closest source is the GitHub discussion "Is there a way to get the project reference id or url from within Postgres?" (https://github.com/orgs/supabase/discussions/12639). It has no answer from Supabase staff. One user reports that the suggested `ALTER SYSTEM` setting failed on a hosted Pro project with a permission error, even as `postgres`.
  - I did not rely on anything undocumented.
- **So: a marker row, set once per project with a reviewed script.** The marker is the table `triad.project`, holding one row with the project's name and the time it was marked.
  - The table allows exactly one row, and only the names `local`, `feedbox-preview` and `feedbox-prod`.
  - The schema `triad` is not an API schema. Its privileges are also revoked from anon and authenticated, and row-level security is on with no policy.
  - The migration and the undo script never touch it.
- **Marker scripts:** `supabase/marker/feedbox-preview.sql` and `supabase/marker/feedbox-prod.sql`. Each is one `do` block with its own guard. It refuses, and changes nothing, if the project already has a marker. A double paste in one query is detected and named.
- **Each marker also checks tonight's real state, so it cannot be set in the wrong project:**
  - The preview marker requires the Feedbox tables, the Lumen board and exactly 221 Lumen people.
  - The prod marker requires no Feedbox tables, no schema `private`, no type `idea_status` and no Lumen people.
  - Each marker refuses in the other project; both cases were tested locally.
- **The local database is marked `local`** by `supabase/marker/local.sql`. `supabase db reset` and `supabase db start` run it before the seed (`[db.seed] sql_paths` in `supabase/config.toml`). It is never pasted.

## Every script

The line counts and last lines are those at `f65d623`. Each file's first line names its path, line count and last line, except the migration. The pinned links were checked to serve byte-for-byte the committed files.

| File | Lines | Last line | What it checks or does | When Nik runs it |
|---|---|---|---|---|
| `supabase/marker/feedbox-preview.sql` | 66 | `-- end of feedbox-preview.sql` | **Changes:** sets the marker `feedbox-preview` (guarded as above) | **Now**, once, in feedbox-preview |
| `supabase/marker/feedbox-prod.sql` | 65 | `-- end of feedbox-prod.sql` | **Changes:** sets the marker `feedbox-prod` (guarded as above) | **Now**, once, in feedbox-prod |
| `supabase/checks/preview-seed.sql` | 219 | `-- end of preview-seed.sql` | Read-only, 16 rows: project is feedbox-preview; migration present and unchanged (one fingerprint); 221 Lumen people and one profile per person; rows board_owners 1, boards 1, changelog_entries 2, changelog_items 3, comments 9, ideas 10, votes 1059; 10 ideas on the Lumen board, owner Ana, 2 published entries; each of the 10 ideas' status, vote count and comment count | **Now**, after the preview marker; any time later |
| `supabase/checks/prod-before-migration.sql` | 165 | `-- end of prod-before-migration.sql` | Read-only, 5 rows: project is feedbox-prod; none of the 8 Feedbox tables; no type `idea_status`, schema `private`, trigger `on_auth_user_created`, functions or tables in public; no Lumen people | **Now**, after the prod marker; again in M3 just before the migration |
| `supabase/checks/prod-after-migration.sql` | 227 | `-- end of prod-after-migration.sql` | Read-only, 15 rows: project; the 8 tables; RLS on all 8; `idea_status` values; columns, indexes, 19 policies, 19 functions and 10 triggers (counts plus md5 fingerprints); table and column privileges of anon and authenticated, exactly as in the F3 report; who may call which function; `pg_trgm` in `extensions`; no email column; no Feedbox rows except one profile per person | M3, right after the migration |
| `supabase/checks/prod-ready-for-board.sql` | 169 | `-- end of prod-ready-for-board.sql` | Read-only, 6 rows: project; migration present and unchanged; no Lumen people; 0 boards; 0 rows in the other tables (profiles aside) | M3, before the board script |
| `supabase/checks/prod-board.sql` | 181 | `-- end of prod-board.sql` | Read-only, 6 rows: project; migration present; no Lumen people; exactly 1 board, `feedbox`; its name, tagline and intro exactly as in `board-feedbox.sql` | M3, after the board script |
| `supabase/production/board-feedbox.sql` | 60 | `-- end of board-feedbox.sql` | **Changes:** inserts the Feedbox board. It is now one `do` block that refuses unless the marker is `feedbox-prod` (or `local`), the migration is applied, there are no Lumen people and there is no board; a double paste is named | M3 |
| `supabase/seed.sql` | 213 (was 202) | `-- end of seed.sql` | **Changes:** the Lumen seed (already run on preview) | Not again |
| `supabase/production/undo-feedbox-v1.sql` | 103 (was 101) | `-- end of undo-feedbox-v1.sql` | **Changes:** the F3b undo (already run on prod) | Not again |
| `supabase/production/check-undo-feedbox-v1.sql` | 19 (was 16) | `-- end of check-undo-feedbox-v1.sql` | Read-only F3b check, kept as it was run; superseded by `prod-before-migration.sql` | Not again |
| `supabase/marker/local.sql` | 25 | `-- end of local.sql` | **Changes:** marks the local database `local` | Never (local reset only) |
| `supabase/migrations/20261113000000_feedbox_v1.sql` | 937 | `  on conflict (id) do nothing;` | **Unchanged** since `423572c` | M3 (feedbox-prod) |

**How every check works:**
- **One read-only statement:** each check is ONE `SELECT`, with no `$` quoting and no statement that changes anything (a unit test checks this). The columns are `n`, `check_name`, `result` (`PASS` or `FAIL`) and `message`.
- **Row 0 is the overall result:** "PASS: all N checks passed." or "FAIL: k of N checks failed. Stop here and send this result to Claude.ai."
- **Row 1 is the project:** if it fails, every other row says "FAIL: not checked, because check 1 (project) failed."
- **Messages:** each one says what was found and what was expected, for example "PASS: "Dark mode for the editor": planned, 214 votes, 3 comments (expected planned, 214 votes, 3 comments)."
- **Missing objects:** no check ever errors on a missing table. Such tables are read through `query_to_xml` behind a `to_regclass` test, which I tested on an empty project.
- **Expected values live in the scripts:** this includes md5 fingerprints taken from a fresh local install of the unchanged migration. The overall migration fingerprint is `160138805f7dcd5baa26b543b24aede3`.
- **Shared blocks are identical:** the blocks for the project, the fingerprint, the counts and the result are word for word the same in all five checks, and a unit test enforces this.
- **First real test of the fingerprint:** `preview-seed.sql` on feedbox-preview is the first time the fingerprint is compared with a hosted database. If only row 2 (migration) FAILs there, it means the hosted catalog prints something differently from local Postgres 17.11, and Claude.ai should see it before M3.

## Every change to the seed and the undo script

**`supabase/seed.sql`** (was 202 lines at `944f007`, now 213):
1. Line 1 added: `-- supabase/seed.sql | 213 lines | last line: -- end of seed.sql`.
2. The header comment says a double paste is reported.
3. In `declare`, two variables were added (`v_same_txn boolean`, `v_at timestamptz`); the existing two were only re-aligned.
4. The guard `if exists (… slug = 'lumen') then raise 'The Lumen board already exists. The seed has run before; nothing was changed.'` was replaced. It now reads the Lumen board's `xmin` and `created_at` and raises one of two messages:
   - If the board was created in this same query: "Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again."
   - Otherwise: "Refused: the Lumen board already exists (created <time>). The seed has run before, or this script was pasted twice into one query. Nothing was changed by this copy."
5. The last line was added: `-- end of seed.sql`.

Nothing else changed: the same people, ideas, votes, comments, changelog and final check.

**`supabase/production/undo-feedbox-v1.sql`** (was 101 lines at `fb13cc7`, now 103):
1. Line 1 added: `-- supabase/production/undo-feedbox-v1.sql | 103 lines | last line: -- end of undo-feedbox-v1.sql`.
2. One message changed. The missing-table refusal was "… does not exist, so this is not the state this script was written for. Nothing was changed." It is now "Refused: table public.% does not exist. The undo has already run, this script was pasted twice into one query, or this is the wrong project. Nothing was changed by this copy."
3. The last line was added: `-- end of undo-feedbox-v1.sql`.

Nothing else changed.

**`supabase/production/check-undo-feedbox-v1.sql`** (was 16 lines, now 19): the header line, one comment line ("Kept as run on 2026-11-13; superseded by supabase/checks/prod-before-migration.sql.") and the footer line. The query itself is unchanged.

## Local results (local Supabase in Docker only)

**The test script:** `npm run test:checks` (`scripts/test-sql-checks.sh`) sends every script the way the SQL Editor sends a paste: the whole text as ONE query string (`psql -c`). "Pasted twice" means the text twice in one query.
- **Database states:** it walks the local database through four states:
  - (A) the Lumen preview;
  - (B) an empty project like feedbox-prod tonight;
  - (C) prod after the migration;
  - (D) prod with its board.
- **Refusals:** for every refusal it compares a snapshot of the marker, the tables, the people, the functions and the row counts before and after. Every refusal changed nothing.
- **Clean-up:** it resets the database at the start and the end.
- **Result: all 56 expectations were met.** Afterwards, `npx supabase test db` gave `Files=10, Tests=225, Result: PASS`.

PASS and FAIL in every state (row 0 of each check):

| State | Check | Result | The failing row's message, when it FAILs |
|---|---|---|---|
| A, marked `local` | preview-seed | FAIL | "this project is marked local; this check is for feedbox-preview." |
| A, marked `feedbox-preview` | preview-seed | **PASS** | "all 15 checks passed." |
| A, one vote deleted | preview-seed | FAIL | votes 1058 (expected 1059); "Faster startup on large notebooks": 87 votes (expected 88) |
| A, `grant insert on ideas to anon` | preview-seed | FAIL | "the database does not match the reviewed Feedbox v1 migration (fingerprint b7e8…, expected 1601…)" |
| A | prod-before-migration, prod-after-migration, prod-ready-for-board, prod-board | FAIL | "this project is marked feedbox-preview; this check is for feedbox-prod." |
| B, no marker | prod-before-migration | FAIL | "this project has no project marker (triad.project)." |
| B, marked `feedbox-prod` | prod-before-migration | **PASS** | "all 4 checks passed." |
| B, one stray `public.boards` | prod-before-migration | FAIL | "1 of the 8 Feedbox tables exist (expected 0): boards." |
| B | prod-after-migration | FAIL | 12 rows, for example "0 row-level security policies (expected 19)"; no error |
| B | prod-ready-for-board, prod-board | FAIL | the migration fingerprint differs; "no table boards" |
| B | preview-seed | FAIL | "this project is marked feedbox-prod; this check is for feedbox-preview." |
| C, after the migration | prod-after-migration | **PASS** | "all 14 checks passed." |
| C | prod-ready-for-board | **PASS** | "all 5 checks passed." |
| C, `grant update (status) on ideas` | prod-after-migration | FAIL | row 9, column privileges |
| C, RLS off on votes | prod-after-migration | FAIL | "row-level security is on for 7 tables in public (expected 8)." |
| C, one function body replaced | prod-after-migration | FAIL | "19 functions … DO NOT match the reviewed migration" |
| C | prod-before-migration | FAIL | "8 of the 8 Feedbox tables exist (expected 0)" |
| C | prod-board | FAIL | "0 boards (expected 1)" |
| D, after the board script | prod-board | **PASS** | "all 5 checks passed." |
| D, tagline changed | prod-board | FAIL | row 5, board text |
| D, a second board | prod-board | FAIL | "2 boards (expected 1)" |
| D | prod-ready-for-board | FAIL | "1 boards (expected 0)." |
| D | prod-after-migration | FAIL | row 14, "boards 1" |

Changing scripts: every refusal below changed nothing (snapshot before = after).

| Script | State | Result |
|---|---|---|
| marker feedbox-prod, pasted twice | B | "Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. …" |
| marker feedbox-prod | B | success |
| marker feedbox-prod again | B | "Refused: this project is already marked as feedbox-prod (since …). … If you pasted this script twice into one query, that is the cause. Nothing was changed by this copy." |
| marker feedbox-preview | B | "Refused: this project has no Feedbox tables, but feedbox-preview has them. Are you in feedbox-prod? …" |
| marker feedbox-preview or feedbox-prod | A (already marked) | "Refused: this project is already marked as feedbox-preview …" |
| seed | A (seeded) | "Refused: the Lumen board already exists (created …). The seed has run before, or this script was pasted twice into one query. Nothing was changed by this copy." |
| seed, pasted twice | C (fresh migration) | "Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. …" |
| seed | B (no tables) | `relation "public.boards" does not exist` (see F3c-D2) |
| migration (unchanged), pasted twice | B | `type "idea_status" already exists`; nothing changed, and prod-before-migration still PASS (see F3c-D1) |
| migration again | A and C | `type "idea_status" already exists`; nothing changed |
| board script, pasted twice | C | "Refused: this script was pasted twice into one query. …"; prod-ready-for-board still PASS |
| board script | C | success |
| board script again | D | "Refused: this project already has a board (feedbox, created …). …" |
| board script | A | "Refused: this project is marked feedbox-preview. The Feedbox board is only for feedbox-prod. …" |
| board script | B | "Refused: the Feedbox migration is not applied in this project …" |
| undo | A and D | "Refused: table public.boards has rows. …" |
| undo, pasted twice | C | "Refused: table public.boards does not exist. The undo has already run, this script was pasted twice into one query, …"; prod-after-migration still PASS |
| undo when already undone | B | the same message |

**Unit, lint and typecheck:** `npm test` gave 100 tests passing (77 from before, plus 23 new in `tests/sql-files.test.ts`); `npm run lint` and `npm run typecheck` are clean.

## CI results (on `f65d623`)

Both workflow runs concluded `success` on head `f65d62355695c33c8fcbff4a9b6c849467a626d8`: https://github.com/adriatic/triad-feedbox/actions/runs/43562281701 (push) and https://github.com/adriatic/triad-feedbox/actions/runs/43562286208 (pull_request).

| Check | Result |
|---|---|
| `lint` | pass (push 17s; pull_request 19s) |
| `typecheck` | pass (push 27s; pull_request 27s) |
| `unit` | pass (push 28s; pull_request 26s). 11 test files, including the new `tests/sql-files.test.ts` |
| `db` | pass (push 1m10s; pull_request 58s). Log: `Files=10, Tests=225, Result: PASS`, then `SQL checks: all 56 expectations met.` |
| `Vercel` | pass (Preview deployment completed) |

## Steps for Nik, later

**⚠️ WAITING FOR CLAUDE.AI'S GO-AHEAD. Do not start these steps until Claude.ai has read the scripts and says so.** These are only the steps needed now: mark both projects, and check each one. Nothing here changes Feedbox data.

**For every script below, before you click Run:** look at the first line in the editor. It names the file, its line count and its last line. Scroll to the bottom and check that the last line is exactly the one it names. If it is not, the copy is incomplete or doubled: clear the query and paste again.

### In feedbox-preview

1. **Select the project.** In Chrome, open https://supabase.com/dashboard, choose the organisation **TRIAD**, then the project **feedbox-preview**. Check that the project selector at the top says **`feedbox-preview`**.
2. **Clear all existing queries.** In the left menu, click **SQL Editor**.
   1. At the top of the SQL Editor, click each "Untitled query" tab.
   2. Its orange dot turns into an ×. Click the ×, which deletes that query.
   3. Repeat until no query tab is left.
3. **Mark the project (changes the database once).**
   - Open https://raw.githubusercontent.com/adriatic/triad-feedbox/f65d62355695c33c8fcbff4a9b6c849467a626d8/supabase/marker/feedbox-preview.sql (**66 lines**, last line `-- end of feedbox-preview.sql`). Press **Cmd+A**, then **Cmd+C**.
   - In the SQL Editor, click **+ New query**, press **Cmd+V**, check the first and last lines, and click **Run**.
   - Expected: **"Success. No rows returned."**
   - If it says "Refused: …", nothing was changed: send the message to Claude.ai.
4. **Check the project and the seed (read-only).**
   - Open https://raw.githubusercontent.com/adriatic/triad-feedbox/f65d62355695c33c8fcbff4a9b6c849467a626d8/supabase/checks/preview-seed.sql (**219 lines**, last line `-- end of preview-seed.sql`). Copy it the same way.
   - Click **+ New query**, paste, check the first and last lines, and click **Run**.
   - Expected: 16 rows; row 0 says **"PASS: all 15 checks passed."**
   - If row 0 says FAIL, send all rows to Claude.ai. If only row 2 (migration) fails, that is the fingerprint difference described above, not a data problem.

### In feedbox-prod

5. **Select the project.** Choose the project **feedbox-prod** and check that the project selector at the top says **`feedbox-prod`**.
6. **Clear all existing queries.** In the SQL Editor:
   1. At the top of the SQL Editor, click each "Untitled query" tab.
   2. Its orange dot turns into an ×. Click the ×, which deletes that query.
   3. Repeat until no query tab is left.
7. **Mark the project (changes the database once).**
   - Open https://raw.githubusercontent.com/adriatic/triad-feedbox/f65d62355695c33c8fcbff4a9b6c849467a626d8/supabase/marker/feedbox-prod.sql (**65 lines**, last line `-- end of feedbox-prod.sql`). Copy it.
   - Click **+ New query**, paste, check the first and last lines, and click **Run**.
   - Expected: **"Success. No rows returned."**
   - If it says "Refused: …", nothing was changed: send the message to Claude.ai.
8. **Check the project (read-only).**
   - Open https://raw.githubusercontent.com/adriatic/triad-feedbox/f65d62355695c33c8fcbff4a9b6c849467a626d8/supabase/checks/prod-before-migration.sql (**165 lines**, last line `-- end of prod-before-migration.sql`). Copy it.
   - Click **+ New query**, paste, check the first and last lines, and click **Run**.
   - Expected: 5 rows; row 0 says **"PASS: all 4 checks passed."**
9. Send Claude.ai the results of steps 3, 4, 7 and 8 (screenshots are fine). Do not run the migration, the seed or `board-feedbox.sql` anywhere now; the migration and the board script come in M3.

## Links and hashes

- Pull request #2: https://github.com/adriatic/triad-feedbox/pull/2
- New head of `f3-database`: `f65d62355695c33c8fcbff4a9b6c849467a626d8`
- Commit: https://github.com/adriatic/triad-feedbox/commit/f65d62355695c33c8fcbff4a9b6c849467a626d8
- Migration (unchanged, as applied on feedbox-preview): https://raw.githubusercontent.com/adriatic/triad-feedbox/423572ca740d43a64cc9b88d71b5df4918c6f9c6/supabase/migrations/20261113000000_feedbox_v1.sql
- Source for the project question: https://github.com/orgs/supabase/discussions/12639
- CLAUDE.md: a new section "SQL is code" (the rule, the project markers, how check scripts and changing scripts are written, the header and footer, the tests, and the clear-the-editor step with Nik's exact clicks), plus the rule that a migration is never edited after it has run on feedbox-preview, and the new commands `npm run test:checks` and `npm run sql:headers`.

## Check before pushing

I searched this report for `TODO`, `TBD`, `XXX`, `{{`, `CI_TABLE` and angle-bracket placeholders. The only angle brackets are in the quoted message "(created <time>)", which shows where the script prints a time. Every requested item is present:
- the first line;
- the decisions;
- how the project is identified, with its source and the local test;
- the table of every script with file, line count, last line, what it checks and when;
- the local PASS and FAIL results;
- the CI results;
- the new head;
- every change to the seed and the undo script, with the new line counts;
- the statement that the migration is unchanged;
- "Steps for Nik, later", starting with the clear-queries step and marked as waiting for Claude.ai.
