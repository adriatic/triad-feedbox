# Feedbox

Feedbox is a free, open-source feedback and roadmap board. Each product gets a public board where people post ideas and upvote them, and the owner moves ideas through Open, Planned, Building and Shipped and publishes a changelog.

It is built with Next.js, Supabase and Vercel, and is the worked example for an article about the TRIAD protocol (Tracker-Recorded, Independently Approved Development).

Status: early build. The core library (`lib/feedbox/`) and an app skeleton exist; the board itself is not built yet.

## Run it locally

Needs Node 24 (see `.nvmrc`).

```sh
npm ci
npm run dev        # http://localhost:3000
npm run lint
npm run typecheck
npm test
```

## Is TRIAD ready?

Before a TRIAD session, one command runs 19 checks of every piece on the Mac: the Claude desktop app, Chrome, Claude Code, Node.js, the project, reports and Obsidian folders, Docker, the GitHub sign-in, SSH, the `cc-reports` branch, the required checks and the latest CI run on `main`, Vercel Production and its build of `main`, and the two Supabase projects (feedbox-preview and feedbox-prod, asked with no key). Run it in a new Terminal tab:

```sh
/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
```

It prints one `PASS` or `FAIL` line per check (each `FAIL` says what to do) and ends with `READY: all 19 checks passed.` or `NOT READY: K of 19 checks failed.` It only reads: it changes, starts and signs in to nothing, and needs no key. The paths in it are those of the author's Mac; see the header of [`scripts/triad-ready.sh`](scripts/triad-ready.sh).

The design brief and the six screen sources are in [`design/`](design/).

Licence: MIT, see [LICENSE](LICENSE).
