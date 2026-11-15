# Task T1: TRIAD readiness check

2026-11-15 · Claude Code · branch `t1-readiness` · pull request #3 · head `9333ab44405cc25261d0ef31049918cba629d759`

`scripts/triad-ready.sh` is one read-only command that checks, line by line, whether TRIAD is ready on the Mac. It runs 18 checks, prints one PASS or FAIL line for each, and ends with `READY: all 18 checks passed.` or `NOT READY: K of 18 checks failed.` Every FAIL line says what to do. A real run on this Mac took about 5 seconds and found one real FAIL: Docker is not running (colima is stopped), which I left as it was. CI is green on pull request #3. Nothing touched a database. Nothing was merged.

## Decisions Nik must make

- **T1-D1: Should the script check feedbox-prod too?** At the moment it checks only feedbox-preview. The feedbox-prod project ID is not written down anywhere on this Mac. "Important URLs.md" names only the preview ID (qrbeiveyomidfafivuta), and the CLAUDE.md files and reports hold no Feedbox prod ID. The project ID is not a secret: it is in the dashboard address and, once the app uses Supabase, in every page's code. So the check would be safe. To add it, Nik copies the feedbox-prod ID from the address bar of its dashboard into "Important URLs.md", and a later task adds the check (the same keyless test as preview). Recommended: yes. I did not guess the ID.
- **T1-D2: Should Docker count towards READY?** At the moment a stopped Docker makes the result NOT READY. Docker is needed only for Claude Code's local database tests, and CI runs those tests anyway. The two options:
  - (a) keep it a FAIL. Recommended: `colima start` takes about a minute, and a stopped Docker breaks `npm run test:db` and `npm run test:checks` in the middle of a task.
  - (b) make it information only, always PASS.

## Steps for Nik

**T1-1** On the Mac, in Terminal, open a new tab: click **Shell**, then **New Tab** (or press cmd+T). Do not type in the tab where Claude Code runs. Expected: a new tab with a plain prompt ending in `%`, and no Claude Code welcome box.
Result

**T1-2** On the Mac, in the new Terminal tab from T1-1, type this line exactly and press Return:
`/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh`
Expected: within about 10 seconds, 18 lines that each start with PASS or FAIL, then one last line. The "Project folder" line says the folder is on branch t1-readiness. The script exists only on this branch until pull request #3 is merged, so the folder stays on this branch until then.
Result

**T1-3** On the Mac, in the same Terminal tab, read the last line printed by T1-2 and compare it with `READY: all 18 checks passed.`
- If it matches, TRIAD is ready.
- If it says `NOT READY: 1 of 18 checks failed.` and the only FAIL line is the Docker line, type `colima start`, press Return, wait for the prompt to come back (about a minute), and run the line from T1-2 again.
- For any other FAIL, do what that line says, or copy all the lines into the TRIAD chat.
Result

## Every check

Checks marked "extra" are additions to the list in the task; the source of each is given in its row. Every FAIL line also gives what was found, such as the folder or address and the version or HTTP code.

