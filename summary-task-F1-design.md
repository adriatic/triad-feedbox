# Task F1: Feedbox design report

- Repository: `adriatic/triad-feedbox` (public, MIT). Local folder: `/Users/nikolajivancic/Work/triad-feedbox`
- This report is on branch `cc-reports`. The commit hash is in the "Repository state" section at the end.
- Inputs read: `FEEDBOX-DESIGN-BRIEF.md` (v1, 2026-11-12) and the six screens in `feedbox-inputs/design/` (Main, Idea, PostIdea, SignIn, Changelog, BoardPhone, plus `canvas.json`).
- No application code was written. Nothing was merged. No Supabase or Vercel project was created.

Values in ⟨angle brackets⟩ are values only Nik can know, such as his domain or his Vercel team slug. Each one says where to find it. They are left blank on purpose. Every other value is filled in.

---

## Decisions Nik must make

Each line gives my recommendation. Answering "accept all" is enough to start F2. Section numbers point to the full reasoning below.

| # | Decision | Recommendation | Section |
|---|---|---|---|
| D1 | One board per deployment, or many | **One board per deployment.** The schema still carries `board_id` everywhere, so many boards later is a routing change, not a migration. | 1 |
| D2 | What the production board is | **Feedbox's own board** (feedback about Feedbox itself). The invented Lumen board is seeded only in Preview, for tests and screenshots. | 1 |
| D3 | Supabase plan | **Two free projects** (`feedbox-preview`, `feedbox-prod`), if Nik's account has two free project slots left. If pact-web already uses them, see the options in section 9. | 9 |
| D4 | Who sends the magic-link email | **A custom SMTP provider (Resend, free tier) on a domain Nik owns.** Supabase's built-in mailer only sends to members of the Supabase organisation and only a few emails an hour, so real visitors would never get a link. | 4, 9 |
| D5 | The sending domain and the production web address | ⟨Nik chooses⟩. Suggestion: sender `no-reply@feedbox.⟨your domain⟩` and web address `https://triad-feedbox.vercel.app` (free), with a custom domain later. | 9, Setup |
| D6 | Names shown on ideas and comments | **Ask for a display name once, on first sign-in.** Never show email addresses. | 4 |
| D7 | Similar ideas while typing a title | **Trigram match on titles (Postgres `pg_trgm`)**: catches partial words and typos at no cost. No AI embeddings. | 5 |
| D8 | What merging does | **Move votes to the target, counting each person once. Move comments, labelled with where they came from. The merged idea redirects to the target. No undo in v1.** | 5 |
| D9 | Spam control | **Owner can hide ideas and comments, plus database rate limits** (ideas, comments and votes per person per hour). No CAPTCHA in v1. | 6 |
| D10 | Comments in v1 | **Yes**, plain text, flat (no threads), no editing, no email notifications. | 7 |
| D11 | Changelog | **Owner-written entries built from Shipped ideas**: the owner picks Shipped ideas and writes one line each. Every line links back to its idea. | 8 |
| D12 | How Nik's approval is recorded | **A second GitHub account for Claude Code** (machine user), plus branch protection on `main` that needs one approving review. Without it, Nik cannot formally approve pull requests that were opened under his own account. | 11 |
| D13 | Preview protection | **Keep Vercel Authentication on Preview deployments** and create a bypass secret for the automated tests. | 9, 10 |

---

## Steps for Nik

1. **Create the empty GitHub repository.** The GitHub token in my environment (account `adriatic`) is not allowed to create repositories (`Resource not accessible by personal access token`). I prepared the repository locally and made no remote call that changed anything. Do one of the following:
   - **(a)** On github.com, choose New repository. Owner `adriatic`, name `triad-feedbox`, Public. Leave **all** "Initialize" boxes unticked: no README, no .gitignore, no licence. Then tell me, and I will push `main` (README stub and MIT LICENSE) and `cc-reports` (this report).
   - **(b)** Give the token the "Administration: write" permission (fine-grained token) or the `repo` scope (classic token), and I will create the repository myself.
2. Answer D1 to D13 above, or reply "accept all".
3. Do the **Setup batch for Nik** at the end of this report, in one sitting (about 60 to 90 minutes, most of it waiting for DNS to verify).
4. Tell me when the setup is done, and give me F2.

---

## 1. One board or many boards

| Option | What it means | Cost |
|---|---|---|
| A. One board per deployment (recommended) | The deployment serves the single board named in `FEEDBOX_BOARD_SLUG`. Routes are at the site root (`/`, `/ideas/42`, `/changelog`). The schema keeps a `boards` table and `board_id` on every row. | A second product needs a second Vercel project, or a later routing change. |
| B. Many boards by slug | Routes become `/b/lumen`, `/b/lumen/ideas/42`, and so on. Boards are created by SQL, or through a self-service "create a board" flow. | Self-service creation brings a sign-up flow, per-board quotas, abuse handling and an admin view. That is roughly one extra task, plus testing on every screen. |
| C. Leave it out (no `boards` table) | A single implicit board, so tables have no `board_id`. | Adding boards later touches every table, every policy and every query. This is the one place where leaving it out is expensive later. |

**Recommendation:** A. The schema is ready for many boards, and the routes serve one. That keeps v1 small and keeps the later upgrade a routing change only. Boards are created by a migration or seed, never from the UI.

