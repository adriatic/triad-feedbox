DO NOT RUN ANY SQL YET. Claude.ai reads the undo script first.

# Task F3b: a script to undo the Feedbox migration on feedbox-prod (Nik's decision B)

Date: 2026-11-13. Branch `f3-database`, pull request #2 (still open, not merged). Nothing was run against any hosted database.

## Decisions Nik must make

None new. One thing to know before step 3 below: the migration's section 10 created a `profiles` row for **every person who already existed in `auth.users`** on feedbox-prod. If anyone had signed up there before 3:22 PM, `profiles` is not empty. In that case the undo script **refuses and changes nothing**, as the task requires ("nothing may be dropped if any Feedbox row exists anywhere"). Step 2 below is a read-only pre-check that shows this before anything is run. If it shows a profile, stop and ask Claude.ai.

## Summary

| Item | Value |
|---|---|
| New head of `f3-database` | `fb13cc76dcbd9e8dedfe98518b83cbe37a328786` (previous head `944f0079f398d2bb0584cf81d5aecf06c5421037`) |
| Undo script | `supabase/production/undo-feedbox-v1.sql`, **101 lines** |
| Read-only check | `supabase/production/check-undo-feedbox-v1.sql`, 16 lines |
| Migration and seed | unchanged |
| Pull request | https://github.com/adriatic/triad-feedbox/pull/2 |
| Undo script, pinned | https://raw.githubusercontent.com/adriatic/triad-feedbox/fb13cc76dcbd9e8dedfe98518b83cbe37a328786/supabase/production/undo-feedbox-v1.sql |
| Check, pinned | https://raw.githubusercontent.com/adriatic/triad-feedbox/fb13cc76dcbd9e8dedfe98518b83cbe37a328786/supabase/production/check-undo-feedbox-v1.sql |

Both pinned links were checked: each serves a file byte-for-byte equal to the committed one.

## How the script works

- **One statement:** the whole script is one `do $undo$ … $undo$;` block, so it is all or nothing. If the guard refuses, or any drop fails, nothing changes. It has no psql commands.
- **Guard first, before any change:**
  - For each of the 8 tables (`boards`, `profiles`, `board_owners`, `ideas`, `votes`, `comments`, `changelog_entries`, `changelog_items`), it refuses if the table does not exist ("Refused: table public.X does not exist…") or has any row ("Refused: table public.X has rows…").
  - It then refuses if `auth.users` has any email ending `@lumen.example`.
  - Every refusal ends with "Nothing was changed."
- **Named drops, no CASCADE:** each object is dropped by its exact name and signature. If anything outside the migration depends on a Feedbox object, the drop fails and the whole block is undone, instead of silently removing that other object too.
- **`pg_trgm` is left in schema `extensions`, for three reasons** (also stated in the script):
  - The migration only ran `create extension if not exists`, so the script cannot tell whether the migration created it or it was already there.
  - It holds no data and is not in an exposed schema.
  - The migration's `if not exists` simply finds it again when it is re-applied in M3. Locally, the re-applied migration printed `NOTICE: extension "pg_trgm" already exists, skipping`.
- **What the migration changed outside its own objects:** I checked its grants and revokes. Every one is on a Feedbox table, sequence, function or the schema `private`, so dropping those objects removes them. The migration changed nothing on other objects.

## Every object the script drops

1. **Trigger:** `on_auth_user_created` on `auth.users`.
2. **Tables (8), in one `drop table` statement:** `public.changelog_items`, `public.changelog_entries`, `public.comments`, `public.votes`, `public.ideas`, `public.board_owners`, `public.profiles`, `public.boards`.
   - This also removes what belongs to them: their 19 row-level security policies, their indexes and constraints, the 9 triggers on them, their grants, and the identity sequences `public.ideas_id_seq` and `public.comments_id_seq`.
   - The 9 triggers are:
     - on `ideas`: `ideas_rate_limit`, `ideas_before_insert`, `ideas_before_update`, `ideas_after_insert`;
     - on `comments`: `comments_rate_limit`, `comments_after_change`;
     - on `votes`: `votes_rate_limit`, `votes_after_change`;
     - on `changelog_items`: `changelog_items_check`.
