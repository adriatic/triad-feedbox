DO NOT RUN ANY SQL YET. Claude.ai reviews the steps first.

# Task M3: merge F3 (pull request #2) and write Nik's steps for feedbox-prod

Date: 2026-11-14 (Nik's time). Nothing was run against any hosted database.

## Decisions Nik must make

None.

## Summary

| Item | Value |
|---|---|
| Approval | Nik, "merge" for pull request #2, 2026-11-14 at 5:06 PM (TRIAD tracker); approves `f3-database` at `f65d62355695c33c8fcbff4a9b6c849467a626d8` |
| Approved head checked | `origin/f3-database` was exactly `f65d62355695c33c8fcbff4a9b6c849467a626d8` before the merge |
| Pull request | https://github.com/adriatic/triad-feedbox/pull/2 (MERGED, squash, 2026-11-15 01:08:56 UTC = 2026-11-14 5:08 PM Pacific) |
| **Merge commit on `main`** | **`17bc04c4a931353dbe4de71246980114c123ac98`** "F3: database migration, access rules and database tests (#2)" |
| Branch `f3-database` | deleted on GitHub (and locally) |
| Tag | `f3` (annotated, like `f2`) on `17bc04c4a931353dbe4de71246980114c123ac98`, pushed |
| Production | https://triad-feedbox-delta.vercel.app answers HTTP 200 with the placeholder page (below) |

## What was done (Part A)

1. **Approved head:** `git fetch` showed `origin/f3-database` at `f65d62355695c33c8fcbff4a9b6c849467a626d8`. It matches.
2. **Approval line:** the line "Approved by Nik on 2026-11-14 at 5:06 PM (recorded in the TRIAD tracker)." was added at the top of the pull request's description. The rest of the description is unchanged.
3. **Checks before the merge:** every check on head `f65d623` passed, on both workflow runs.

   | Check | Result |
   |---|---|
   | `lint` | pass (push run 43562281701: 17s; pull_request run 43562286208: 19s) |
   | `typecheck` | pass (27s; 27s) |
   | `unit` | pass (28s; 26s) |
   | `db` | pass (1m10s; 58s). Log: `Files=10, Tests=225, Result: PASS` and `SQL checks: all 56 expectations met.` |
   | `Vercel` | pass (Preview deployment completed) |

   On the merge commit `17bc04c` itself, `lint`, `typecheck`, `unit` and `db` passed on its push run, and the Vercel status is success ("Deployment has completed").
4. **Ruleset:** `db` was added to the required status checks of the ruleset "main" (id 27181565) with gh (`PUT repos/adriatic/triad-feedbox/rulesets/27181565`). gh was allowed to change it. I compared the ruleset before and after: apart from the added `db`, everything is identical.
5. **Merge:** `gh pr merge 2 --squash --match-head-commit f65d62355695c33c8fcbff4a9b6c849467a626d8 --delete-branch`. Afterwards the branch `f3-database` is gone from GitHub, and local `main` was fast-forwarded to `17bc04c`. Tag `f3` was added to the merge commit and pushed (`refs/tags/f3^{}` = `17bc04c4a931353dbe4de71246980114c123ac98`).
6. **Production check:**
   - The Vercel status on merge commit `17bc04c` is success ("Deployment has completed"). Vercel reports through this commit status, not through GitHub deployments; M2 was checked the same way.
   - https://triad-feedbox-delta.vercel.app answered **HTTP 200** with the placeholder page:
     - page title "Feedbox" and heading "Feedbox";
     - the line "A free, open-source feedback and roadmap board. The board is being built; this page is a placeholder.";
     - the list Open, Planned, Building, Shipped.
   - The response was cached 820 seconds before 01:25:10 UTC, so it was built at about 01:11 UTC, after the merge at 01:08:56 UTC.

## The ruleset "main" as it now stands

- Enforcement: **active**. Target: the default branch (`~DEFAULT_BRANCH`). Bypass list: empty.
- Rules:
  - **Restrict deletions** (`deletion`).
  - **Block force pushes** (`non_fast_forward`).
  - **Require a pull request:** 0 approvals; merge methods merge, squash and rebase. The other settings are unchanged.
  - **Require status checks:**
    - `lint`, `typecheck`, `unit` and **`db`** (all GitHub Actions, integration 15368);
    - `Vercel`;
    - "require branches to be up to date" is off, as before.

## Every pinned file is the reviewed file

- **Whole tree:** the merge commit's tree is **identical** to the tree of `f65d623`. Both tree hashes are `d2df1c98aaeca1a187a5dbd1efc2cf1216421acd`, and `git diff f65d623 17bc04c` is empty.
- **Each file Nik will paste:** for each one I checked three things:
  - the git blob at the merge commit equals the blob at `f65d623`;
  - the raw GitHub link pinned to the merge commit serves exactly that content (sha256 compared);
  - its line count and last line.

| File | Lines | Last line | Blob = `f65d623` | Raw link = file | sha256 |
|---|---|---|---|---|---|
| `supabase/checks/prod-before-migration.sql` | 165 | `-- end of prod-before-migration.sql` | yes | yes | `ac1da25de9ad37f97300e77f1e4bc1e41bb37873928855e8e6c3087556a748f5` |
| `supabase/migrations/20261113000000_feedbox_v1.sql` | 937 | `  on conflict (id) do nothing;` | yes, and = `423572c` (blob `36c1945e8223a3ecc13fe374d68515e5ee97c51a`) | yes | `25077cb5974b0810601816af39297a082cdd5b97a350e842a9832970d6795384` |
| `supabase/checks/prod-after-migration.sql` | 227 | `-- end of prod-after-migration.sql` | yes | yes | `9dd2bb574a961ce5d3ab825691748769fdb6308e758ac88534efa6637b00e752` |
| `supabase/checks/prod-ready-for-board.sql` | 169 | `-- end of prod-ready-for-board.sql` | yes | yes | `15f05c31e19cface084bc95f77dbff148a02e200eb1da4dbd2a8532aab5f3371` |
| `supabase/production/board-feedbox.sql` | 60 | `-- end of board-feedbox.sql` | yes | yes | `5183313aff84515da2e35e47962793489e1c9befe35cd31fde09b266834663c5` |
| `supabase/checks/prod-board.sql` | 181 | `-- end of prod-board.sql` | yes | yes | `9fde7d2c541dcc1c7cc8771363b540b6536179ce48d083982d6653b49889c0d2` |

The migration's sha256 is the one `tests/sql-files.test.ts` pins, and it is the file that ran on feedbox-preview.

## Steps for Nik

**⚠️ WAITING FOR CLAUDE.AI'S GO-AHEAD. Do not start these steps until Claude.ai has reviewed them and says so.** All steps are in **feedbox-prod**.

**How to paste a script (used in M3-3 to M3-8):**
1. Open the step's link in a new Chrome tab. Every link is pinned to the merge commit `17bc04c`.
2. Click into the page, press **Cmd+A**, then **Cmd+C**.
3. In the SQL Editor, click **+ New query**, click into the empty editor, and press **Cmd+V**.
4. Before clicking **Run**, check two things:
   - **Top:** the first line is the one the step gives.
   - **Bottom:** scroll to the end. The last line with text must be exactly the step's last line, at the line number it gives. The editor may show one empty line after it; that is fine.
5. If either does not match, the copy is incomplete or doubled. Close that query tab with its ×, and paste again.

**M3-1. Select feedbox-prod.**
- In Chrome, open https://supabase.com/dashboard, choose the organisation **TRIAD**, then the project **feedbox-prod**.
- Check two things:
  - the project selector at the top of the page says **`feedbox-prod`**;
  - the address bar does **NOT** contain `qrbeiveyomidfafivuta`.
- If either check fails, **stop**: you are not in feedbox-prod. Choose the project again, or send a screenshot to Claude.ai. Nothing has been changed.

**M3-2. Clear all existing queries.** In the left menu, click **SQL Editor**. Then:
1. At the top of the SQL Editor, click each "Untitled query" tab.
2. Its orange dot turns into an ×. Click the ×, which deletes that query.
3. Repeat until no query tab is left.

**M3-3. Check before the migration (read-only): must PASS.**
- Link: https://raw.githubusercontent.com/adriatic/triad-feedbox/17bc04c4a931353dbe4de71246980114c123ac98/supabase/checks/prod-before-migration.sql
- **165 lines.** First line `-- supabase/checks/prod-before-migration.sql | 165 lines | last line: -- end of prod-before-migration.sql`. Last line (165) `-- end of prod-before-migration.sql`.
- Paste it as described above and click **Run**.
- Expected: 5 rows. Row 0 says **"PASS: all 4 checks passed."**
- **If row 0 says FAIL** (or an error appears): **stop**. Nothing was changed, because this script only reads. Send all rows to Claude.ai. Do not run the migration.

**M3-4. Run the migration (CHANGES the database).**
- Link: https://raw.githubusercontent.com/adriatic/triad-feedbox/17bc04c4a931353dbe4de71246980114c123ac98/supabase/migrations/20261113000000_feedbox_v1.sql
- **937 lines.** This file has no header line, because it is exactly the file that ran on feedbox-preview.
  - First line: a line of `=` signs, `-- =============================================================================`.
  - Second line: `-- Feedbox v1: schema, access rules (row-level security), triggers and owner`.
  - Last line (937): `  on conflict (id) do nothing;`
- Paste it as described above and click **Run**. If the editor warns about a possibly destructive operation, check once more that the selector says `feedbox-prod`, then confirm with **Run this query**.
- Expected: **"Success. No rows returned."**
- **If an error appears:** **stop, and do not run it again.** Nothing was changed: the SQL Editor runs the pasted text as one transaction, so an error undoes the whole script (see F3c-D3). Copy the whole message and send it to Claude.ai.
  - If the message is `type "idea_status" already exists`, the migration was already applied, or the text was pasted twice.

**M3-5. Check after the migration (read-only): must PASS.**
- Link: https://raw.githubusercontent.com/adriatic/triad-feedbox/17bc04c4a931353dbe4de71246980114c123ac98/supabase/checks/prod-after-migration.sql
- **227 lines.** First line `-- supabase/checks/prod-after-migration.sql | 227 lines | last line: -- end of prod-after-migration.sql`. Last line (227) `-- end of prod-after-migration.sql`.
- Paste it as described above and click **Run**.
- Expected: 15 rows. Row 0 says **"PASS: all 14 checks passed."**
- **If row 0 says FAIL:** **stop**. The migration **is** applied (M3-4 changed the database), but this check changed nothing. Send all rows to Claude.ai. Do not run the board script, and do not try to undo anything on your own.

**M3-6. Check that prod is ready for its board (read-only): must PASS.**
- Link: https://raw.githubusercontent.com/adriatic/triad-feedbox/17bc04c4a931353dbe4de71246980114c123ac98/supabase/checks/prod-ready-for-board.sql
- **169 lines.** First line `-- supabase/checks/prod-ready-for-board.sql | 169 lines | last line: -- end of prod-ready-for-board.sql`. Last line (169) `-- end of prod-ready-for-board.sql`.
- Paste it as described above and click **Run**.
- Expected: 6 rows. Row 0 says **"PASS: all 5 checks passed."**
- **If row 0 says FAIL:** **stop**. The migration is applied and there is no board yet; this check changed nothing. Send all rows to Claude.ai. Do not run the board script.

**M3-7. Add the Feedbox board (CHANGES the database: one row).**
- Link: https://raw.githubusercontent.com/adriatic/triad-feedbox/17bc04c4a931353dbe4de71246980114c123ac98/supabase/production/board-feedbox.sql
- **60 lines.** First line `-- supabase/production/board-feedbox.sql | 60 lines | last line: -- end of board-feedbox.sql`. Last line (60) `-- end of board-feedbox.sql`.
- Paste it as described above and click **Run**.
- Expected: **"Success. No rows returned."**
- **If it says "Refused: …":** **stop**. Nothing was changed, as the message says. It may also say the script was pasted twice, or already ran. Copy the message and send it to Claude.ai.
- **If any other error appears:** **stop, and do not run it again.** Nothing was changed, because the script is all or nothing. Send the whole message to Claude.ai.

**M3-8. Check the board (read-only): must PASS.**
- Link: https://raw.githubusercontent.com/adriatic/triad-feedbox/17bc04c4a931353dbe4de71246980114c123ac98/supabase/checks/prod-board.sql
- **181 lines.** First line `-- supabase/checks/prod-board.sql | 181 lines | last line: -- end of prod-board.sql`. Last line (181) `-- end of prod-board.sql`.
- Paste it as described above and click **Run**.
- Expected: 6 rows. Row 0 says **"PASS: all 5 checks passed."**
- **If row 0 says FAIL:** **stop**. The migration and the board row **are** in feedbox-prod (M3-4 and M3-7 changed the database), but this check changed nothing. Send all rows to Claude.ai, and change nothing on your own.

**M3-9. Send your record to the TRIAD chat.**
1. In the Mac **Notes** app, open the note where you recorded M3-1 to M3-8 (results and screenshots).
2. In the menu bar, choose **File → Export as PDF…**, choose where to save it (for example Desktop), and click **Save**.
3. In Claude.ai, open the TRIAD chat, click the **+** (attach) button, choose the PDF you just saved, and send it.

## Links and hashes

- Pull request #2: https://github.com/adriatic/triad-feedbox/pull/2
- Merge commit: https://github.com/adriatic/triad-feedbox/commit/17bc04c4a931353dbe4de71246980114c123ac98
- Tag `f3`: https://github.com/adriatic/triad-feedbox/releases/tag/f3
- Approved head (now merged): `f65d62355695c33c8fcbff4a9b6c849467a626d8`
- Migration as applied on feedbox-preview: `423572ca740d43a64cc9b88d71b5df4918c6f9c6`
- Production: https://triad-feedbox-delta.vercel.app
- Vercel deployment of the merge commit: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/4p59rV7fbUtRjbk1QZKVhnp59gmw

## Check before pushing

I searched this report for `TODO`, `TBD`, `XXX`, `{{` and angle-bracket placeholders, and found none. Every requested item is present:
- the first line;
- the merge commit hash;
- the pull-request link;
- the check results;
- the ruleset as it now stands;
- the tag;
- the Production check;
- the byte-for-byte confirmation of every pinned file against `f65d623` (and the migration against `423572c`);
- Steps M3-1 to M3-9, each script with its pinned link, line count and last line, each failure with what to do, marked as waiting for Claude.ai's go-ahead.