**D2, the production board:** Production runs a board named "Feedbox" about Feedbox itself, so the article can link to a live board that is in real use. Preview is seeded with the Lumen example from the brief (the same ideas and vote counts as the screens), which keeps screenshots and tests matched to the design.

## 2. Data model

All tables are in the `public` schema, with row-level security switched on for every one. Keys are `uuid` for people (they come from `auth.users`). Ideas use a `bigint` identity, so addresses read `/ideas/42`.

### Tables

**`boards`**
| column | type | notes |
|---|---|---|
| id | uuid pk | `gen_random_uuid()` |
| slug | text unique | `^[a-z0-9-]{2,40}$` |
| name | text | "Lumen" |
| tagline | text | "What should Lumen do next?" |
| intro | text | the line under the heading on the board |
| created_at | timestamptz | default `now()` |

**`board_owners`** (who may run the owner tools on a board)
| column | type | notes |
|---|---|---|
| board_id | uuid fk → boards | |
| user_id | uuid fk → auth.users | |
| created_at | timestamptz | |
| | | primary key (board_id, user_id) |

**`profiles`** (public face of a signed-in person; the email address is never stored here)
| column | type | notes |
|---|---|---|
| id | uuid pk fk → auth.users | created by a trigger on sign-up |
| display_name | text null | 2 to 40 characters; null until set on first sign-in |
| created_at | timestamptz | |

**`ideas`**
| column | type | notes |
|---|---|---|
| id | bigint identity pk | |
| board_id | uuid fk → boards | |
| author_id | uuid fk → profiles | |
| title | text | 4 to 120 characters, trimmed |
| body | text | 0 to 4,000 characters |
| status | enum `idea_status` | `open`, `planned`, `building`, `shipped`; shown as Open, Planned, Building, Shipped |
| vote_count | int default 0 | kept up to date by a trigger, never written by the app |
| comment_count | int default 0 | kept up to date by a trigger |
| merged_into_id | bigint null fk → ideas | set when merged; merged ideas leave the lists |
| hidden_at | timestamptz null | set by the owner; hidden ideas are visible to owners only |
| hidden_by | uuid null | |
| status_changed_at | timestamptz | |
| shipped_at | timestamptz null | set when the status becomes Shipped |
| created_at, updated_at | timestamptz | |

Indexes: (board_id, status, vote_count desc), (board_id, created_at desc), and a GIN trigram index on `title` (section 5).

**`votes`**
| column | type | notes |
|---|---|---|
| idea_id | bigint fk → ideas, on delete cascade | |
| user_id | uuid fk → profiles | |
| created_at | timestamptz | |
| | | **primary key (idea_id, user_id)**: one vote per person per idea |

**`comments`**
| column | type | notes |
|---|---|---|
| id | bigint identity pk | |
| idea_id | bigint fk → ideas | |
| author_id | uuid fk → profiles | |
| body | text | 1 to 2,000 characters |
| moved_from_idea_id | bigint null | set when a merge moved this comment |
| hidden_at, hidden_by | | owner hide |
| created_at | timestamptz | |

**`changelog_entries`** (one release, for example "Lumen 2.4")
| column | type | notes |
|---|---|---|
| id | uuid pk | |
| board_id | uuid fk → boards | |
| title | text | "Lumen 2.4" |
| released_on | date | "Nov 3, 2026" |
| published_at | timestamptz null | null means draft, visible to owners only |
| created_by | uuid | |
| created_at | timestamptz | |

**`changelog_items`** (one line per shipped idea inside an entry)
| column | type | notes |
|---|---|---|
| entry_id | uuid fk → changelog_entries, on delete cascade | |
| idea_id | bigint fk → ideas | must be Shipped and on the same board (checked by a trigger) |
| note | text | "Press ? anywhere to see every shortcut…" |
| position | int | display order |
| | | primary key (entry_id, idea_id); an idea appears in at most one entry (unique on idea_id) |

### Relations at a glance

```
boards 1─* board_owners *─1 auth.users 1─1 profiles
boards 1─* ideas 1─* votes      *─1 profiles
              ideas 1─* comments   *─1 profiles
              ideas ─merged_into→ ideas
boards 1─* changelog_entries 1─* changelog_items *─1 ideas
```

### Small defaults (no decision needed; say so if you disagree)
- Posting an idea also casts the author's vote, so a new idea starts at 1.
- Lists never show merged or hidden ideas. A merged idea's address redirects to its target.
- There are no deletes in the app. Owners hide. Removing a person's data on request is a documented SQL snippet in the README (section 4).

## 3. Roles and access rules (row-level security)

### Roles
| Role | Who | How it is known |
|---|---|---|
| Anyone | not signed in | Supabase `anon` role |
| Signed in | has a session | `authenticated` role, `auth.uid()` |
| Owner | signed in and listed in `board_owners` for this board | `is_board_owner(board_id)`, a `security definer` SQL function |

### Rules per table
| Table | Read | Create | Change | Hide |
|---|---|---|---|---|
| boards | anyone | migration only | migration only | n/a |
| board_owners | owners of that board | SQL by Nik only | n/a | n/a |
| profiles | anyone (`id`, `display_name` only) | trigger on sign-up | own row, `display_name` only | n/a |
| ideas | anyone, if not hidden; owners see all | signed in, `author_id = auth.uid()`, on a board that exists, within the rate limit | **author**: no changes in v1. **Owner**: status, merge and hide, through functions only (see below). | owner, through `hide_idea()` |
| votes | anyone (counts); a person's own rows to show "you voted" | signed in, `user_id = auth.uid()`, idea not hidden and not merged | never updated | own row deleted = unvote |
| comments | anyone, if not hidden and the idea is visible; owners see all | signed in, `author_id = auth.uid()`, idea visible, within the rate limit | no edits in v1 | owner, through `hide_comment()` |
| changelog_entries / items | anyone if `published_at` is set; owners see drafts | owner | owner | owner (unpublish) |

