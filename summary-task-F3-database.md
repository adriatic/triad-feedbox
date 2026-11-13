DO NOT RUN ANY SQL YET. Claude.ai reads the migration first.

# Task F3: database migration, access rules and database tests

- Repository: https://github.com/adriatic/triad-feedbox, branch `f3-database` (from `main` at `b0fec8d`)
- Pull request: **https://github.com/adriatic/triad-feedbox/pull/2** (open, not merged)
- Local folder: `/Users/nikolajivancic/Work/triad-feedbox`
- Date: 2026-11-13
- **Nothing was applied to a hosted database.** I ran no `supabase login` and no `supabase link`, used no secret key, and ran no SQL against feedbox-preview or feedbox-prod. Everything ran on a local Supabase database in Docker (colima) and on the CI runner.

---

## Decisions Nik must make

| # | Decision | Recommendation |
|---|---|---|
| F3-D1 | **Ranking of similar ideas.** Plain trigram matching (D7) ranks by the best-matching word. For "Sync notes" on the Lumen board it lists Export notes to Markdown, Pin notes to the top of a notebook and Tag notes by colour (all 0.55) **before** Sync between two laptops (0.45), because "notes" is a longer shared word than "sync". The right idea is still among the five suggestions, a typo ("synch") finds it first, and "dark theme" finds Dark mode for the editor. | **Accept for v1.** The better ranking (weighting rare words above common ones) is a later small change to `similar_ideas` only. |
| F3-D2 | **One extra owner function, `unhide_comment`.** The task listed `hide_comment` only. F1 says hidden items can be unhidden, so I added it, mirroring `unhide_idea`. | **Accept.** |
| F3-D3 | **Who can see who voted.** F1 section 3 said votes are readable by "anyone (counts)". In the migration a person sees **only their own** vote rows, which is all the vote button needs. Counts come from `ideas.vote_count`, which is public. So nobody can list who voted for what. | **Accept** (more private, and costs nothing). |
| F3-D4 | **The Preview seed creates 221 invented people** in `auth.users` on feedbox-preview (8 named, plus 213 voters, all `@lumen.example`, which cannot receive email). This makes every vote count a real row, so the counts match the design exactly and stay right. "Ana" (`ana@lumen.example`) is made owner of the Lumen board for later tests. Nobody can sign in as them. | **Accept.** |

Smaller choices inside the decided design, for Claude.ai's review (no answer needed):
- `comment_count` counts comments that are **not hidden**, so the number on the board matches what visitors can read.
- A signed-in person needs a display name before posting, voting or commenting. This is enforced in the policies through `has_display_name()` (F1 section 4).
- Rate-limited actions raise SQLSTATE `P0001` with the message "You are posting quickly. Try again in a few minutes." and detail `rate_limit:idea`, `rate_limit:comment` or `rate_limit:vote`.
- Owner functions raise `42501` for "not an owner", `P0002` for "not found" and `23514` for a refused rule.

---

## For Claude.ai's line-by-line review

### The migration file
- Path: **`supabase/migrations/20261113000000_feedbox_v1.sql`**
- Lines: **937**
- Commit (the last one that touches it, and the head of the branch): **`423572ca740d43a64cc9b88d71b5df4918c6f9c6`**
- Exact file at that commit: https://github.com/adriatic/triad-feedbox/blob/423572ca740d43a64cc9b88d71b5df4918c6f9c6/supabase/migrations/20261113000000_feedbox_v1.sql
- Sections: 1 extension, schema and type · 2 tables · 3 indexes · 4 helper functions · 5 triggers · 6 owner functions · 7 `similar_ideas` · 8 privileges (revoke everything, then grant) · 9 RLS and policies · 10 profiles for existing users
- It contains no psql commands, no `begin`/`commit`, and no board or idea rows. Its only data write is section 10: a profile row (no name) for every user who already exists in `auth.users`.
- Other files in this pull request: `supabase/seed.sql` (Lumen, Preview only), `supabase/production/board-feedbox.sql` (one board row, prod only), `supabase/tests/*.sql` and `_helpers.psql`, `supabase/config.toml` (local only), `supabase/templates/magic_link.html`.

### Tables and row-level security

| Table | RLS | Purpose |
|---|---|---|
| `boards` | **enabled** | one row per board; created by SQL only |
| `profiles` | **enabled** | `id`, `display_name`, `created_at`; no email |
| `board_owners` | **enabled** | who owns which board; rows added by SQL only |
| `ideas` | **enabled** | ideas, with counts, status, merge and hide state |
| `votes` | **enabled** | primary key `(idea_id, user_id)`: one vote per person per idea |
| `comments` | **enabled** | flat comments, with `moved_from_idea_id` and hide state |
| `changelog_entries` | **enabled** | releases; `published_at` null means draft |
| `changelog_items` | **enabled** | one line per shipped idea; `idea_id` unique (at most one entry) |

