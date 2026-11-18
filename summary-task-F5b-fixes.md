# Task F5b: fixes for what Nik's F5a run found on the Preview

Branch `f5-screens`, pull request #7 (not merged). New head: `6a31ec6d3bd1a20f8aec737fb76323b87a61ce0a` (was `ad3d088`).
No migration, no dashboard setting and no hosted database was touched. The idea "Sync notes" from Nik's F5a run stays on feedbox-preview.

## Fault 1: no similar ideas while typing on the Preview

- **Cause:**
  - On Post an idea, the similar ideas were the only thing besides the vote button that the browser asked from Supabase itself.
  - Everything else (the board, the search box, posting, comments, sign-in) goes through the app's server, which is why F5a-1 to F5a-10 and the posting in F5a-11 worked.
  - When the browser's call failed, the code dropped the error without a word. The panel then showed "No similar ideas yet" instead of a message.
  - Running the new test against the old code (`ad3d088`) shows exactly this: when the browser cannot reach Supabase, the old form shows "No similar ideas yet" for "Sync notes", and the old vote button says "Your session has ended. Sign in again to vote."
- **What I could not see:** which error Nik's browser got. Vercel's runtime logs only hold what the server does, and this call went from Chrome straight to supabase.co, so it was never in them. I also could not open the logs: there is no Vercel sign-in or Vercel CLI on the Mac, because of the rule "no secrets on the Mac". So the cause is the path (a browser-only call that fails silently), not one proven error message.
- **Fix:**
  - The similar ideas are now asked through a server action (`findSimilar` in `app/ideas/new/actions.ts`). It is the same path as the board's search box, which F5a-4 showed working on feedbox-preview.
  - Votes go through a server action too (`components/vote-action.ts`), both on the board and beside Post an idea.
  - The browser client (`lib/supabase/browser.ts`) is removed: the browser no longer calls Supabase at all.
  - A failure is now shown in words ("Similar ideas could not be loaded just now. …"). The server writes it to its log, so a later failure would appear in Vercel's runtime logs.
- **Test:**
  - In `e2e/screens.spec.ts`, the browser cannot reach the local Supabase API at all, and any attempt fails the test.
  - The similar-ideas test (typing "Sync notes") and the vote tests now pass only if everything goes through the server.
  - On the old code this test fails with "No similar ideas yet" and with "requests from the browser straight to Supabase", so it would have caught the fault before the Preview.

## Fault 2: Return in Title posted the idea

- **Cause:** a form with a single-line field is sent when you press Return, which is the browser's built-in behaviour. The form did not stop it, so Return in Title posted at once, before the similar ideas were seen and before Details was filled.
- **Fix:** Return in Title no longer posts. It moves the cursor to Details, and the similar ideas stay on screen. Only the **Post idea** button posts.
- **Details stays optional, on purpose:**
  - F1 section 2 (Data model, table `ideas`) says "body: 0 to 4,000 characters".
  - The database's check `ideas_body_check` allows an empty body.
  - F2's `validateBody` says "Idea details: optional, up to 4,000 characters".
  - The design (`PostIdea.dc.html`) does not mark Details as required either.
- **Test:** in `e2e/screens.spec.ts`, after the similar ideas appear for "Sync notes", Return is pressed in Title. The test checks that the cursor is in Details, that the address is still `/ideas/new`, that the list is still there, and that the person has posted no idea.

## Fault 3: dates in UTC

- **Cause:** every date was formatted in UTC on the server (`formatDate`, `formatMonthDay`). Nik posted at about 5 PM on Nov 17, Pacific time, which is already Nov 18 in UTC.
- **Choice: the viewer's own time zone, as the browser knows it.** It is right for a visitor anywhere, and needs no setting.
  - One board time zone would show the wrong day to everyone outside it.
  - The page arrives with the UTC date, and the browser replaces it with its own date as soon as the page starts (`components/LocalDate.tsx`).
- **What it covers:**
  - Ideas: "Posted by … on Nov 17, 2026".
  - Comments: "Nov 17", with the full date when you point at it.
  - The changelog's dates are release dates the owner chose, plain calendar dates with no time. They are shown as written, the same everywhere, which is right.
  - The welcome page shows no date.
- **Tests:**
  - **Unit** (`lib/feedbox/format.test.ts`): a post at 01:04 UTC on Nov 18, 2026 (5:04 PM Pacific on Nov 17) reads "Nov 17, 2026" and "Nov 17" in America/Los_Angeles, and "Nov 18, 2026" in UTC and in Europe/Berlin. A calendar date reads the same in every time zone.
  - **End-to-end** (`e2e/screens.spec.ts`): an idea and a comment made at that moment show "Nov 17, 2026" and "Nov 17" in a Pacific browser, and "Nov 18, 2026" and "Nov 18" in a Berlin browser. On the old code it fails with "Nov 18, 2026" in the Pacific browser.
  - Playwright now runs in Pacific time on the Mac and in CI.