**Owner actions go through SQL functions, not direct table writes:** `set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, and `publish_changelog_entry`. Each function checks `is_board_owner` first, does its whole job in one transaction, and is the only route to those columns. Table privileges back this up with column grants: `authenticated` may insert only `title, body, board_id` into `ideas` and may update no column of `ideas`. Because of that, a hand-made API call cannot change `status`, `vote_count` or `hidden_at`.

### What a visitor can never do
- Vote twice on one idea, vote as someone else, or change a vote count directly.
- Change an idea's status, merge, hide or unhide anything, or write the changelog.
- Read hidden ideas or comments, draft changelog entries, or the owners list.
- Read anyone's email address. Emails live only in `auth.users`, which is not exposed. Pages show `profiles.display_name`.
- Make themselves an owner. `board_owners` has no insert policy at all.
- Delete anything, including their own idea.

### How "one vote per person per idea" is enforced
1. **Primary key `(idea_id, user_id)` on `votes`.** The database refuses a second row, even from parallel requests.
2. **RLS insert check `user_id = auth.uid()`**, so nobody can insert a vote for someone else.
3. **A trigger** adds or subtracts 1 on `ideas.vote_count` in the same transaction.
4. The app inserts with `on conflict do nothing`, so a double click is harmless. The vote button's state comes from whether the person's own row exists.

"Leave it out" (votes as a plain counter with no `votes` table) is not a real option: without a per-person row, one vote per person cannot be enforced, and unvoting is impossible.

## 4. Sign-in by magic link

**Library:** `@supabase/ssr` in Next.js App Router. The session lives in HTTP-only cookies, and middleware refreshes it.

**Flow**
1. The `/sign-in` page shows one email field and "Send me a link", as in `SignIn.dc.html`. The page remembers where the visitor came from (`?next=/ideas/42`, accepted only if it is a path on this site).
2. A server action calls `signInWithOtp({ email, options: { emailRedirectTo: <site>/auth/confirm?next=…, shouldCreateUser: true } })`. The page switches to "Check your email".
3. The email template (set in the Supabase dashboard; exact text in the Setup batch) links to `/auth/confirm?token_hash=…&type=email&next=…`.
4. **`/auth/confirm` shows a "Finish signing in" button and does not sign in on page load.** Mail scanners (Outlook Safe Links and similar) open links in advance, and that would use up a one-time link before the person clicks. The button posts the form, the server calls `verifyOtp({ type: 'email', token_hash })`, sets the cookies and redirects to `next`.
5. Link lifetime is 900 seconds, matching "expires in 15 minutes" on the screen. A link works once.

**First sign-in:** the trigger has created a `profiles` row with no display name. If `display_name` is empty, `/auth/confirm` sends the person to `/welcome`: one field, "Name shown with your ideas" (for example "Mira K."), then on to `next`. Nobody can post, vote or comment until a display name is set.

| Display name option | Cost |
|---|---|
| Ask once on first sign-in (recommended) | One extra small screen, not in the six designs; it reuses the Sign-in layout. |
| Use the part of the email before the @ | Leaks part of the email address publicly. |
| Leave it out ("Member 4821") | Ideas and comments read anonymously, which no longer matches the designs ("Posted by Mira K."). |

**Session:** the access token lasts 1 hour and refreshes automatically, so a person stays signed in on that browser until they sign out. **Sign-out** is a POST to `/auth/sign-out`, which calls `signOut({ scope: 'local' })`, so only this device is signed out, and then returns to the board. The header always shows the state: "Viewing as visitor", "Signed in as ⟨name⟩", or "Signed in as owner", as the brief requires.

**Owners** sign in the same way. Owner status comes only from `board_owners`.

**Left out of v1, with cost:** passwords and social logins (no cost; the brief says magic link). Six-digit codes typed instead of clicking the link (cost: no fallback when links break across devices; easy to add later). Changing the email address (cost: the person signs up again with the new address). Self-service account deletion (cost: Nik runs a documented SQL snippet when asked). Because the app stores email addresses, the README will include a short privacy note.

## 5. Similar ideas while typing, and merging

### Similar ideas
| Option | How | Cost |
|---|---|---|
| Simple text match (`ILIKE '%word%'`) | Match each typed word against titles | Misses typos and word forms ("laptop" against "laptops" works, "synch" against "sync" does not); full scans. |
| **Trigram similarity (`pg_trgm`), recommended** | The SQL function `similar_ideas(board, query)` returns up to 5 visible, unmerged ideas ranked by `word_similarity(query, title)` above 0.3, then by votes. A GIN index keeps it fast. | One Postgres extension, available on Supabase free. |
| Full-text search (`tsvector`) | Stemmed word match | Good for whole words, weak for partial words typed mid-title; language-specific. |
| Embeddings (pgvector plus an AI API) | Meaning-based match | Needs a paid API key and a call per keystroke burst, and cannot be tested offline. Too much for a free open-source v1. |
| Leave it out | No live list | More duplicates, so more manual merging. Screen 3 loses its right-hand panel. |

The screen calls `similar_ideas` 300 ms after the last keystroke, once the title has 3 or more characters, as in `PostIdea.dc.html`. Each result has its own Vote button, so voting on an existing idea is one click. **The board's search box uses the same function**, matching on both title and body, so there is only one search mechanism.

### What merging does (`merge_ideas(source, target)`, owner only, one transaction)
1. **Votes:** every person who voted on the source gets a vote on the target, unless they already have one (`insert … on conflict do nothing`). The source's votes are then deleted. The target's count rises by the number of *new* voters, not by the source's total, so nobody is counted twice.
2. **Comments:** moved to the target, keeping their author and date, with `moved_from_idea_id` set so the page can show "From the merged idea 'Synch notes'".
3. **Source:** `merged_into_id = target`. It leaves every list, and its address redirects to the target with a note.
4. Both ideas must be on the same board. Merging into an idea that is itself merged, or merging an idea into itself, is refused.

**Undo:** leave it out in v1, and the merge dialog asks for confirmation. Cost: a wrong merge is fixed only by SQL. Exact undo would need a log of which votes were moved; it can be added later as a `merge_log` table.

## 6. Spam control

| Option | What | Cost |
|---|---|---|
| **Owner hide (recommended)** | The Hide idea and Hide comment buttons (shown in `Idea.dc.html`). Hidden rows vanish for everyone except owners, and can be unhidden. | Needs the owner to look regularly. |
| **Database rate limits (recommended)** | A trigger refuses inserts beyond **5 ideas, 30 comments and 100 votes per person per hour**. The app shows "You are posting quickly. Try again in a few minutes." | A few lines of SQL plus tests. |
| Sign-in email limits (recommended; Supabase setting only) | Supabase limits sign-in emails per hour per project, and per address and IP. | None; set in the Setup batch. |
| CAPTCHA (Cloudflare Turnstile through Supabase Auth) | A challenge before a sign-in email is sent | Another account and key, plus friction for every visitor. Add it only if someone abuses the sign-in form to burn the email quota (Resend free allows 100 emails a day). |
| Block a person, word filters, reports | | Extra screens and rules; not needed for a small board. |
| Leave it out (nothing) | | One determined person can flood the board, and the owner can only clean up with SQL. Not acceptable for a public board. |

## 7. Comments in v1

| Option | Cost |
|---|---|
| **Include, minimal (recommended):** plain text, flat list, newest last, owner replies marked "Owner" (as in the design), owner can hide | About a third of task F5 and F6, plus the rate limit and RLS tests. |
| Owner replies only | Visitors cannot add context, and the comment box in the design goes. |
| Leave it out | The Idea detail screen loses half its content, the "N comments" count on every row disappears, and three screens need redrawing. |

Left out even when comments are included: editing, threads, reactions, Markdown and email notifications.

## 8. Changelog

| Option | What | Cost |
|---|---|---|
| Generated from Shipped ideas | The page lists Shipped ideas by `shipped_at` | No release names ("Lumen 2.4") and no human line per idea, so it does not match `Changelog.dc.html`. |
| Written by hand (free text) | The owner writes release notes | Loses the "every entry started as an idea" link back. The owner must remember what shipped. |
| **Hybrid (recommended)** | The owner creates an entry (title and date). The form lists Shipped ideas that are not in any entry yet, all ticked. The owner writes one line for each and publishes. Each line links to its idea and shows its vote count. | One owner-only form (`/changelog/new`), which is not among the six screens; it reuses the Post-an-idea layout. |
| Leave it out | The Shipped tab on the board is the only record | Screen 5 goes, and the article loses its "roadmap to changelog" ending. |

## 9. Environments

### Projects
| Environment | Supabase | Vercel | Data |
|---|---|---|---|
| Local (optional) | `npx supabase start` in Docker (colima) | `npm run dev` on localhost:3000 | Lumen seed; reset at will |
| Preview | project **`feedbox-preview`** | every pull request and branch deployment | Lumen seed plus test users; reset before test runs |
| Production | project **`feedbox-prod`** | `main` only | real data; migrations applied in merge tasks only |

Sharing one Supabase project between Preview and Production is rejected: tests would write into live data, and a migration under review would change Production before approval.

### Environment variables
| Name | Where | Preview value | Production value |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Vercel, `.env.local` | feedbox-preview URL | feedbox-prod URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Vercel, `.env.local` | feedbox-preview publishable key | feedbox-prod publishable key |
| `NEXT_PUBLIC_SITE_URL` | Vercel | not set (the app uses Vercel's `VERCEL_BRANCH_URL`) | `https://triad-feedbox.vercel.app`, or the custom domain |
| `FEEDBOX_BOARD_SLUG` | Vercel, `.env.local` | `lumen` | `feedbox` |
| `SUPABASE_SECRET_KEY` | **never in Vercel.** Only in the local env file and GitHub Actions, for test setup | feedbox-preview secret key | not used anywhere |
| `E2E_BASE_URL` | GitHub Actions (set per run) | the Preview URL | n/a |
| `VERCEL_AUTOMATION_BYPASS_SECRET` | GitHub Actions, local env file | from Vercel | n/a |
| `SUPABASE_PREVIEW_REF`, `SUPABASE_PROD_REF` | local env file, for `npx supabase db push` | project reference | project reference |

