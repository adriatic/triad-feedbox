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
2. Never push to `main` directly. The ruleset on `main` restricts deletions, blocks force pushes, requires a pull request (0 approvals) and requires six status checks: `lint`, `typecheck`, `unit`, `db`, `e2e` and `Vercel` (`lint`, `typecheck`, `unit` and `Vercel` since M2, `db` since M3, `e2e` since M5).
3. **Never merge** in a build task. Merging is a separate merge task (M2, M3, …), given only after Nik says "merge" in his chat with Claude.ai. Nik's word, with its time, is recorded in the TRIAD tracker, and the merge task message quotes it.
4. A merge task: check that the branch head is the approved commit, confirm the pull request's checks are green, squash-merge with gh (`--match-head-commit`), delete the branch, confirm that the Production deployment of `main` succeeds, tag the merge commit `f<n>`, and report.
5. CI checks (GitHub Actions workflow `CI`): `lint`, `typecheck`, `unit`, `db` (pgTAP tests, `npm run test:checks` and, since F6b, `npm run test:races` on a local Supabase database in Docker on the runner), `e2e` (since F4: Playwright against the app built on the runner and LOCAL Supabase in Docker; a required check since M5). All five, plus Vercel's own status `Vercel`, are required on `main`.

## Three rules that are never broken
1. **You never hold a Supabase secret key**: not in a file on the Mac, not in your shell, not in a commit. No secret key of a hosted project exists anywhere outside the Supabase dashboard. The three GitHub Actions secrets `SUPABASE_PREVIEW_SECRET_KEY`, `SUPABASE_PREVIEW_PUBLISHABLE_KEY` and `SUPABASE_PREVIEW_URL`, which no workflow ever used, were deleted on 2026-11-18 by Nik's decision A1-D1.
2. **You never apply a change to a hosted database.** No `supabase login`, no `supabase db push`, no SQL against `feedbox-preview` or `feedbox-prod`. You write the migration; Claude.ai reads it line by line; Nik runs it, first on Preview, then on Production. Local Supabase in Docker (colima) for tests is fine.
3. **No secrets on the Mac for this project.** No `.env.local` with keys, no Supabase CLI login, no machine-user token. `.gitignore` excludes every `.env*` file.

Supabase projects were created with "Automatically expose new tables" ON and "Enable automatic RLS" OFF. Every migration must therefore revoke the default grants, grant explicitly, and enable RLS on every table it creates.