There are exactly these 8 tables in `public` (checked by a test), and RLS is enabled on all 8 (one test each). Where a table has no policy for a command, that command is refused.

### Every policy

| Table | Policy | Command | Role | Condition |
|---|---|---|---|---|
| boards | boards_read | SELECT | anon, authenticated | `true` |
| profiles | profiles_read | SELECT | anon, authenticated | `true` |
| profiles | profiles_update_own | UPDATE | authenticated | using and check: `id = (select auth.uid())` |
| board_owners | board_owners_read | SELECT | authenticated | `user_id = (select auth.uid()) or is_board_owner(board_id)` |
| ideas | ideas_read | SELECT | anon, authenticated | `hidden_at is null or is_board_owner(board_id)` |
| ideas | ideas_insert_own | INSERT | authenticated | check: `author_id = (select auth.uid()) and has_display_name()` |
| votes | votes_read_own | SELECT | authenticated | `user_id = (select auth.uid())` |
| votes | votes_insert_own | INSERT | authenticated | check: `user_id = (select auth.uid()) and has_display_name() and exists (idea with that id, hidden_at is null, merged_into_id is null)` |
| votes | votes_delete_own | DELETE | authenticated | `user_id = (select auth.uid())` |
| comments | comments_read | SELECT | anon, authenticated | `exists (idea i visible to the reader with i.id = comments.idea_id and (comments.hidden_at is null or is_board_owner(i.board_id)))` |
| comments | comments_insert_own | INSERT | authenticated | check: `author_id = (select auth.uid()) and has_display_name() and exists (idea not hidden, not merged)` |
| changelog_entries | changelog_entries_read | SELECT | anon, authenticated | `published_at is not null or is_board_owner(board_id)` |
| changelog_entries | changelog_entries_insert_owner | INSERT | authenticated | check: `is_board_owner(board_id)` |
| changelog_entries | changelog_entries_update_owner | UPDATE | authenticated | using and check: `is_board_owner(board_id)` |
| changelog_entries | changelog_entries_delete_owner | DELETE | authenticated | `is_board_owner(board_id)` |
| changelog_items | changelog_items_read | SELECT | anon, authenticated | `exists (entry with e.id = entry_id)`, so it is visible exactly when its entry is |
| changelog_items | changelog_items_insert_owner | INSERT | authenticated | check: `exists (entry e with e.id = entry_id and is_board_owner(e.board_id))` |
| changelog_items | changelog_items_update_owner | UPDATE | authenticated | using and check: the same as insert |
| changelog_items | changelog_items_delete_owner | DELETE | authenticated | the same as insert |

There are 19 policies in total; the list above is taken from `pg_policies` on the local database. There is deliberately no policy (and no grant) for: insert, update or delete on `boards` and `board_owners`; insert and delete on `profiles`; update and delete on `ideas`; update on `votes`; update and delete on `comments`.

### Grants left to anon and authenticated (after "revoke all")

| Object | anon | authenticated |
|---|---|---|
| `boards` | SELECT | SELECT |
| `profiles` | SELECT | SELECT; UPDATE (`display_name`) |
| `board_owners` | none | SELECT |
| `ideas` | SELECT | SELECT; INSERT (`board_id`, `title`, `body`) |
| `votes` | none | SELECT; INSERT (`idea_id`); DELETE |
| `comments` | SELECT | SELECT; INSERT (`idea_id`, `body`) |
| `changelog_entries` | SELECT | SELECT; INSERT (`board_id`, `title`, `released_on`); UPDATE (`title`, `released_on`); DELETE |
| `changelog_items` | SELECT | SELECT; INSERT (`entry_id`, `idea_id`, `note`, `position`); UPDATE (`note`, `position`); DELETE |
| sequences `ideas_id_seq`, `comments_id_seq` | none | none (identity columns need no sequence grant; inserts are tested) |
| `is_board_owner(uuid)`, `has_display_name()`, `similar_ideas(uuid, text, integer, boolean)` | EXECUTE | EXECUTE |
| `set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment`, `publish_changelog_entry` | none | EXECUTE (each then checks ownership) |
| schema `private` | none | USAGE |
| `private.recent_count(text, uuid)` | none | EXECUTE (needed by the rate-limit trigger; `private` is not exposed by the API) |
| all other `private` functions (trigger functions) | none | none |

