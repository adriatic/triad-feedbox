# Task F5c: the sort control and the changelog header

Branch `f5-screens`, pull request #7 (not merged). New head: `b35a3be87398de8e51b98911ecab593637dcfa41` (was `6a31ec6`).
No migration and no dashboard setting changed, and nothing ran against a hosted database.

## What changed

### The sort control (as Nik chose on 2026-11-17 at 6:35 PM)

- **The button:** one button to the right of the search box. It shows the current order's icon and name, then a small down-arrow:
  - an up-arrow and "Most votes", or
  - a clock and "Newest".
- **The menu:** clicking the button opens a small menu with both orders, each with its icon, and a tick at the current one. Choosing one changes the list and closes the menu. Clicking anywhere else also closes it.
- **Keyboard:**
  - Tab reaches the button.
  - Return, Space or the down-arrow opens the menu, on the current order.
  - The up- and down-arrows, Home and End move between the two choices; Return or Space chooses.
  - Escape closes the menu and returns to the button. Tab closes it and moves on.
- **Screen readers:** the button is read as "Sort ideas: Most votes" (or "Newest"), says that it opens a menu, and says whether the menu is open. The two choices are read as choices with one of them checked.
- **Address:** the order stays in the address as before: `?sort=new` for Newest, nothing for Most votes.
- **Phone layout:** the button sits beside the search box on the same row, and the search box takes the rest of the width.
- **Looks:** light and dark, from the existing colours. The icons are small inline drawings in the style of the search icon, and no new dependency was added.
- **Files:** `components/SortMenu.tsx` (new), `app/page.tsx`, `app/globals.css`. The names "Top" and "New" became "Most votes" and "Newest" in `lib/feedbox/list.ts`.

### The header never links to the page you are on

- **On /changelog** (as in `Changelog.dc.html`):
  - "Lumen" with "Changelog" beside it.
  - The sign-in state pill.
  - A **Back to the board** button.
  - The Changelog link is not shown.
- **On the board:** the **Changelog** link stays. The board's name "Lumen" at the top left is not a link there, because it would lead to the board you are on.
- **On /sign-in:** the **Sign in** button is not shown, because that is the page you are on.
- **On every other page:** unchanged. "Lumen" leads to the board, and **Changelog** leads to the changelog.
- **File:** `components/Header.tsx` now knows which page it is on.

**Differences from the design that remain:**
- On /changelog, the header also keeps **Sign in** or **Sign out**. The design shows only the pill and "Back to the board", but signing in and out from every page seemed more important than matching it exactly.
- On the phone layout, the changelog header takes two rows: "Back to the board" and "Sign in"/"Sign out" move to a second row. There is no phone design for the changelog.

## Tests

All tests are in `e2e/screens.spec.ts`; all 12 end-to-end tests pass locally and in CI.

- **Sort by mouse:**
  - The button reads "Most votes".
  - The menu lists "Most votes" (ticked) and "Newest", each with its icon.
  - Choosing Newest gives `?sort=new` and the newest-first order. Choosing Most votes gives the address without `?sort` and the most-votes order.
- **Sort by keyboard:**
  - Tab from the search box reaches the button.
  - Return opens the menu on the current order, and Escape closes it, back on the button.
  - The down-arrow opens it, the arrows move, and Return chooses. This is done for both orders.
  - A page opened with `?sort=new` shows "Newest".
- **Sort on the phone (390 px):**
  - The button is on the same row as the search box, to its right, inside the screen.
  - Choosing Newest from its menu works.
  - Nothing is wider than the phone.
- **The header (new test):**
  - On the board there is no link to the board, and **Changelog** leads to /changelog.
  - There the header reads "Lumen Changelog". The links are only **Back to the board** and **Sign in**, the pill reads "Viewing as visitor", and **Back to the board** leads to the board.
  - An idea page has "Lumen", **Changelog** and **Sign in**, and /sign-in has no **Sign in** button.

## Images remade

- **Screenshots in `screenshots/F5/`:**
  - Recaptured where the screen changed: every board state (the new sort button), the changelog (the new header), and the sign-in and "Check your email" pages (no Sign in button there).
  - One new state, `board-sort-menu-visitor`, shows the sort menu open. It is in light and dark, at 1280 and 390 px, so there are now 68 images.
  - Unchanged: the idea pages, Post an idea, the confirm page and the welcome page.