3. **Functions in `public` (10):**
   - `is_board_owner(uuid)`
   - `has_display_name()`
   - `set_idea_status(bigint, public.idea_status)`
   - `merge_ideas(bigint, bigint)`
   - `hide_idea(bigint)`
   - `unhide_idea(bigint)`
   - `hide_comment(bigint)`
   - `unhide_comment(bigint)`
   - `publish_changelog_entry(uuid, boolean)`
   - `similar_ideas(uuid, text, integer, boolean)`
4. **Functions in `private` (9):**
   - `recent_count(text, uuid)`
   - `handle_new_user()`
   - `enforce_rate_limit()`
   - `ideas_before_insert()`
   - `ideas_before_update()`
   - `ideas_after_insert()`
   - `votes_after_change()`
   - `comments_after_change()`
   - `changelog_items_check()`
5. **Type:** `public.idea_status`.
6. **Schema:** `private`. It is dropped without CASCADE, so the drop fails if anything else is in it.

**Not dropped:** the extension `pg_trgm`, for the reasons above.

## Local results (local Supabase in Docker only)

Everything below ran as the role `postgres`, which is not a superuser (`rolsuper = f`), the same role the SQL Editor uses. `auth.users` is owned by `supabase_auth_admin`, and `postgres` could still drop the trigger on it.

**(a) Migration only, then the undo script.**
- **Setup:** `npx supabase db reset --no-seed` left 0 users and 0 profiles.
- **Undo:** the script finished without error (exit 0).
- **Check afterwards** (`check-undo-feedbox-v1.sql`):

  | Column | Value |
  |---|---|
  | `boards_table` | NULL |
  | `private_schema` | NULL |
  | `idea_status_type` | NULL |
  | `auth_trigger_count` | 0 |
  | `feedbox_function_count` | 0 |

  No relation was left in schema `public`. `pg_trgm` is still in `extensions`.
- **The migration applies cleanly again:** running the migration file once more succeeded (only `NOTICE: extension "pg_trgm" already exists, skipping`). All 8 tables are back with RLS enabled.
- **Tests on the re-applied schema:** `Files=10, Tests=225, Result: PASS`.
- **Same schema as a fresh install:** I compared a `pg_dump --schema-only` of `public` and `private` from the re-applied migration with one from a fresh reset. The dump includes grants. The two are **identical**, 1206 lines each.

**(b) Migration plus seed, then the undo script: refused, nothing changed.**
```
ERROR:  Refused: table public.boards has rows. This script only removes an empty Feedbox schema. Nothing was changed.
```
The counts were the same before and after:

| Item | Before | After |
|---|---|---|
| Users | 221 | 221 |
| Profiles | 221 | 221 |
| Boards | 1 | 1 |
| Ideas | 10 | 10 |
| Votes | 1059 | 1059 |
| Comments | 9 | 9 |
| Feedbox functions | 19 | 19 |
| `on_auth_user_created` triggers | 1 | 1 |

**Extra: migration only, plus one ordinary person in `auth.users` (no Lumen).** This is the case described under "Decisions". The script refused: `Refused: table public.profiles has rows. … Nothing was changed.` Afterwards `boards` and `private` still existed, and the profile row was still there.

**(c) Normal reset, then the full suite:** `npx supabase db reset` followed by `npx supabase test db` gave `Files=10, Tests=225, Result: PASS`.

## CI results (on `fb13cc7`)

CI_RESULTS

## Steps for Nik, later

**⚠️ WAITING FOR CLAUDE.AI'S GO-AHEAD. Do not start these steps until Claude.ai has read the undo script and says so.** These steps are for **feedbox-prod only**. Do not run anything on feedbox-preview.