## What step 4 found

- **Other browser-side calls:** only the vote button called Supabase from the browser. It is moved to the server with the similar ideas (Fault 1), and the new e2e guard covers it.
  - Every other interactive piece already used server actions or page addresses: sign-in, Finish signing in, the welcome name, comments, and the search box.
  - No other `fetch`, realtime channel or browser Supabase client is left.
- **Other UTC dates:** none beyond the two formatters fixed above.
  - The release date of a changelog entry is a calendar date and is correct as it is.
  - The rate limits count "the last hour", which does not depend on a time zone.
  - The database sets no date by `current_date`.
- **Other Return problems:** none. The comment box is multi-line, so Return makes a new line. On the sign-in page and the name page, Return is meant to send the one field.

## Screenshots

I recaptured them to check, and no screen looks different. 60 of 64 images were the same to the pixel, and the 4 `sign-in-check-email-*` images differ only by the timestamp in the test address. So the committed images are unchanged, and so are the side-by-side images.

## Results

- **Commit:** `6a31ec6d3bd1a20f8aec737fb76323b87a61ce0a` on `f5-screens`, pull request #7: https://github.com/adriatic/triad-feedbox/pull/7
- **Local runs:** lint, typecheck, unit (131 tests) and e2e (11 tests) all pass. Against the old code, the new e2e tests fail as described above.
- **CI on 6a31ec6:**

  | Check | push run 44214160566 | pull request run 44214168151 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on 6a31ec6, "Deployment has completed".

- **Preview:** https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app
- **CLAUDE.md:** the Layout lines now say that the browser never calls Supabase itself, and describe `LocalDate`.

## Steps for Nik

Everything happens on the Mac, in Chrome, where you are signed in to Vercel, on the Preview of pull request #7. The Preview uses feedbox-preview, whose board is Lumen. Run every step from the first: these steps replace F5a-1 to F5a-20. Your idea "Sync notes" from the F5a run is on the board, so the Open tab now has 5 ideas.

**F5b-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app

Expected: the board "What should Lumen do next?". At the top right it reads "Signed in as Nik I.", with a **Sign out** button: you are still signed in from the F5a run.

Result

**F5b-2** In the same tab, click **Sign out** at the top right. (If the top right already reads "Viewing as visitor", there is nothing to click.)

Expected: the board, with "Viewing as visitor" and a **Sign in** button at the top right. The tabs read "Open 5", "Planned 2", "Building 1", "Shipped 3". The Open tab is underlined and shows five ideas, in this order: "Sync between two laptops" (73), "Search inside attachments" (58), "Share a note by link" (49), "Tag notes by colour" (41), "Sync notes" (1).

Result

**F5b-3** In the same tab, click the tab **Planned 2**, then **Shipped 3**, then **Open 5**.

Expected: Planned shows "Dark mode for the editor" (214) and "Offline mode" (132). Shipped shows three Shipped ideas (green chips). Open shows the five Open ideas again.

Result

**F5b-4** In the same tab, on the Open tab, click **Sort: Top**.

Expected: the button now reads "Sort: New", and the order is "Sync notes", "Tag notes by colour", "Share a note by link", "Search inside attachments", "Sync between two laptops". Click **Sort: New** once more: it reads "Sort: Top", "Sync between two laptops" is first again, and "Sync notes" is last.

Result

**F5b-5** In the same tab, click in the box **Search ideas** and type `laptop`. Wait one second.

Expected: only "Sync between two laptops" is listed, and the address ends in `?q=laptop`. Then select the text in the box and delete it. After one second the five Open ideas are back.

Result

**F5b-6** In the same tab, in the Open list, click the title **Sync notes**.

Expected: the idea page "Sync notes" with the chip "Open", a vote button showing 1, "Posted by Nik I. on Nov 17, 2026" (in F5a it wrongly read Nov 18, 2026), "0 comments", and the link "Sign in to comment" at the bottom.

Result

**F5b-7** On the same page, click **← All ideas**. Scroll to the bottom of the board and click **See what shipped**.

Expected:
- The page "What shipped in Lumen", with "Every entry started as an idea on the board. Newest first."
- On the left, two dates, newest first: "Nov 3, 2026" (Lumen 2.4), then "Sep 18, 2026" (Lumen 2.3).
- Under Nov 3: "Keyboard shortcut cheat sheet" with the link "See the idea, 96 votes", and "Faster startup on large notebooks" with "See the idea, 88 votes".
- Under Sep 18: "Pin notes to the top of a notebook" with "See the idea, 121 votes".
- Each line has a green "Shipped" chip and one sentence of what changed.
- The top right still reads "Viewing as visitor".

