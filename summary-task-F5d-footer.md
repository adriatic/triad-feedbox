# Task F5d: no link to the page you are on, in the footer too

Branch `f5-screens`, pull request #7 (not merged). New head: `365a320c34dd4477d7e444fbaa65b5f27106493c` (was `b35a3be`).
No migration and no dashboard setting changed, and nothing ran against a hosted database.

## What changed

- **The footer:**
  - On /changelog the line reads "Lumen runs on Feedbox, a free, open-source feedback board." with no "See what shipped" link.
  - On every other page the line and its **See what shipped** link stay as before.
  - The footer moved from `app/layout.tsx` into a new `components/Footer.tsx`, which knows which page it is on, like the header since F5c.
- **Two more self-links, found in step 1 and removed the same way:**
  - **The board's tabs:** the current tab (for example "Open 6" on the Open tab) is now plain text, still underlined and still marked as the current page for screen readers. The other three tabs stay links. File: `app/page.tsx`.
  - **The sort menu:** the ticked order (for example "Most votes" while the board is sorted by most votes) is no longer a link. The other order stays one. Choosing the ticked order by click, Return or Space only closes the menu, as before. File: `components/SortMenu.tsx`.
- **No change in looks:** the board screenshots, including the one with the sort menu open, came out identical to F5c.
- **CLAUDE.md:** the Layout section now states the rule "no link to the page you are on" and names the footer.

## What step 1 found

I checked every link and redirect in `app/` and `components/`, then confirmed it with the new test, which loads each page a visitor can open (see Tests).

| Where | Link | Before F5d | Now |
|---|---|---|---|
| Footer, on /changelog | **See what shipped** to /changelog | link to the page you are on | removed (the words before it stay) |
| Board, the current tab | e.g. **Open 6** to the same tab, order and search | link to the page you are on | plain text |
| Sort menu, the ticked order | e.g. **Most votes** to the same address | link to the page you are on (a click only closed the menu) | not a link; a click still only closes the menu |
| Header | brand, Changelog, Sign in | fixed in F5c | unchanged |

Everything else leads elsewhere: the idea links, "Back to all ideas", "Cancel", "Post an idea", the sign-in links ("Keep browsing without signing in" and "Continue" never lead back to /sign-in, because `safeNextPath` refuses it), the release links on the changelog, and the 404 page's link to the board. Three pages need a signed-in person and are not in the test: Post an idea and Welcome (their only links lead to the board or the changelog), and /changelog/new (its header and footer lead to /changelog, a different page).

## Tests

- **New end-to-end test** in `e2e/screens.spec.ts`, "nothing links to the page you are on: the footer, the tabs and the sort menu (task F5d)":
  - On the board, the footer reads "Lumen runs on Feedbox, a free, open-source feedback board. See what shipped" and has exactly one link to /changelog.
  - The tab links are only "Planned 2", "Building 1" and "Shipped 3", and "Open" is the current tab.
  - In the sort menu, the only link is Newest (`/?sort=new`). Return on the ticked "Most votes" closes the menu, and the address stays `/`.
  - After **See what shipped**, on /changelog, the footer reads "Lumen runs on Feedbox, a free, open-source feedback board." and has no link at all.
  - On `/`, `/?tab=planned`, `/?sort=new`, `/?q=sync`, `/changelog`, an idea page, `/sign-in` and `/sign-in?next=%2Fchangelog`, no link on the page leads to that page's own address.
- **Proof that it catches the fault:** run against the F5c code, the test fails.
- **Two tests adjusted:** they found tabs as links, and the current tab is no longer a link. The `tab` helper in `e2e/screens.spec.ts` and one line in `e2e/auth.spec.ts` now find tabs by their class.
- **Local runs:** lint, typecheck, unit (131 tests) and e2e (13 tests) all pass.

## Images remade

- **Screenshots in `screenshots/F5/`:** the four changelog images (`changelog-light-1280`, `changelog-dark-1280`, `changelog-light-390`, `changelog-dark-390`) were recaptured; the footer link is gone. All other screens came out identical. The "Check your email" images differed only in the test email address, which carries a timestamp, so they were left as they were. Still 68 images.
- **Side-by-side images in `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/`:** `Changelog.png` remade. The other five came out identical and were left as they were.

## Results

- **Commit:** `365a320c34dd4477d7e444fbaa65b5f27106493c` on `f5-screens`, pull request #7: https://github.com/adriatic/triad-feedbox/pull/7
- **CI on 365a320:**

  | Check | push run 44244907073 | pull request run 44244912034 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on 365a320, "Deployment has completed".
- **Preview:** https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app

## Steps for Nik

These steps check only what F5d changed. Everything happens on the Mac, in Chrome (where you are signed in to Vercel), on the Preview of pull request #7. You may be signed in or not; do not sign in or out. In Chrome, when the pointer rests on a link, its address appears in a small box at the bottom left of the window; on text that is not a link, no box appears.

**F5d-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f5-screens-nikolaj-ivancics-projects.vercel.app/changelog then scroll to the bottom of the page.

Expected: the page "What shipped in Lumen". The last line of the page reads "Lumen runs on Feedbox, a free, open-source feedback board." with nothing after it: no "See what shipped".

Result

**F5d-2** In the same tab, rest the pointer on the words of that last line.

Expected: no address box appears at the bottom left of the Chrome window, and none of the words is blue.

Result

**F5d-3** In the same tab, scroll to the top and click **Back to the board** in the header, then scroll to the bottom of the board.

Expected: the board "What should Lumen do next?". The last line reads "Lumen runs on Feedbox, a free, open-source feedback board. See what shipped", with "See what shipped" in blue. With the pointer on "See what shipped", the box at the bottom left shows an address ending in `/changelog`.

Result

**F5d-4** Click **See what shipped**, then scroll to the bottom of the page.

Expected: the page "What shipped in Lumen" opens, and its last line again ends at "feedback board." with no "See what shipped".

Result

**F5d-5** In the same tab, scroll to the top, click **Back to the board**, and rest the pointer on the tab **Open** (underlined) below the board's title. Then rest it on the tab **Planned**.

Expected: on **Open**, no address box appears at the bottom left, and clicking it changes nothing. On **Planned**, the box shows an address ending in `?tab=planned`.

Result

**F5d-6** On the board's Open tab, click the button **Most votes** to the right of the box **Search ideas**. In the menu, rest the pointer on **Most votes** (with the tick), then on **Newest**. Then click **Most votes**.

Expected: on **Most votes**, no address box appears; on **Newest**, the box shows an address ending in `?sort=new`. After the click on **Most votes**, the menu closes, the address does not change, and the button still reads "Most votes".

Result

**F5d-7** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

No new decision. F5-D1 and F5-D2 from the F5 report stay open as written there.
