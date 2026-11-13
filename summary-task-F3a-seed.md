DO NOT RUN ANY SQL YET. Claude.ai reads the seed first.

# Task F3a: make the Lumen seed run in the Supabase SQL Editor

Date: 2026-11-13. Branch `f3-database`, pull request #2 (still open, not merged).

## Decisions Nik must make

None. The migration is unchanged (it is already applied on feedbox-preview as reviewed). Only `supabase/seed.sql` changed.

## Summary

| Item | Value |
|---|---|
| New head of `f3-database` | `944f0079f398d2bb0584cf81d5aecf06c5421037` (previous head `423572ca740d43a64cc9b88d71b5df4918c6f9c6`) |
| Files changed | `supabase/seed.sql` only |
| Seed line count | 202 (was 205) |
| Migration | `supabase/migrations/20261113000000_feedbox_v1.sql`, unchanged (937 lines) |
| Pull request | https://github.com/adriatic/triad-feedbox/pull/2 |
| Pinned seed for review and for Nik | https://raw.githubusercontent.com/adriatic/triad-feedbox/944f0079f398d2bb0584cf81d5aecf06c5421037/supabase/seed.sql (checked: byte-for-byte equal to the committed file) |

## What changed and why

**What failed on feedbox-preview:** the old seed was 13 separate statements. Statement 7 created a temporary table `lumen_ideas`, and statements 8 to 13 read it. In the SQL Editor the run stopped with `42P01: relation "lumen_ideas" does not exist`, and nothing from the seed was saved.

**The new seed is ONE statement:** a single plpgsql `do $seed$ … $seed$;` block. Nothing has to survive from one statement to the next, whatever way the SQL Editor sends the text.
- **Ideas:** the ten ideas (title, body, status, votes, author, created_at, shipped_at) are now a `jsonb` constant declared inside the block, `v_ideas`. They are read with `jsonb_to_recordset` wherever the temporary table was read before: the idea insert, the timestamp update, the vote insert and the final check. There is no temporary table any more, so no `create temporary table` or `drop table`. The editor should therefore not warn about a destructive operation.
- **Board id:** the board's id is kept in a variable (`insert … returning id into v_board`) instead of being looked up by slug each time.
- **Refusal:** it is kept. If a board with slug `lumen` exists, the block raises "The Lumen board already exists. The seed has run before; nothing was changed." before anything else.
- **Data:** the people, board, owner, ideas, votes, comments and changelog are the same. Text, ids and times were copied unchanged.
- **Final check (slightly stricter):** it now also reports an idea that is missing, not only one whose count is wrong, and it is limited to the Lumen board.
- **All or nothing:** a `do` block is one statement. If any step or the final check fails, the whole seed is undone.
- **Still runnable in the SQL Editor:** it has no psql commands and no `begin` or `commit`.

## Local results (local Supabase in Docker only)

1. **Reset with the new seed:** `npx supabase db reset` ran "Applying migration 20261113000000_feedbox_v1.sql… Seeding data from supabase/seed.sql… Finished". Afterwards:

   | Item | Count |
   |---|---|
   | People at `@lumen.example` | 221 |
   | Boards | 1 |
   | Owners | 1 |
   | Ideas | 10 |
   | Votes | 1059 |
   | Comments | 9 |
   | Changelog entries | 2 |
   | Changelog items | 3 |

   Vote counts: 214, 187, 132, 121, 96, 88, 73, 58, 49, 41.
2. **pgTAP:** `npx supabase test db` gave `Files=10, Tests=225, Result: PASS`. It passed again after every later reset.
3. **Second run is refused, and nothing changes:** the new seed was run again on the seeded database, as one statement through psql in the local container. The result:
   ```
   ERROR:  The Lumen board already exists. The seed has run before; nothing was changed.
   CONTEXT:  PL/pgSQL function inline_code_block line 44 at RAISE
   ```
   Before and after, the counts were the same: users 221, profiles 221, boards 1, owners 1, ideas 10, votes 1059, comments 9, entries 2, items 3. The newest row version in `ideas` (`xmin`) was also unchanged, at 1082.
4. **Same data as the old seed:** I reset with `--no-seed`, ran the old seed (from `423572c`) through psql, and dumped the data. The dump covered people with display names, the board, the owner, every idea column, the non-author votes with times, comments, changelog entries and items. I compared it with the same dump from the new seed: **identical**, 1306 lines each. The authors' own votes were left out of the line-by-line diff, because their times come from `now()`. The vote counts above confirm them.
5. **A failed check undoes everything:** on an empty database (`--no-seed`), I ran a copy of the new seed changed so that "Dark mode for the editor" gets one vote too few. The result was `ERROR: Seed check failed: Dark mode for the editor has 213, expected 214`. Afterwards there were 0 users, 0 boards, 0 ideas and 0 votes. That copy lives only in the scratchpad and was not committed. Then I ran a normal reset: 225 tests pass.

## Why the temporary table disappeared: no documented reason found

