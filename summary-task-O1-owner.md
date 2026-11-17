DO NOT RUN ANY SQL YET. Claude.ai reads the scripts first.

# Task O1: make Nik the owner of the Feedbox board on feedbox-prod (SQL as code)

Date: 2026-11-17. Branch `o1-owner` from `main` at `08067e7` (tag `f4`). Pull request **#5**: https://github.com/adriatic/triad-feedbox/pull/5. Head **`2412bac4d6e2fe4965cd8bfb630a391fb89f020a`**. Not merged.

## In short

- **The changing script:** `supabase/production/owner-nik.sql` adds one row to `public.board_owners`, which makes you the owner of the board "feedbox" on feedbox-prod.
- **How it finds you:** your email address is not in the repository. Your person is found as the one and only person on feedbox-prod, with the display name "Nikolaj Ivancic". If that is not true, the script refuses in plain words and changes nothing.
- **The check:** `supabase/checks/prod-owner.sql`, a read-only check, confirms the result.
- **Tests:** both scripts are tested on a local database set up like feedbox-prod, in every right and wrong state the task names, and more. All 80 expectations of `npm run test:checks` are met, on the Mac and in CI (job `db`).
- **Database:** I ran nothing against a hosted database.

## The two scripts

| File | Lines | First line | Last line | What it does |
|---|---|---|---|---|
| `supabase/production/owner-nik.sql` | 171 | `-- supabase/production/owner-nik.sql \| 171 lines \| last line: -- end of owner-nik.sql` | `-- end of owner-nik.sql` | **Changes** the database: one do-block (all or nothing) that inserts one row into `public.board_owners` (board "feedbox", the one person). It refuses, changing nothing, unless: (1) the project marker says `feedbox-prod`; (2) the Feedbox v1 migration fingerprint is `160138805f7dcd5baa26b543b24aede3`; (3) the board "feedbox" exists; (4) there is exactly one person, named "Nikolaj Ivancic"; (5) that person is not an owner yet. A double paste is refused: "this script was pasted twice into one query. Nothing was changed". |
| `supabase/checks/prod-owner.sql` | 181 | `-- supabase/checks/prod-owner.sql \| 181 lines \| last line: -- end of prod-owner.sql` | `-- end of prod-owner.sql` | **Reads only**: one SELECT, 6 rows. Row 0 is the overall PASS or FAIL. Rows 1 to 5: project marker feedbox-prod; migration unchanged; board "feedbox" exists; exactly one owner; that owner is named "Nikolaj Ivancic". |

- **Pinned links** (head `2412bac4d6e2fe4965cd8bfb630a391fb89f020a`):
  - https://raw.githubusercontent.com/adriatic/triad-feedbox/2412bac4d6e2fe4965cd8bfb630a391fb89f020a/supabase/production/owner-nik.sql
  - https://raw.githubusercontent.com/adriatic/triad-feedbox/2412bac4d6e2fe4965cd8bfb630a391fb89f020a/supabase/checks/prod-owner.sql
- **The fingerprint:** `owner-nik.sql` computes the migration fingerprint with the block that every check script shares, copied word for word. A new unit test in `tests/sql-files.test.ts` keeps it identical.
- **Stricter than `board-feedbox.sql`:** unlike that script, `owner-nik.sql` does not accept the marker `local`. The tests set the local database's marker to `feedbox-prod` instead, the same way section B already does.

## Local results (`npm run test:checks`, section F, and the new lines in section A)

The local database is walked through the real states, ending as feedbox-prod with its board. Each refusal is also checked to have changed nothing (the same counts before and after). All 80 expectations were met.