The app at runtime uses only the publishable key, so every rule is enforced by RLS. The secret key bypasses RLS, and Production never holds it in the app.

### Free-tier limits that matter (check the pricing pages on the day; these change)
- **Supabase free:** 2 active free projects per account, which is exactly Preview plus Production. If pact-web already uses free projects, the options are: pause one of them, or put Feedbox in a paid organisation (about USD 25 a month plus compute), or keep Preview local only (cost: Vercel Previews then have no database, and preview testing (section 10) is lost). 500 MB database, 50,000 monthly active users, 5 GB egress. **Projects pause after 7 days without activity:** Preview will pause between tasks, and Nik un-pauses it in the dashboard (about 1 minute). **No daily backups on free:** the merge tasks include `npx supabase db dump` of Production into a local folder.
- **Supabase built-in email:** sends only to members of the Supabase organisation, at a very low hourly rate. **So custom SMTP is required for Production** (D4).
- **Resend free:** 3,000 emails a month, 100 a day, one domain. Each sign-in is one email.
- **Vercel Hobby:** free for non-commercial use, which fits a free open-source project. One build at a time. Deployment Protection with Vercel Authentication is available, and so is the automation bypass secret.

## 10. Tests

| Level | Tool | What | When |
|---|---|---|---|
| Unit | Vitest | The core library (`lib/feedbox/`), pure TypeScript with no Supabase or Next imports: title and body validation, status labels and allowed transitions, sort and tab filtering, vote toggle state (optimistic update and rollback), the `next` path guard, changelog grouping by entry and date, date and count formatting ("Nov 3, 2026", "214 votes"). | Every push, in GitHub Actions |
| Database | pgTAP through `npx supabase test db` on local Supabase in Docker | **Every RLS rule in section 3**, each as a pass and a fail case: a second vote is refused; a vote for another user is refused; a visitor cannot update status; hidden rows are invisible to visitors and visible to owners; owner functions refuse non-owners; merge moves votes without double-counting and moves comments; rate limits trigger at the 6th idea in an hour; emails are unreadable. | Every push, in GitHub Actions (Docker is available there) |
| End to end | Playwright | Visitor reads the board, switches tabs, searches and sorts. Sign-in, without real email: the test calls `auth.admin.generateLink` with the Preview secret key and opens the confirm link. First-sign-in name. Post an idea and see similar ideas. Vote and unvote. Comment. Owner changes status, merges, hides, and publishes a changelog entry. Light and dark themes; widths 1280 and 390. | Against every Preview deployment |
| Visual check by Nik | Screenshots | Playwright saves one screenshot per screen and state to `screenshots/F⟨n⟩/`, to compare with the six designs. | End of F5 and F6 |