- **Side-by-side images in `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/`:**
  - Remade: `Main.png`, `BoardPhone.png` and `Changelog.png`.
  - Also `SignIn.png`, because the sign-in page lost its Sign in button.
  - `Idea.png` and `PostIdea.png` came out identical and were left as they were.
  - `Changelog.png` now shows the same header as the design, plus Sign in.

## Results

- **Commit:** `b35a3be87398de8e51b98911ecab593637dcfa41` on `f5-screens`, pull request #7: https://github.com/adriatic/triad-feedbox/pull/7
- **Local runs:** lint, typecheck, unit (131 tests) and e2e (12 tests) all pass.
- **CI on b35a3be:**

  | Check | push run 44225121813 | pull request run 44225126724 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on b35a3be, "Deployment has completed".

- **Preview:** https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app
- **CLAUDE.md:** the Layout line for `components/` now names the sort menu and the header rule.

## Steps for Nik

These steps check only what F5c changed. Everything happens on the Mac, in Chrome (where you are signed in to Vercel), on the Preview of pull request #7, which uses feedbox-preview and its Lumen board. Since your F5b run, the Open tab has 6 ideas.

**F5c-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app

Expected: the board "What should Lumen do next?" with the Open tab underlined and "Open 6". The top right reads either "Viewing as visitor" or "Signed in as Nik I.". Both are fine for these steps, so do not sign in or out. At the top left, "Lumen" is not a link: clicking it does nothing, and the page stays as it is.

Result

**F5c-2** In the same tab, look at the button to the right of the box **Search ideas**.

Expected: the button shows a small up-arrow, the words "Most votes" and a small down-arrow. The six Open ideas are listed in this order: "Sync between two laptops" (73), "Search inside attachments" (58), "Share a note by link" (49), "Tag notes by colour" (41), "F5b check: sync over the local network" (1), "Sync notes" (1).

Result

**F5c-3** Click the button **Most votes**.

Expected: a small menu opens under the button with two lines. The first is an up-arrow, "Most votes" in bold, and a tick at the right. The second is a clock and "Newest".

Result

**F5c-4** In that menu, click **Newest**.

Expected: the menu closes. The address ends in `?sort=new`, and the button now shows a clock and "Newest". The order is "F5b check: sync over the local network", "Sync notes", "Tag notes by colour", "Share a note by link", "Search inside attachments", "Sync between two laptops".

Result

**F5c-5** Click the button **Newest**, and in the menu click **Most votes**.

Expected: when the menu opens, the tick is at "Newest". After the click the menu closes, the address ends in `.vercel.app/` (no `?sort`), and the button shows the up-arrow and "Most votes". The order is again the one in F5c-2, starting with "Sync between two laptops".

Result

**F5c-6** Click the button **Most votes** again, then press the Escape key.

Expected: the menu opens, and Escape closes it without changing anything. The button still reads "Most votes".

Result

**F5c-7** In Chrome, drag the right edge of the window to the left until the window is as narrow as Chrome allows.

Expected: the phone layout of the board. The box **Search ideas** and the button with the up-arrow and "Most votes" sit side by side on one row, below the tabs. The search box fills the space up to the button, and nothing runs off the right edge.

Result

**F5c-8** In the same narrow window, click the button **Most votes**, then click **Newest** in the menu. Then click the button **Newest** and click **Most votes** in the menu.

Expected: the menu opens under the button and fits in the window. After **Newest**, the order is the one in F5c-4 and the address ends in `?sort=new`. After **Most votes**, the order is the one in F5c-2 again. Then drag the window back to its normal width.

Result

**F5c-9** In the normal-width window, on the board, click **Changelog** at the top right (left of the sign-in pill).

Expected: the page "What shipped in Lumen". The header shows the "L" box, "Lumen" and, beside it in grey, "Changelog". On the right are the sign-in pill, a **Back to the board** button, and **Sign in** or **Sign out**. There is no "Changelog" link in the header.

Result

**F5c-10** On the changelog page, click **Back to the board**.

Expected: the board "What should Lumen do next?", with **Changelog** at the top right again and the Open ideas in the order of F5c-2.

Result

**F5c-11** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

No new decision. F5-D1 and F5-D2 from the F5 report stay open as written there.