| State | Script | Result |
|---|---|---|
| Lumen preview (marker feedbox-preview) | prod-owner.sql | FAIL (as expected): row 1, project |
| Lumen preview (marker feedbox-preview) | owner-nik.sql | refused: "this project is marked feedbox-preview … Nothing was changed." |
| feedbox-prod with its board, no person | prod-owner.sql | FAIL: "the board "feedbox" has 0 owners (expected exactly 1)" |
| same | owner-nik.sql | refused: "this project has no person yet. Sign in once on https://triad-feedbox-delta.vercel.app and set your display name first. Nothing was changed." |
| one person, no display name yet | owner-nik.sql | refused: "the one person in this project has the display name (none yet), not "Nikolaj Ivancic". Nothing was changed." |
| one person "Nikolaj Ivancic", marker changed to feedbox-preview | owner-nik.sql | refused: "this project is marked feedbox-preview. This script is only for feedbox-prod. …" |
| same, with a changed grant (migration no longer as reviewed) | owner-nik.sql | refused: "the database does not match the reviewed Feedbox v1 migration (fingerprint b7e8194c…, expected 16013880…)" |
| same, with no board | owner-nik.sql | refused: "this project has no board "feedbox" …" |
| two people | owner-nik.sql | refused: "this project has 2 people, so this script cannot tell which one is Nik (it expects exactly one)." |
| one person with another name | owner-nik.sql | refused: "… has the display name "Someone Else", not "Nikolaj Ivancic"." |
| one person "Nikolaj Ivancic", script pasted twice into one query | owner-nik.sql ×2 | refused: "this script was pasted twice into one query. Nothing was changed: the whole query is undone. …" |
| same, before the owner is added | prod-owner.sql | FAIL: 0 owners |
| same | owner-nik.sql | **success** |
| after the owner script | prod-owner.sql | **PASS: all 5 checks passed.** |
| owner renamed "Someone Else" | prod-owner.sql | FAIL: "the owner … is named "Someone Else" (expected "Nikolaj Ivancic")" |
| a second person added as a second owner | prod-owner.sql | FAIL: "2 owners (expected exactly 1)" |
| owner row removed | prod-owner.sql | FAIL: 0 owners |
| marker changed to feedbox-preview | prod-owner.sql | FAIL: row 1, project |
| a changed grant | prod-owner.sql | FAIL: row 2, migration |
| after the owner script | prod-board.sql (from M3) | PASS (still) |
| after the owner script, run again | owner-nik.sql | refused: ""Nikolaj Ivancic" is already an owner of the board "feedbox" (since …). This script has run before, or was pasted twice into one query. Nothing was changed by this copy." |

Also, locally:
- `npm run lint` and `npm run typecheck` are clean.
- `npm test`: 118 passed. This includes the header and footer of both new files, the check being one read-only SELECT with no `$`, its shared blocks, and the new fingerprint test.

## CI

- **Runs at `2412bac4d6e2fe4965cd8bfb630a391fb89f020a`:** 44118962993 (push) and 44118998626 (pull request) both succeeded. The `db` job of each run printed every line above and "SQL checks: all 80 expectations met."

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass (56 s) | pass (1 m 6 s) |
  | typecheck | pass (1 m 10 s) | pass (1 m 6 s) |
  | unit | pass (48 s) | pass (1 m 8 s) |
  | db | pass (1 m 45 s) | pass (1 m 48 s) |
  | e2e | pass (2 m 10 s) | pass (2 m 29 s) |
  | Vercel | pass | pass |

- **Other files changed:**
  - `scripts/test-sql-checks.sh`: section F, a `person` helper, and `board_owners` added to the counts a refusal must leave unchanged;
  - `tests/sql-files.test.ts`: the two new files and the fingerprint test.
- **Not changed:** the migration, and every script you have already run.

## Steps for Nik

**O1-1 and O1-2 prepare. O1-3 and O1-4 (the SQL) wait for Claude.ai's go-ahead in the TRIAD chat; do not run them before.**

**O1-1** On the Mac, in Chrome, open a new tab (cmd+T) and go to https://supabase.com/dashboard. Choose the organisation **TRIAD**, then the project **feedbox-prod**. Expected: the project selector at the top of the page says **feedbox-prod**, and the address bar contains `imlitxtkpvrcmijgdsrw` and does NOT contain `qrbeiveyomidfafivuta`. If either is not so, stop: you are not in feedbox-prod. Choose the project again, or send a screenshot to Claude.ai. Nothing has been changed.
Result

**O1-2** On the Mac, in the same Chrome tab, with **feedbox-prod** shown at the top of the page, click **SQL Editor** in the left menu. At the top of the SQL Editor, click each "Untitled query" tab: its orange dot turns into an ×. Click the ×, which deletes that query. Repeat until no query tab is left. Expected: no query tab is left in the SQL Editor.
Result

