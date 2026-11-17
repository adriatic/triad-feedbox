# Task C1: cleanup after F4 and O1 (four small leftovers)

Date: 2026-11-17. Branch `c1-cleanup` from `main` at `33cff75` (tag `o1`). Pull request **#6**: https://github.com/adriatic/triad-feedbox/pull/6. Head **`27da8794765af542dee3faf95cd65c86e78e7d11`**. Not merged.

## In short

- **Done:** all four items from your decision of 2026-11-17 8:45 AM.
- **Untouched:** no hosted project, and no SQL file.
- **Tests:** CI is green. Locally, 119 unit tests, 5 e2e tests and 80 SQL expectations pass.
- **The readiness check:** its "Required checks" line passes with the new expectation of six checks. The only failure was that the Claude desktop app was not running on the Mac when I ran it.

## What changed, per item

**1. M5-D2: `e2e` is a required check everywhere**
- **The script:** `scripts/triad-ready.sh` now expects `lint typecheck unit db e2e Vercel`, on line 64 and in the header line that documents `TRIAD_REQUIRED_CHECKS`. The comment of check 14 now says "the ruleset since M5".
- **CLAUDE.md:**
  - "Branches, pull requests and merging", rule 2: "requires six status checks: `lint`, `typecheck`, `unit`, `db`, `e2e` and `Vercel`", with when each was added (M2, M3, M5);
  - rule 5: `e2e` is "a required check since M5" (it said "not yet a required check"), and all five CI checks plus `Vercel` are required on `main`;
  - "Is TRIAD ready?": "`main` requires the six checks `lint`, `typecheck`, `unit`, `db`, `e2e` and `Vercel`".
- **Nothing else** in the repository still said that `e2e` is not required. README.md names no list of required checks.
- **Unit tests:** the script's unit tests (`tests/triad-ready.test.ts`) still pass unchanged.
- **The difference this makes:** the script would now FAIL "Required checks" if `e2e` were removed from the ruleset.

**2. F4d-D1: local emails come from Feedbox <feedbox@pactresearch.net>**
- **The config:** `supabase/config.toml`, block `[local_smtp]`: `admin_email = "feedbox@pactresearch.net"` and `sender_name = "Feedbox"`. Mailpit still catches every email; nothing is sent.
- **The e2e check:** the helper that reads each email from Mailpit (used by all four form sign-in tests) now checks that the sender is exactly `Feedbox <feedbox@pactresearch.net>`.
- **Proven locally:** the last three emails Mailpit caught all came from `{Name: Feedbox, Address: feedbox@pactresearch.net}`.
- **Unit test:** `tests/email-templates.test.ts` checks the two config lines.

**3. F4h-D2: OTP length 8 locally; 1 second kept on purpose**
- **OTP length:** `supabase/config.toml`, `[auth.email]`: `otp_length = 8`, as on the hosted projects. The MFA phone section's own `otp_length = 6` is left alone. `tests/email-templates.test.ts` checks the email one.
- **`max_frequency`:** stays `"1s"`, with a comment saying why.
- **CLAUDE.md "Dashboard settings":** a new table, "Local Supabase (`supabase/config.toml`) against these settings".
  - **Mirrored:** the templates and subjects, Confirm email, OTP expiration 900, OTP length 8, and the sender.
  - **Different on purpose:**
    - sending: Mailpit, not Resend;
    - the email rate limit: 60 per hour, not 30;
    - the minimum interval per user: 1 second, not 60, because the e2e tests send two sign-in emails to one address within seconds;
    - the Redirect URLs: locally also 127.0.0.1, for Playwright.

**4. F4h-D1: feedbox-prod's minimum interval per user**
- **CLAUDE.md "Dashboard settings":** the row now reads 60 seconds for feedbox-prod too: "Nik, 2026-11-17 8:47 AM (screenshot of the Rate Limits page, opened from feedbox-prod's address; the page itself does not show the project name)".
- **No gap left:** the table has no cell left that says "not in the screenshot".

## The readiness check (run by me, on the branch, after the push)

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
FAIL Claude desktop app: not running, so Claude.ai cannot reach the files on this Mac. Open the Claude app from the Dock (or Finder, Applications, Claude) and leave it open.
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch c1-cleanup.
PASS Git working tree: clean; last commit 27da879 C1: cleanup after F4 and O1 (e2e required, local sender, OTP length, prod interval). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 131 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 48708e0).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit 33cff75, 2026-11-17T16:34:56Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
NOT READY: 1 of 19 checks failed.
```

- **Required checks:** PASS with the new expectation of six checks.
- **The one FAIL:** the Claude desktop app was not running on the Mac at that moment. It is not related to this change; your step C1-1 opens it.

## Results

- **Locally:**
  - `npm run lint` and `npm run typecheck`: clean.
  - `npm test`: 119 passed.
  - `npm run test:e2e`: 5 passed, on a freshly restarted local stack with the new config.
  - `npm run test:checks`: all 80 expectations met.
- **CI at `27da879`:** runs 44130657973 (push) and 44130671509 (pull request) both succeeded.

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass (42 s) | pass (55 s) |
  | typecheck | pass (1 m 12 s) | pass (1 m 0 s) |
  | unit | pass (1 m 3 s) | pass (1 m 2 s) |
  | db | pass (1 m 49 s) | pass (1 m 44 s) |
  | e2e | pass (2 m 4 s) | pass (2 m 9 s) |
  | Vercel | pass | pass |

- **Vercel status of `27da879`:** success. Deployment: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/BAzkf7cmJg3KmHQhnVTHD5nWxfcz
- **Pull request:** #6, https://github.com/adriatic/triad-feedbox/pull/6, head `27da8794765af542dee3faf95cd65c86e78e7d11`. **Not merged.**
- **Files:** `scripts/triad-ready.sh`, `CLAUDE.md`, `supabase/config.toml`, `e2e/auth.spec.ts`, `tests/email-templates.test.ts`.

## Steps for Nik

**C1-1** On the Mac, open the Claude desktop app from the Dock (or Finder, Applications, Claude) and leave it open. Expected: the Claude app window is open.
Result

**C1-2** On the Mac, in the Terminal app, open a new tab (cmd+T), type `colima start` and press Return. Wait until the prompt comes back (up to about a minute). Expected: the last line says colima is running, or that it is already running.
Result

**C1-3** On the Mac, in the Terminal app, open another new tab (cmd+T), type this line and press Return:
/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
Expected: 19 lines starting with PASS, including "PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.", and as the last line exactly: READY: all 19 checks passed. If any line says FAIL, copy the whole output into the note; that line says what to do.
Result

**C1-4** On the Mac, in the Notes app, click the note where you wrote the Results of C1-1 to C1-3 (with the Terminal output of C1-3). Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "C1 results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

## Decisions for Nik

**C1-D1: merge pull request #6. Your decision.**
- **What it holds:** only docs, the readiness script's expected list, local Supabase settings and tests. Nothing changes on any hosted project or in Production's behaviour.
- **My recommendation:** say "merge" for #6 after your C1-3 shows READY. A merge task M7 then squash-merges it.

No other decision is open from F4, O1 or this task.