**How a Preview is tested**
1. A pull request triggers a Vercel Preview built against `feedbox-preview`.
2. A GitHub Action waits for Vercel's "deployment succeeded" status. It then resets the test data (deletes rows of users `e2e+*@feedbox.test` and re-applies the Lumen seed) and runs Playwright against the Preview URL, sending the bypass header `x-vercel-protection-bypass`.
3. The pull request shows unit, database and end-to-end results as checks. Branch protection requires all three.
4. Nik opens the Preview (signed in to Vercel) and follows the short checklist that each task report includes, then approves.

**Leave it out:** without end-to-end tests, Nik clicks through every flow by hand in each task, and RLS mistakes surface only by chance. Without database tests, the access rules (the main security of the app) are unchecked. I recommend all three levels. End-to-end tests start in F4, and the Preview runner arrives in F5.

## 11. Build split: F2 to F6, each followed by a merge task

Every task opens one pull request from a branch `f⟨n⟩-…` and adds its report to `cc-reports`. Each task is sized for Nik to review in about 20 to 30 minutes.

| Task | Scope | Out of scope | Nik checks |
|---|---|---|---|
| **F2: Core library and skeleton** | Next.js App Router skeleton (TypeScript, ESLint, Vitest), `.gitignore`, the CI workflow (lint, typecheck, unit tests). `lib/feedbox/`: types, status names and transitions, validation, sorting and filtering, formatting, the `next` path guard, with unit tests. Copy `design/` (brief, six screens, `canvas.json`). A placeholder home page so Vercel builds. | Any Supabase code. Any real screen. | CI is green. Unit tests read as the rules in sections 3 to 8. The Vercel Preview shows the placeholder. |
| **F3: Database migration** | `supabase/migrations/0001_feedbox.sql`: tables, enum, indexes, `pg_trgm`, triggers (counts, profiles, rate limits, shipped_at), RLS policies, column grants, owner functions, `similar_ideas`. `supabase/seed.sql` (Lumen). pgTAP tests for every rule. Applied to **feedbox-preview** only. | App code that uses the database. | pgTAP is green in CI. Nik reads the policy list in the report against section 3. Nik sees the Lumen data in the Preview dashboard. |
| **F4: Sign-in and routes** | Supabase clients (server and browser), middleware, `/sign-in`, `/auth/confirm`, `/auth/sign-out`, `/welcome`. Every route as a bare page that reads real data (board, idea, changelog), with the header showing the sign-in state. The first Playwright test (sign-in through generateLink). | Styling to the designs. Owner tools. | On the Preview: request a link, receive the email, sign in, set a name, sign out. Header states are correct. |
| **F5: Screens** | The board (tabs, search, sort, vote), Idea detail (vote, comments, comment box), Post an idea (with live similar ideas), Sign-in styled, Changelog (read only). Light and dark, desktop and phone. Playwright for visitor flows; the Preview test runner; screenshots. | Owner tools. The changelog editor. | Screenshots side by side with the six designs. Vote twice: still one vote. |
| **F6: Owner tools and changelog** | The owner panel on Idea detail (status, merge with confirmation, hide or unhide idea and comment). Hidden items shown to owners as "Hidden". The `/changelog/new` editor and publishing. The README's owner and privacy section, with the person-removal SQL. Playwright owner flows. | Undo merge. CAPTCHA. Many boards. | On the Preview, as owner: move an idea to Shipped, publish a changelog entry, merge two ideas and see the counts. As a visitor: hidden items have gone. |
| **M2 to M6: Merge task after each** | Rebase on `main` and confirm all checks are green. Confirm Nik's approving review is on the PR (D12). Squash-merge. **M3:** `npx supabase db push` of the migration to **feedbox-prod**. **M4:** after Nik has signed in once on Production, make him owner of the `feedbox` board (one SQL line in the report). **Every merge task from M3 on:** `npx supabase db dump` of Production into a local backup folder first. Confirm the Production deployment loads. Tag `f⟨n⟩` and write the report. | Any change to code. | Production URL works, and the tag exists. |