1. **Confirm the project.** In Chrome, open https://supabase.com/dashboard, choose the organisation **TRIAD**, then the project **feedbox-prod**. Check that the project selector at the top of the page says **`feedbox-prod`** (it was called "TRIAD prod" before your rename). If it says anything else, stop.
2. **Read-only pre-check.** In the left menu, click **SQL Editor**, then **+ New query**. Paste the following and click **Run**:
   ```sql
   select
     (select count(*) from auth.users)                                  as all_people,
     (select count(*) from auth.users where email like '%@lumen.example') as lumen_people,
     (select count(*) from public.profiles)          as profiles,
     (select count(*) from public.boards)            as boards,
     (select count(*) from public.board_owners)      as owners,
     (select count(*) from public.ideas)             as ideas,
     (select count(*) from public.votes)             as votes,
     (select count(*) from public.comments)          as comments,
     (select count(*) from public.changelog_entries) as entries,
     (select count(*) from public.changelog_items)   as items;
   ```
   Expected: one row. Every column from `lumen_people` to `items` should be **0**. `all_people` is shown for information.
   - If `profiles` (or any other column after `all_people`) is not 0, **stop** and send the result to Claude.ai. The undo script would refuse anyway.
   - If the query fails with "relation … does not exist", **stop** and send the result to Claude.ai. It means you are not in the project that has the Feedbox tables.
3. **Copy the undo script, exactly as reviewed.** In a new Chrome tab, open
   https://raw.githubusercontent.com/adriatic/triad-feedbox/fb13cc76dcbd9e8dedfe98518b83cbe37a328786/supabase/production/undo-feedbox-v1.sql
   This address is pinned to the reviewed commit. Click into the page, press **Cmd+A**, then **Cmd+C**.
4. **Run it.** Back in the SQL Editor, click **+ New query**, press **Cmd+V**, and click **Run**.
   - The editor will probably warn about a destructive operation (the script drops tables). Check once more that the project selector says `feedbox-prod`, then confirm with **Run this query**.
   - Expected: **"Success. No rows returned."**
   - If it says "Refused: …", nothing was changed. Copy the message and send it to Claude.ai.
   - If any other error appears, **do not run it again**: copy the whole message and send it to Claude.ai. The script is all or nothing, so an error means nothing was changed.
5. **Read-only check afterwards.** Click **+ New query**. Paste the contents of
   https://raw.githubusercontent.com/adriatic/triad-feedbox/fb13cc76dcbd9e8dedfe98518b83cbe37a328786/supabase/production/check-undo-feedbox-v1.sql
   (or this same text) and click **Run**:
   ```sql
   select
     to_regclass('public.boards')       as boards_table,
     to_regnamespace('private')         as private_schema,
     to_regtype('public.idea_status')   as idea_status_type,
     (select count(*) from pg_trigger
       where tgname = 'on_auth_user_created'
         and tgrelid = 'auth.users'::regclass) as auth_trigger_count,
     (select count(*) from pg_proc
       where pronamespace = 'public'::regnamespace
         and proname in ('is_board_owner', 'has_display_name', 'set_idea_status',
                         'merge_ideas', 'hide_idea', 'unhide_idea', 'hide_comment',
                         'unhide_comment', 'publish_changelog_entry', 'similar_ideas')
     ) as feedbox_function_count;
   ```
   Expected: one row with `boards_table` **NULL**, `private_schema` **NULL**, `idea_status_type` **NULL**, `auth_trigger_count` **0** and `feedbox_function_count` **0**.
6. Tell Claude.ai the results of steps 2, 4 and 5 (screenshots are fine). Do not run the migration, the seed or `board-feedbox.sql` on feedbox-prod now. The migration is applied there again after the merge, in M3.

## Links and hashes

- Pull request #2: https://github.com/adriatic/triad-feedbox/pull/2
- New head of `f3-database`: `fb13cc76dcbd9e8dedfe98518b83cbe37a328786`
- Commit: https://github.com/adriatic/triad-feedbox/commit/fb13cc76dcbd9e8dedfe98518b83cbe37a328786
- Migration as applied on feedbox-prod (unchanged): https://raw.githubusercontent.com/adriatic/triad-feedbox/423572ca740d43a64cc9b88d71b5df4918c6f9c6/supabase/migrations/20261113000000_feedbox_v1.sql

## Check before sending

I searched this report for `TODO`, `TBD`, `XXX`, `{{`, `CI_RESULTS`, `RAW_CHECK` and angle-bracket placeholders, and found none. Every requested item is present:
- the first line;
- the new head commit;
- the script's line count;
- every object dropped;
- the local results (a), (b) and (c);
- the CI results;
- the read-only check;
- "Steps for Nik, later", marked as waiting for Claude.ai and starting with the feedbox-prod project check.