| # | Check name | What it looks at | What a FAIL says to do |
|---|---|---|---|
| 1 | macOS version | `sw_vers`. Information only, always PASS. | (never fails) |
| 2 | Claude desktop app | Whether `/Applications/Claude.app/Contents/MacOS/Claude` is running (`pgrep`). | "Open the Claude app from the Dock (or Finder, Applications, Claude) and leave it open." |
| 3 | Chrome | Whether `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` is running. | "Open Google Chrome from the Dock, then open the TRIAD chat and the tracker page." |
| 4 | Claude Code | `claude --version` (or `~/.local/bin/claude`); prints the version. | "Install Claude Code (https://claude.com/claude-code), then open a new Terminal tab and run this check again." |
| 5 | Node.js (extra: CLAUDE.md Commands, README "Needs Node 24") | `node --version` against the major version in `.nvmrc` (24). | Wrong version: "Tell Claude Code; it does not stop a session, but npm commands may behave differently." Missing: "Tell Claude Code: Node.js 24 is needed…" |
| 6 | Project folder | `/Users/nikolajivancic/Work/triad-feedbox` exists, is a git clone whose `origin` is `adriatic/triad-feedbox`; prints the branch. | Missing: "Tell Claude Code; do not create it by hand." Not a clone or the wrong clone: "Tell Claude Code; do not change the folder by hand." |
| 7 | Git working tree | `git status --porcelain` and the last commit. Information only, always PASS. | (never fails) |
| 8 | Reports folder | `/Users/nikolajivancic/CC reports and tasks` exists, can be written to, and holds `feedbox-inputs`; counts the summary-task reports. It is a plain folder, not a git clone (see "How the reports folder is set up"). | Missing: "Tell Claude Code and Claude.ai; do not create it by hand." Read-only, or no `feedbox-inputs`: "Tell Claude Code." |
| 9 | Obsidian vault | `/Users/nikolajivancic/Obsidian/pact-web` and `TRIAD/TRIAD setup.md` exist. | "Open Obsidian and check that the vault pact-web is synced; tell Claude.ai." |
| 10 | Docker | `docker info` (time-limited). | "In Terminal, type colima start and press Return (it takes about a minute), then run this check again." |
| 11 | GitHub sign-in | `env -u GH_TOKEN ~/gh-cli api user` and `api repos/adriatic/triad-feedbox` (the stored sign-in, as in CLAUDE.md). | Program missing: "Tell Claude Code." Cannot read the repository: "Check the network and https://www.githubstatus.com, then tell Claude Code. Do not sign in yourself." |
| 12 | git over SSH (extra: CLAUDE.md "Push over SSH") | `git ls-remote --heads origin main` in the project folder, with `BatchMode=yes` and a connect timeout. | "Check the network, then tell Claude Code." |
| 13 | Reports branch | The branch `cc-reports` exists on GitHub. | "Tell Claude Code." |
| 14 | Required checks (extra: CLAUDE.md "Branches, pull requests and merging", rule 2; ruleset since M3) | The rules on `main` require `lint`, `typecheck`, `unit`, `db` and `Vercel`. | Missing check: "Tell Claude.ai; the ruleset on main must be fixed in a task before the next merge." Unreadable: "Tell Claude Code." |
| 15 | CI on main | The latest run of workflow CI on `main`. | Failed: "Tell Claude.ai before starting a task." Still running: "Wait a few minutes and run this check again." None, or unreadable: "Tell Claude Code." |
| 16 | Vercel Production | `https://triad-feedbox-delta.vercel.app` answers HTTP 200 with "Feedbox" in the page. | Wrong answer: "Open it in Chrome; if it is broken, tell Claude.ai." No answer: "Check the network and https://www.vercel-status.com, then tell Claude.ai." |
| 17 | Vercel build of main (extra: CLAUDE.md merge task "confirm that the Production deployment of main succeeds") | The commit status "Vercel" on the latest commit of `main`. | Not success: "If it is pending, wait a few minutes; otherwise tell Claude.ai." Unreadable: "Tell Claude Code." |
| 18 | Supabase feedbox-preview | `https://qrbeiveyomidfafivuta.supabase.co/auth/v1/health` with **no key**. A project that is up answers 401 "No API key found in request". | Other answer: "Open the Supabase dashboard in Chrome and check that feedbox-preview is not paused; tell Claude.ai." No answer: "Check https://status.supabase.com and the Supabase dashboard, then tell Claude.ai." |

**When an earlier check fails.** If the project folder check (6) fails, check 12 is not run. If the GitHub sign-in check (11) fails, checks 13, 14, 15 and 17 are not run. Each check that is not run still counts as a FAIL, with the message "not checked, because the … check failed. Fix that first."

**Checks left out, and why:**
- **Supabase feedbox-prod:** its project ID is not on the Mac (see T1-D1).
- **Supabase with a key** (for example, whether the tables exist): a key is not needed to see that the project answers. CLAUDE.md rule 3 keeps keys off the Mac, and no `.env.local` exists in the project folder.
- **The TRIAD chat and the tracker open in Chrome:** reading Chrome's tabs needs AppleScript automation access. The first run would show a macOS permission prompt and change a privacy setting, so it would not be read-only.
- **The Claude desktop app actually connected to Claude.ai:** nothing on the Mac shows the state of that link without reading the app's private data or signing in. The script checks that the app is running, which was the cause on 2026-11-13.
- **Obsidian Sync state:** this is not shown outside the Obsidian app. The script checks that the vault and the TRIAD note are there.

## Why a bash script

- **Nothing to install:** macOS ships `/bin/bash` (version 3.2) and every program the script uses: `pgrep`, `curl`, `git`, `sw_vers`. All real runs used that bash.
- **Works when Node is broken:** it needs no `npm ci` and runs even when Node.js itself is the thing that is broken.
- **No new dependency:** `limited` (inside the script) gives every network call a time limit, so the script needs neither `timeout` nor `perl`.
- **Lines Nik can read:** each check is a few plain lines that can be read in review.

