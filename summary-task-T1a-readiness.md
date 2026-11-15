# Task T1a: readiness check, follow-up to T1

2026-11-15 · Claude Code · branch `t1-readiness` · pull request #3 · new head `ca8059e47fc9b90af5620acff4cb7594006b602f` (was `9333ab4`)

`scripts/triad-ready.sh` now runs 19 checks. The new check "Supabase feedbox-prod" asks the project's public address with no key, exactly like the check for feedbox-preview. Seven PASS messages that said more than the script checks now say only what was checked. A real run on this Mac at the new head gave `READY: all 19 checks passed.`. CI is green. Nothing touched a database. Nothing was merged.

## Steps for Nik

**T1a-1** On the Mac, in Terminal, open a new tab: click **Shell**, then **New Tab** (or press cmd+T). Do not type in the tab where Claude Code runs. Expected: a new tab with a plain prompt ending in `%`, and no Claude Code welcome box.
Result

**T1a-2** On the Mac, in the new Terminal tab from T1a-1, type this line exactly and press Return:
`/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh`
Expected: within about 10 seconds, 19 lines that each start with PASS or FAIL, then one last line. The second-to-last check line starts with `PASS Supabase feedbox-preview` and the last check line starts with `PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401`.
Result

**T1a-3** On the Mac, in the same Terminal tab, read the last line printed by T1a-2 and compare it with `READY: all 19 checks passed.`
- If it matches, TRIAD is ready.
- If it says `NOT READY: 1 of 19 checks failed.` and the only FAIL line is the Docker line, type `colima start`, press Return, wait for the prompt to come back (about a minute), and run the line from T1a-2 again. Expected then: `READY: all 19 checks passed.`
- For any other FAIL, copy all the lines into the TRIAD chat.
Result

**T1a-4** On the Mac, in the Notes app, click the note where you wrote the Results of T1a-1 to T1a-3. Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "T1a results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

I took the menu names in T1a-4 (File, Export as PDF…, and the + button in the chat) from how Notes and Claude.ai look in general. I could not check them on this Mac.

## What changed (commit `ca8059e` on pull request #3)

### 1. New check: Supabase feedbox-prod (T1-D1)

- **Project ID:** `imlitxtkpvrcmijgdsrw`. I read it from `/Users/nikolajivancic/Obsidian/pact-web/TRIAD/Important URLs.md`, section Supabase: "feedbox-prod: its project ID imlitxtkpvrcmijgdsrw appears in the address bar (from Nik, 2026-11-15 2:48 PM)". It is the same ID as in the task.
- **What it asks:** `https://imlitxtkpvrcmijgdsrw.supabase.co/auth/v1/health` with no key. PASS needs HTTP 401 with "No API key found in request".
- **Place:** check 19, after Supabase feedbox-preview (check 18).
- **One function for both projects:** the two Supabase checks now share the function `supabase_check`, so the preview and prod checks cannot drift apart.
- **New test overrides** (described in the script's header): `TRIAD_PROD_REF` (project ID) and `TRIAD_PROD_SUPABASE_URL` (the address asked, the same as `TRIAD_PREVIEW_URL` for preview).
- **No key on the Mac:** none was read, and none is sent.

### 2. Docker (T1-D2)

No change: a stopped Docker is still a FAIL.

### 3. Messages that now say only what was checked

I went through all the PASS and FAIL messages. These seven PASS messages claimed more than the script checks, and were changed:

| Check | Old | New |
|---|---|---|
| Claude desktop app | running. Claude.ai can reach the reports folder and the Obsidian notes. | running (this check cannot see whether its link to Claude.ai works). |
| Reports folder | … exists and can be written to; it holds feedbox-inputs and N summary-task reports. | … exists and has write permission (nothing was written); it holds feedbox-inputs and N summary-task reports. |
| Docker | running (Docker X); the local database tests can run. | running (Docker X). The local database itself is not looked at. |
| git over SSH | the project folder can read branch main from GitHub over SSH, the way Claude Code pushes. | the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried). |
| Vercel Production | https://triad-feedbox-delta.vercel.app answers (HTTP 200, page Feedbox). | https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox. |
| Vercel build of main | Vercel built the latest commit on main successfully. | Vercel's status on the latest commit of main is success. |
| Supabase feedbox-preview | project qrbeiveyomidfafivuta answers (it asks for a key, as expected; none is sent). | the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at). |

The two FAIL messages of Supabase feedbox-preview changed only in their first words: "project X does not answer" is now "the address of project X does not answer", and "project X answered HTTP …" is now "the address of project X answered HTTP …". Each Supabase FAIL message now names its own project (feedbox-preview or feedbox-prod) in "check that … is not paused".

