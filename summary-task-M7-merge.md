# Task M7: merge C1 (pull request #6, the cleanup)

Done. Pull request #6 is squash-merged into `main` as commit **ed790b4a83011bf258e7099e853669785fc1d99f**. The merge commit is tagged `c1`. Production is green and still serves the Feedbox board page. The readiness check says **READY: all 19 checks passed.** on branch main. No file was changed, and nothing was run against a hosted database.

## Steps for Nik

None are needed for M7.

## Results

- **Approved head:** `origin/c1-cleanup` was exactly `27da8794765af542dee3faf95cd65c86e78e7d11` before the merge.
- **Approval line:** added at the top of the description of pull request #6: "Approved by Nik on 2026-11-17 at 1:55 PM (recorded in the TRIAD tracker)."
- **Checks on the pull request before the merge:** all green on head 27da879:

  | Check | Push run 44130657973 | Pull request run 44130671509 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

  `Vercel` passed with "Deployment has completed".
- **Merge:** squash-merged with `--match-head-commit 27da8794765af542dee3faf95cd65c86e78e7d11` at 2026-11-17T21:57:28Z (UTC). The merge commit is `ed790b4a83011bf258e7099e853669785fc1d99f`.
- **Branch:** `c1-cleanup` is deleted on GitHub and in the local folder.
- **Byte-for-byte:** the files at the merge commit are byte-for-byte those at 27da879. Both commits have the same git tree `33540556314c2e6743fffbb4991aab9b3dea66cc`, and `git diff 27da879 ed790b4` is empty.
- **Tag:** `c1` (annotated tag object `671005545b6b0e669038c5139ffe8af4835b0941`) points to `ed790b4` and is pushed to GitHub.
- **Local folder:** `/Users/nikolajivancic/Work/triad-feedbox` is on `main` at `ed790b4`, up to date with `origin/main`, and clean.
- **CI on main:** run 44185175499 passed for commit ed790b4. Its jobs lint, typecheck, unit, db and e2e all passed.
- **Production:**
  - Vercel's status on `ed790b4` is success, "Deployment has completed": https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/3Hf17p9wDWFSnMFx49cRihRxAgq3
  - https://triad-feedbox-delta.vercel.app answers HTTP 200 with the Feedbox board page. Its title is "Feedbox", it says "What should Feedbox do next?" and it shows "Viewing as visitor".

## Readiness check (step 7)

Run in Claude Code's shell from `main`:

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit ed790b4 C1: cleanup after F4 and O1 (e2e required, local sender, OTP length, prod interval) (#6). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 132 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit ea6fcdf).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit ed790b4, 2026-11-17T21:57:31Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
```

Exit code 0. The Project folder line says branch main.

## Links

- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/6
- **Merge commit:** https://github.com/adriatic/triad-feedbox/commit/ed790b4a83011bf258e7099e853669785fc1d99f
- **Tag:** https://github.com/adriatic/triad-feedbox/releases/tag/c1
- **CI run on main:** https://github.com/adriatic/triad-feedbox/actions/runs/44185175499

## Noted for later

The next task that touches CLAUDE.md will update the feedbox-prod "Minimum interval per user" row in "Dashboard settings". The row will say that Nik verified it on screen at 2026-11-17 8:49 AM, not only that he opened it from feedbox-prod's address. M7 changes no file, so this is not done here.

## Decisions for Nik

None. No decision is open.
