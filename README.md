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

The design brief and the six screen sources are in [`design/`](design/).

Licence: MIT, see [LICENSE](LICENSE).
