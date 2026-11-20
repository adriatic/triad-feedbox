# Task M12: merge CT1 (pull request #11, Contact the owner and Messages)

**Pull request #11 is merged into main.**
- Merge commit: `5b89b6cbbf6d815dae71dab74f7a3389ae369ee3`, a squash merge.
- Tag: `ct1`.
- Branch `ct1-contact` is deleted.
- Production is live with Contact the owner.
- The local folder is on main at the merge commit, and it is clean.

I ran nothing against a hosted database, changed no file in the repository, and did not touch the manual in Obsidian.

## Steps for Nik

None are needed for this task.

## What was done

### 1. Branch heads

| | Expected | Found |
|---|---|---|
| `origin/ct1-contact` | `c9f7e88dd8c32f6bb9fe3617080d026217067a6e` | `c9f7e88dd8c32f6bb9fe3617080d026217067a6e` |
| `origin/main` | `4bb817e449ce0fdd9aa615399a7e8dfa4dd08c59` | `4bb817e449ce0fdd9aa615399a7e8dfa4dd08c59` |

Pull request #11 was open, and its head was `c9f7e88dd8c32f6bb9fe3617080d026217067a6e`.

### 2. Approval line

The description of pull request #11 now starts with this line:

> Approved by Nik on 2026-11-19 at 7:58 PM (recorded in the TRIAD tracker). feedbox-prod migrated (messages) and checked (PASS) before the merge, reported 8:14 PM.

The rest of the description is unchanged.

### 3. Checks on the approved head `c9f7e88`

All six required checks were green before the merge.

| Check | Push run 44606585987 | Pull-request run 44606602135 |
|---|---|---|
| lint | pass (1m9s) | pass (45s) |
| typecheck | pass (55s) | pass (43s) |
| unit | pass (52s) | pass (56s) |
| db | pass (4m20s) | pass (3m40s) |
| e2e | pass (2m50s) | pass (2m32s) |
| Vercel | pass: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/AysWHATfoeJJg5urxkMhwwzbQEUm | |

### 4. Merge, branch and tag

- **Command:** `gh pr merge 11 --squash --match-head-commit c9f7e88dd8c32f6bb9fe3617080d026217067a6e --delete-branch`.
- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/11, state MERGED, merged at 2026-11-20T04:15:52Z (8:15 PM on 2026-11-19, Nik's time).
- **Merge commit:** `5b89b6cbbf6d815dae71dab74f7a3389ae369ee3`, "CT1: contact the owner (messages to the board's owners) (#11)". Its single parent is `4bb817e449ce0fdd9aa615399a7e8dfa4dd08c59`.
- **Branch:** `ct1-contact` is deleted on GitHub (`git ls-remote --heads origin ct1-contact` returns nothing) and locally.
- **Tag:** `ct1` points at `5b89b6cbbf6d815dae71dab74f7a3389ae369ee3` and is pushed. `git ls-remote --tags origin ct1` returns `5b89b6cbbf6d815dae71dab74f7a3389ae369ee3 refs/tags/ct1`.

**The files at the merge commit are byte-for-byte those at `c9f7e88`:**
- Both commits have the same tree, `761bc47d6ec7d15b588f7b22abb2d32a6ca9900b`.
- `git diff --stat c9f7e88 5b89b6c` is empty.

The merge changed 130 files (2776 lines added, 83 removed), exactly the CT1 pull request. The migration `supabase/migrations/20261119120000_messages.sql` on main is therefore the same file that ran on feedbox-preview and feedbox-prod.

### 5. Local folder

- `git switch main` and `git pull --ff-only` fast-forwarded main from `4bb817e` to `5b89b6c`.
- `git status`: `## main...origin/main`, with nothing changed and nothing untracked.

### 6. Production

| Check | Result |
|---|---|
| Vercel's status on `5b89b6c` (the Production deployment of main) | success, "Deployment has completed": https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/9jdyutR1G7Nfz2dbjG2mEh3XBYk3 |
| CI run on main for `5b89b6c` (push run 44673240479) | success: lint, typecheck, unit, db and e2e all pass |
| https://triad-feedbox-delta.vercel.app | HTTP 200. Title "Feedbox", heading "What should Feedbox do next?", and the footer link "Contact the owner" |
| https://triad-feedbox-delta.vercel.app/contact | HTTP 200. Heading "Contact the owner", the sentence "Only signed-in people can send a message to the owner of Feedbox.", and the button "Sign in to contact the owner" (to `/sign-in?next=%2Fcontact`) |

Both pages were fetched without signing in, so they show what a visitor sees.

### 7. Is TRIAD ready? (`scripts/triad-ready.sh`, exit code 0)

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit 5b89b6c CT1: contact the owner (messages to the board's owners) (#11). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 149 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 12b8efe).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit 5b89b6c, 2026-11-20T04:15:54Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
```

The Project folder line says "on branch main", as the task asks. The script ran before this report was pushed, so the Reports branch line still shows the CT1 report commit `12b8efe`.

## Links

- Pull request: https://github.com/adriatic/triad-feedbox/pull/11
- Merge commit: https://github.com/adriatic/triad-feedbox/commit/5b89b6cbbf6d815dae71dab74f7a3389ae369ee3
- Tag: https://github.com/adriatic/triad-feedbox/tree/ct1
- CI on main: https://github.com/adriatic/triad-feedbox/actions/runs/44673240479
- Production: https://triad-feedbox-delta.vercel.app and https://triad-feedbox-delta.vercel.app/contact

## Decisions for Nik

There are no new decisions. CT1-D1, CT1-D2 and CT1-D3 are already decided.