Result

**F5b-8** On the same changelog page, click **See the idea, 96 votes**.

Expected: the idea page "Keyboard shortcut cheat sheet" with a green "Shipped" chip, a vote button showing 96, "Posted by Jun H. on Aug 1, 2026", and the link "Sign in to comment" at the bottom.

Result

**F5b-9** In the Mail app on the Mac, delete every earlier email whose subject is "Your Feedbox sign-in link" or "Your first Feedbox sign-in link".

Expected: no Feedbox sign-in email is left in the inbox.

Result

**F5b-10** In Chrome, in the same tab, go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app and click **Sign in** at the top right. In **Email address**, type your own email address and click **Send me a link**.

Expected: the card reads "Check your email" and names your address.

Result

**F5b-11** In the Mail app, open the new email "Your Feedbox sign-in link" (from Feedbox) and click the link **Sign in to Feedbox**.

Expected: Chrome opens a page "Finish signing in" with a button; you are not signed in yet.

Result

**F5b-12** On that page, click **Finish signing in**.

Expected: the Lumen board, with "Signed in as Nik I." and a **Sign out** button at the top right. The page "Name shown with your ideas" does not appear, because your name is already set from the F5a run.

Result

**F5b-13** On the board, click **Post an idea**. Click in **Title** and type `Sync notes`. Wait one second.

Expected: on the right, the heading "Similar ideas already on the board", and below it these five ideas, in this order, each with its vote count, its status chip and a button:
- "Sync notes", 1 vote, Open, button **Voted** (your own idea already has your vote)
- "Export notes to Markdown", 187 votes, Building, button **Vote**
- "Pin notes to the top of a notebook", 121 votes, Shipped, button **Vote**
- "Tag notes by colour", 41 votes, Open, button **Vote**
- "Sync between two laptops", 73 votes, Open, button **Vote**

Result

**F5b-14** With the cursor still in **Title** (after "Sync notes"), press Return. Wait two seconds.

Expected: nothing is posted. The page stays on "Post an idea" (the address still ends in `/ideas/new`), the cursor moves into **Details**, "Sync notes" is still in Title, and the five similar ideas are still on the right.

Result

**F5b-15** Select all the text in **Title** and type `F5b check: sync over the local network` instead. In **Details**, type `Posted by Nik while checking task F5b.` Click **Post idea**.

Expected: the new idea's page with the heading "F5b check: sync over the local network", the chip "Open", a filled vote button showing 1, the details text, and "Posted by Nik I. on" today's date as the clock on your Mac shows it (Pacific time; for example "Nov 17, 2026" on the evening of Nov 17).

Result

**F5b-16** Click **← All ideas**. In the row "Tag notes by colour" (41), double-click the vote button on the left.

Expected: the Open tab now reads "Open 6". The button turns filled (blue) and shows 42, not 43.

Result

**F5b-17** Reload the page (⌘R).

Expected: "Tag notes by colour" still shows 42 with a filled button: one vote, even after a double click.

Result

**F5b-18** Click the filled 42 button of "Tag notes by colour" once. Then reload the page (⌘R).

Expected: after the click the button is outlined again and shows 41. After the reload it still shows 41, outlined.

Result

**F5b-19** Click the title **Tag notes by colour**. Click in **Add a comment**, type `F5b check: comment from Nik.` and click **Post comment**.

Expected: the comment appears at the bottom of the list with "Nik I." and today's date as month and day, as your Mac's clock shows it (for example "Nov 17"). The heading above the comments changes from "1 comment" to "2 comments", and the box is empty again.

Result

**F5b-20** On the Mac, open the Apple menu, then **System Settings**, then **Appearance**, and click **Dark**. Go back to the Chrome tab.

Expected: the Feedbox page is dark: near-black background, light text, and lilac buttons and chips in darker colours. Then set Appearance back to what it was before (for example **Light** or **Auto**).

Result

**F5b-21** In Chrome, drag the right edge of the window to the left until the window is as narrow as Chrome allows. Click **Lumen** at the top left.

Expected: the phone layout of the board. The header shows only the "L" box, "Lumen", the "Signed in as Nik I." pill and **Sign out**. **Post an idea** spans the full width, the four tabs sit on one row, and each idea shows its title, chip and comment count, without the description line. Drag the window back to its normal width.

Result

**F5b-22** Click **Sign out** at the top right.

Expected: the board, with "Viewing as visitor" and a **Sign in** button at the top right.

Result

**F5b-23** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

No new decision. F5-D1 and F5-D2 from the F5 report stay open as written there.