## Reports
- Every task ends with a report `summary-task-<id>-<topic>.md` in `/Users/nikolajivancic/CC reports and tasks/`, also committed to the branch `cc-reports` (file at the branch root) and pushed.
- Order: decisions Nik must make, then Steps for Nik (complete, numbered), then results, links, check names and commit hashes.
- Before sending, search the report for unfilled placeholders or missing items and fix them.
- `cc-reports` is never merged into `main`. Use a separate worktree or `git switch`; never mix report commits into a task branch.
- **Architecture description (task A1):** every task that changes how the parts connect (a new path, a new service, a key, or a rule in the "never" list) updates `docs/ARCHITECTURE.md` in the same pull request, and its report says so.
- **Steps check links by clicking (Nik, F5d-3, 2026-11-17):** a step checks what a link does by clicking it, never by Chrome's hover address box, which did not show on Nik's Mac.

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
- `npm run test:races`: runs a merge or an undo in one database session while another session votes, unvotes, comments, merges or undoes at the same moment (task F6b; local database only; resets it at the start and the end)
- `npm run sql:headers`: sets the line count in the header line of every pasted SQL file
- `npm run e2e:supabase`: the full local Supabase stack (database, auth, API, Mailpit) that the end-to-end tests need; `npm run db:start` starts the database only
- `npm run test:e2e`: Playwright tests in `e2e/` (builds the app, starts it on http://127.0.0.1:3000 with the LOCAL Supabase keys from `supabase status`, never a hosted project)
- `npm run screenshots`: Playwright screenshots of every screen and state (light and dark, 1280 and 390 px) into `screenshots/F5/`, against LOCAL Supabase; with `SIDE_BY_SIDE_DIR=<folder>` also one design-beside-screen image per design (the designs are drawn with `e2e/design-support.js`). Not part of `test:e2e` or CI, so the committed images change only when asked for
- `npm run db:types`: regenerate `lib/supabase/database.types.ts` from the local database (after a migration)

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

## Sign-in emails
- Two Supabase email templates are code, in `supabase/templates/`: `confirmation.html` ("Confirm signup", subject "Your first Feedbox sign-in link", sent on a person's FIRST sign-in) and `magic_link.html` ("Magic Link", subject "Your Feedbox sign-in link", every later sign-in). Both link to `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`, so both land on `/auth/confirm`, which calls `verifyOtp({ type: 'email', token_hash })` only when the button is pressed. Never `{{ .ConfirmationURL }}`: it goes through supabase.co and comes back with `code=`, which `/auth/confirm` does not accept.
- The hosted projects require email confirmation, and each project's dashboard (Authentication, Emails, Templates) must hold exactly these two subjects and bodies. Nik pastes them; a change to a template file is a step for Nik in both projects.
- `supabase/config.toml` sets the same for local Supabase (`enable_confirmations = true`, both templates); `tests/email-templates.test.ts` keeps the files and the config in line.
- In a freshly started local stack, the auth service sends Supabase's default emails for a few seconds (it loads the template files before the gateway that serves them is up). `e2e/global-setup.ts` waits until both Feedbox templates are in use before the end-to-end tests start.

## Dashboard settings
**Rule (Nik, 2026-11-15 9:04 PM): dashboard settings are code too, and are checked.** Every setting that lives only in a dashboard (Vercel, Supabase, Resend) is written here, as the source of truth, with who checked it and when. When a task needs a dashboard change, the task changes this section in the same pull request and gives Nik the step; after Nik's check, the "Checked" column is updated.

**Secrets never appear here.** A row marked **SECRET** names the value and where it lives; the value itself exists only in that dashboard. Never write, ask for or copy it.

### Vercel (project `triad-feedbox`, team `nikolaj-ivancics-projects`)
#### App settings on Vercel
Settings, Environment Variables. Each is type **Config** (not secret: the two `NEXT_PUBLIC_` values are built into the code the browser gets) and is set once per environment.

| Setting | Preview | Production | Where the value comes from | Checked |
|---|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | feedbox-preview's Project URL | feedbox-prod's Project URL | Supabase dashboard, the project, Connect (or Project Settings, Data API): `https://<project ID>.supabase.co` | Nik, added 2026-11-15 6:39 PM |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | feedbox-preview's publishable key | feedbox-prod's publishable key | Supabase dashboard, the project, Project Settings, API Keys: the key starting `sb_publishable_` (never a secret key) | Nik, added 2026-11-15 6:39 PM |
| `FEEDBOX_BOARD_SLUG` | `lumen` | `feedbox` | The board's slug: `lumen` from `supabase/seed.sql`, `feedbox` from `supabase/production/board-feedbox.sql` | Nik, added 2026-11-15 6:39 PM |
| `NEXT_PUBLIC_SITE_URL` | not set (a Preview links back to its own address) | `https://triad-feedbox-delta.vercel.app` | The Production address; it must match feedbox-prod's Site URL and Redirect URLs | Nik, 2026-11-15/16 |

- **A changed setting reaches a deployment only when it is built again.** `NEXT_PUBLIC_` values are copied into the code at build time. After adding or changing a setting, push a new commit to the branch (Vercel builds a new Preview), or in Vercel open Deployments, the deployment's ⋯ menu, **Redeploy**.
- All settings are read through `lib/supabase/env.ts` (`NEXT_PUBLIC_SITE_URL` through `lib/supabase/site.ts`, where it is optional). A missing one fails with `Missing environment variable <NAME>. ...`, never with Supabase's "URL and Key are required"; `lib/supabase/env.test.ts` keeps this in `unit`.
- Locally and in CI the values come from `npx supabase status` (the local stack), never from a hosted project.

| Other Vercel setting | Value | Checked |
|---|---|---|
| Deployment Protection, Vercel Authentication | Standard Protection (Previews need a Vercel sign-in; Production is public) | set in Setup (F1, step C6); seen working 2026-11-15 (a Preview answers 302 to Vercel's sign-in) |

### Supabase (organisation TRIAD)
#### Sign-in by email (both projects)
| Setting | feedbox-preview | feedbox-prod | Checked |
|---|---|---|---|
| Authentication, Emails, Templates, **Magic Link** | subject `Your Feedbox sign-in link`, body = `supabase/templates/magic_link.html` | the same | Nik, 2026-11-15/16 (feedbox-preview also at 2026-11-15 7:16 PM) |
| Authentication, Emails, Templates, **Confirm signup** | subject `Your first Feedbox sign-in link`, body = `supabase/templates/confirmation.html` | the same | Nik, 2026-11-15/16 |
| Authentication, Emails, SMTP Settings, **Enable Custom SMTP** | on | on | Nik, 2026-11-15/16 (decision F4-D3) |
| Sender email | `feedbox@pactresearch.net` | `feedbox@pactresearch.net` | Nik, 2026-11-15/16 |
| Sender name | `Feedbox` | `Feedbox` | Nik, 2026-11-15/16 |
| Host | `smtp.resend.com` | `smtp.resend.com` | Nik, 2026-11-15/16 |
| Port | `465` | `465` | Nik, 2026-11-15/16 |
| Username | `resend` | `resend` | Nik, 2026-11-15/16 |
| Password | **SECRET**: the Resend API key named `feedbox-preview` | **SECRET**: the Resend API key named `feedbox-prod` | lives only in Supabase and Resend |

The template files are the source; `tests/email-templates.test.ts` checks them and `supabase/config.toml` uses them locally (see "Sign-in emails"). A change to a template file is a step for Nik in both projects.

#### URL Configuration (Authentication, URL Configuration)
| Setting | feedbox-preview | feedbox-prod | Checked |
|---|---|---|---|
| Site URL | `http://localhost:3000` | `https://triad-feedbox-delta.vercel.app` | feedbox-prod: Nik, 2026-11-16 4:58 PM. feedbox-preview: Nik, 2026-11-16 5:31 PM |
| Redirect URLs | exactly two: `http://localhost:3000/**` and `https://triad-feedbox-*-nikolaj-ivancics-projects.vercel.app/**` (no leftover team-slug entry) | exactly one: `https://triad-feedbox-delta.vercel.app/**` | feedbox-prod: Nik, 2026-11-16 4:58 PM. feedbox-preview: Nik, 2026-11-16 5:31 PM |

If a Preview address is missing from feedbox-preview's Redirect URLs, Supabase quietly links to the Site URL instead, and the sign-in link breaks.

#### Sign In / Providers, Email, and Rate Limits
| Setting | feedbox-preview | feedbox-prod | Checked |
|---|---|---|---|
| Sign In / Providers: Allow new users to sign up | on | on | feedbox-prod: Nik, 2026-11-16 5:31 PM. feedbox-preview: Nik, 2026-11-16 9:13 PM |
| Sign In / Providers: **Confirm email** | on (a first sign-in gets the Confirm signup email) | on | feedbox-prod: Nik, 2026-11-16 5:31 PM. feedbox-preview: Nik, 2026-11-16 9:13 PM |
| Email: Enable email provider | on | on | Nik, 2026-11-16 9:13 PM |
| Email: Enable magic links and email OTP | on | on | Nik, 2026-11-16 9:13 PM |
| Email: Email OTP length | 8 digits | 8 digits | Nik, 2026-11-16 9:13 PM |
| Email: **Email OTP expiration** | `900` seconds | `900` seconds | Nik, 2026-11-16 9:28 PM, after a reload. **Corrected:** it was `3600` in both projects (seen 9:13 PM), not the `900` of Setup step D-9; Nik's decision F4f-D1 set both to `900`, to match "expires in 15 minutes" in both email templates and on the sign-in page |
| Rate Limits: rate limit for sending emails | `30` per hour | `30` per hour | feedbox-prod: Nik, 2026-11-16 5:31 PM. feedbox-preview: Nik, 2026-11-16 9:13 PM |
| Rate Limits: minimum interval per user | `60` seconds | `60` seconds | feedbox-preview: Nik, 2026-11-16 9:13 PM. feedbox-prod: Nik, 2026-11-17 8:47 AM (screenshot of the Rate Limits page, opened from feedbox-prod's address), and verified on screen by Nik on 2026-11-17 at 8:49 AM (noted in M7) |

#### Local Supabase (`supabase/config.toml`) against these settings
The local stack mirrors the hosted sign-in settings, except where a difference is on purpose:

| Setting | Local | Hosted (both projects) | Why |
|---|---|---|---|
| Email templates and subjects, Confirm email, OTP expiration 900, OTP length 8 | the same | the same | mirrored (OTP length since C1) |
| Sender | `Feedbox <feedbox@pactresearch.net>` (`[local_smtp]`) | `Feedbox <feedbox@pactresearch.net>` | mirrored since C1; locally Mailpit catches every email, nothing is sent |
| Sending | Mailpit | custom SMTP through Resend | **different on purpose**: no email leaves the Mac or the CI runner |
| Rate limit for sending emails | `60` per hour | `30` per hour | **different on purpose**: repeated e2e runs send many emails |
| Minimum interval per user (`max_frequency`) | `1s` | `60` seconds | **different on purpose**: the e2e tests send two sign-in emails to one address within seconds |
| Redirect URLs | `http://localhost:3000/**`, `http://127.0.0.1:3000/**` | see URL Configuration | **different on purpose**: Playwright uses 127.0.0.1 |

#### Chosen at project creation (Setup, F1)
| Setting | Value (both projects) | Checked |
|---|---|---|
| Automatically expose new tables | on | chosen at creation; not part of the check of 2026-11-16 |
| Enable automatic RLS | off | chosen at creation; not part of the check of 2026-11-16 |

Every migration is written for exactly these two choices (see "Three rules").

### Resend (sends the Supabase emails)
| Setting | Value | Checked |
|---|---|---|
| Sending domain | `pactresearch.net` (the domain both API keys may send for) | Nik, 2026-11-15/16 |
| API key `feedbox-preview` | Sending access, domain `pactresearch.net`; **SECRET**, pasted only into feedbox-preview's SMTP password | Nik, 2026-11-15/16 |
| API key `feedbox-prod` | Sending access, domain `pactresearch.net`; **SECRET**, pasted only into feedbox-prod's SMTP password | Nik, 2026-11-15/16 |

One key per project, so either can be revoked without touching the other.

## Is TRIAD ready?
`scripts/triad-ready.sh` (task T1) tells Nik, line by line, whether every piece of TRIAD is in place on the Mac before a session. Nik runs it in a NEW Terminal tab (not inside Claude Code):

    /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh

- It prints `PASS` or `FAIL`, the check's name and what it found; every `FAIL` says what to do. The last line is `READY: all N checks passed.` or `NOT READY: K of N checks failed.` (exit code 0 or 1).
- The 19 checks, in order: macOS version (information); Claude desktop app running; Chrome running; Claude Code installed; Node.js matches `.nvmrc`; the project folder is a clone of `adriatic/triad-feedbox` (and its branch); the git working tree (information); the reports folder exists, can be written to and holds `feedbox-inputs`; the Obsidian vault and its TRIAD folder; Docker running; the stored GitHub sign-in can read the repository; git reaches GitHub over SSH; the `cc-reports` branch exists; `main` requires the six checks `lint`, `typecheck`, `unit`, `db`, `e2e` and `Vercel`; the latest CI run on `main` passed; Vercel Production answers; Vercel's status on `main`'s latest commit is success; Supabase feedbox-preview answers; Supabase feedbox-prod answers (both asked with no key; project IDs from the Obsidian note `TRIAD/Important URLs.md`).
- It only reads: it changes, installs, starts, stops and signs in to nothing, sends no key, and every network check has a time limit. The `TRIAD_*` variables in its header point checks at wrong places, for testing only. `tests/triad-ready.test.ts` keeps those rules in `unit`.
- When you add a piece to TRIAD, add its check here, in README.md and in the script, and update the count of checks in all three places and in `tests/triad-ready.test.ts`.

## Layout
- **No link to the page you are on** (tasks F5c and F5d): not in the header, the footer, the board's tabs (the current tab is plain text) or the sort menu (the ticked order is not a link). `e2e/screens.spec.ts` checks every page a visitor can open
- `app/`: Next.js App Router routes: `/`, `/ideas/[id]` (with the Owner tools for owners, task F6: `OwnerTools.tsx`, `owner-actions.ts`; on a merge's target, Undo merge, task F6a), `/ideas/new`, `/changelog`, `/changelog/new` (the changelog editor for owners, task F6), `/contact` (Contact the owner, task CT1), `/messages` (the owners' Messages page, task CT1), `/sign-in`, `/auth/confirm`, `/auth/sign-out`, `/welcome`
- `proxy.ts`: Next.js 16's middleware: refreshes the Supabase session and sends a signed-in person without a display name to `/welcome`
- `lib/supabase/`: the server client (`@supabase/ssr`, publishable key only), data reads and writes, generated database types. **The browser never calls Supabase itself** (task F5b): every read and write goes through a page, a server action or `proxy.ts`, with the person's session cookies. The fixture in `e2e/fixtures.ts` (task F6) blocks the browser from the Supabase API in every end-to-end test that imports it, and fails on any attempt
- `components/`: shared pieces: the header with the sign-in state (on `/changelog` it reads "<board> Changelog" with "Back to the board", task F5c; for owners "Messages (n)", except on `/messages`, task CT1), the footer (`Footer`: no "See what shipped" link on `/changelog`, task F5d; "Contact the owner" on every page but `/contact`, task CT1), the board's sort menu (`SortMenu`: "Most votes" or "Newest", task F5c), the vote button (`useVote`: votes and unvotes without a reload, through the server action `components/vote-action.ts`; the database is the authority), the status chip, the board's search box, `LocalDate` (a moment shown as the date in the viewer's own time zone, task F5b; a calendar date such as a changelog release is shown as written)
- `app/globals.css`: the styles, taken from the six designs (colours, light and dark by the system setting, phone layout below 640 px)
- `e2e/`: Playwright tests (local Supabase only): `auth.spec.ts` (F4, sign-in), `screens.spec.ts` (F5, the screens), `owner.spec.ts` (F6, the owner tools and the changelog editor; F6a, undo of a merge), `messages.spec.ts` (CT1, Contact the owner and Messages), `screenshots.spec.ts` (only with `npm run screenshots`); `fixtures.ts` (the shared `test`, which blocks the browser from Supabase); `helpers.ts` (sign in as a test person, tidy up); `e2e/global-setup.ts` waits until local Supabase sends the Feedbox email templates
- `screenshots/F5/`: the F5 screenshots, `<state>-<light|dark>-<1280|390>.png`
- `lib/feedbox/`: core library. Pure TypeScript with **no** Supabase or Next imports; unit tests sit beside the code as `*.test.ts`
- `lib/messages/`: the messages part (task CT1), kept self-contained with general names so it can be carried over to another app (docs/ARCHITECTURE.md, section 8): `core.ts` (rules and words, pure TypeScript, tested in `core.test.ts`) and `data.ts` (server reads and writes through `lib/supabase/server.ts`)
- `design/`: design brief and the six screen sources (part of the app's definition)
- `supabase/`: `config.toml` (local only), `migrations/`, `seed.sql`, `production/`, `apply/` (a migration as Nik pastes it, guarded by the project marker: `<project>-<topic>.sql`, tasks O2, F6a and CT1; `tests/sql-files.test.ts` keeps its statements identical to the migration file), `preview/` (changing scripts for feedbox-preview only, task F6), `people/` (removing a person on request: the template `remove-person.sql`, copied per request with only its block "request" changed, task F6), `checks/` (read-only check scripts), `marker/` (project markers), `tests/`, `templates/`
- `scripts/`: `sql-files.ts` (header lines of pasted SQL), `test-sql-checks.sh` (tests of check and changing scripts), `test-races.sh` (two sessions at the same time, task F6b) and `triad-ready.sh` (is TRIAD ready on the Mac); `tests/`: repository-level unit tests (`tests/sql-files.test.ts`, `tests/triad-ready.test.ts`, `tests/email-templates.test.ts`)
- Later tasks add `TRIAD.md` and `templates/` (at the root)
