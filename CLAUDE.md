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
5. CI checks (GitHub Actions workflow `CI`): `lint`, `typecheck`, `unit`, `db` (pgTAP tests on a local Supabase database in Docker on the runner).

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

## Database
- One migration per database task in `supabase/migrations/`. It must run as one script in the Supabase SQL Editor (no psql commands).
- Every new table: revoke all from anon and authenticated, grant back only what is needed (column by column for writes), enable RLS, add policies. Every security definer function: `set search_path = ''` and full schema names.
- `supabase/seed.sql` (Lumen) is for local and feedbox-preview only. `supabase/production/` holds the few rows feedbox-prod needs.
- Tests: `supabase/tests/NN_name.sql`, each in a transaction that is rolled back, sharing `supabase/tests/_helpers.psql`. Test boards never use the slug `lumen`.

## Layout
- `app/`: Next.js App Router routes
- `lib/feedbox/`: core library. Pure TypeScript with **no** Supabase or Next imports; unit tests sit beside the code as `*.test.ts`
- `design/`: design brief and the six screen sources (part of the app's definition)
- `supabase/`: `config.toml` (local only), `migrations/`, `seed.sql`, `production/`, `tests/`, `templates/`
- Later tasks add `e2e/`, `components/`, `screenshots/`, `TRIAD.md` and `templates/` (at the root)