**Messages kept, and why:**
- **FAIL Claude desktop app** ("not running, so Claude.ai cannot reach the files on this Mac") and **FAIL Reports branch** ("… so Claude.ai cannot read the reports there"): each states what was found, then the consequence that the setup note documents. They claim nothing about what was checked.
- **All other messages:** each says only what the script looked at.

### 4. Counts, tests and documents

- **`tests/triad-ready.test.ts`:** a new test, "has 19 checks, among them both Supabase projects". It counts the distinct check names in the script (19) and pins both project IDs. `unit` now has 106 tests.
- **`CLAUDE.md`:** "The 19 checks, in order: …" now includes feedbox-prod and the source of the project IDs. The Vercel build check is reworded to match its message. The section now says to update the count of checks in the script, CLAUDE.md, README.md and the test.
- **`README.md`:** "runs 19 checks", "the two Supabase projects (feedbox-preview and feedbox-prod, asked with no key)", and the last lines `READY: all 19 checks passed.` / `NOT READY: K of 19 checks failed.`
- **Any other "18":** none was left. The T1 version wrote no count in CLAUDE.md or README.md, and the script counts its checks as it runs.

### 5. One fix found while testing

My first try at the FAIL runs below went wrong: the overrides were passed from zsh and arrived as one value, so `TRIAD_TIMEOUT` became "3 TRIAD_PROD_REF=…". The run printed `NOT READY: 12 of 19`, because the time limit no longer worked. The script now uses 10 seconds when `TRIAD_TIMEOUT` is not a whole number; with `TRIAD_TIMEOUT="3 x"` the result is `READY: all 19 checks passed.`. That run is not used in this report. The FAIL runs below were made from bash.

## Real run on this Mac

The run used the full command and no overrides, at `ca8059e`. Docker was running (colima had been started since T1).

```
$ /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.325.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch t1-readiness.
PASS Git working tree: clean; last commit ca8059e T1a: readiness check for feedbox-prod; messages say only what was checked. Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 121 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 4fa3105).
PASS Required checks: branch main requires lint typecheck unit db Vercel before a merge.
PASS CI on main: the latest CI run passed (commit 17bc04c, 2026-11-15T01:08:58Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
exit=0
```

## FAIL runs for the new check

Only the FAIL lines and the last line are shown.
- **First run:** `TRIAD_PROD_REF` points at a project that does not exist, which shows the "does not answer" message.
- **Second run:** `TRIAD_PROD_SUPABASE_URL` points at the Vercel site, which answers 200 instead of 401.

```
$ TRIAD_PROD_REF=nosuchprojectrefxxxx /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
FAIL Supabase feedbox-prod: the address of project nosuchprojectrefxxxx does not answer (no network, wrong project ID, or Supabase down). Check https://status.supabase.com and the Supabase dashboard, then tell Claude.ai.
NOT READY: 1 of 19 checks failed.
exit=1

$ TRIAD_PROD_SUPABASE_URL=https://triad-feedbox-delta.vercel.app /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
FAIL Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answered HTTP 200, not the expected 401. Open the Supabase dashboard in Chrome and check that feedbox-prod is not paused; tell Claude.ai.
NOT READY: 1 of 19 checks failed.
exit=1
```

## CI results (pull request #3, head `ca8059e`)

| Check | Result |
|---|---|
| lint | pass (22 s; 20 s) |
| typecheck | pass (17 s; 19 s) |
| unit | pass (27 s; 18 s), 106 tests |
| db | pass (54 s; 52 s) |
| Vercel | pass (Preview deployment completed) |
| Vercel Preview Comments | pass |

These are GitHub Actions runs 43771736820 and 43771741200 (one started by the branch push, one by the pull request). Locally, `npm run lint`, `npm run typecheck` and `npm test` (106 tests) passed too.

## Links and hashes

- Pull request: https://github.com/adriatic/triad-feedbox/pull/3. New head `ca8059e47fc9b90af5620acff4cb7594006b602f`, on top of `9333ab44405cc25261d0ef31049918cba629d759`. Base `main` at `17bc04c` (tag `f3`).
- Script at the head: https://github.com/adriatic/triad-feedbox/blob/ca8059e47fc9b90af5620acff4cb7594006b602f/scripts/triad-ready.sh
- Not merged. The local project folder stays on `t1-readiness` (clean), so that the command in T1a-2 finds the script.

## Decisions for Nik

None. T1-D1 and T1-D2 are done as Claude.ai decided, and nothing new came up.
