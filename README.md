# Feedbox

Feedbox is a free, open-source feedback and roadmap board. Each product gets a public board where people post ideas and upvote them, and the owner moves ideas through Open, Planned, Building and Shipped and publishes a changelog.

It is built with Next.js, Supabase and Vercel, and is the worked example for an article about the TRIAD protocol (Tracker-Recorded, Independently Approved Development).

Status: version 1. The board, idea pages, posting, voting, comments, sign-in by email link and the changelog are styled to the six designs in [`design/`](design/), and owners have their tools and the changelog editor (see "Owners" below).

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

## Owners

An owner of a board looks after it. On each idea's page an owner sees the **Owner tools** box, and can:

- **change the status**: Open, Planned, Building or Shipped, forward or back. An idea that is in a changelog entry stays Shipped;
- **merge** an idea into another one (a duplicate into the original). Everyone who voted for the duplicate gets a vote on the original, unless they had one already, so nobody counts twice; the comments move along and say where they came from; the duplicate's address then leads to the original. The form says what will happen before the button, and asks plainly: "Merge “…” into “…”? You can undo this from that idea's page.";
- **undo a merge**: on the original's page an owner sees "“<duplicate>” was merged into this idea." with an **Undo merge** button. The duplicate comes back on the board exactly as before, at the same address; everyone who had voted for it counts on it again; the original loses the votes it gained only through the merge (a person who had voted for both keeps a vote on each); the comments go back. What happened in between stays where it was made: a new vote or comment on the original stays there, and a vote someone removed in the meantime is not added back. A wrong merge never needs SQL. Merges made before the undo existed (task F6a) show the note without the button;
- **hide or unhide** an idea, and each comment. Hidden things vanish for everyone else and stay visible to owners, marked "Hidden";
- **write the changelog** at `/changelog/new` (from the button "Write a changelog entry" on the changelog page): a title, a release date, and one line for each Shipped idea that is not in the changelog yet. Publishing shows the entry on `/changelog` at once.

Owners also see hidden ideas in the board's lists. Everything an owner does goes through the owner functions in the database (`set_idea_status`, `merge_ideas`, `undo_merge`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment`, `publish_changelog_entry`), which check that the person owns the board.

**How a person becomes an owner:** only with reviewed SQL, never from the app. The person signs in once and sets a display name; then a script made for that one board and person adds a row to `board_owners`, and a read-only check confirms it. Examples: [`supabase/production/owner-nik.sql`](supabase/production/owner-nik.sql) with [`supabase/checks/prod-owner.sql`](supabase/checks/prod-owner.sql) (the board `feedbox` on Production), and [`supabase/preview/owner-nik.sql`](supabase/preview/owner-nik.sql) with [`supabase/checks/preview-owner-nik.sql`](supabase/checks/preview-owner-nik.sql) (the board `lumen` on the Preview). Each refuses to run in the wrong project, refuses unless it can tell the person apart without an email address, and is safe if pasted twice.

## Privacy

What Feedbox stores, and where:

- **Supabase Auth** (part of the Supabase project): each person's email address, when they signed up and last signed in, and Supabase's own sign-in log. Only the project's administrators can read it; the app never shows an email address to anyone.
- **The Feedbox tables** (the same Supabase project): the display name the person chose (never an email address: a name with "@" is refused), and the ideas, votes and comments they wrote, each with its time. For owners also which ideas or comments they hid, which changelog entries they wrote, and which merges they made or undid. The merge log also keeps, for each merge, whose votes it moved, so the merge can be undone; nobody can read that part through the app, not even an owner.
- **The browser:** only the sign-in session, in HTTP-only cookies. No analytics, no tracking, no other cookies.
- **Resend** sends the sign-in emails and keeps a log of what it sent, as its own terms say. **Vercel** hosts the app and keeps its request logs, as its own terms say.

Everything a person writes on a board (display name, ideas, comments, the number of votes) is public on that board, except what an owner has hidden.

**Removing a person on request.** The removal is a reviewed script, like every SQL in this project ("SQL is code" in [CLAUDE.md](CLAUDE.md)):

1. Find the person's **User UID** in the Supabase dashboard (the project, Authentication, Users, search by their email address). The email address itself is never written into the repository.
2. A task copies the template [`supabase/people/remove-person.sql`](supabase/people/remove-person.sql) to `supabase/people/remove-<date>.sql`, and the check [`supabase/checks/person-removal.sql`](supabase/checks/person-removal.sql) to `supabase/checks/person-removal-<date>.sql`, changing only the two values in their block "request": the project and the User UID. A unit test makes sure nothing else differs.
3. The check, run first, says what will go. The removal script then deletes the person; the database removes with them their profile, their ideas (with every vote, comment and changelog line on those ideas), their votes and their comments, and their votes in the merge log (so an undo of a merge does not bring them back), and the vote and comment counts follow. The check, run again, must PASS.

The script refuses, and changes nothing, in the wrong project, for a person who owns a board (they are removed as an owner first), or when someone else's idea was merged into one of theirs. Backups of the Supabase project, and the Resend and Vercel logs, keep older data until they expire under those services' own terms.

## Settings on Vercel

Four settings, each of type Config, set once for Preview and once for Production (project `triad-feedbox`, Settings, Environment Variables):

| Setting | Preview | Production | Value from |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | feedbox-preview | feedbox-prod | Supabase dashboard: the project's URL, `https://<project ID>.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | feedbox-preview | feedbox-prod | Supabase dashboard, Project Settings, API Keys: the publishable key (`sb_publishable_...`) |
| `FEEDBOX_BOARD_SLUG` | `lumen` | `feedbox` | the board's slug |
| `NEXT_PUBLIC_SITE_URL` | not set | `https://triad-feedbox-delta.vercel.app` | the Production address |

`NEXT_PUBLIC_` values are built into the code, so a deployment sees a changed setting only after it is built again: push a new commit, or use Redeploy in Vercel.

Every other setting that lives only in a dashboard (Vercel, Supabase and Resend: email templates, the email sender, sign-in URLs) is recorded, with who checked it and when, in the section "Dashboard settings" of [CLAUDE.md](CLAUDE.md). Secret values (the Resend keys) are never written down; they live only in the dashboards.

The two sign-in emails ("Confirm signup" for a person's first sign-in, "Magic Link" for every later one) are in [`supabase/templates/`](supabase/templates/); each Supabase project's dashboard must hold the same text.

## Is TRIAD ready?

Before a TRIAD session, one command runs 19 checks of every piece on the Mac: the Claude desktop app, Chrome, Claude Code, Node.js, the project, reports and Obsidian folders, Docker, the GitHub sign-in, SSH, the `cc-reports` branch, the required checks and the latest CI run on `main`, Vercel Production and its build of `main`, and the two Supabase projects (feedbox-preview and feedbox-prod, asked with no key). Run it in a new Terminal tab:

```sh
/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
```

It prints one `PASS` or `FAIL` line per check (each `FAIL` says what to do) and ends with `READY: all 19 checks passed.` or `NOT READY: K of 19 checks failed.` It only reads: it changes, starts and signs in to nothing, and needs no key. The paths in it are those of the author's Mac; see the header of [`scripts/triad-ready.sh`](scripts/triad-ready.sh).

The design brief and the six screen sources are in [`design/`](design/).

Licence: MIT, see [LICENSE](LICENSE).
