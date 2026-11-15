# CLAUDE.md: working rules for Claude Code in this repository

## Where things are
- GitHub repository: `adriatic/triad-feedbox` (public, MIT): https://github.com/adriatic/triad-feedbox
- Local folder on Nik's Mac: `/Users/nikolajivancic/Work/triad-feedbox`
- Reports and task texts: `/Users/nikolajivancic/CC reports and tasks/`
- Design inputs (also copied into `design/`): `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/`
- Production: https://triad-feedbox-delta.vercel.app (Vercel project `triad-feedbox`, team `nikolaj-ivancics-projects`)
- Supabase: organisation TRIAD (Pro plan), projects `feedbox-preview` and `feedbox-prod`, region Americas

Feedbox is the worked example for an article about TRIAD (Tracker-Recorded, Independently Approved Development). Keep everything generic. Nothing from pact-web goes in this repository.

## GitHub account and how to push
- Every git and GitHub action runs as the account `adriatic`. There is no second account.
- **Before any git command, run `git rev-parse --show-toplevel`** and check that it prints `/Users/nikolajivancic/Work/triad-feedbox`.
- Remote `origin` is `git@github.com:adriatic/triad-feedbox.git`. Push over SSH; the key for github.com is set in `~/.ssh/config`.
- **GitHub CLI:** `gh` is the single program `~/gh-cli` (not on `PATH`, not a folder). Use its stored sign-in (account `adriatic`, macOS keychain, in `~/.config/gh`) by putting **`env -u GH_TOKEN`** before every command. The shell's `GH_TOKEN` is limited to chosen repositories and is refused here.
  - Read-only check: `env -u GH_TOKEN ~/gh-cli api repos/adriatic/triad-feedbox --jq .full_name`
  - Open a pull request (after pushing the branch): `env -u GH_TOKEN ~/gh-cli pr create --repo adriatic/triad-feedbox --base main --head <branch> --title "..." --body-file <file>`
  - Checks: `env -u GH_TOKEN ~/gh-cli pr checks <number> --repo adriatic/triad-feedbox`
  - Merge, only in a merge task: `env -u GH_TOKEN ~/gh-cli pr merge <number> --repo adriatic/triad-feedbox --squash --match-head-commit <approved sha>`
- **Never print, copy or move a token.** Never run `gh auth token`, never use `--show-token`, never echo `GH_TOKEN`. Never open key or environment files; refer to them by name only. Do not look for other credentials.
- CI runs on the branch push itself, and Vercel builds a Preview for every pushed branch at `https://triad-feedbox-git-<branch>-nikolaj-ivancics-projects.vercel.app`, so checks and the Preview can be verified before the pull request exists.

## Branches, pull requests and merging
1. Each task works on its own branch from `main`, named `f<n>-<topic>` (for example `f2-core`), and opens exactly ONE pull request into `main`.
2. Never push to `main` directly. The ruleset on `main` restricts deletions, blocks force pushes, requires a pull request (0 approvals) and requires the status checks `lint`, `typecheck`, `unit` and `Vercel` (since M2; `db` is added in M3).
3. **Never merge** in a build task. Merging is a separate merge task (M2, M3, …), given only after Nik says "merge" in his chat with Claude.ai. Nik's word, with its time, is recorded in the TRIAD tracker, and the merge task message quotes it.
4. A merge task: check that the branch head is the approved commit, confirm the pull request's checks are green, squash-merge with gh (`--match-head-commit`), delete the branch, confirm that the Production deployment of `main` succeeds, tag the merge commit `f<n>`, and report.
5. CI checks (GitHub Actions workflow `CI`): `lint`, `typecheck`, `unit`, `db` (pgTAP tests and `npm run test:checks` on a local Supabase database in Docker on the runner).

## Three rules that are never broken
1. **You never hold a Supabase secret key**: not in a file on the Mac, not in your shell, not in a commit. The preview secret key exists only as the GitHub Actions secret `SUPABASE_PREVIEW_SECRET_KEY`, used only by CI.
2. **You never apply a change to a hosted database.** No `supabase login`, no `supabase db push`, no SQL against `feedbox-preview` or `feedbox-prod`. You write the migration; Claude.ai reads it line by line; Nik runs it, first on Preview, then on Production. Local Supabase in Docker (colima) for tests is fine.
3. **No secrets on the Mac for this project.** No `.env.local` with keys, no Supabase CLI login, no machine-user token. `.gitignore` excludes every `.env*` file.

Supabase projects were created with "Automatically expose new tables" ON and "Enable automatic RLS" OFF. Every migration must therefore revoke the default grants, grant explicitly, and enable RLS on every table it creates.

## Reports
- Every task ends with a report `summary-task-<id>-<topic>.md` in `/Users/nikolajivancic/CC reports and tasks/`, also committed to the branch `cc-reports` (file at the branch root) and pushed.
- Order: decisions Nik must make, then Steps for Nik (complete, numbered), then results, links, check names and commit hashes.
- Before sending, search the report for unfilled placeholders or missing items and fix them.
- `cc-reports` is never merged into `main`. Use a separate worktree or `git switch`; never mix report commits into a task branch.