## How the reports folder is set up (looked at, not changed)

- **A plain folder:** `/Users/nikolajivancic/CC reports and tasks` is not a git clone (`git rev-parse` there reports "not a git repository").
- **It holds:** the summary-task reports (120 today), older pact-web files, and `feedbox-inputs`.
- **How a report reaches GitHub:** Claude Code writes each report there, then copies it into a temporary worktree of `cc-reports`, made from the project clone, commits it and pushes it.
- **What the check needs:** the folder exists, can be written to, and holds `feedbox-inputs`. The `cc-reports` branch is checked on GitHub (check 13).

## What changed (pull request #3)

- `scripts/triad-ready.sh` (new, executable). The test overrides (`TRIAD_*`) are described in its header.
- `tests/triad-ready.test.ts` (new, part of `unit`, 5 tests):
  - the script is valid bash and executable;
  - every `TRIAD_*` override is documented in the header;
  - GitHub is called only through `env -u GH_TOKEN`, with no token and no `.env` file;
  - no command starts, changes or signs in to anything, and `colima start` appears only inside the Docker FAIL message;
  - every `curl` is time-limited, and ssh has a connect timeout.
- `CLAUDE.md`: new section "Is TRIAD ready?" (before "Layout"); `scripts/` and `tests/` lines in "Layout" updated.
- `README.md`: new section "Is TRIAD ready?".

Nothing under `supabase/` changed. `npm run sql:headers` reports all pasted SQL files right.

## Real run on this Mac

Run in this session, on branch `t1-readiness` at `9333ab4`, with the full command and no overrides. The Docker FAIL is real: colima is stopped. I did not start it, because the script and this task start nothing.

```
$ /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running. Claude.ai can reach the reports folder and the Obsidian notes.
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.325.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch t1-readiness.
PASS Git working tree: clean; last commit 9333ab4 T1: TRIAD readiness check (scripts/triad-ready.sh). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and can be written to; it holds feedbox-inputs and 120 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH, the way Claude Code pushes.
PASS Reports branch: cc-reports exists on GitHub (latest commit 1734dd4).
PASS Required checks: branch main requires lint typecheck unit db Vercel before a merge.
PASS CI on main: the latest CI run passed (commit 17bc04c, 2026-11-15T01:08:58Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers (HTTP 200, page Feedbox).
PASS Vercel build of main: Vercel built the latest commit on main successfully.
PASS Supabase feedbox-preview: project qrbeiveyomidfafivuta answers (it asks for a key, as expected; none is sent).
NOT READY: 1 of 18 checks failed.
exit=1
```

## FAIL test runs

Each run points some checks at a wrong place with the `TRIAD_*` overrides from the script's header. PASS lines are left out below.
- **Folders:** `$T` is a scratch folder holding:
  - `notgit` (an empty folder);
  - `wrongclone` (a git clone whose origin is `someone/other-repo`);
  - `readonly` (mode 555);
  - `reports-noinputs` and `vault-notriad` (empty folders).
- **Program doubles:** `fake-node` prints `v20.11.1`, and `fake-gh` is this test double:

```
#!/bin/bash
# Test double for the GitHub CLI. "run list" answers $FAKE_RUN (when set);
# a call whose arguments match the pattern $FAKE_FAIL fails; everything
# else goes to the real program.
if [ -n "$FAKE_FAIL" ] && [[ "$*" =~ $FAKE_FAIL ]]; then echo "HTTP 503 (test double)" >&2; exit 1; fi
if [ "$1" = run ] && [ -n "$FAKE_RUN" ]; then echo "$FAKE_RUN"; exit 0; fi
exec /Users/nikolajivancic/gh-cli "$@"
```

The Docker FAIL appears in every run because colima is really stopped. Every FAIL message in the script appears at least once below. The only exception is the Claude Code message for a program that runs but does not print "Claude Code": it has the same text as the "not found" message shown in Run A.

