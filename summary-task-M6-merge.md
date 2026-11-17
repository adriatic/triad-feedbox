# Task M6: merge O1 (pull request #5, the owner scripts)

Date: 2026-11-17 (merged at 8:34 AM Pacific, 16:34:53 UTC).

## In short

- **Merged:** pull request #5 was squash-merged at the approved head `2412bac4d6e2fe4965cd8bfb630a391fb89f020a`. The merge commit on `main` is **`33cff75dc2d4423ec087eaf3767081594a0ccc01`**. The branch `o1-owner` is deleted, and the tag `o1` is pushed.
- **The scripts:** `owner-nik.sql` and `prod-owner.sql` at the merge commit are byte for byte the ones you ran at 8:15 AM.
- **Production:** it deployed `main` with status success, and https://triad-feedbox-delta.vercel.app shows the Feedbox board.
- **Database:** I ran nothing against a hosted database.

## Steps for Nik

None. The two scripts already ran on feedbox-prod (2026-11-17 8:15 AM), and Production already showed "Signed in as owner" (8:22 AM). This merge only records the scripts in `main`.

## Merge

- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/5, state MERGED at 2026-11-17T16:34:53Z.
- **Head before the merge:** `origin/o1-owner` was exactly `2412bac4d6e2fe4965cd8bfb630a391fb89f020a`, as approved. The merge used `--match-head-commit` with that hash. The base `main` was at `08067e7` (tag `f4`), unchanged since the branch was made.
- **Approval line:** the description now starts with "Approved by Nik on 2026-11-17 at 8:33 AM (recorded in the TRIAD tracker). Run on feedbox-prod at 8:15 AM: owner-nik.sql Success, prod-owner.sql PASS 5 of 5." The rest of the description is unchanged.
- **Merge commit:** `33cff75dc2d4423ec087eaf3767081594a0ccc01`, "O1: make Nik the owner of the Feedbox board on feedbox-prod (SQL as code) (#5)", parent `08067e7`.
- **Branch:** `o1-owner` is deleted on GitHub (`git ls-remote` finds no such branch) and on the Mac.
- **Tag:** `o1` is an annotated tag ("O1: Nik as owner of the Feedbox board, owner scripts (PR #5)"), object `c974d16cbca5cc309238ffe6cb2bce49db2693ed`, pointing to `33cff75`. It is pushed.
- **Local folder:** on `main` at `33cff75`, even with `origin/main`, clean.

## Step 7: the scripts are the ones Nik ran

| File | Git file ID at 2412bac | Git file ID at 33cff75 | sha256 (identical at both) | Bytes |
|---|---|---|---|---|
| `supabase/production/owner-nik.sql` | `13d8176099a2c6a7c7a6efa7b951332026b90bad` | `13d8176099a2c6a7c7a6efa7b951332026b90bad` | `483f56fdb1661a7a4ca8c541b6b32edaebf8ecf2ac5c99a6788c3cf97b7ce829` | 10859 |
| `supabase/checks/prod-owner.sql` | `d55535792825b1f7116a7fd23c6a8278b04ebe76` | `d55535792825b1f7116a7fd23c6a8278b04ebe76` | `5245ccf78f22cb78928bb9c5ee9c0f12aeb0020c503698cebcd643f74e1daf16` | 11714 |

- **Same file IDs:** both files have the same git file ID at the two commits, so their content is byte for byte the same.
- **The whole tree:** it is also identical, `66af5d93bfe377b4c5e477de72b38a5db677feca` at both `2412bac` and `33cff75`. Every file at the merge commit is the file at the approved head.
- **Your pinned links** pointed to `2412bac`, so what you pasted is what is now in `main`.

## Checks

- **Before the merge, at `2412bac`:** runs 44118962993 (push) and 44118998626 (pull request) both succeeded.

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |
  | Vercel | pass | pass |

- **After the merge, at `33cff75`:**
  - CI run 44127393337 (push to `main`): success, with lint, typecheck, unit, db and e2e all success.
  - CI run 44127435280 (the push of tag `o1`, same commit): success.
  - Vercel status: success.

## Production

- **Deployment:** Vercel's status on `33cff75` is `success`, "Deployment has completed": https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/CVkKxVq2dQzvvMhMNnx2iDpoF5Lr
- **The page:** https://triad-feedbox-delta.vercel.app answers HTTP 200 with the Feedbox board page, as a visitor:
  - the header reads "Feedbox · Changelog · Post an idea", then "Viewing as visitor" and "Sign in";
  - the heading "Feedbox", "What should Feedbox do next?", and the intro text;
  - the tabs Open (0), Planned (0), Building (0), and so on.

## Decisions for Nik

No new decisions. Still open, with my recommendations unchanged:
- **M5-D2:** the readiness script and CLAUDE.md naming `e2e` as a required check.
- **F4d-D1:** the local sender name and address.
- **F4h-D1:** feedbox-prod's minimum interval per user.
- **F4h-D2:** the local OTP length.

I recommend doing the first three in one small task next, because they are all docs or local settings.