I searched for Supabase documentation, knowledge-base articles and GitHub issues that say how the Dashboard SQL Editor sends a multi-statement script: whether it uses one session or one connection per statement, and whether it splits statements. **I found no documented statement that explains it**, so I am not giving a cause.
- **Closest Supabase page:** the knowledge-base article "Resolving 42P01: relation does not exist error" (https://supabase.com/kb/troubleshooting/resolving-42p01-relation-does-not-exist-error-W4_9-V). It is about this error code in general, not about temporary tables in the SQL Editor.
- **What PostgreSQL itself documents:** a temporary table exists only in the session that created it. So the error is consistent with the later statements running in a different session from the one that created the table. That is a consistent explanation, not a documented fact about the SQL Editor.
- **Either way:** the new seed does not depend on it, because it is one statement.

## CI results (on `944f007`)

Both workflow runs, https://github.com/adriatic/triad-feedbox/actions/runs/43527386283 (push) and https://github.com/adriatic/triad-feedbox/actions/runs/43527394452 (pull_request), ran on head `944f0079f398d2bb0584cf81d5aecf06c5421037` and concluded `success`.


| Check | Result |
|---|---|
| `lint` | pass (push run 43527386283: 27s; pull_request run 43527394452: 33s) |
| `typecheck` | pass (push 21s; pull_request 22s) |
| `unit` | pass (push 21s; pull_request 18s) |
| `db` | pass (push 48s; pull_request 43s). Log: `Files=10, Tests=225, Result: PASS` |
| `Vercel` | pass (Preview deployment completed) |

## Steps for Nik, later

**⚠️ WAITING FOR CLAUDE.AI'S GO-AHEAD. Do not start these steps until Claude.ai has read the new seed and says so.** They are for **feedbox-preview only**, where the migration is already applied (steps 1 to 5 of F3 are done; do not repeat them). Steps 6 and 7 below replace steps 6 and 7 of the F3 report.

6. **Copy and run the seed.** In Chrome, open https://supabase.com/dashboard, choose the organisation **TRIAD** and the project **feedbox-preview**, and check that the name at the top says `feedbox-preview`. In a new tab, open
   https://raw.githubusercontent.com/adriatic/triad-feedbox/944f0079f398d2bb0584cf81d5aecf06c5421037/supabase/seed.sql
   This address is pinned to the new commit. Click into the page, press **Cmd+A**, then **Cmd+C**. Back in the dashboard, click **SQL Editor**, then **+ New query**, press **Cmd+V**, and click **Run**.
   - Expected: **"Success. No rows returned."**
   - If the editor shows a warning, read it, then confirm with **Run this query**.
   - If it says "The Lumen board already exists", the seed had already run, and nothing was changed.
   - If any other error appears, **do not run it again**: copy the whole message and send it to Claude.ai. The seed is all or nothing, so an error means nothing was saved.
7. **Check the seed.** Click **+ New query**, paste the following and click **Run**:
   ```sql
   select title, status, vote_count, comment_count from public.ideas order by vote_count desc;
   ```
   Expected: these 10 rows.

   | title | status | vote_count | comment_count |
   |---|---|---|---|
   | Dark mode for the editor | planned | 214 | 3 |
   | Export notes to Markdown | building | 187 | 2 |
   | Offline mode | planned | 132 | 1 |
   | Pin notes to the top of a notebook | shipped | 121 | 0 |
   | Keyboard shortcut cheat sheet | shipped | 96 | 0 |
   | Faster startup on large notebooks | shipped | 88 | 0 |
   | Sync between two laptops | open | 73 | 2 |
   | Search inside attachments | open | 58 | 0 |
   | Share a note by link | open | 49 | 0 |
   | Tag notes by colour | open | 41 | 1 |

   Then tell Claude.ai the results of steps 6 and 7 (screenshots are fine). Do not run `supabase/production/board-feedbox.sql` anywhere yet.

## Links and hashes

- Pull request #2: https://github.com/adriatic/triad-feedbox/pull/2
- New head of `f3-database`: `944f0079f398d2bb0584cf81d5aecf06c5421037`
- Commit: https://github.com/adriatic/triad-feedbox/commit/944f0079f398d2bb0584cf81d5aecf06c5421037
- Migration (unchanged, as applied on feedbox-preview): https://raw.githubusercontent.com/adriatic/triad-feedbox/423572ca740d43a64cc9b88d71b5df4918c6f9c6/supabase/migrations/20261113000000_feedbox_v1.sql

## Check before sending

I searched this report for `TODO`, `TBD`, `XXX`, `{{`, `CI_` and angle-bracket placeholders, and found none. Every requested item is present:
- the first line;
- the new head commit;
- the seed's line count;
- what changed and why;
- the local pgTAP count;
- the second-run refusal;
- the CI results;
- the search for a documented reason, with its source;
- Steps 6 and 7 pinned to the new commit and marked as waiting for Claude.ai.