```
=== Run A: everything pointed at a wrong place
$ TRIAD_TIMEOUT=3 TRIAD_CLAUDE_APP=/Applications/NoSuch.app/Contents/MacOS/NoSuch TRIAD_CHROME_APP=/Applications/NoChrome.app/Contents/MacOS/NoChrome TRIAD_CLAUDE_CMD=/no/such/claude TRIAD_NODE_CMD=/no/such/node TRIAD_PROJECT_DIR=/no/such/folder TRIAD_REPORTS_DIR=/no/such/reports TRIAD_VAULT_DIR=/no/such/vault TRIAD_DOCKER_CMD=/no/such/docker TRIAD_GH=/no/such/gh TRIAD_PROD_URL=https://no-such-host.invalid TRIAD_PREVIEW_REF=nosuchprojectrefxxxx
FAIL Claude desktop app: not running, so Claude.ai cannot reach the files on this Mac. Open the Claude app from the Dock (or Finder, Applications, Claude) and leave it open.
FAIL Chrome: not running. Open Google Chrome from the Dock, then open the TRIAD chat and the tracker page.
FAIL Claude Code: not found (looked for "/no/such/claude"). Install Claude Code (https://claude.com/claude-code), then open a new Terminal tab and run this check again.
FAIL Node.js: not found (looked for "/no/such/node"). Tell Claude Code: Node.js 24 is needed for the project's npm commands.
FAIL Project folder: /no/such/folder does not exist. Tell Claude Code; do not create it by hand.
FAIL Reports folder: /no/such/reports does not exist. Tell Claude Code and Claude.ai; do not create it by hand.
FAIL Obsidian vault: /no/such/vault does not exist. Open Obsidian and check that the vault pact-web is synced; tell Claude.ai.
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
FAIL GitHub sign-in: the GitHub CLI program /no/such/gh is missing. Tell Claude Code.
FAIL git over SSH: not checked, because the project folder check failed. Fix that first.
FAIL Reports branch: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL Required checks: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL CI on main: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL Vercel Production: https://no-such-host.invalid does not answer (no network, or Vercel down). Check the network and https://www.vercel-status.com, then tell Claude.ai.
FAIL Vercel build of main: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL Supabase feedbox-preview: project nosuchprojectrefxxxx does not answer (no network, wrong project ID, or Supabase down). Check https://status.supabase.com and the Supabase dashboard, then tell Claude.ai.
NOT READY: 16 of 18 checks failed.
exit=1

=== Run B: second kind of each FAIL
$ TRIAD_TIMEOUT=3 TRIAD_NODE_CMD=$T/fake-node TRIAD_PROJECT_DIR=$T/notgit TRIAD_REPORTS_DIR=$T/readonly TRIAD_VAULT_DIR=$T/vault-notriad TRIAD_REPO=adriatic/no-such-repo TRIAD_PROD_URL=https://triad-feedbox-delta.vercel.app/no-such-page TRIAD_PREVIEW_URL=https://triad-feedbox-delta.vercel.app
FAIL Node.js: v20.11.1, but the project's .nvmrc asks for version 24. Tell Claude Code; it does not stop a session, but npm commands may behave differently.
FAIL Project folder: $T/notgit exists but is not a git clone. Tell Claude Code; do not change the folder by hand.
FAIL Reports folder: $T/readonly exists but cannot be written to, so Claude Code cannot save reports. Tell Claude Code.
FAIL Obsidian vault: $T/vault-notriad exists but has no TRIAD/TRIAD setup.md. Open Obsidian and check that the vault pact-web is synced; tell Claude.ai.
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
FAIL GitHub sign-in: the stored GitHub sign-in cannot read adriatic/no-such-repo (signed out, no network, or GitHub down). Check the network and https://www.githubstatus.com, then tell Claude Code. Do not sign in yourself.
FAIL git over SSH: not checked, because the project folder check failed. Fix that first.
FAIL Reports branch: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL Required checks: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL CI on main: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL Vercel Production: https://triad-feedbox-delta.vercel.app/no-such-page answers HTTP 404 without the Feedbox page. Open it in Chrome; if it is broken, tell Claude.ai.
FAIL Vercel build of main: not checked, because the GitHub sign-in check failed. Fix that first.
FAIL Supabase feedbox-preview: project qrbeiveyomidfafivuta answered HTTP 200, not the expected 401. Open the Supabase dashboard in Chrome and check that feedbox-preview is not paused; tell Claude.ai.
NOT READY: 13 of 18 checks failed.
exit=1

=== Run C: third kind
$ TRIAD_TIMEOUT=3 TRIAD_PROJECT_DIR=$T/wrongclone TRIAD_REPORTS_DIR=$T/reports-noinputs TRIAD_MAIN_BRANCH=cc-reports TRIAD_GH=$T/fake-gh FAKE_RUN=in_progress none 17bc04c 2026-11-15T09:00:00Z TRIAD_PROD_URL=http://10.255.255.1
FAIL Project folder: $T/wrongclone is a git clone of "git@github.com:someone/other-repo.git", not of adriatic/triad-feedbox. Tell Claude Code; do not change the folder by hand.
FAIL Reports folder: $T/reports-noinputs has no subfolder feedbox-inputs (the design inputs). Tell Claude Code.
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
FAIL git over SSH: not checked, because the project folder check failed. Fix that first.
FAIL Required checks: branch cc-reports does not require: lint typecheck unit db Vercel. Tell Claude.ai; the ruleset on cc-reports must be fixed in a task before the next merge.
FAIL CI on cc-reports: the latest CI run (commit 17bc04c, started 2026-11-15T09:00:00Z) is still in_progress. Wait a few minutes and run this check again.
FAIL Vercel Production: http://10.255.255.1 does not answer (no network, or Vercel down). Check the network and https://www.vercel-status.com, then tell Claude.ai.
FAIL Vercel build of cc-reports: Vercel's state for the latest commit on cc-reports is failure, not success. If it is pending, wait a few minutes; otherwise tell Claude.ai.
NOT READY: 8 of 18 checks failed.
exit=1

=== Run D: CI failed, a required check missing
$ TRIAD_GH=$T/fake-gh FAKE_RUN=completed failure 17bc04c 2026-11-15T09:00:00Z TRIAD_REQUIRED_CHECKS=lint typecheck unit db e2e Vercel
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
FAIL Required checks: branch main does not require: e2e. Tell Claude.ai; the ruleset on main must be fixed in a task before the next merge.
FAIL CI on main: the latest CI run failed (failure, commit 17bc04c, 2026-11-15T09:00:00Z). Tell Claude.ai before starting a task.
NOT READY: 3 of 18 checks failed.
exit=1

=== Run E: branches that do not exist
$ TRIAD_MAIN_BRANCH=no-such-branch TRIAD_REPORTS_BRANCH=no-such-reports
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
FAIL git over SSH: the project folder cannot read branch no-such-branch from GitHub over SSH (no network, or the SSH key is not loaded). Check the network, then tell Claude Code.
FAIL Reports branch: branch no-such-reports was not found on GitHub, so Claude.ai cannot read the reports there. Tell Claude Code.
FAIL Required checks: branch no-such-branch does not require: lint typecheck unit db Vercel. Tell Claude.ai; the ruleset on no-such-branch must be fixed in a task before the next merge.
FAIL CI on no-such-branch: there is no CI run on branch no-such-branch. Tell Claude Code.
FAIL Vercel build of no-such-branch: Vercel's state for branch no-such-branch could not be read. Tell Claude Code.
NOT READY: 6 of 18 checks failed.
exit=1

=== Run F: GitHub answers the sign-in but fails later calls
$ TRIAD_GH=$T/fake-gh FAKE_FAIL=rules/branches|commits/main/status|^run 
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
FAIL Required checks: the rules of branch main could not be read. Tell Claude Code.
FAIL CI on main: no CI run on branch main could be read. Tell Claude Code.
FAIL Vercel build of main: Vercel's state for branch main could not be read. Tell Claude Code.
NOT READY: 4 of 18 checks failed.
exit=1

=== Run G: wrong Node.js version
$ TRIAD_NODE_CMD=$T/fake-node
FAIL Node.js: v20.11.1, but the project's .nvmrc asks for version 24. Tell Claude Code; it does not stop a session, but npm commands may behave differently.
FAIL Docker: not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again.
NOT READY: 2 of 18 checks failed.
exit=1
```

## CI results (pull request #3, head `9333ab4`)

| Check | Result |
|---|---|
| lint | pass (24 s; pull_request run 27 s) |
| typecheck | pass (19 s; 20 s) |
| unit | pass (20 s; 26 s), 105 tests in 12 files |
| db | pass (1 m 8 s; 1 m 2 s) |
| Vercel | pass (Preview deployment completed) |
| Vercel Preview Comments | pass |

These are GitHub Actions runs 43755610134 and 43755634182 (one started by the branch push, one by the pull request). Locally `npm run lint`, `npm run typecheck` and `npm test` also passed (105 tests).

## Links and hashes

- Pull request: https://github.com/adriatic/triad-feedbox/pull/3 (T1: TRIAD readiness check), head `9333ab44405cc25261d0ef31049918cba629d759`, base `main` at `17bc04c4a931353dbe4de71246980114c123ac98` (tag `f3`).
- Script at the head: https://github.com/adriatic/triad-feedbox/blob/9333ab44405cc25261d0ef31049918cba629d759/scripts/triad-ready.sh
- Not merged. Merging needs Nik's "merge" and a merge task.
- The local project folder stays on branch `t1-readiness` (clean), so that the command in T1-2 finds the script.
