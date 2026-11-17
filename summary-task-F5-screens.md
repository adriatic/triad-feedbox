# Task F5: the screens (board, idea page, post an idea, sign-in, changelog)

Done. The five screens are built and styled to the six designs:
- light and dark;
- desktop (1280 px) and phone (390 px).

The Playwright tests cover the visitor and signed-in flows against LOCAL Supabase. CI is green on pull request #7 (not merged), and its Vercel Preview builds.
- **Not changed:** no migration, no database change, no new dependency.
- **Never touched:** feedbox-preview and feedbox-prod.

Two decisions are open, in the last section:
- **F5-D1:** the "Owner" mark on comments for every viewer needs a database function.
- **F5-D2:** the hosted-Preview test runner, not built.

## Readiness check (run first, from main at ed790b4)

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit ed790b4 C1: cleanup after F4 and O1 (e2e required, local sender, OTP length, prod interval) (#6). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 133 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 5a46f5e).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit ed790b4, 2026-11-17T21:57:31Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
```

## What was built

**Screens**
- **Board** (`/`; Main.dc.html, and BoardPhone.dc.html below 640 px):
  - Tabs Open, Planned, Building, Shipped, each with its count.
  - **Search** through `similar_ideas`, as section 5 says. It matches titles and details, waits 300 ms after the last keystroke, needs 3 or more characters, and searches within the tab. The address shows the search (`?q=`), so a search can be linked.
  - **Sort** Top or New.
  - **Vote and unvote** without a reload.
  - A visitor's vote button leads to sign-in and comes back to the same page.
- **Idea detail** (`/ideas/<id>`; Idea.dc.html):
  - Vote.
  - The details, as paragraphs.
  - Comments, flat and newest last, with name and date.
  - The comment box for a signed-in person; a visitor sees "Sign in to comment".
- **Post an idea** (`/ideas/new`; PostIdea.dc.html):
  - Title and Details.
  - The live list "Similar ideas already on the board", 300 ms after the last keystroke, from 3 characters, up to 5 ideas.
  - Each similar idea has its own Vote button ("Vote", then "Voted").
  - Posting opens the new idea, which already has the author's vote.
- **Sign-in, welcome and confirm** (SignIn.dc.html):
  - styled as one card;
  - the "Check your email" state with "Use a different email address";
  - `/auth/confirm` still signs in only when **Finish signing in** is pressed, never on page load.
- **Changelog** (`/changelog`; Changelog.dc.html): read only, newest first. Each line links to its idea with its vote count.
- **Every page:**
  - The header shows "Viewing as visitor", "Signed in as <name>" or "Signed in as owner". It never shows an email address.
  - A refused post, comment or vote says "You are posting quickly. Try again in a few minutes." (section 6).
  - Light or dark follows the Mac's system setting.

**Files**
- **New:**
  - `app/globals.css`: all styles, taken from the designs' colours and sizes.
  - `components/useVote.ts`, `VoteButton.tsx`, `StatusChip.tsx`, `SearchBox.tsx`.
  - `app/ideas/new/PostIdeaForm.tsx` and `app/ideas/new/actions.ts` (post an idea).
  - `app/ideas/[id]/CommentForm.tsx` and `app/ideas/[id]/actions.ts` (add a comment).
  - `app/not-found.tsx`.
  - `lib/feedbox/screens.ts` with `screens.test.ts`.
  - `e2e/helpers.ts`, `e2e/screens.spec.ts`, `e2e/screenshots.spec.ts`, `e2e/design-support.js`.
  - `screenshots/F5/` (64 PNG files, 4.1 MB).
- **Changed:**
  - `app/layout.tsx`: Inter through next/font, and a footer with the changelog link.
  - `components/Header.tsx` and `SignInLink.tsx`.
  - The six existing pages.
  - `lib/supabase/data.ts`: votes, search, owners for comments.
  - `e2e/auth.spec.ts`: new headings.
  - `package.json`: script `screenshots`.
  - `playwright.config.ts`: comment only.
  - CLAUDE.md.
- **CLAUDE.md:**
  - "Dashboard settings": feedbox-prod's "Minimum interval per user" row now says it was verified on screen by Nik on 2026-11-17 at 8:49 AM (noted in M7).
  - The `npm run screenshots` command, and the new layout lines.

**Tests**
- **Unit:** 130 pass (11 new in `lib/feedbox/screens.test.ts`: the similar-ideas rules, board addresses, dates and paragraphs, recognising the rate limit and a second vote).
- **e2e:** 10 pass, against LOCAL Supabase in Docker as in F4. The 5 F4 tests are kept; `e2e/screens.spec.ts` adds 5:
  1. **Visitor:**
     - reads the board;
     - tabs with counts 4, 2, 1, 3;
     - sort Top and New with the exact order;
     - search "laptop", "pdfs" (only in the details), too short, no match, and a search inside the Building tab;
     - an idea with its comments in order and no comment box;
     - the changelog and its link.
  2. **Phone, 390 px, dark:**
     - nothing is wider than the screen;
     - the dark background is the design's.
  3. **Signed in:**
     - sign-in, and the header "Signed in as E2E Sam";
     - **post with similar ideas:** none at "Sy", the list at "Sync notes", and voting from the list counts in the database;
     - post the idea, which starts with the author's vote;
     - **vote twice gives one vote:** a double click, a reload, and a second insert through the API refused by the database (23505);
     - **unvote**, also after a reload;
     - **comment:** it appears last, the count goes up, and the box empties;
     - sign out.
  4. **Rate limits:**
     - the 6th idea in an hour, the 31st comment and the 101st vote are each refused with the message;
     - nothing is posted, and the vote button returns to its old state.
  5. **Owner:** "Signed in as owner", and the "Owner" mark on Ana's comment.
- **Tidying:** each spec removes its test people, which also removes their ideas, votes and comments. After a full run, the local Lumen data was checked to be exactly the seed again.
- **Screenshot spec:** `e2e/screenshots.spec.ts` runs only with `npm run screenshots`, so CI and ordinary runs never rewrite the committed images.

**New dependencies:** none. The Inter font comes through `next/font/google`, which is part of Next.js 16.4.6 (already a dependency). The font files are downloaded at build time and served from the site itself, so the browser makes no request to Google.

## Pull request, commit and checks

- **Pull request:** #7, https://github.com/adriatic/triad-feedbox/pull/7 (not merged)
- **Branch and head:** `f5-screens` at **`3353bfc86446bb5d529b8269e8fbeb8c706c2f5f`** (one commit on `main` ed790b4).
- **CI** (both runs passed):

  | Check | Push run 44189551358 | Pull request run 44189610740 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** pass, "Deployment has completed".
- **Preview of the pull request:** https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app (behind Vercel Authentication; it answers 302 to Vercel's sign-in without one, as expected).

## Screenshots and side-by-side images

**In the repository:** `screenshots/F5/<state>-<light|dark>-<1280|390>.png`, 16 states × 4 = 64 images:
- board-visitor, board-planned-visitor, board-sort-new-visitor, board-search-visitor, board-signed-in, board-owner;
- idea-visitor, idea-signed-in, idea-owner;
- post-idea-empty, post-idea-similar;
- sign-in, sign-in-check-email, confirm, welcome;
- changelog.

**Side by side, for Claude.ai (not in git):** in `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/`. In each image the design is on the left and the built screen on the right, with the same Lumen data, light. The designs were drawn from `design/*.dc.html` by `e2e/design-support.js`, a small stand-in for the design tool's runtime, which is not in the repository.

| Image | Design | Built screen |
|---|---|---|
| `Main.png` | Main.dc.html | board, Open tab, Top, visitor, 1280 |
| `Idea.png` | Idea.dc.html (owner view) | "Dark mode for the editor", signed in as Ana (the seed's owner), 1280 |
| `PostIdea.png` | PostIdea.dc.html | Post an idea, signed in as Sam P., title "Sync notes", 1280 |
| `SignIn.png` | SignIn.dc.html | sign-in form, visitor, 1280 |
| `Changelog.png` | Changelog.dc.html | changelog, visitor, 1280 |
| `BoardPhone.png` | BoardPhone.dc.html | board, Planned tab, visitor, 390 |

**Differences from the designs that I know of, each with its reason**

| # | Difference | Reason |
|---|---|---|
| 1 | Comment counts and some descriptions differ (for example "Sync between two laptops": design 14 comments, built 2). "Shipped" shows 3, not 2. | The data is the Lumen seed (F3), which has fewer comments, slightly different details, and the shipped idea "Pin notes to the top of a notebook" from the changelog design. The screens show what the database holds. |
| 2 | The Idea page has no "Owner tools" box (status, merge, hide). | Out of scope: owner tools are F6. |
| 3 | Comments are ordered oldest first; the design shows Ana's Oct 9 comment above Tom's Oct 5 one. | The task and F1 section 7 say "newest last". |
| 4 | The "Owner" mark on comments shows only to owners. Visitors and members see no mark. | The database lets only owners read `board_owners`, so nobody else can know who the owners are. Changing that is a database change: decision **F5-D1**. |
| 5 | The header shows the name ("Signed in as Sam P.") and a Sign out button. The designs show the email address (PostIdea, Idea), "Signed in as visitor" (PostIdea) and "Not signed in" (SignIn). | The design brief and F1 section 4 say the header shows "Viewing as visitor", "Signed in as <name>" or "Signed in as owner", and that email addresses are never shown. |
| 6 | The phone header says "Viewing as visitor" in full, where BoardPhone says "Visitor". | The task says the header always shows those words. It still fits on one line at 390 px. |
| 7 | A "Changelog" link in the desktop header, and a footer line "<board> runs on Feedbox … See what shipped" on every page. | Main.dc.html has no way to reach the changelog. The footer is the way on a phone, where the header has no room. |
| 8 | The board on a phone also shows the search box and the Sort button; BoardPhone.dc.html has neither. | Search and sort are part of the board (task item 1) and should work on a phone too. |
| 9 | Post an idea lists up to 5 similar ideas; the design shows 3. For "Sync notes" the list also includes weaker matches such as "Pin notes to the top of a notebook". | F1 section 5: `similar_ideas` returns up to 5 ideas above similarity 0.3. "notes" alone is enough above that threshold. |
| 10 | A similar idea the person has already voted for shows a filled "Voted" button (Sam P. wrote "Sync between two laptops", so his vote is on it). | The button shows the person's real vote; pressing it removes the vote. |
| 11 | In dark mode, the text on accent-coloured buttons, the logo letter and a pressed vote button is dark (#0F1115), not white. | White on the dark accent #8B93FF is too faint to read easily (about 2.6:1). The designs already use the dark colour for a pressed vote in dark mode, so the same rule is used everywhere. |
| 12 | Desktop pages are a little taller: the board's intro line wraps beside "Post an idea", and there is a footer. | The board's intro text from the seed is slightly longer than the design's, and the footer is new (row 7). |
| 13 | The sign-in field is empty with the placeholder "you@example.com"; the design shows "sam@mail.example" typed in. | The design shows a filled-in example; the real page starts empty. |

## Steps for Nik

Everything happens on the Mac, in Chrome, where you are signed in to Vercel, on the Preview of pull request #7. The Preview uses feedbox-preview, whose board is Lumen.

**F5-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app

Expected: the board "What should Lumen do next?", with "Viewing as visitor" at the top right and the tabs "Open 4", "Planned 2", "Building 1", "Shipped 3". The Open tab is underlined and shows four ideas, starting with "Sync between two laptops" at 73 votes.

Result

**F5-2** In the same tab, click the tab **Planned 2**, then **Shipped 3**, then **Open 4**.

Expected: Planned shows "Dark mode for the editor" (214) and "Offline mode" (132). Shipped shows three Shipped ideas (green chips). Open shows the four Open ideas again.

Result

**F5-3** In the same tab, on the Open tab, click **Sort: Top**.

Expected: the button now reads "Sort: New", and the order is "Tag notes by colour", "Share a note by link", "Search inside attachments", "Sync between two laptops". Click **Sort: New** once more: it reads "Sort: Top", and "Sync between two laptops" is first again.

Result

**F5-4** In the same tab, click in the box **Search ideas** and type `laptop`. Wait one second.

Expected: only "Sync between two laptops" is listed, and the address ends in `?q=laptop`. Then select the text in the box and delete it. After one second the four Open ideas are back.

Result

**F5-5** In the Mail app on the Mac, delete every earlier email whose subject is "Your Feedbox sign-in link" or "Your first Feedbox sign-in link".

Expected: no Feedbox sign-in email is left in the inbox.

Result

**F5-6** Back in the Chrome tab, click **Sign in** at the top right. In **Email address**, type your own email address and click **Send me a link**.

Expected: the card reads "Check your email" and names your address.

Result

**F5-7** In the Mail app, open the new email "Your Feedbox sign-in link" (from Feedbox) and click the link **Sign in to Feedbox**.

Expected: Chrome opens a page "Finish signing in" with a button; you are not signed in yet.

Result

**F5-8** On that page, click **Finish signing in**. If the page then asks "Name shown with your ideas", type `Nik` and click **Continue**.

Expected: the Lumen board. The top right reads "Signed in as" followed by your name, with a **Sign out** button.

Result

**F5-9** On the board, click **Post an idea**. Click in **Title** and type `Sync notes`. Wait one second.

Expected: on the right, the heading "Similar ideas already on the board", and below it up to five ideas, including "Sync between two laptops" with "73 votes", each with a **Vote** button.

Result

**F5-10** Select all the text in **Title** and type `F5 check: sync over the local network` instead. In **Details**, type `Posted by Nik while checking task F5.` Click **Post idea**.

Expected: the new idea's page with the heading "F5 check: sync over the local network", "Posted by" your name with today's date, the chip "Open", and a filled vote button showing 1.

Result

**F5-11** Click **← All ideas**. In the row "Tag notes by colour" (41), double-click the vote button on the left.

Expected: the button turns filled (blue) and shows 42, not 43.

Result

**F5-12** Reload the page (⌘R).

Expected: "Tag notes by colour" still shows 42 with a filled button: one vote, even after a double click.

Result

**F5-13** Click the filled 42 button of "Tag notes by colour" once. Then reload the page (⌘R).

Expected: after the click the button is outlined again and shows 41. After the reload it still shows 41, outlined.

Result

**F5-14** Click the title **Tag notes by colour**. Click in **Add a comment**, type `F5 check: comment from Nik.` and click **Post comment**.

Expected: the comment appears at the bottom of the list with your name and today's date. The heading above the comments changes from "1 comment" to "2 comments", and the box is empty again.

Result

**F5-15** On the Mac, open the Apple menu, then **System Settings**, then **Appearance**, and click **Dark**. Go back to the Chrome tab.

Expected: the Feedbox page is dark: near-black background, light text, and lilac buttons and chips in darker colours. Then set Appearance back to what it was before (for example **Light** or **Auto**).

Result

**F5-16** In Chrome, drag the right edge of the window to the left until the window is as narrow as Chrome allows. Click **Lumen** at the top left.

Expected: the phone layout of the board. The header shows only the "L" box, "Lumen", the "Signed in as …" pill and **Sign out**. **Post an idea** spans the full width, the four tabs sit on one row, and each idea shows its title, chip and comment count, without the description line. Drag the window back to its normal width.

Result

**F5-17** Click **Sign out** at the top right.

Expected: the board, with "Viewing as visitor" and a **Sign in** button at the top right.

Result

**F5-18** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

**F5-D1: show the "Owner" mark on comments to everyone. Your decision.**
- **Now:** the mark shows only to owners. The database lets only owners read `board_owners`; visitors and members cannot learn who the owners are, and the app has no secret key to look it up.
- **The change:** one new migration (never an edit of the Feedbox v1 migration). It adds a function `public.board_owner_ids(p_board_id uuid) returns setof uuid`:
  - `security definer`, `set search_path = ''`;
  - granted to `anon` and `authenticated`;
  - it returns only the owners' profile ids, never an email address (display names are already public).
- **Afterwards:** pgTAP tests, Claude.ai's line-by-line reading, then you run it on feedbox-preview and later on feedbox-prod. The app would then call it in `getOwnerIds`.
- **What it reveals:** which display names own the board, which the Owner mark shows anyway.
- **My recommendation:** yes, as a small database task before or with F6 (F6 adds owner replies and needs the same).

**F5-D2: the Preview test runner (F1 section 10). Not built. Your decision.**
- **What it would add over the local e2e:**
  - it tests the real Vercel build with the real Vercel settings, against feedbox-preview's real settings: Redirect URLs, email templates, Confirm email, row-level security as applied there;
  - it catches a mistake in a dashboard setting or an environment variable, which the local tests cannot see.
- **What it needs:**
  - **Vercel:** you create a "Protection Bypass for Automation" secret (Settings, Deployment Protection), and add it to GitHub as the Actions secret `VERCEL_AUTOMATION_BYPASS_SECRET`.
  - **GitHub:** a workflow that waits for Vercel's Preview status, then runs Playwright against the Preview address with the header `x-vercel-protection-bypass`.
  - **For signed-in tests:** `SUPABASE_PREVIEW_SECRET_KEY` (already a GitHub Actions secret, so far unused), to make sign-in links without email (generateLink) and to remove the test people afterwards.
- **The risks:**
  - The job writes test people, ideas and votes into feedbox-preview, the board you review.
  - A key that bypasses row-level security is used on every pull request.
  - Runs depend on feedbox-preview being awake (free projects pause) and on its email limits.
- **The middle way:** a visitor-only check of the Preview (read the board, tabs, search, an idea, the changelog). It needs only the Vercel bypass secret, no Supabase key, and writes nothing.
- **My recommendation:** keep the local e2e as the required check now, and take the middle way in a later task, after F6, as a check that is not required. Build the full signed-in runner only if a Preview-only fault ever slips through.

No other decision is open.