## Commands
- `npm ci`: install
- `npm run dev`: local server on http://localhost:3000
- `npm run lint`, `npm run typecheck`, `npm test`: the same three checks as CI
- `npm run build`: production build (what Vercel runs)
- `npm run db:start`: local Supabase database in Docker (colima must be running: `colima start`). Applies `supabase/migrations/` and `supabase/seed.sql`. Ports 5542x, so it runs beside other local Supabase projects.
- `npm run test:db`: the pgTAP tests in `supabase/tests/` against the local database
- `npm run db:reset`: rebuild the local database from the migration and the seed
- `npm run db:stop`: stop this project's local containers only
- `npm run test:checks`: runs every check script and changing script on the right and the wrong states (local database only; resets it at the start and the end)
- `npm run sql:headers`: sets the line count in the header line of every pasted SQL file

## Database
- One migration per database task in `supabase/migrations/`. It must run as one script in the Supabase SQL Editor (no psql commands).
- Every new table: revoke all from anon and authenticated, grant back only what is needed (column by column for writes), enable RLS, add policies. Every security definer function: `set search_path = ''` and full schema names.
- `supabase/seed.sql` (Lumen) is for local and feedbox-preview only. `supabase/production/` holds the few rows feedbox-prod needs.
- Tests: `supabase/tests/NN_name.sql`, each in a transaction that is rolled back, sharing `supabase/tests/_helpers.psql`. Test boards never use the slug `lumen`.
- **A migration is never edited after it has run on feedbox-preview**, not even its comment lines: production must get exactly the file that ran on Preview. `tests/sql-files.test.ts` pins the sha256 of each applied migration. A fix is a new migration.

## SQL is code (Nik, 2026-11-13)
Every query Nik runs is written, tested and reviewed like any other code. Nik never types SQL from the tracker and never compares results by eye.
- **Every SQL Nik runs is a file in this repository**, reviewed by Claude.ai line by line, and run from a raw GitHub link pinned to a commit. That includes read-only checks.
- **Which project:** a script cannot tell feedbox-preview from feedbox-prod by itself, because Supabase exposes no project name or ref in SQL. Each hosted project therefore holds a marker row in `triad.project`, set once with the reviewed scripts `supabase/marker/feedbox-preview.sql` and `supabase/marker/feedbox-prod.sql`. The local database is marked `local` by `supabase/marker/local.sql`, which runs on every reset. Every check, and every changing script written from now on, reads the marker first and refuses in the wrong project.
- **Check scripts** (`supabase/checks/<project>-<moment>.sql`):
  - Each is ONE read-only `SELECT`, with no `$` quoting and no statement that changes anything.
  - It never errors when an object is missing; tables that may not exist are read through `query_to_xml` behind a `to_regclass` test.
  - Row 1 checks the project marker. Row 0 is the overall `PASS`/`FAIL`. Each row has the columns `n`, `check_name`, `result` (`PASS` or `FAIL`) and `message`, in plain words: what was found and what was expected.
  - Every expected value is written inside the script. Long values are md5 fingerprints taken from a fresh local install.
  - The shared blocks (`-- shared:<name>:begin` … `end`) are identical in every check; a unit test enforces this.
- **Changing scripts** are ONE `do` block, so they are all or nothing. They check the project and the expected state before changing anything. A refusal says what was found, says that nothing was changed, and, when the cause can be a double paste, says that the script may have been pasted twice into one query. To detect a double paste in the same query, compare the row's `xmin` with `pg_current_xact_id()`.
- **Header and footer:** every pasted SQL file (except a migration that has already run) starts with `-- <path> | <N> lines | last line: -- end of <file name>` and ends with `-- end of <file name>`. `npm run sql:headers` sets N, and `unit` fails if either line is wrong.
- **Tests:** `scripts/test-sql-checks.sh` (`npm run test:checks`, CI job `db`) sends each script the way the SQL Editor does, as one query string. It shows each check PASSing on its state and FAILing on wrong states (wrong project, empty, seeded, tampered), and each changing script refusing with nothing changed. Add every new script and state there.
- **Steps for Nik with SQL always start with this step: clear all existing queries in the Supabase SQL Editor,** so no earlier query can be run by mistake. The clicks (found by Nik, 2026-11-13 9:12 PM):
  1. At the top of the SQL Editor, click each "Untitled query" tab.
  2. Its orange dot turns into an ×. Click the ×, which deletes that query.
  3. Repeat until no query tab is left.

  Then, for each script: click **+ New query**, paste from the pinned link, and check that the editor shows the header line and, at the bottom, the last line it names, before clicking **Run**.

## Layout
- `app/`: Next.js App Router routes
- `lib/feedbox/`: core library. Pure TypeScript with **no** Supabase or Next imports; unit tests sit beside the code as `*.test.ts`
- `design/`: design brief and the six screen sources (part of the app's definition)
- `supabase/`: `config.toml` (local only), `migrations/`, `seed.sql`, `production/`, `checks/` (read-only check scripts), `marker/` (project markers), `tests/`, `templates/`
- `scripts/`: `sql-files.ts` (header lines of pasted SQL) and `test-sql-checks.sh` (tests of check and changing scripts); `tests/`: repository-level unit tests (`tests/sql-files.test.ts`)
- Later tasks add `e2e/`, `components/`, `screenshots/`, `TRIAD.md` and `templates/` (at the root)
