# Task F5a: the changelog screenshots showed the wrong screen

Done. The screenshot spec is fixed, and all 64 images in `screenshots/F5/` and all six side-by-side images were remade in one run.
- **Checked by eye:** every one of the 64 now shows the screen and state in its file name.
- **Before:** four of them, the changelog images, were wrong.
- **Pushed:** to `f5-screens` (pull request #7, not merged). CI is green and Vercel succeeded on the new head.
- **Not changed:** no screen, no migration, no setting.
- **Never touched:** feedbox-preview and feedbox-prod.

## Cause

`e2e/screenshots.spec.ts` used one shared browser context per signed-in state ("visitor", Sam, Ana) for each theme and width. The visitor states ran in this order: sign-in, check-email, confirm, welcome, changelog.

The **welcome** capture signs in a new test person, who has no display name yet, in that shared "visitor" browser. The **changelog** capture came next in the same browser. That person was still signed in, so the app (`proxy.ts`) sent them to `/welcome`, as it should for anyone without a name. The spec took the screenshot without checking where it was.

## Fix

In `e2e/screenshots.spec.ts`:
- **A fresh browser for every capture.** No session or cookie carries over from an earlier capture. Signed-in states sign in again each time.
- **A check before every screenshot.** Each state now names its expected address and its expected header text ("Viewing as visitor", "Signed in as Sam P.", "Signed in as owner", or "Signed in" for welcome). The capture fails if either is wrong, so a wrong screen can no longer be saved under a state's name.

## Images that were wrong before

I put all 64 old images (from 3353bfc) on four contact sheets, one per theme and width, and looked at each against its file name.

| File | What it showed | Now |
|---|---|---|
| `changelog-light-1280.png` | /welcome ("Welcome to Lumen", header "Signed in") | the changelog as a visitor |
| `changelog-dark-1280.png` | /welcome | the changelog as a visitor |
| `changelog-light-390.png` | /welcome | the changelog as a visitor |
| `changelog-dark-390.png` | /welcome | the changelog as a visitor |

The other 60 were right. After the recapture, I looked at all 64 again on the same kind of contact sheets: each shows its named screen and state.
- **Files changed:** 9 in total.
- **The four above.**
- **The four `sign-in-check-email-*` images:** the test address they show has a new timestamp, as every run does.
- **`post-idea-similar-dark-390.png`:** a few pixels of font rendering. It shows the same screen as before.

## Side-by-side images (remade, all six from the same run)

In `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/`:
- **The six files:** `Main.png`, `Idea.png`, `PostIdea.png`, `SignIn.png`, `Changelog.png` and `BoardPhone.png`.
- **`Changelog.png`:** now shows Changelog.dc.html on the left and, on the right, the changelog as a visitor at 1280 px: "What shipped in Lumen", Nov 3, 2026 (Lumen 2.4) and Sep 18, 2026 (Lumen 2.3), and three lines with "See the idea, 96 / 88 / 121 votes".
- **New differences** from the design on that page, not listed in the F5 report:
  - The header shows "Feedback and roadmap" and **Sign in**, where the design shows "Changelog" and a **Back to the board** button. Every page uses the same header, which has a Changelog link and the sign-in state.
  - The footer line from F5 (row 7 of the F5 differences).

## Pull request, commit and checks

- **Pull request:** #7, https://github.com/adriatic/triad-feedbox/pull/7 (not merged)
- **New head:** **`ad3d08805161fcc1e4fc968905cbc5a2649e9c56`** on `f5-screens`, one commit after 3353bfc.
- **CI** (both runs passed):

  | Check | Push run 44191555140 | Pull request run 44191572787 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on ad3d088, "Deployment has completed".
- **Preview:** https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app

## Steps for Nik

Everything happens on the Mac, in Chrome, where you are signed in to Vercel, on the Preview of pull request #7. The Preview uses feedbox-preview, whose board is Lumen. These steps replace F5-1 to F5-18.

**F5a-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app

Expected: the board "What should Lumen do next?", with "Viewing as visitor" at the top right and the tabs "Open 4", "Planned 2", "Building 1", "Shipped 3". The Open tab is underlined and shows four ideas, starting with "Sync between two laptops" at 73 votes.

Result

**F5a-2** In the same tab, click the tab **Planned 2**, then **Shipped 3**, then **Open 4**.

Expected: Planned shows "Dark mode for the editor" (214) and "Offline mode" (132). Shipped shows three Shipped ideas (green chips). Open shows the four Open ideas again.

Result

**F5a-3** In the same tab, on the Open tab, click **Sort: Top**.

Expected: the button now reads "Sort: New", and the order is "Tag notes by colour", "Share a note by link", "Search inside attachments", "Sync between two laptops". Click **Sort: New** once more: it reads "Sort: Top", and "Sync between two laptops" is first again.

Result

**F5a-4** In the same tab, click in the box **Search ideas** and type `laptop`. Wait one second.

Expected: only "Sync between two laptops" is listed, and the address ends in `?q=laptop`. Then select the text in the box and delete it. After one second the four Open ideas are back.

Result

**F5a-5** In the same tab, scroll to the bottom of the board and click **See what shipped**.

Expected:
- The page "What shipped in Lumen", with "Every entry started as an idea on the board. Newest first."
- On the left, two dates, newest first: "Nov 3, 2026" (Lumen 2.4), then "Sep 18, 2026" (Lumen 2.3).
- Under Nov 3: "Keyboard shortcut cheat sheet" with the link "See the idea, 96 votes", and "Faster startup on large notebooks" with "See the idea, 88 votes".
- Under Sep 18: "Pin notes to the top of a notebook" with "See the idea, 121 votes".
- Each line has a green "Shipped" chip and one sentence of what changed.
- The top right still reads "Viewing as visitor".

Result

**F5a-6** On the same changelog page, click **See the idea, 96 votes**.

Expected: the idea page "Keyboard shortcut cheat sheet" with a green "Shipped" chip, a vote button showing 96, "Posted by Jun H. on Aug 1, 2026", and the link "Sign in to comment" at the bottom.

Result

**F5a-7** In the Mail app on the Mac, delete every earlier email whose subject is "Your Feedbox sign-in link" or "Your first Feedbox sign-in link".

Expected: no Feedbox sign-in email is left in the inbox.

Result

**F5a-8** In Chrome, in the same tab, go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app and click **Sign in** at the top right. In **Email address**, type your own email address and click **Send me a link**.

Expected: the card reads "Check your email" and names your address.

Result

**F5a-9** In the Mail app, open the new email "Your Feedbox sign-in link" (from Feedbox) and click the link **Sign in to Feedbox**.

Expected: Chrome opens a page "Finish signing in" with a button; you are not signed in yet.

Result

**F5a-10** On that page, click **Finish signing in**. If the page then asks "Name shown with your ideas", type `Nik` and click **Continue**.

Expected: the Lumen board. The top right reads "Signed in as" followed by your name, with a **Sign out** button.

Result

**F5a-11** On the board, click **Post an idea**. Click in **Title** and type `Sync notes`. Wait one second.

Expected: on the right, the heading "Similar ideas already on the board", and below it up to five ideas, including "Sync between two laptops" with "73 votes", each with a **Vote** button.

Result

**F5a-12** Select all the text in **Title** and type `F5 check: sync over the local network` instead. In **Details**, type `Posted by Nik while checking task F5.` Click **Post idea**.

Expected: the new idea's page with the heading "F5 check: sync over the local network", "Posted by" your name with today's date, the chip "Open", and a filled vote button showing 1.

Result

**F5a-13** Click **← All ideas**. In the row "Tag notes by colour" (41), double-click the vote button on the left.

Expected: the button turns filled (blue) and shows 42, not 43.

Result

**F5a-14** Reload the page (⌘R).

Expected: "Tag notes by colour" still shows 42 with a filled button: one vote, even after a double click.

Result

**F5a-15** Click the filled 42 button of "Tag notes by colour" once. Then reload the page (⌘R).

Expected: after the click the button is outlined again and shows 41. After the reload it still shows 41, outlined.

Result

**F5a-16** Click the title **Tag notes by colour**. Click in **Add a comment**, type `F5 check: comment from Nik.` and click **Post comment**.

Expected: the comment appears at the bottom of the list with your name and today's date. The heading above the comments changes from "1 comment" to "2 comments", and the box is empty again.

Result

**F5a-17** On the Mac, open the Apple menu, then **System Settings**, then **Appearance**, and click **Dark**. Go back to the Chrome tab.

Expected: the Feedbox page is dark: near-black background, light text, and lilac buttons and chips in darker colours. Then set Appearance back to what it was before (for example **Light** or **Auto**).

Result

**F5a-18** In Chrome, drag the right edge of the window to the left until the window is as narrow as Chrome allows. Click **Lumen** at the top left.

Expected: the phone layout of the board. The header shows only the "L" box, "Lumen", the "Signed in as …" pill and **Sign out**. **Post an idea** spans the full width, the four tabs sit on one row, and each idea shows its title, chip and comment count, without the description line. Drag the window back to its normal width.

Result

**F5a-19** Click **Sign out** at the top right.

Expected: the board, with "Viewing as visitor" and a **Sign in** button at the top right.

Result

**F5a-20** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

No new decision. F5-D1 and F5-D2 from the F5 report stay open as written there.
