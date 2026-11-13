# Task M2: open the F2 pull request and merge it

- Repository: https://github.com/adriatic/triad-feedbox
- Local folder: `/Users/nikolajivancic/Work/triad-feedbox`
- Date: 2026-11-13
- Approval: Nik said "merge" for F2 in his chat with Claude.ai on 2026-11-13 at 10:13 AM, after "preview ok". It is recorded in the TRIAD tracker and approves `f2-core` at `691f0015ae39bde9bc48060ad900c07e17532056` only.
- No file was changed. No database work was done.

## Decisions Nik must make

One small one:

| # | Decision | Recommendation |
|---|---|---|
| M2-D1 | Where the gh note for this repository comes from | The gh setup is described in **`/Users/nikolajivancic/Work/diff-tests/CLAUDE.md`**, not in `pactresearch-web/CLAUDE.md` (see "How gh was found"). **Accept** that F3's first commit copies that setup into this repository's `CLAUDE.md`, as you planned. |

## Steps for Nik

None for this task. Optional: open https://triad-feedbox-delta.vercel.app in Chrome to see the placeholder on Production. It is public, so no Vercel sign-in is needed.

---

## How gh was found and signed in

1. `/Users/nikolajivancic/work/pactresearch-web/CLAUDE.md` (and its included `AGENTS.md`) **does not mention gh**. It covers keys, databases, reports and how to work, but has no GitHub CLI section. No gh program is on `PATH`, and a search of the usual locations (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/bin`) found none.
2. I then searched the `CLAUDE.md` files in Nik's other project folders, read-only. **`/Users/nikolajivancic/Work/diff-tests/CLAUDE.md`** has a "GitHub CLI" section, which says:
   - gh is the single program **`~/gh-cli`** (version 2.100.0), not on `PATH`;
   - the Mac has two sign-ins: the shell's `GH_TOKEN` (limited to chosen repositories, which is why F1 and F2 were refused) and gh's **stored sign-in in `~/.config/gh`, kept in the macOS keychain**;
   - use the stored sign-in by putting **`env -u GH_TOKEN`** before every gh command;
   - never run `gh auth token`, never use `--show-token`, never echo `GH_TOKEN`.
3. A read-only check, `env -u GH_TOKEN ~/gh-cli auth status`, showed "Logged in to github.com account adriatic (keyring)". `env -u GH_TOKEN ~/gh-cli api repos/adriatic/triad-feedbox` reported `admin=true`, `push=true`. So the setup works for this repository, and I continued past step 2.
4. No token was printed, copied, moved or written anywhere. `GH_TOKEN` was not changed or widened.

## Steps carried out

| Step | Result |
|---|---|
| 1. `origin/f2-core` = approved head | `691f0015ae39bde9bc48060ad900c07e17532056`, matching exactly |
| 2. Pull request | **https://github.com/adriatic/triad-feedbox/pull/1**, title "F2: core library and app skeleton". Description: the approval line, then the "Pull-request text" block from the F2 report. My first attempt had an error in my text-extraction command (an `awk` syntax error), so the pull request was first opened with only the approval line as its description. I corrected the description at once with `gh pr edit` (20 lines, checked). Nothing else was affected. |
| 3. Checks | All green (table below) |
| 4. Ruleset | Required status checks added (below) |
| 5. Squash-merge | Merged at 2026-11-13 18:16:57 UTC (10:16 AM Pacific), with `--match-head-commit 691f001…`, so GitHub would have refused if the branch had moved. Merge commit on `main`: **`b0fec8dadb42c9849b7a75d7b6b6e3af53aaa118`**. Its file tree is identical to the approved head (`git diff 691f001 b0fec8d` is empty). Branch `f2-core` deleted on GitHub and locally. GitHub keeps the read-only `refs/pull/1/head` for the pull request's history. |
| 6. Production and tag | Below |

## Check results on pull request #1

| Check | Push run (43478650586) | Pull-request run (43480792826) |
|---|---|---|
| `lint` | pass (29 s) | pass (47 s) |
| `typecheck` | pass (15 s) | pass (1 m 4 s) |
| `unit` | pass (24 s) | pass (1 m 2 s) |
| `Vercel` (Preview build) | pass: "Deployment has completed" | (one status per commit) |
| `Vercel Preview Comments` | pass | |

## The ruleset "main" as it now stands

Ruleset id 27181565, enforcement **Active**, target: the default branch (`main`), bypass list empty ("current user can bypass: never"). Last updated 2026-11-13 10:16:46 AM Pacific.

1. **Restrict deletions** (unchanged)
2. **Block force pushes** (unchanged)
3. **Require a pull request before merging** (unchanged): 0 approvals; merge methods merge, squash and rebase allowed; the other options as Nik set them
4. **Require status checks to pass** (new):
   - `lint` (source: GitHub Actions)
   - `typecheck` (source: GitHub Actions)
   - `unit` (source: GitHub Actions)
   - `Vercel` (commit status from Vercel; any source)
   - "Require branches to be up to date before merging": **off**. "Do not enforce on create": off.

gh was allowed to change the ruleset, so step 4 was not skipped. I did this before the merge, so the merge itself already passed under the new rules.

## Production check

- The Vercel status on merge commit `b0fec8d` was success ("Deployment has completed").
- https://triad-feedbox-delta.vercel.app answered **HTTP 200** with the placeholder page: the heading "Feedbox", the line "A free, open-source feedback and roadmap board. The board is being built; this page is a placeholder.", "Ideas move through:", then Open, Planned, Building, Shipped. The page title is "Feedbox". Before M2 the same address returned 404.

## Tag

- **`f2`**, an annotated tag (object `b83238dfd5e78d740f9338cf5d8ab6f1ac44f150`) on merge commit `b0fec8dadb42c9849b7a75d7b6b6e3af53aaa118`, with the message "F2: core library and app skeleton. Approved by Nik on 2026-11-13 at 10:13 AM (TRIAD tracker)." Pushed to GitHub.

## Commit hashes

| What | Hash |
|---|---|
| Approved head of `f2-core` | `691f0015ae39bde9bc48060ad900c07e17532056` |
| Merge commit on `main` | `b0fec8dadb42c9849b7a75d7b6b6e3af53aaa118` |
| Tag `f2` → | `b0fec8dadb42c9849b7a75d7b6b6e3af53aaa118` |
| This report on `cc-reports` | given in the closing message (a commit cannot contain its own hash) |

## For F3 (not done now, as instructed)

The first commit of F3 adds the gh note to this repository's `CLAUDE.md`: `~/gh-cli`, `env -u GH_TOKEN` before every command, never print a token. It also replaces the F2 lines that say the token cannot open pull requests and that Nik clicks.

## Check before sending

I searched this report for `TODO`, `TBD`, `XXX`, `{{` and angle-bracket placeholders, and found none. Every requested item is present: how gh was found and signed in (no token values), the pull-request link, the check results, the ruleset as it now stands, the merge commit hash, the Production check and the tag.
