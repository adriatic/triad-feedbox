# Feedbox

Feedbox is a free, open-source feedback and roadmap board. Each product gets a public board where people post ideas and upvote them, and the owner moves ideas through Open, Planned, Building and Shipped and publishes a changelog.

It is built with Next.js, Supabase and Vercel, and is the worked example for an article about the TRIAD protocol (Tracker-Recorded, Independently Approved Development).

Status: early build. The core library (`lib/feedbox/`), the database and sign-in by email link exist; every page is still bare (unstyled) until the screens are built.

## Run it locally

Needs Node 24 (see `.nvmrc`). The app reads three settings: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (never a secret key) and `FEEDBOX_BOARD_SLUG` (the one board this deployment shows, for example `lumen` locally). For the local Supabase, `npx supabase status` prints the URL and the publishable key. A missing setting stops the app with `Missing environment variable <NAME>`.

```sh
npm ci
npm run dev        # http://localhost:3000
npm run lint
npm run typecheck
npm test
```

With Docker running (for example `colima start`), the local Supabase and the end-to-end tests:

```sh
npm run e2e:supabase   # local Supabase in Docker
npm run test:e2e       # Playwright, against the local database only
```

## Settings on Vercel

Four settings, each of type Config, set once for Preview and once for Production (project `triad-feedbox`, Settings, Environment Variables):

| Setting | Preview | Production | Value from |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | feedbox-preview | feedbox-prod | Supabase dashboard: the project's URL, `https://<project ID>.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | feedbox-preview | feedbox-prod | Supabase dashboard, Project Settings, API Keys: the publishable key (`sb_publishable_...`) |
| `FEEDBOX_BOARD_SLUG` | `lumen` | `feedbox` | the board's slug |
| `NEXT_PUBLIC_SITE_URL` | not set | `https://triad-feedbox-delta.vercel.app` | the Production address |

`NEXT_PUBLIC_` values are built into the code, so a deployment sees a changed setting only after it is built again: push a new commit, or use Redeploy in Vercel.

The two sign-in emails ("Confirm signup" for a person's first sign-in, "Magic Link" for every later one) are in [`supabase/templates/`](supabase/templates/); each Supabase project's dashboard must hold the same text.

## Is TRIAD ready?

Before a TRIAD session, one command runs 19 checks of every piece on the Mac: the Claude desktop app, Chrome, Claude Code, Node.js, the project, reports and Obsidian folders, Docker, the GitHub sign-in, SSH, the `cc-reports` branch, the required checks and the latest CI run on `main`, Vercel Production and its build of `main`, and the two Supabase projects (feedbox-preview and feedbox-prod, asked with no key). Run it in a new Terminal tab:

```sh
/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
```

It prints one `PASS` or `FAIL` line per check (each `FAIL` says what to do) and ends with `READY: all 19 checks passed.` or `NOT READY: K of 19 checks failed.` It only reads: it changes, starts and signs in to nothing, and needs no key. The paths in it are those of the author's Mac; see the header of [`scripts/triad-ready.sh`](scripts/triad-ready.sh).

The design brief and the six screen sources are in [`design/`](design/).

Licence: MIT, see [LICENSE](LICENSE).
