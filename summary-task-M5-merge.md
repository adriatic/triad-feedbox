# Task M5: merge F4 (pull request #4, sign-in by email link)

Date: 2026-11-16 (merged at 9:42 PM Pacific, 2026-11-17 05:42:56 UTC).

## In short

- **Merged:** pull request #4 was squash-merged at the approved head `85780446079627bc3c5404bc33cf94d687910631`. The merge commit on `main` is **`08067e74dac569b9bb01e165a3e05809da8d15ad`**. The branch `f4-auth` is deleted, and the tag `f4` is pushed.
- **Ruleset:** `main` now requires **`e2e`** too (decision F4-D1). Its other rules are unchanged.
- **Production:** it deployed `main` with status success. https://triad-feedbox-delta.vercel.app answers HTTP 200 with the Feedbox board page.
- **The readiness check:** 17 PASS and 2 FAIL. The two failures are the Mac's state at the time: the Claude desktop app and Docker were not running. Neither is about the merge. Output below.
- **Database:** I ran nothing against a hosted database.

## Steps for Nik

These steps sign in on **Production** for the first time. feedbox-prod has no person yet, so this is a first sign-in. Production is public: no Vercel sign-in is needed.

**M5-1** On the Mac, in Chrome, open a new tab (cmd+T), type this address in the address bar and press Return:
https://triad-feedbox-delta.vercel.app
Expected: a plain, unstyled page with the heading "Feedbox", the line "What should Feedbox do next?", and near the top the words "Viewing as visitor" followed by a "Sign in" link.
Result

**M5-2** On the Mac, in the same Chrome tab, click **Sign in** at the top of the page. In the field **Email**, type your own email address. Click **Send me a link**. Expected: the heading changes to "Check your email", with the line "We sent a sign-in link to (your address). It works once and expires in 15 minutes."
Result

**M5-3** On the Mac, in Mac Mail or in Gmail, find the new email from **Feedbox <feedbox@pactresearch.net>** with the subject **Your first Feedbox sign-in link**. It usually arrives within a minute. If it is not in the inbox after 5 minutes, look in the Spam (Junk) folder. Its text starts "Sign in to Feedbox. This is your first sign-in, so this link also confirms your email address." Expected: the sender and subject are exactly as written here.
Result

**M5-4** On the Mac, in that email, Control-click the link **Sign in to Feedbox** and choose **Copy Link** (Mac Mail) or **Copy link address** (Gmail in Chrome). Do not click the link itself. Go back to the Chrome tab from M5-1, click the address bar, press cmd+V and press Return. Expected: the address starts with https://triad-feedbox-delta.vercel.app/auth/confirm?next= and contains `token_hash=`. The page shows the heading "Finish signing in" and a button **Finish signing in**. The top of the page still says "Viewing as visitor".
Result

**M5-5** On the Mac, in the same Chrome tab, click **Finish signing in**. Expected: a page "Welcome to Feedbox" with the field **Name shown with your ideas**, and the top of the page says "Signed in".
Result

**M5-6** On the Mac, in the same Chrome tab, type a display name of 2 to 40 characters in the field **Name shown with your ideas**, for example `Nik I.`, and click **Continue**. Expected: the board page "Feedbox" again.
Result