Every other privilege was revoked: tables and sequences from anon and authenticated; functions from public, anon and authenticated. `service_role` keeps the platform defaults, and the app never uses it. All of these values are checked by tests in `01_structure.sql`.

Columns that nobody writes through the API: `ideas.author_id` (default `auth.uid()`), `status`, `vote_count`, `comment_count`, `merged_into_id`, `hidden_at`, `hidden_by`, `status_changed_at`, `shipped_at`, `created_at`, `updated_at`; `votes.user_id` (default `auth.uid()`); `comments.author_id` (default), `moved_from_idea_id`, `hidden_at`, `hidden_by`; `changelog_entries.published_at`, `created_by` (default); `profiles.id`.

### Security definer functions and what they check
All of them run `set search_path = ''` and name every schema in full. A test checks this for every function in `public` and `private`, the security invoker ones included.

| Function | Checks, in order | Then |
|---|---|---|
| `public.is_board_owner(board)` | none (it is the check) | true if `board_owners` has (board, `auth.uid()`). Definer, so the `board_owners` policy can call it without looping. |
| `public.set_idea_status(idea, status)` | idea exists (locked `for update`), else P0002 → caller owns its board, else 42501 → idea not merged → new status differs ("The idea is already Planned.") | update status. The trigger then sets `status_changed_at` and `shipped_at`, and refuses to leave Shipped while the idea is in a changelog entry. |
| `public.merge_ideas(source, target)` | not the same idea → both locked in id order → both exist (P0002) → caller owns the source's board (42501) → same board → source not merged → target not merged → target not hidden → source not in a changelog entry | copy votes to target `on conflict do nothing`, delete source votes, move comments (setting `moved_from_idea_id`), repoint ideas merged into the source, set `source.merged_into_id`; return the target's vote count |
| `public.hide_idea(idea)` / `unhide_idea(idea)` | idea exists (P0002) → caller owns its board (42501) | set (keeping the first value) or clear `hidden_at` and `hidden_by` |
| `public.hide_comment(comment)` / `unhide_comment(comment)` | comment exists (P0002) → caller owns the board of its idea (42501) | set or clear `hidden_at` and `hidden_by` |
| `public.publish_changelog_entry(entry, publish = true)` | entry exists (locked; P0002) → caller owns its board (42501) → when publishing, at least one line ("Pick at least one shipped idea.") | set `published_at` (keeping the first value), or clear it to unpublish |
| `private.recent_count(kind, user)` | kind is idea, comment or vote | count that person's rows in the last hour (definer, so hidden rows count too) |
| `private.handle_new_user()` (trigger on `auth.users`) | none | insert a profile (no name) `on conflict do nothing` |
| `private.ideas_before_insert()` (trigger) | none | `status_changed_at = now()`; `shipped_at` set only for Shipped |
| `private.ideas_before_update()` (trigger) | leaving Shipped while in a changelog entry → refused (F2-D2), **even for a direct SQL update by the database owner** | stamps `status_changed_at`, `shipped_at` and `updated_at` (`updated_at` only for real changes, not counts) |
| `private.ideas_after_insert()` (trigger) | none | the author's vote |
| `private.votes_after_change()` (trigger) | none | `vote_count` +1 or −1 (never below 0) |
| `private.comments_after_change()` (trigger) | none | `comment_count` follows insert, delete, hide, unhide and move |
| `private.changelog_items_check()` (trigger) | the idea is on the entry's board and is Shipped | this runs **before** RLS, so its messages never name the idea; a test proves a hidden title does not leak |