**O1-3 (waits for Claude.ai's go-ahead; CHANGES the database: one row)** On the Mac, in Chrome, open a new tab (cmd+T) and open this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/2412bac4d6e2fe4965cd8bfb630a391fb89f020a/supabase/production/owner-nik.sql
Click into the page, press cmd+A, then cmd+C. Go back to the Supabase tab, check that the top of the page says **feedbox-prod**, click **+ New query**, click into the empty editor and press cmd+V. Before clicking Run, check: the first line is `-- supabase/production/owner-nik.sql | 171 lines | last line: -- end of owner-nik.sql`, and when you scroll to the end, the last line with text is `-- end of owner-nik.sql` at line 171 (one empty line after it is fine). If either does not match, close that query tab with its × and paste again. Then click **Run**. Expected: **"Success. No rows returned."** If it says "Refused: …", stop: nothing was changed, as the message says; copy the message and send it to Claude.ai. If any other error appears, stop and do not run it again: nothing was changed, because the script is all or nothing; send the whole message to Claude.ai.
Result

**O1-4 (waits for Claude.ai's go-ahead; read-only: must PASS)** On the Mac, in Chrome, open a new tab (cmd+T) and open this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/2412bac4d6e2fe4965cd8bfb630a391fb89f020a/supabase/checks/prod-owner.sql
Click into the page, press cmd+A, then cmd+C. Go back to the Supabase tab, check that the top of the page says **feedbox-prod**, click **+ New query**, click into the empty editor and press cmd+V. Before clicking Run, check: the first line is `-- supabase/checks/prod-owner.sql | 181 lines | last line: -- end of prod-owner.sql`, and the last line with text is `-- end of prod-owner.sql` at line 181. If either does not match, close that query tab with its × and paste again. Then click **Run**. Expected: 6 rows; row 0 says **"PASS: all 5 checks passed."**, and row 5 (owner is Nik) says PASS. If row 0 says FAIL, stop: this check changed nothing, but O1-3 did add the owner row; send all rows to Claude.ai and change nothing on your own.
Result

**O1-5** On the Mac, in Chrome, open a new tab (cmd+T), type https://triad-feedbox-delta.vercel.app in the address bar and press Return. Click **Sign in**, type your own email address in **Email** and click **Send me a link**. Expected: the heading "Check your email".
Result

**O1-6** On the Mac, in Mac Mail or in Gmail, find the new email from **Feedbox <feedbox@pactresearch.net>** with the subject **Your Feedbox sign-in link** (without "first": you already exist on Production). Control-click the link **Sign in to Feedbox** and choose **Copy Link** (Mac Mail) or **Copy link address** (Gmail). Go back to the Chrome tab from O1-5, click the address bar, press cmd+V and press Return. Expected: the address starts with https://triad-feedbox-delta.vercel.app/auth/confirm?next= and the page shows the button **Finish signing in**.
Result

**O1-7** On the Mac, in the same Chrome tab, click **Finish signing in**. Expected: the board page "Feedbox" (your name is not asked again), and the top of the page says **"Signed in as owner"**.
Result

**O1-8** On the Mac, in the same Chrome tab, click **Sign out** at the top of the page, then press cmd+R. Expected: the top of the page says "Viewing as visitor" with a "Sign in" link.
Result

**O1-9** On the Mac, in the Notes app, click the note where you wrote the Results of O1-1 to O1-8 (with the screenshots of O1-3 and O1-4). Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "O1 results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

About these steps:
- **The script relies on there being exactly one person on feedbox-prod.** Production is public and new sign-ups are allowed, so if anyone else signs in before O1-3, the script refuses ("this project has 2 people …") and changes nothing. See O1-D1.
- **Not checked by me:** the Supabase and Notes labels and the chat's + button.

## Decisions for Nik

**O1-D1: if a second person signs in on Production before O1-3. Your decision.**
- **What happens:** the script refuses and changes nothing. Making you the owner then needs a script that identifies you another way.
- **The other way:** for example by the time of your first sign-in (2026-11-17), or with your email typed into the SQL Editor by you, never committed.
- **My recommendation:**
  - run O1-3 and O1-4 soon after Claude.ai's go-ahead, while you are the only person;
  - write the other script only if the refusal actually happens.

**O1-D2: merging pull request #5. Your decision.**
- **The order:** the steps run the scripts from links pinned to the head `2412bac4d6e2fe4965cd8bfb630a391fb89f020a`, before the merge, so the merge can include the evidence of your run.
- **My recommendation:** say "merge" for #5 after O1-4 passes and Claude.ai has read your PDF. A merge task M6 then squash-merges it.

**Still open:**
- **M5-D2:** the readiness script and CLAUDE.md naming `e2e` as required.
- **F4d-D1:** the local sender.
- **F4h-D1:** feedbox-prod's minimum interval per user.
- **F4h-D2:** the local OTP length.

My recommendations there are unchanged.