**M5-7** On the Mac, in the same Chrome tab, read the top of the page, then click **Changelog** at the top and read it again. Expected: both times it says "Signed in as" followed by the name you typed in M5-6 (not "Signed in as owner": you are not the board's owner yet), with a **Sign out** button next to it. The Changelog page shows the heading "Changelog".
Result

**M5-8** On the Mac, in the same Chrome tab, click **Sign out** at the top of the page. Expected: the board page "Feedbox", and the top of the page says "Viewing as visitor" with a "Sign in" link.
Result

**M5-9** On the Mac, in the same Chrome tab, press cmd+R to reload the page and read the top again. Expected: still "Viewing as visitor".
Result

**M5-10** On the Mac, in the Notes app, click the note where you wrote the Results of M5-1 to M5-9. Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "M5 results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

About these steps:
- **Not checked by me:**
  - that Production's email arrives from the Feedbox sender (only your inbox can show it);
  - the Changelog contents on Production (the feedbox board may have no releases yet);
  - the Notes menu names and the chat's + button.
- **What I did check:** as a visitor, Production shows "Feedbox", "What should Feedbox do next?", "Viewing as visitor" and "Sign in".

## Merge

- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/4, state MERGED at 2026-11-17T05:42:56Z.
- **Head before the merge:** `origin/f4-auth` was exactly `85780446079627bc3c5404bc33cf94d687910631`, as approved. The merge used `--match-head-commit` with that hash.
- **Approval line:** the description now starts with "Approved by Nik on 2026-11-16 at 9:41 PM (recorded in the TRIAD tracker)." The rest of the description is unchanged.
- **Merge commit:** `08067e74dac569b9bb01e165a3e05809da8d15ad`, "F4: sign-in by email link, and every route as a bare page (#4)", parent `cea809f` (tag `t1`).
- **Byte-for-byte:** the merge commit's tree is `3ab7b36c393fd82393e03a6f8f50bc9036af05d3`, the same tree object as at `8578044`. `git diff 8578044 08067e7` is empty. So every file at the merge commit is byte for byte the file at the approved head.
- **Branch:** `f4-auth` is deleted on GitHub (`git ls-remote` finds no such branch) and on the Mac.
- **Tag:** `f4` is an annotated tag ("F4: sign-in by email link (PR #4)"), object `5247f94aaa951c2286b74eeae185ca43b6bdf116`, pointing to `08067e7`. It is pushed.
- **Local folder:** on `main` at `08067e7`, even with `origin/main`, clean.

## Checks

- **Before the merge, at `8578044`:** runs 44024616757 (push) and 44024621856 (pull request).

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |
  | Vercel | pass | pass |

- **After the merge, at `08067e7`:**
  - CI run 44026030349 (push to `main`): success, with lint, typecheck, unit, db and e2e all success.
  - CI run 44026054134 (the push of tag `f4`, same commit): success.
  - Vercel status: success.

## Ruleset "main" as it now stands

The change was made with `gh api -X PUT repos/adriatic/triad-feedbox/rulesets/27181565`. gh was allowed to make it.

| | |
|---|---|
| Ruleset | `main` (ID 27181565), enforcement **active**, target the default branch, no bypass actors |
| Restrict deletions | yes |
| Block force pushes | yes |
| Require a pull request | yes, 0 approvals; merge, squash and rebase allowed |
| Required status checks | `lint`, `typecheck`, `unit`, `db`, **`e2e` (new)** from GitHub Actions; `Vercel` |

The other rules, the conditions and the bypass list compare equal to the ruleset before the change.

## Production

- **Deployment:** Vercel's status on `08067e7` is `success`, "Deployment has completed": https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/2BZn8YiwWQDH3BN7f9NGKvZkpFjS
- **The page:** https://triad-feedbox-delta.vercel.app answers HTTP 200. It is the Feedbox board page, not the placeholder:
  - the title is "Feedbox", and the header reads "Feedbox · Changelog · Post an idea";
  - "Viewing as visitor" and "Sign in";
  - the heading "Feedbox" and the line "What should Feedbox do next?".

## The readiness check (step 7)

I ran `/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh` after the merge. It ended with exit code 1:

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
FAIL Claude desktop app: not running, so Claude.ai cannot reach the files on this Mac. Open the Claude app from the Dock (or Finder, Applications, Claude) and leave it open.
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit 08067e7 F4: sign-in by email link, and every route as a bare page (#4). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 128 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit d804c7f).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit 08067e7, 2026-11-17T05:42:59Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
NOT READY: 2 of 19 checks failed.
```

- **The two failures:** the Claude desktop app and Docker (colima) were not running on the Mac when it ran. Neither affects the merge. Each line says what to do.
- **"Required checks" (a follow-up):** this line already shows `e2e`, because it prints what the ruleset requires. But the script expects only `lint typecheck unit db Vercel` (`scripts/triad-ready.sh` line 64), so it would still pass if `e2e` were removed again. See M5-D2.

## Decisions for Nik

**M5-D1: make yourself the owner of the Feedbox board on Production. Your decision.**
- **What it is:** the next database step, after your first sign-in on Production (M5-1 to M5-9). Until then, the header says "Signed in as <name>", not "Signed in as owner", and `/changelog/new` is closed to you.
- **How:** following "SQL is code": a reviewed changing script in `supabase/production/`, plus a check script. Both are tested locally, read line by line by Claude.ai, and run by you on feedbox-prod from a pinned link. I did not write it in this task.
- **My recommendation:** yes, as the next task, right after your M5 steps. Your person must exist on Production before the script can name it.

**M5-D2: bring the readiness script and CLAUDE.md up to date with the new ruleset. Your decision.**
- **The change:**
  - set the script's expected list (line 64) to `lint typecheck unit db e2e Vercel`;
  - in CLAUDE.md, change "Branches, pull requests and merging", rule 2, to name the six required checks;
  - rule 5 and "Is TRIAD ready?" still say `e2e` is not yet required, or list only five checks.
- **My recommendation:** yes, in one small task (scripts and docs; the unit tests for the script stay as they are).

**Still open from F4:**
- **F4d-D1:** the local sender name and address.
- **F4h-D1:** feedbox-prod's minimum interval per user.
- **F4h-D2:** the local OTP length.

My recommendations there are unchanged.