Security **invoker** functions (the caller's own rules apply): `public.has_display_name()`, `public.similar_ideas(...)`, and `private.enforce_rate_limit()`. The rate-limit trigger is deliberately invoker: `current_user` is then the request's role, so only `anon` and `authenticated` requests are limited, while rows written inside owner functions (for example votes moved by a merge) are not. A test covers exactly that case.

### F2-D2 rules in the database
1. An idea in a changelog entry stays Shipped: trigger `ideas_before_update`, plus checks in `set_idea_status` and `merge_ideas`.
2. A display name may not contain "@": check constraint `profiles_display_name_check` (also 2 to 40 characters, one line, single spaces).
3. Changelog entry title at most 80 characters and each line at most 280: check constraints `changelog_entries_title_check` and `changelog_items_note_check`.

---

## pgTAP results

**225 tests in 10 files, all passing**, both locally and in CI (`Files=10, Tests=225, Result: PASS`).

| File | Tests | What it proves |
|---|---|---|
| `01_structure.sql` | 49 | the 8 tables exist; RLS is on for each; `search_path = ''` on every function; the exact table, column, sequence, function and schema privileges listed above; no email column anywhere; anon and authenticated cannot read `auth.users` |
| `02_boards_profiles_owners.sql` | 23 | boards are read-only; profile on sign-up; own display name only; the "@" and length rules; nobody inserts or deletes profiles; owners list visibility; nobody makes themselves an owner; `is_board_owner` |
| `03_ideas.sql` | 24 | hidden ideas visible to owners only; posting with a name (author, Open, author's vote); refused without a name, as a visitor, in another's name, with a status or a vote count; title and body limits; **no direct writes of `vote_count`, `status` or `hidden_at`, not even by the owner**; no edits, no deletes |
| `04_votes.sql` | 20 | vote allowed; second vote refused (`votes_pkey`); a double click is harmless; no voting as someone else, on hidden or merged ideas, without a name, or as a visitor; only your own votes are visible; unvote own only; count equals rows |
| `05_comments.sql` | 22 | comment allowed; refused in another's name, empty, too long, on hidden or merged ideas, without a name, as a visitor; no edits or deletes; hide and unhide by the owner only, with count and visibility |
| `06_owner_functions.sql` | 20 | `set_idea_status` (owner only, not another board's owner, same status refused, Shipped sets and clears `shipped_at`, not found); `hide_idea` and `unhide_idea` (owner only; visibility) |
| `07_merge.sql` | 15 | owner only; not into itself, across boards, into a hidden or merged idea, nor twice; **4 voters after merging 3 + 2 votes with one person on both**; comments moved with `moved_from_idea_id`; earlier merges repointed |
| `08_changelog.sql` | 31 | owner-only entries and lines; drafts hidden; title ≤ 80 and line ≤ 280 (boundaries included); only Shipped ideas from the same board; at most one entry per idea; publish owner only and not when empty; unpublish; stays Shipped while in an entry; no title leak |
| `09_rate_limits.sql` | 9 | the 6th idea, the 31st comment and the 101st vote in an hour are refused; older rows stop counting; a merge is not limited |
| `10_similar_ideas.sql` | 12 | suggestions for "Sync notes"; the closest title first; typo; < 3 characters; unrelated words; hidden, merged and other-board ideas never suggested; limit; title only by default; details on request |

**The tests do catch broken rules.** As a check, I switched off RLS on `ideas` and `votes` in the local database and granted `update` on `ideas` to authenticated. The suite then failed 25 tests in 5 files. After `supabase db reset`, all 225 passed again.

**Bugs the tests found and I fixed before the pull request:**
1. The rate-limit trigger referred to `new.user_id` and `new.author_id` in one expression, and PL/pgSQL rejected the missing field. It now uses separate branches.
2. The changelog line check named the idea in its error message, before RLS could refuse a non-owner. The message is now generic.

## CI check names

Workflow `CI` (`.github/workflows/ci.yml`):
1. `lint`
2. `typecheck`
3. `unit` (77 Vitest tests)
4. **`db` (new):** `npm ci`, then `npx supabase db start` (a local database in Docker on the runner, which applies the migration and `seed.sql`), then `npx supabase test db`. No keys, no hosted project.

All green on pull request #2, for both the push run (43507877124) and the pull-request run (43507909444). `Vercel` passed too. **For M3:** add `db` to the required status checks of the `main` ruleset.

## Pull request
**https://github.com/adriatic/triad-feedbox/pull/2**: "F3: database migration, access rules and database tests". Opened with gh (`~/gh-cli`, `env -u GH_TOKEN`). Not merged.

## Commit hashes

| Commit | Content |
|---|---|
| `f721c69` | CLAUDE.md: gh note (`~/gh-cli`, `env -u GH_TOKEN`, never print a token); the F2 token-workaround lines removed |
| `dbc2a57` | Supabase CLI 3.1.0 as a pinned dev dependency, `supabase/config.toml` (local only, ports 5542x), magic link template |
| `1dbc594` | the migration |
| `42d7218` | `supabase/seed.sql` and `supabase/production/board-feedbox.sql` |
| `1b186e6` | pgTAP tests |
| `1286a74` | CI job `db`; CLAUDE.md database rules and commands; npm scripts `db:start`, `db:reset`, `db:stop`, `test:db` |
| `423572ca740d43a64cc9b88d71b5df4918c6f9c6` | the changelog line check no longer names the idea, plus its test. **Head of `f3-database`; the migration as it is to be reviewed.** |
| `main` (unchanged) | `b0fec8dadb42c9849b7a75d7b6b6e3af53aaa118` |
| this report on `cc-reports` | given in the closing message |

## npm audit (recheck)
No change since F2: **7 moderate** findings, all in the same chain (`minimatch` inside `typescript-eslint`, used only while linting). `typescript-eslint` 8.72.2 is still the newest release, so no fix exists yet. The Supabase CLI added no findings.

## Notes
- **Local ports:** the default local Supabase ports (5432x) are used by pactresearch-web's local stack on this Mac. I did not touch it. Feedbox's local stack uses 5542x (`supabase/config.toml`).
- `supabase/seed.sql` refuses to run twice. If the board `lumen` exists, it stops with "The Lumen board already exists…" and changes nothing. `board-feedbox.sql` uses `on conflict do nothing`.
- The seed ends with its own check that every vote count matches the design brief.
- Out of scope, and not done: app code using the database, sign-in, screens, making Nik an owner.

---

## Steps for Nik, later

**⚠️ WAITING FOR CLAUDE.AI'S GO-AHEAD. Do not start these steps until Claude.ai has read the migration and says so.** These steps are for **feedbox-preview only**. feedbox-prod comes in a later task.

1. In Chrome, open https://supabase.com/dashboard, choose the organisation **TRIAD** and then the project **feedbox-preview**. Check that the name at the top of the page says `feedbox-preview`.
2. **Read-only pre-check.** In the left menu, click **SQL Editor**, then **+ New query**. Paste the following and click **Run**:
   ```sql
   select extname, extnamespace::regnamespace as schema from pg_extension where extname = 'pg_trgm';
   select to_regclass('public.ideas') as ideas_table, to_regnamespace('private') as private_schema;
   ```
   Expected: the first result has **no rows** (or one row with schema `extensions`). The second shows **NULL** for both. If `pg_trgm` is in schema `public`, or either value is not NULL, stop and send the result to Claude.ai.
3. **Copy the migration, exactly as reviewed.** In a new Chrome tab, open
   https://raw.githubusercontent.com/adriatic/triad-feedbox/423572ca740d43a64cc9b88d71b5df4918c6f9c6/supabase/migrations/20261113000000_feedbox_v1.sql
   This address is pinned to the reviewed commit. Click into the page, press **Cmd+A**, then **Cmd+C**.
4. **Run the migration.** Back in the SQL Editor, click **+ New query**, press **Cmd+V**, and click **Run**. If the editor warns about a possibly destructive operation, read it, then confirm with **Run this query**. Expected: **"Success. No rows returned."** If an error appears, **do not run it again**: copy the whole message and send it to Claude.ai.
5. **Check the migration.** **+ New query**, paste and **Run**:
   ```sql
   select relname as table_name, relrowsecurity as rls_enabled
   from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' order by 1;
   ```
   Expected: 8 rows (`board_owners`, `boards`, `changelog_entries`, `changelog_items`, `comments`, `ideas`, `profiles`, `votes`), each with `rls_enabled` = **true**.
6. **Copy and run the seed.** Open
   https://raw.githubusercontent.com/adriatic/triad-feedbox/423572ca740d43a64cc9b88d71b5df4918c6f9c6/supabase/seed.sql
   Press **Cmd+A**, **Cmd+C**. In the SQL Editor click **+ New query**, press **Cmd+V**, and click **Run**. The seed ends with `drop table lumen_ideas` (a temporary helper table), so the editor will probably warn about a destructive operation; confirm with **Run this query**. Expected: **"Success. No rows returned."** If it says "The Lumen board already exists", the seed had already run, and nothing was changed.
7. **Check the seed.** **+ New query**, paste and **Run**:
   ```sql
   select title, status, vote_count, comment_count from public.ideas order by vote_count desc;
   ```
   Expected: 10 rows, from **Dark mode for the editor, planned, 214, 3** down to **Tag notes by colour, open, 41, 1**.
8. Tell Claude.ai the results of steps 4 to 7 (screenshots are fine). Do not run `supabase/production/board-feedbox.sql` anywhere yet; it is for feedbox-prod, in a later task.

---

## Check before sending
I searched this report for `TODO`, `TBD`, `XXX`, `{{` and angle-bracket placeholders, and found none. Every requested item is present: the first line; the decisions; the migration's path, line count (937) and commit; the table of tables with RLS state; every policy (19); every grant; every security definer function with its checks; the pgTAP results (225, all passing); the CI check names with `db`; the pull-request link; the commit hashes; the npm audit recheck; and "Steps for Nik, later", marked as waiting for Claude.ai.