**D12, recording approval:** pull requests opened with Nik's own token are authored by `adriatic`, and GitHub does not let an author approve their own pull request. Options:
- **A second GitHub account, `⟨machine user name, e.g. adriatic-cc⟩`, with write access (recommended).** Claude Code opens pull requests as that account, Nik approves as `adriatic`, and branch protection *requires* that approval. This is the cleanest "Independently Approved" evidence for the article. Cost: one free account and one token (Setup batch, part F).
- Nik writes "Approved" as a pull-request comment, and the merge task checks for it. Cost: nothing stops a merge without it except discipline.
- Leave it out (Nik merges by hand). Cost: no recorded approval in the tracker; the merge tasks shrink to nothing.

## 12. Repository layout

```
triad-feedbox/
├── README.md            what Feedbox is, run locally, deploy, owner setup, privacy note
├── LICENSE              MIT
├── TRIAD.md             the protocol as used in this repository: task to branch to PR to report on cc-reports to approval to merge task (headings only until Nik supplies the article's wording)
├── templates/
│   ├── task.md          the shape of a task (goal, scope, out of scope, checks)
│   ├── report.md        the shape of a summary report (decisions, steps for Nik, results, commit hash)
│   └── merge-task.md
├── .github/
│   ├── pull_request_template.md
│   └── workflows/ci.yml  lint, typecheck, unit, pgTAP, e2e on Preview
├── design/
│   ├── FEEDBOX-DESIGN-BRIEF.md
│   ├── canvas.json
│   └── *.dc.html        the six screens
├── screenshots/
│   └── F5/, F6/         Playwright screenshots per task
├── app/                 Next.js routes: /, /ideas/[id], /ideas/new, /sign-in, /welcome, /changelog, /changelog/new, /auth/confirm, /auth/sign-out
├── components/          VoteButton, StatusChip, IdeaRow, Header, …
├── lib/
│   ├── feedbox/         core library (pure TypeScript) and its *.test.ts files
│   └── supabase/        server and browser clients, generated database types
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   ├── seed.sql
│   └── tests/           pgTAP *.test.sql
├── e2e/                 Playwright tests and the reset-test-data script
└── package.json, tsconfig.json, next.config.ts, playwright.config.ts, vitest.config.ts
```

Reports never go on `main`. They live on the `cc-reports` branch, with the same file names as in `/Users/nikolajivancic/CC reports and tasks`. `cc-reports` is never merged.

---

## Setup batch for Nik

Do this once, in order, on the Mac. Write each value marked **SAVE** into a password manager entry called "Feedbox". Do not paste secret keys into chat with me.

Your Mac has Node 24 (through nvm), Docker and colima, and git. Homebrew, the GitHub CLI, the Supabase CLI and the Vercel CLI are **not** installed; none of them is needed, because the Supabase CLI runs through `npx`.

### A. GitHub repository (if you chose 1a in Steps for Nik)
1. Open https://github.com/new while signed in as `adriatic`.
2. Repository name: `triad-feedbox`. Description: "Feedbox: a free, open-source feedback and roadmap board. Worked example for the TRIAD protocol." Visibility: **Public**.
3. Leave "Add a README", ".gitignore" and "Choose a license" all **off**. Click **Create repository**.
4. Tell me it exists. I will push `main` and `cc-reports`.

