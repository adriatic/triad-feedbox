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
- The `gh` CLI is not installed. Open pull requests and read checks through the GitHub REST API with `curl` and the `GH_TOKEN` environment variable, for example `POST https://api.github.com/repos/adriatic/triad-feedbox/pulls`. Never print the token.
- The token cannot create repositories or change repository settings, and you must not try to.

## Branches, pull requests and merging
1. Each task works on its own branch from `main`, named `f<n>-<topic>` (for example `f2-core`), and opens exactly ONE pull request into `main`.
2. Never push to `main` directly. The ruleset on `main` restricts deletions, blocks force pushes and requires a pull request (0 approvals). Required status checks are added in M2.
3. **Never merge** in a build task. Merging is a separate merge task (M2, M3, …), given only after Nik says "merge" in his chat with Claude.ai. Nik's word, with its time, is recorded in the TRIAD tracker, and the merge task message quotes it.
4. A merge task: confirm the pull request's checks are green, squash-merge through the API, confirm that the Production deployment of `main` succeeds, and report.
5. CI checks (GitHub Actions workflow `CI`): `lint`, `typecheck`, `unit`.

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

## Layout
- `app/`: Next.js App Router routes
- `lib/feedbox/`: core library. Pure TypeScript with **no** Supabase or Next imports; unit tests sit beside the code as `*.test.ts`
- `design/`: design brief and the six screen sources (part of the app's definition)
- Later tasks add `supabase/`, `e2e/`, `components/`, `screenshots/`, `TRIAD.md` and `templates/`