### B. Email sending (Resend), needed for D4
1. Go to https://resend.com and choose **Sign up**. Use GitHub or your email.
2. Choose **Domains**, then **Add Domain**. Enter `feedbox.⟨your domain⟩` (a subdomain keeps your main domain's mail settings untouched). Region: the one closest to you (for example `eu-west-1`).
3. Resend shows DNS records (an MX record, a TXT record for SPF, and a TXT record for DKIM). In another tab, sign in to the company where ⟨your domain⟩ is registered, open its DNS settings, and add each record exactly as shown.
4. Back in Resend, click **Verify DNS Records**. Wait until the status is **Verified**. This usually takes minutes, but can take up to a few hours, so continue with C while you wait.
5. Choose **API Keys**, then **Create API Key**. Name `feedbox-preview`, permission **Sending access**, domain `feedbox.⟨your domain⟩`. **SAVE** it as "Resend key, preview".
6. Repeat step 5 with the name `feedbox-prod`. **SAVE** it as "Resend key, prod".

### C. Vercel project (first, so the production address is known)
1. Go to https://vercel.com and sign in **with GitHub** as `adriatic`.
2. Note your team slug: click your avatar, choose **Settings**, and find the URL slug under "Team URL" (for a Hobby account it is often your user name plus `-projects`). **SAVE** it as "Vercel team slug".
3. Click **Add New…**, then **Project**. Under "Import Git Repository", choose **Adjust GitHub App Permissions** and give Vercel access to `adriatic/triad-feedbox` only. Back in Vercel, click **Import** next to `triad-feedbox`.
4. Project Name: `triad-feedbox`. Framework Preset: **Next.js**. Leave the build settings at their defaults. Do not add environment variables yet. Click **Deploy**. **The first deployment fails, because `main` has no app until F2 merges. That is expected.**
5. Open the project and choose **Settings**, then **Domains**. **SAVE** the production address, which should be `https://triad-feedbox.vercel.app`. If that name was taken, Vercel shows another one. Use the shown one everywhere below.
6. Choose **Settings**, then **Deployment Protection**. Under "Vercel Authentication", choose **Standard Protection** (this protects Previews, while Production stays public).
7. On the same page, under "Protection Bypass for Automation", click **Add Secret** (or **Generate**). **SAVE** it as "Vercel bypass secret".

### D. Supabase projects
1. Go to https://supabase.com/dashboard and sign in (GitHub login is fine).
2. On the organisation's list of projects, count your **active free projects**. If you already have two, stop here and tell me. D3 then needs a choice (see section 9).
3. Click **New project**. Organisation: your personal one (free plan). Name `feedbox-preview`. Database password: click **Generate a password**, then **SAVE** it as "DB password, preview". Region: the closest one to you, for example **Central EU (Frankfurt)**. Click **Create new project** and wait about 2 minutes.
4. Repeat step 3 with the name `feedbox-prod`. **SAVE** its password as "DB password, prod". Use the same region.
5. **For each of the two projects, do steps 6 to 13** (switch projects with the selector at the top left).
6. On **Project Settings**, then **General**, copy the **Project ID** (the reference, about 20 lowercase letters). **SAVE** it as "Supabase ref, preview" or "Supabase ref, prod".
7. On **Project Settings**, then **Data API**, copy the **Project URL** (`https://⟨ref⟩.supabase.co`). **SAVE** it.
8. On **Project Settings**, then **API Keys**, copy the **Publishable key** (`sb_publishable_…`). **SAVE** it. For **feedbox-preview only**, also reveal and copy the **Secret key** (`sb_secret_…`) and **SAVE** it as "Supabase secret key, preview". Never put any secret key in Vercel.
9. On **Authentication**, then **Sign In / Providers**: make sure **Email** is enabled and "Allow new users to sign up" is on. Set **Email OTP Expiration** to `900` seconds. Click **Save**.
10. On **Authentication**, then **URL Configuration**:
    - Site URL: for feedbox-prod, the production address from C5. For feedbox-preview, `http://localhost:3000`.
    - Redirect URLs, click **Add URL** for each:
      - feedbox-prod: `https://triad-feedbox.vercel.app/**` (or your address from C5, followed by `/**`).
      - feedbox-preview: `https://triad-feedbox-*-⟨Vercel team slug from C2⟩.vercel.app/**` and `http://localhost:3000/**`.
    - Click **Save**.
11. On **Authentication**, then **Emails**, then **SMTP Settings**: turn on **Enable Custom SMTP**. Fill in:
    - Sender email: `no-reply@feedbox.⟨your domain⟩`
    - Sender name: `Feedbox`
    - Host: `smtp.resend.com`
    - Port: `465`
    - Username: `resend`
    - Password: the Resend key from B5 (for preview) or from B6 (for prod).
    - Click **Save**. If Supabase refuses, B4 is not verified yet. Wait and retry.
12. On **Authentication**, then **Emails**, then **Templates**, choose **Magic Link**. Subject: `Your Feedbox sign-in link`. Replace the body with exactly:
    ```html
    <h2>Sign in to Feedbox</h2>
    <p>Click the link below to finish signing in. It works once and expires in 15 minutes.</p>
    <p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email">Sign in to Feedbox</a></p>
    <p>If you did not ask for this, you can ignore this email.</p>
    ```
    Click **Save**. (The app always sends a `RedirectTo` that already contains `?next=…`, so `&token_hash` is correct here.)
13. On **Authentication**, then **Rate Limits**: set "Rate limit for sending emails" to `30` per hour and leave the rest at their defaults. Click **Save**.

### E. Supabase CLI on the Mac (lets me apply migrations to feedbox-preview)
1. Open Terminal.
2. Run `colima start --cpu 4 --memory 6`, and wait for "done". This is the Docker engine that local Supabase and the database tests use.
3. Run `cd /Users/nikolajivancic/Work/triad-feedbox`.
4. Run `npx --yes supabase@latest login`. A browser window opens; click **Authorize**. The terminal says "You are now logged in". This stores a Supabase access token on this Mac only.
5. Run `npx --yes supabase@latest projects list`. Both `feedbox-preview` and `feedbox-prod` should be listed.

### F. GitHub: machine user, secrets and branch protection (for D12)
1. Sign out of GitHub, or use a private browser window. Create a new account at https://github.com/signup. User name `⟨machine user name, e.g. adriatic-cc⟩`; use an email alias you control (for example `⟨your address⟩+cc@…` if your provider supports plus addresses). Turn on two-factor authentication when asked.
2. In that account, open **Settings**, then **Developer settings**, then **Personal access tokens**, then **Fine-grained tokens**, then **Generate new token**. Name `triad-feedbox-cc`. Expiration: 90 days. Resource owner: the machine account. Repository access: you cannot pick `triad-feedbox` until step 4, so come back here after step 4 and choose **Only select repositories**, then `adriatic/triad-feedbox`. Permissions: **Contents** read and write, **Pull requests** read and write, **Issues** read and write, **Actions** read, **Commit statuses** read, **Metadata** read (automatic). Generate the token and **SAVE** it as "GitHub token, Claude Code".
3. Sign back in as `adriatic`.
4. Open `https://github.com/adriatic/triad-feedbox/settings/access`, click **Add people**, enter the machine user and choose role **Write**. Accept the invitation from the machine account (in the private window), then finish step 2.
5. Open `https://github.com/adriatic/triad-feedbox/settings/secrets/actions` and click **New repository secret** for each:
   - `SUPABASE_PREVIEW_URL`: Project URL of feedbox-preview (D7)
   - `SUPABASE_PREVIEW_PUBLISHABLE_KEY`: from D8
   - `SUPABASE_PREVIEW_SECRET_KEY`: from D8
   - `VERCEL_AUTOMATION_BYPASS_SECRET`: from C7
6. Open `https://github.com/adriatic/triad-feedbox/settings/branches` (or **Rules**, then **Rulesets**), then **Add branch ruleset**. Name `main`. Enforcement **Active**. Target: the default branch. Tick **Restrict deletions**, **Block force pushes**, **Require a pull request before merging** (required approvals: **1**), and **Require status checks to pass** (the check names appear after F2's first CI run, so add them in M2; I will remind you). Click **Create**.

### G. Vercel environment variables
1. Open the Vercel project, choose **Settings**, then **Environment Variables**. For each line, click **Add**, tick only the environments named, and click **Save**:
   - `NEXT_PUBLIC_SUPABASE_URL`: Production = feedbox-prod URL; Preview = feedbox-preview URL.
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: Production = feedbox-prod publishable key; Preview = feedbox-preview publishable key.
   - `NEXT_PUBLIC_SITE_URL`: Production only = the address from C5.
   - `FEEDBOX_BOARD_SLUG`: Production = `feedbox`; Preview = `lumen`.
2. Do **not** add any `SUPABASE_SECRET_KEY`.

### H. Local environment file (kept outside the repository, never committed)
1. In Terminal, run `mkdir -p ~/.config/triad-feedbox && touch ~/.config/triad-feedbox/env.preview && chmod 600 ~/.config/triad-feedbox/env.preview && open -e ~/.config/triad-feedbox/env.preview`.
2. In the TextEdit window that opens, paste these lines, put your saved values after each `=`, and save:
   ```
   NEXT_PUBLIC_SUPABASE_URL=
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
   SUPABASE_SECRET_KEY=
   FEEDBOX_BOARD_SLUG=lumen
   VERCEL_AUTOMATION_BYPASS_SECRET=
   SUPABASE_PREVIEW_REF=
   SUPABASE_PROD_REF=
   GITHUB_TOKEN_CC=
   ```
   (`GITHUB_TOKEN_CC` is the machine user's token from F2. All the others are preview values, except `SUPABASE_PROD_REF`.)
3. In F2 I will link `.env.local` in the repository to this file, and make sure `.gitignore` excludes it before anything else is committed.

### I. Tell me
Reply "Setup done", along with three values that are not secret: the production address (C5), the Vercel team slug (C2), and the machine user name (F1). Then give me F2.

---

## Check before sending
- I searched the report for `TODO`, `TBD`, `XXX`, `lorem` and `{{`. The only `{{` are the Supabase email template's own variables in Setup step D-12, which are intentional. The ⟨angle-bracket⟩ items are the values only Nik can know: ⟨your domain⟩, the Vercel team slug, the machine user name and the email alias. Each says where to find it. ⟨n⟩ (task number), ⟨name⟩ (the signed-in person's display name) and ⟨ref⟩ (the Supabase project ID) are notation inside patterns, not gaps.
- All twelve decision areas are covered (sections 1 to 12), each with options, a recommendation, and "leave it out" with its cost. Section 3's "leave it out" is the unenforceable counter. For section 2, "leave it out" is covered table by table: `boards` in section 1, `profiles` in section 4, `comments` in section 7, the changelog tables in section 8, and `votes` in section 3.
- Nothing from pact-web is named except the stack comparison and the free-project warning in D3.

## Repository state
- Local `/Users/nikolajivancic/Work/triad-feedbox`: `main` holds one commit, `be88836697659277004cb367f8c394c19d9a87be` (README stub and MIT LICENSE). `cc-reports` holds this report.
- Remote: **not pushed yet**; waiting for step 1 of Steps for Nik.
- Commits are listed in the summary message that accompanies this report.
