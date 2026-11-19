# Task F6a: merge with undo

Repository `adriatic/triad-feedbox`, branch `f6-owner-tools`, pull request #10 (https://github.com/adriatic/triad-feedbox/pull/10), not merged.

- **Previous head:** `5cca3a06533e26ad3b765a4d1f0abe1ee143af74` (task F6).
- **New head:** `25fc4fe8ce49112fb9143f422d56d0f1421c0808` ("F6a: merge with undo").
- **Why:** after running F6 on the Preview, Nik rejected "There is no undo. A wrong merge can only be repaired by hand in the database." (TRIAD chat, 2026-11-18 5:54-6:06 PM). Decision **F1-D8** ("no undo in v1") is replaced: an owner can undo any merge from the app, and a wrong merge never needs SQL.
- **Hosted databases:** nothing was run against feedbox-preview or feedbox-prod. No migration that has run was edited: the v1 and O2 migrations keep their pinned sha256. No dashboard setting changed.

## What was built

**1. A new migration**, `supabase/migrations/20261118120000_merge_undo.sql` (344 lines, sha256 `60a9681b612a90a1c7db046bee0b75fe598499d490da993d60f7707d51e037f7`, pinned in `tests/sql-files.test.ts`):

- **The merge log, in two tables** (both with row-level security):
  - `public.idea_merges`, one row per merge. It holds the board, the source, the target, the owner who merged (`merged_by`) and the time (`merged_at`); the comments the merge moved (`moved_comment_ids`); the ideas merged earlier into the source that the merge pointed at the target (`rerouted_idea_ids`); and when and by whom it was undone (`undone_at`, `undone_by`). The **owners of the board read it** (policy `idea_merges_read_owner`). Nobody writes it except through the two functions.
  - `public.idea_merge_votes`, one row per vote the merge took from the source. It holds who, when they voted, whether the merge added a vote for them on the target (`added_to_target`), and whether they removed their vote on the target since (`target_vote_removed_at`).
    - **Nobody reads it through the API, not even an owner:** who voted for what is private (a person reads only their own votes). It has RLS on, no policy and no grant; only the functions use it.
    - The task asked for one log table. The votes are kept apart for that privacy reason, and so that a person's rows go with them when they are removed (`on delete cascade` on `profiles`).
  - **No email anywhere:** `tests/sql-files.test.ts` checks that the migration has no "mail" and no "@"; `01_structure.sql` checks that no table has an email column.
- **`merge_ideas`, new version:**
  - The same name, arguments and result, and the same rules and messages, so the app's call did not change. `create or replace` keeps its owner and grants, and the migration grants it again explicitly.
  - Before anything moves, it writes the log row and one vote row per voter on the source. Then it does what version 1 did.
- **`undo_merge(p_merge_id)`, new and for owners only.** It is security definer with `search_path ''` and checks `is_board_owner`. It returns the vote count of the idea that is back on the board.
  - **The source is back as it was:** the same row and address, and the same title, details, author, date and status. Ideas merged into it before point at it again.
  - **Votes:**
    - Everyone whose vote the merge took counts on the source again, as long as they still have their vote on the target.
    - The target loses the votes the merge added. A person who had voted for both keeps a vote on each.
  - **Comments:** the comments the merge moved go back, with the mark they had before. A comment that came into the source from an earlier merge keeps its "From the merged idea" line.
  - **In between:** anything done between the merge and the undo stays where it was made.
    - A new vote or comment on the target stays.
    - A person who removed their vote on the target in the meantime gets it back on neither idea; see decision F6a-D1. The trigger `votes_after_delete_merge_log` notes such an unvote in the log. It is security invoker like the rate-limit trigger, so only a person's own unvote through the app counts, never votes moved by the functions.
  - **Two merges into one target, the older undone first:** a vote that the newer merge also took (a person who voted for both sources) stays on the target. From then on it belongs to the newer merge, whose own undo takes it.
  - **Refusals.** Each is a plain sentence the app shows, and nothing is changed:

    | Case | Message |
    |---|---|
    | Not an owner | "Only an owner of this board can do this." (42501) |
    | Unknown merge | "Merge not found." (P0002) |
    | Undone already | "This merge has already been undone." |
    | The merged idea was removed | "The merged idea no longer exists, so this merge cannot be undone." |
    | The target was removed | "The idea it was merged into no longer exists, so this merge cannot be undone." |
    | The target has itself been merged since | "“<target>” has itself been merged into another idea since. Undo that merge first, on the page of the idea it was merged into." |
    | Safety net | "“<source>” is no longer merged into “<target>”, so there is nothing to undo." |

- **Privileges:**
  - Everything on the new tables and the sequence is revoked from `anon` and `authenticated`; then only `select` on `idea_merges` is granted to `authenticated`.
  - Execute on the four new or replaced functions is revoked from `public`, `anon` and `authenticated`; then `merge_ideas` and `undo_merge` are granted to `authenticated`.
  - `private.note_merged_vote_removed` is also granted to `authenticated`, like `private.recent_count`, because the unvote trigger runs as the caller. It only marks the caller's own rows (`auth.uid()`), and `private` is not exposed by the API.

**2. The app:**

- **The target's page, for owners:**
  - It always shows one note per idea merged into it, newest first: "“<source>” was merged into this idea." (`getMergeNotes` in `lib/supabase/data.ts`, `mergeNotes` in `lib/feedbox/merge.ts`).
  - A merge in the log that is not undone has the button **Undo merge** (`UndoMergeButton` in `OwnerTools.tsx`, which calls the server action `undoMerge` and so `undo_merge`).
  - Right after a merge, the note also says "Its votes and comments are here now: N votes in all."
- **After Undo merge:**
  - The owner stays on the target at `/ideas/<target>?unmerged=<source>`, which reads "Merge undone: “<source>” is back on the board, with N votes and M comments. Open “<source>”" (the last part is a link). The note is gone.
  - A display bug found by the new e2e test is fixed: the vote button kept the old count when the page reloaded at the same address. It is now keyed by the count.
- **Members and visitors never see Undo merge.**
  - A visitor or member who opens the source's old address still lands on the target with the note, as before.
  - Opening the target directly shows them no note.
- **The merge question is plain.** Before the button, the merge panel now reads "Merge “<source>” into “<target>”? You can undo this from that idea’s page." "There is no undo" and "by hand in the database" are gone.
- **Merges made before this migration** (for example your F6-7 merge of "Sync notes" into "F5b check: sync over the local network" on the Preview) have no log row. Their note stays on the target's page for owners, **without** an Undo merge button.
  - The same goes for an idea that was merged into another idea that was then merged here. It can be undone in turn once that later merge is undone.
  - If the log cannot be read at all (a database without this migration), the notes show without the button and the reason goes to the server log; the page does not break.

**3. SQL is code.** Four new scripts, in the O2 pattern; they are given in full below.

- `supabase/apply/preview-merge-undo.sql` (458 lines) and `supabase/apply/prod-merge-undo.sql` (459 lines): ONE do-block, all or nothing. They refuse, and change nothing, if:
  - the project marker names another project or is missing;
  - the merge log already exists (run before), or the script was pasted twice into one query (detected with `xmin` and `pg_current_xact_id()`);
  - the database is not exactly the v1 + O2 migrations (fingerprint `ea60181fdd11e237aa19ee5d6d6c186d`).

  Their section 4 is the migration's statements word for word (a unit test checks this).
- `supabase/checks/preview-merge-undo.sql` and `supabase/checks/prod-merge-undo.sql` (248 lines each): one read-only SELECT with 8 checks:
  1. the project;
  2. the fingerprint of v1 + O2 + F6a, `2814d0ac55dce9fa93db839da532dec7` (taken from a fresh local install, and equal to what the pasted apply script builds);
  3. both log tables, with RLS on;
  4. who reads the log;
  5. `merge_ideas` writes the log, and only signed-in people may call it;
  6. `undo_merge` likewise;
  7. the unvote trigger is on;
  8. every merge that can still be undone names an idea that is merged.
- The prod versions are ready. As in O2, you run them on feedbox-prod only in the merge task, **before** the merge.
- **The removal template** `supabase/people/remove-person.sql` and its check `supabase/checks/person-removal.sql` now expect the v1 + O2 + F6a fingerprint, because they must work on the database as it will be. The check also counts the person's rows in the merge log. They are templates and have never run.
  - `supabase/preview/owner-nik.sql` and its check have run and were not changed. They still expect the O2 fingerprint and are tested in the O2 state.

**4. Docs:** `docs/ARCHITECTURE.md` (sections 1.2, 1.3, 3.10, 5, 6 and 7), README (Owners and Privacy) and the CLAUDE.md layout; see "docs/ARCHITECTURE.md and README changes" below.

## Tests

- **pgTAP, new file `supabase/tests/12_merge_undo.sql`** (51 tests; all pgTAP: 299, was 243):
  - **The log:** the board, source, target, owner, the 3 moved comments and the idea merged earlier into the source; every vote taken, and which ones the merge added.
  - **Refused while the target is itself merged since**, with nothing changed.
  - **In between:** pat votes for the target, kim comments on it, max removes his vote, and ned removes his vote and votes again. The log notes max and ned.
  - **Who may undo:** a member, the owner of another board and a visitor cannot; an unknown merge is "not found"; the refusals change nothing.
  - **The undo:**
    - the source is identical to a snapshot taken before the merge (id, board, author, title, details, status, date, not merged);
    - its voters are exactly sam, lee and joe (max and ned removed theirs in between);
    - the target is left with kim, lee, ned and pat: lee voted for both and keeps it, and pat's and ned's new votes stay;
    - the counts are right;
    - the moved comments are identical to the snapshot, and the new comment stays on the target;
    - the earlier merged idea points at the source again, and the log records who undid it.
  - **A second undo** of the same merge is refused; then the older merge can be undone too, with joe's vote and comment back on "Older duplicate".
  - **Merge again after an undo**, and undo again; the log keeps both merges.
  - **Two merges into one target, the older undone first:** kim keeps a vote on each, and pat's vote stays on the target, now held by the second merge. Then the second undo brings all three ideas back to exactly their votes before.
  - **Refused when the merged idea was removed.**
  - **Reading and writing the log:**
    - an owner reads only their own board's merges;
    - not even an owner reads `idea_merge_votes`, or can insert, update or delete `idea_merges`;
    - a member reads no merge and cannot read the votes;
    - a visitor can read neither table.
- **pgTAP `01_structure.sql`** now expects ten tables, `select` on `idea_merges` for `authenticated`, `undo_merge` callable by `authenticated` only, and `private.note_merged_vote_removed` as the second private function `authenticated` may call.
- **SQL harness** `scripts/test-sql-checks.sh`: **200 expectations met** (was 149).
  - **New section G2** (feedbox-prod):
    - the check FAILs before the script runs;
    - the preview script is refused here;
    - refused if the migration was changed, without the O2 migration, or without a marker;
    - refused when pasted twice;
    - then it runs, and the check PASSes;
    - the check FAILs on 13 tampered states: wrong project; `idea_merge_votes` readable; `idea_merges` readable by visitors or writable; RLS off; the policy dropped; an open policy; `undo_merge` for visitors or without `search_path`; `merge_ideas` as invoker; the trigger off; `undo_merge` dropped; an extra grant;
    - a second run is refused.
  - **New section L** (feedbox-preview with you as owner, like now): the same refusals.
    - With the pasted functions, "Nik" merges two test ideas, and the check then counts 1 open merge. He undoes it, and both ideas are back at 1 vote, not merged.
    - A member cannot undo.
    - After F6a, the older preview checks FAIL as they should (the fingerprint changed).
  - **New section M:** `supabase db reset` with all three migration files gives exactly the fingerprint the pasted scripts give (the check PASSes).
  - **Moved to the O2 state** (`reset --version 20261118000000`): sections I and J, so `owner-nik.sql` is still tested where it ran.
  - **Section K** (removal) now runs on the F6a database: Del's vote is in a merge's log, and after the removal Del's log rows are gone while Nik's stays.
- **Unit:** 182 tests (was 164):
  - `mergeNotes` (3 tests);
  - in `tests/sql-files.test.ts`: the migration's sha256; no email in it; each apply script runs the migration word for word and uses the shared fingerprint block; preview and prod differ only in the project; and which fingerprint each template expects.
- **e2e:** 17 tests (was 16).
  - **New:** "an owner merges and undoes the merge: both ideas, their counts and comments are as before (task F6a)".
    - It reads every field of both ideas, every vote and every comment from the database before the merge.
    - It merges through the app, checks the note and the count, and checks that a member and a visitor never see Undo merge, not even on the address from the merge.
    - It clicks Undo merge and checks the message. Then it reads the database again: **exactly equal**.
    - It opens the source through the link (its comment carries no merged mark) and finds both ideas on the board as a visitor.
  - The F6 merge test now checks the new question, that no "no undo" text is left, and the Undo merge button.
- **Local runs, all passing:** lint, typecheck, unit 182, pgTAP 299, SQL harness 200 of 200, e2e 17.

## Results

| What | Result |
|---|---|
| Head | `25fc4fe8ce49112fb9143f422d56d0f1421c0808` |
| CI push run 44444579337 | lint, typecheck, unit, db, e2e: all pass |
| CI pull request run 44444584836 | lint, typecheck, unit, db, e2e: all pass (no re-run needed) |
| Vercel | success (Preview of the branch) |
| Pull request #10 | open, mergeable, not merged |

- Preview: https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app
- Migration (pinned): https://github.com/adriatic/triad-feedbox/blob/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/migrations/20261118120000_merge_undo.sql

## Images

- **`screenshots/F5/`:**
  - `idea-owner-merge-*` (4 images) recaptured: the merge panel with the new question;
  - `idea-owner-merged-*` (4 images) new: the target's page right after a merge, with the note and Undo merge, light and dark, 1280 and 390 px.

  The new state merges a test idea into "Dark mode for the editor" through the app and undoes it through the app after each capture, so the Lumen data is unchanged ("Dark mode for the editor" read 214 votes and 3 comments before and after).
- **`/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/F5-side-by-side/`:**
  - **`Idea.png`** remade: `Idea.dc.html` beside the owner's idea page, captioned "Built (F6a)".
  - **`IdeaMerged.png`** new: `Idea.dc.html` beside the target's page with the note and Undo merge. The design has no such note; the note uses the board's "planned" blue, like the visitor's merged note, and its button is the ordinary white button of the Owner tools.

## The SQL you run, in full

Order on feedbox-preview (steps F6a-3 to F6a-8): `supabase/apply/preview-merge-undo.sql`, then `supabase/checks/preview-merge-undo.sql`, which must say "PASS: all 8 checks passed."

The prod versions are run only in the merge task, before the merge, in the same order.

Pinned links (raw, commit 25fc4fe):

- https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/apply/preview-merge-undo.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/checks/preview-merge-undo.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/apply/prod-merge-undo.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/checks/prod-merge-undo.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/migrations/20261118120000_merge_undo.sql

### The migration: `supabase/migrations/20261118120000_merge_undo.sql`

Pinned: https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/migrations/20261118120000_merge_undo.sql

```sql
-- =============================================================================
-- Feedbox F6a: a merge can be undone from the app (Nik, 2026-11-18 5:54-6:06
-- PM; replaces decision F1-D8 "no undo in v1"). Task F6a.
--
-- * Adds the merge log: public.idea_merges (one row per merge: board, source,
--   target, the owner, the time, the comments it moved, the ideas it pointed
--   at the target, and when and by whom it was undone) and
--   public.idea_merge_votes (one row per person whose vote on the source the
--   merge took: when they voted, whether the merge added a vote for them on
--   the target, and whether they removed their vote on the target since).
-- * Replaces public.merge_ideas (same name, arguments and result, so the
--   app's call does not change) with a version that also writes the log.
-- * Adds public.undo_merge(p_merge_id), for owners only. It refuses, and
--   changes nothing, when the undo cannot be done safely.
-- * Row-level security on both new tables. Owners of the board read
--   idea_merges (no email, no vote in it). Nobody reads idea_merge_votes
--   through the API: who voted for what is private (a person reads only their
--   own votes), so only the two functions use it. Nobody writes either table
--   except through the functions.
-- * Every security definer function sets search_path to '' and names every
--   schema in full. Execute is revoked from public, anon and authenticated
--   (the hosted projects grant new functions automatically), then granted to
--   authenticated where needed.
-- * Merges made before this migration have no log row: their note stays on
--   the target's page, without an Undo merge button.
-- * The Feedbox v1 (20261113000000) and O2 (20261118000000) migrations are
--   never edited; this is a new migration. Nik pastes it on a hosted project
--   through the guarded copy in supabase/apply/ (task F6a), which runs
--   exactly the statements below.
-- =============================================================================

create table public.idea_merges (
  id                bigint generated always as identity primary key,
  board_id          uuid not null references public.boards (id) on delete cascade,
  source_id         bigint references public.ideas (id) on delete set null,
  target_id         bigint references public.ideas (id) on delete set null,
  merged_by         uuid references public.profiles (id) on delete set null,
  merged_at         timestamptz not null default now(),
  moved_comment_ids bigint[] not null default '{}',
  rerouted_idea_ids bigint[] not null default '{}',
  undone_at         timestamptz,
  undone_by         uuid references public.profiles (id) on delete set null,
  constraint idea_merges_two_ideas check (source_id <> target_id)
);

create unique index idea_merges_one_open_per_source on public.idea_merges (source_id) where undone_at is null;
create index idea_merges_target_idx on public.idea_merges (target_id);
create index idea_merges_board_idx on public.idea_merges (board_id);

create table public.idea_merge_votes (
  merge_id               bigint not null references public.idea_merges (id) on delete cascade,
  user_id                uuid not null references public.profiles (id) on delete cascade,
  source_voted_at        timestamptz not null,
  added_to_target        boolean not null,
  target_vote_removed_at timestamptz,
  primary key (merge_id, user_id)
);

create index idea_merge_votes_user_idx on public.idea_merge_votes (user_id);

-- A person who removes their vote on the target after a merge: noted in the
-- log, so an undo neither gives them that vote back on the source nor takes a
-- later vote of theirs from the target. Only their own rows, by auth.uid().
create function private.note_merged_vote_removed(p_idea_id bigint)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.idea_merge_votes mv
    set target_vote_removed_at = now()
    from public.idea_merges m
    where m.id = mv.merge_id
      and m.target_id = p_idea_id
      and m.undone_at is null
      and mv.user_id = (select auth.uid())
      and mv.target_vote_removed_at is null;
$$;

-- Security INVOKER on purpose, like the rate-limit trigger: current_user is
-- then the role of the request. Only a person's own unvote through the app
-- counts; votes moved by merge_ideas and undo_merge (which run as the
-- function owner) do not.
create function private.votes_after_delete_merge_log()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    perform private.note_merged_vote_removed(old.idea_id);
  end if;
  return null;
end;
$$;

create trigger votes_after_delete_merge_log
  after delete on public.votes
  for each row execute function private.votes_after_delete_merge_log();

-- Merges the source idea into the target (F1 section 5) and writes the log.
-- Returns the target's new vote count. The same rules as in version 1.
create or replace function public.merge_ideas(p_source_id bigint, p_target_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source public.ideas;
  v_target public.ideas;
  v_merge  bigint;
  v_count  integer;
begin
  if p_source_id = p_target_id then
    raise exception 'An idea cannot be merged into itself.' using errcode = 'check_violation';
  end if;

  -- Lock both rows, always in id order, so two merges cannot deadlock.
  perform 1 from public.ideas
    where id in (p_source_id, p_target_id) order by id for update;
  select * into v_source from public.ideas where id = p_source_id;
  select * into v_target from public.ideas where id = p_target_id;

  if v_source.id is null or v_target.id is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_source.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_source.board_id <> v_target.board_id then
    raise exception 'Both ideas must be on the same board.' using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is not null then
    raise exception 'This idea has already been merged.' using errcode = 'check_violation';
  end if;
  if v_target.merged_into_id is not null then
    raise exception 'The target idea has itself been merged.' using errcode = 'check_violation';
  end if;
  if v_target.hidden_at is not null then
    raise exception 'The target idea is hidden. Unhide it first, or pick another idea.' using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.changelog_items ci where ci.idea_id = p_source_id) then
    raise exception 'This idea is in a changelog entry. Remove it from the entry first.' using errcode = 'check_violation';
  end if;

  -- The log, written before anything moves: the comments that will move and
  -- the ideas merged earlier into the source, which will point at the target.
  insert into public.idea_merges (board_id, source_id, target_id, merged_by, moved_comment_ids, rerouted_idea_ids)
  values (
    v_source.board_id, p_source_id, p_target_id, (select auth.uid()),
    array(select c.id from public.comments c where c.idea_id = p_source_id order by c.id),
    array(select i.id from public.ideas i where i.merged_into_id = p_source_id order by i.id)
  )
  returning id into v_merge;

  -- Every vote on the source, and whether the merge adds a vote on the target for that person.
  insert into public.idea_merge_votes (merge_id, user_id, source_voted_at, added_to_target)
    select v_merge, v.user_id, v.created_at,
           not exists (select 1 from public.votes t where t.idea_id = p_target_id and t.user_id = v.user_id)
    from public.votes v
    where v.idea_id = p_source_id;

  -- Votes: everyone who voted on the source gets a vote on the target unless
  -- they already have one; then the source's votes go. Triggers keep both
  -- counts right, so nobody is counted twice.
  insert into public.votes (idea_id, user_id, created_at)
    select p_target_id, v.user_id, v.created_at
    from public.votes v
    where v.idea_id = p_source_id
    on conflict (idea_id, user_id) do nothing;
  delete from public.votes where idea_id = p_source_id;

  -- Comments move to the target and remember where they came from.
  update public.comments
    set idea_id = p_target_id,
        moved_from_idea_id = coalesce(moved_from_idea_id, p_source_id)
    where idea_id = p_source_id;

  -- Ideas merged earlier into the source now point straight at the target.
  update public.ideas set merged_into_id = p_target_id where merged_into_id = p_source_id;
  update public.ideas set merged_into_id = p_target_id where id = p_source_id;

  select vote_count into v_count from public.ideas where id = p_target_id;
  return v_count;
end;
$$;

comment on function public.merge_ideas(bigint, bigint) is
  'Merges the source idea into the target and writes the merge log (task F6a). Owners only. Returns the target''s new vote count.';

-- Undoes one merge from the log (task F6a). Owners only. Returns the vote
-- count of the idea that is back on the board.
-- * The source idea is back on the board as it was: same row, same address;
--   ideas that pointed at it before the merge point at it again.
-- * Everyone whose vote on the source the merge took counts on it again,
--   unless they removed their vote on the target since.
-- * The target loses the votes the merge added to it, unless that person
--   removed the vote since (then there is nothing to take) or another merge
--   into the same target that is still in place took a vote of theirs too
--   (then that merge now holds the vote, and its own undo takes it).
--   A person who had voted for both before the merge keeps a vote on each.
-- * The comments the merge moved go back, with the mark they had before.
--   Anything else done in between (a new vote or comment on the target,
--   hiding, a status) stays where it was made.
create function public.undo_merge(p_merge_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_merge  public.idea_merges;
  v_source public.ideas;
  v_target public.ideas;
  v_count  integer;
begin
  select * into v_merge from public.idea_merges where id = p_merge_id for update;
  if v_merge.id is null then
    raise exception 'Merge not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_merge.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_merge.undone_at is not null then
    raise exception 'This merge has already been undone.' using errcode = 'check_violation';
  end if;
  if v_merge.source_id is null then
    raise exception 'The merged idea no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
  end if;
  if v_merge.target_id is null then
    raise exception 'The idea it was merged into no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
  end if;

  -- Lock both ideas, always in id order, as merge_ideas does.
  perform 1 from public.ideas
    where id in (v_merge.source_id, v_merge.target_id) order by id for update;
  select * into v_source from public.ideas where id = v_merge.source_id;
  select * into v_target from public.ideas where id = v_merge.target_id;

  if v_target.merged_into_id is not null then
    raise exception '“%” has itself been merged into another idea since. Undo that merge first, on the page of the idea it was merged into.', v_target.title
      using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is distinct from v_target.id then
    raise exception '“%” is no longer merged into “%”, so there is nothing to undo.', v_source.title, v_target.title
      using errcode = 'check_violation';
  end if;

  -- 1. The source is back on the board; ideas merged into it before point at it again.
  update public.ideas set merged_into_id = null where id = v_source.id;
  update public.ideas set merged_into_id = v_source.id
    where id = any (v_merge.rerouted_idea_ids) and merged_into_id = v_target.id;

  -- 2. Votes back on the source: everyone the merge took a vote from, who
  --    still has a vote on the target and has not removed it since.
  insert into public.votes (idea_id, user_id, created_at)
    select v_source.id, mv.user_id, mv.source_voted_at
    from public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.target_vote_removed_at is null
      and exists (select 1 from public.votes t where t.idea_id = v_target.id and t.user_id = mv.user_id)
    on conflict (idea_id, user_id) do nothing;

  -- 3. Votes the merge added to the target go, unless removed since, or
  --    another merge into the same target that is still in place also took a
  --    vote of that person's (then that merge holds the vote from now on).
  delete from public.votes t
    using public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.added_to_target
      and mv.target_vote_removed_at is null
      and t.idea_id = v_target.id
      and t.user_id = mv.user_id
      and not exists (
        select 1
        from public.idea_merge_votes other
        join public.idea_merges om on om.id = other.merge_id
        where om.target_id = v_target.id and om.undone_at is null and om.id <> v_merge.id
          and other.user_id = mv.user_id and other.target_vote_removed_at is null
      );
  update public.idea_merge_votes other
    set added_to_target = true
    from public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.added_to_target
      and mv.target_vote_removed_at is null
      and other.user_id = mv.user_id
      and other.target_vote_removed_at is null
      and other.merge_id = (
        select min(om.id)
        from public.idea_merges om
        join public.idea_merge_votes o2 on o2.merge_id = om.id
        where om.target_id = v_target.id and om.undone_at is null and om.id <> v_merge.id
          and o2.user_id = mv.user_id and o2.target_vote_removed_at is null
      );

  -- 4. The comments the merge moved go back to the source, with the mark
  --    they had before ("From the merged idea" only if they came from an
  --    earlier merge into the source).
  update public.comments
    set idea_id = v_source.id,
        moved_from_idea_id = case when moved_from_idea_id = v_source.id then null else moved_from_idea_id end
    where id = any (v_merge.moved_comment_ids) and idea_id = v_target.id;

  -- 5. The log says it was undone, when and by whom.
  update public.idea_merges
    set undone_at = now(), undone_by = (select auth.uid())
    where id = v_merge.id;

  select vote_count into v_count from public.ideas where id = v_source.id;
  return v_count;
end;
$$;

comment on function public.undo_merge(bigint) is
  'Undoes one merge from the merge log (task F6a). Owners only. Returns the vote count of the idea that is back on the board.';

-- Privileges. First take everything away, then grant back only what is needed.
revoke all on table public.idea_merges, public.idea_merge_votes from anon, authenticated;
revoke all on sequence public.idea_merges_id_seq from anon, authenticated;
revoke all on function
  public.merge_ideas(bigint, bigint),
  public.undo_merge(bigint),
  private.note_merged_vote_removed(bigint),
  private.votes_after_delete_merge_log()
  from public, anon, authenticated;

grant select on public.idea_merges to authenticated;
grant execute on function public.merge_ideas(bigint, bigint) to authenticated;
grant execute on function public.undo_merge(bigint) to authenticated;
-- The unvote trigger runs as the caller and notes the unvote through this
-- helper. "private" is not exposed by the API, so this does not make it callable.
grant execute on function private.note_merged_vote_removed(bigint) to authenticated;

-- Row-level security: owners of the board read the merges; nobody reads the
-- votes in the log, and nobody writes either table, except through the functions.
alter table public.idea_merges      enable row level security;
alter table public.idea_merge_votes enable row level security;

create policy idea_merges_read_owner on public.idea_merges
  for select to authenticated
  using (public.is_board_owner(board_id));
```

### Apply on feedbox-preview (steps F6a-3 to F6a-5): `supabase/apply/preview-merge-undo.sql`

Pinned: https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/apply/preview-merge-undo.sql

```sql
-- supabase/apply/preview-merge-undo.sql | 458 lines | last line: -- end of preview-merge-undo.sql
-- =============================================================================
-- Applies the migration supabase/migrations/20261118120000_merge_undo.sql
-- on feedbox-preview only (task F6a: a merge can be undone). CHANGES the database: adds
-- the merge log (tables public.idea_merges and public.idea_merge_votes), a new
-- version of public.merge_ideas that writes it, public.undo_merge, and the
-- trigger that notes an unvote on a merged idea's target. Nothing else.
-- Run once in the Supabase SQL Editor of feedbox-preview, in task F6a, before the pull request is merged.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-preview; the merge log does not exist yet; and the
--   reviewed Feedbox v1 and O2 migrations are present unchanged (the same
--   fingerprint as the check scripts). If the script was pasted twice into
--   one query, the message says so.
-- * Section 4 is the migration's statements word for word;
--   tests/sql-files.test.ts keeps them identical to the migration file.
-- * Check afterwards with supabase/checks/preview-merge-undo.sql.
-- =============================================================================

do $f6a$
declare
  v_project  text;
  v_md5      text;
  v_same_txn boolean;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-preview. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-preview' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-preview. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse to run twice (also when pasted twice into one query).
  if to_regclass('public.idea_merges') is not null then
    select c.xmin::text = (pg_current_xact_id()::xid)::text into v_same_txn
    from pg_class c where c.oid = to_regclass('public.idea_merges');
    if v_same_txn then
      raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
    end if;
    raise exception 'Refused: the merge log (public.idea_merges) already exists in this project, so this script has run before. Nothing was changed by this copy. Run supabase/checks/preview-merge-undo.sql to see its state.';
  end if;

  -- 3. Refuse unless the reviewed Feedbox v1 and O2 migrations are present unchanged.
  if to_regclass('public.boards') is null or to_regclass('public.board_owners') is null then
    raise exception 'Refused: the Feedbox migration is not applied in this project (no table public.boards or public.board_owners). Nothing was changed.';
  end if;
  with
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
  fp as (select a.md5 from mig_all a)
  select fp.md5 into v_md5 from fp;
  if v_md5 is distinct from 'ea60181fdd11e237aa19ee5d6d6c186d' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 and O2 migrations (fingerprint %, expected ea60181fdd11e237aa19ee5d6d6c186d). Nothing was changed.', v_md5;
  end if;

  -- 4. The migration 20261118120000_merge_undo.sql, word for word.
-- migration:begin
create table public.idea_merges (
  id                bigint generated always as identity primary key,
  board_id          uuid not null references public.boards (id) on delete cascade,
  source_id         bigint references public.ideas (id) on delete set null,
  target_id         bigint references public.ideas (id) on delete set null,
  merged_by         uuid references public.profiles (id) on delete set null,
  merged_at         timestamptz not null default now(),
  moved_comment_ids bigint[] not null default '{}',
  rerouted_idea_ids bigint[] not null default '{}',
  undone_at         timestamptz,
  undone_by         uuid references public.profiles (id) on delete set null,
  constraint idea_merges_two_ideas check (source_id <> target_id)
);

create unique index idea_merges_one_open_per_source on public.idea_merges (source_id) where undone_at is null;
create index idea_merges_target_idx on public.idea_merges (target_id);
create index idea_merges_board_idx on public.idea_merges (board_id);

create table public.idea_merge_votes (
  merge_id               bigint not null references public.idea_merges (id) on delete cascade,
  user_id                uuid not null references public.profiles (id) on delete cascade,
  source_voted_at        timestamptz not null,
  added_to_target        boolean not null,
  target_vote_removed_at timestamptz,
  primary key (merge_id, user_id)
);

create index idea_merge_votes_user_idx on public.idea_merge_votes (user_id);

-- A person who removes their vote on the target after a merge: noted in the
-- log, so an undo neither gives them that vote back on the source nor takes a
-- later vote of theirs from the target. Only their own rows, by auth.uid().
create function private.note_merged_vote_removed(p_idea_id bigint)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.idea_merge_votes mv
    set target_vote_removed_at = now()
    from public.idea_merges m
    where m.id = mv.merge_id
      and m.target_id = p_idea_id
      and m.undone_at is null
      and mv.user_id = (select auth.uid())
      and mv.target_vote_removed_at is null;
$$;

-- Security INVOKER on purpose, like the rate-limit trigger: current_user is
-- then the role of the request. Only a person's own unvote through the app
-- counts; votes moved by merge_ideas and undo_merge (which run as the
-- function owner) do not.
create function private.votes_after_delete_merge_log()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    perform private.note_merged_vote_removed(old.idea_id);
  end if;
  return null;
end;
$$;

create trigger votes_after_delete_merge_log
  after delete on public.votes
  for each row execute function private.votes_after_delete_merge_log();

-- Merges the source idea into the target (F1 section 5) and writes the log.
-- Returns the target's new vote count. The same rules as in version 1.
create or replace function public.merge_ideas(p_source_id bigint, p_target_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source public.ideas;
  v_target public.ideas;
  v_merge  bigint;
  v_count  integer;
begin
  if p_source_id = p_target_id then
    raise exception 'An idea cannot be merged into itself.' using errcode = 'check_violation';
  end if;

  -- Lock both rows, always in id order, so two merges cannot deadlock.
  perform 1 from public.ideas
    where id in (p_source_id, p_target_id) order by id for update;
  select * into v_source from public.ideas where id = p_source_id;
  select * into v_target from public.ideas where id = p_target_id;

  if v_source.id is null or v_target.id is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_source.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_source.board_id <> v_target.board_id then
    raise exception 'Both ideas must be on the same board.' using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is not null then
    raise exception 'This idea has already been merged.' using errcode = 'check_violation';
  end if;
  if v_target.merged_into_id is not null then
    raise exception 'The target idea has itself been merged.' using errcode = 'check_violation';
  end if;
  if v_target.hidden_at is not null then
    raise exception 'The target idea is hidden. Unhide it first, or pick another idea.' using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.changelog_items ci where ci.idea_id = p_source_id) then
    raise exception 'This idea is in a changelog entry. Remove it from the entry first.' using errcode = 'check_violation';
  end if;

  -- The log, written before anything moves: the comments that will move and
  -- the ideas merged earlier into the source, which will point at the target.
  insert into public.idea_merges (board_id, source_id, target_id, merged_by, moved_comment_ids, rerouted_idea_ids)
  values (
    v_source.board_id, p_source_id, p_target_id, (select auth.uid()),
    array(select c.id from public.comments c where c.idea_id = p_source_id order by c.id),
    array(select i.id from public.ideas i where i.merged_into_id = p_source_id order by i.id)
  )
  returning id into v_merge;

  -- Every vote on the source, and whether the merge adds a vote on the target for that person.
  insert into public.idea_merge_votes (merge_id, user_id, source_voted_at, added_to_target)
    select v_merge, v.user_id, v.created_at,
           not exists (select 1 from public.votes t where t.idea_id = p_target_id and t.user_id = v.user_id)
    from public.votes v
    where v.idea_id = p_source_id;

  -- Votes: everyone who voted on the source gets a vote on the target unless
  -- they already have one; then the source's votes go. Triggers keep both
  -- counts right, so nobody is counted twice.
  insert into public.votes (idea_id, user_id, created_at)
    select p_target_id, v.user_id, v.created_at
    from public.votes v
    where v.idea_id = p_source_id
    on conflict (idea_id, user_id) do nothing;
  delete from public.votes where idea_id = p_source_id;

  -- Comments move to the target and remember where they came from.
  update public.comments
    set idea_id = p_target_id,
        moved_from_idea_id = coalesce(moved_from_idea_id, p_source_id)
    where idea_id = p_source_id;

  -- Ideas merged earlier into the source now point straight at the target.
  update public.ideas set merged_into_id = p_target_id where merged_into_id = p_source_id;
  update public.ideas set merged_into_id = p_target_id where id = p_source_id;

  select vote_count into v_count from public.ideas where id = p_target_id;
  return v_count;
end;
$$;

comment on function public.merge_ideas(bigint, bigint) is
  'Merges the source idea into the target and writes the merge log (task F6a). Owners only. Returns the target''s new vote count.';

-- Undoes one merge from the log (task F6a). Owners only. Returns the vote
-- count of the idea that is back on the board.
-- * The source idea is back on the board as it was: same row, same address;
--   ideas that pointed at it before the merge point at it again.
-- * Everyone whose vote on the source the merge took counts on it again,
--   unless they removed their vote on the target since.
-- * The target loses the votes the merge added to it, unless that person
--   removed the vote since (then there is nothing to take) or another merge
--   into the same target that is still in place took a vote of theirs too
--   (then that merge now holds the vote, and its own undo takes it).
--   A person who had voted for both before the merge keeps a vote on each.
-- * The comments the merge moved go back, with the mark they had before.
--   Anything else done in between (a new vote or comment on the target,
--   hiding, a status) stays where it was made.
create function public.undo_merge(p_merge_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_merge  public.idea_merges;
  v_source public.ideas;
  v_target public.ideas;
  v_count  integer;
begin
  select * into v_merge from public.idea_merges where id = p_merge_id for update;
  if v_merge.id is null then
    raise exception 'Merge not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_merge.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_merge.undone_at is not null then
    raise exception 'This merge has already been undone.' using errcode = 'check_violation';
  end if;
  if v_merge.source_id is null then
    raise exception 'The merged idea no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
  end if;
  if v_merge.target_id is null then
    raise exception 'The idea it was merged into no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
  end if;

  -- Lock both ideas, always in id order, as merge_ideas does.
  perform 1 from public.ideas
    where id in (v_merge.source_id, v_merge.target_id) order by id for update;
  select * into v_source from public.ideas where id = v_merge.source_id;
  select * into v_target from public.ideas where id = v_merge.target_id;

  if v_target.merged_into_id is not null then
    raise exception '“%” has itself been merged into another idea since. Undo that merge first, on the page of the idea it was merged into.', v_target.title
      using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is distinct from v_target.id then
    raise exception '“%” is no longer merged into “%”, so there is nothing to undo.', v_source.title, v_target.title
      using errcode = 'check_violation';
  end if;

  -- 1. The source is back on the board; ideas merged into it before point at it again.
  update public.ideas set merged_into_id = null where id = v_source.id;
  update public.ideas set merged_into_id = v_source.id
    where id = any (v_merge.rerouted_idea_ids) and merged_into_id = v_target.id;

  -- 2. Votes back on the source: everyone the merge took a vote from, who
  --    still has a vote on the target and has not removed it since.
  insert into public.votes (idea_id, user_id, created_at)
    select v_source.id, mv.user_id, mv.source_voted_at
    from public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.target_vote_removed_at is null
      and exists (select 1 from public.votes t where t.idea_id = v_target.id and t.user_id = mv.user_id)
    on conflict (idea_id, user_id) do nothing;

  -- 3. Votes the merge added to the target go, unless removed since, or
  --    another merge into the same target that is still in place also took a
  --    vote of that person's (then that merge holds the vote from now on).
  delete from public.votes t
    using public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.added_to_target
      and mv.target_vote_removed_at is null
      and t.idea_id = v_target.id
      and t.user_id = mv.user_id
      and not exists (
        select 1
        from public.idea_merge_votes other
        join public.idea_merges om on om.id = other.merge_id
        where om.target_id = v_target.id and om.undone_at is null and om.id <> v_merge.id
          and other.user_id = mv.user_id and other.target_vote_removed_at is null
      );
  update public.idea_merge_votes other
    set added_to_target = true
    from public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.added_to_target
      and mv.target_vote_removed_at is null
      and other.user_id = mv.user_id
      and other.target_vote_removed_at is null
      and other.merge_id = (
        select min(om.id)
        from public.idea_merges om
        join public.idea_merge_votes o2 on o2.merge_id = om.id
        where om.target_id = v_target.id and om.undone_at is null and om.id <> v_merge.id
          and o2.user_id = mv.user_id and o2.target_vote_removed_at is null
      );

  -- 4. The comments the merge moved go back to the source, with the mark
  --    they had before ("From the merged idea" only if they came from an
  --    earlier merge into the source).
  update public.comments
    set idea_id = v_source.id,
        moved_from_idea_id = case when moved_from_idea_id = v_source.id then null else moved_from_idea_id end
    where id = any (v_merge.moved_comment_ids) and idea_id = v_target.id;

  -- 5. The log says it was undone, when and by whom.
  update public.idea_merges
    set undone_at = now(), undone_by = (select auth.uid())
    where id = v_merge.id;

  select vote_count into v_count from public.ideas where id = v_source.id;
  return v_count;
end;
$$;

comment on function public.undo_merge(bigint) is
  'Undoes one merge from the merge log (task F6a). Owners only. Returns the vote count of the idea that is back on the board.';

-- Privileges. First take everything away, then grant back only what is needed.
revoke all on table public.idea_merges, public.idea_merge_votes from anon, authenticated;
revoke all on sequence public.idea_merges_id_seq from anon, authenticated;
revoke all on function
  public.merge_ideas(bigint, bigint),
  public.undo_merge(bigint),
  private.note_merged_vote_removed(bigint),
  private.votes_after_delete_merge_log()
  from public, anon, authenticated;

grant select on public.idea_merges to authenticated;
grant execute on function public.merge_ideas(bigint, bigint) to authenticated;
grant execute on function public.undo_merge(bigint) to authenticated;
-- The unvote trigger runs as the caller and notes the unvote through this
-- helper. "private" is not exposed by the API, so this does not make it callable.
grant execute on function private.note_merged_vote_removed(bigint) to authenticated;

-- Row-level security: owners of the board read the merges; nobody reads the
-- votes in the log, and nobody writes either table, except through the functions.
alter table public.idea_merges      enable row level security;
alter table public.idea_merge_votes enable row level security;

create policy idea_merges_read_owner on public.idea_merges
  for select to authenticated
  using (public.is_board_owner(board_id));
-- migration:end
end;
$f6a$;
-- end of preview-merge-undo.sql
```

### Check on feedbox-preview (steps F6a-6 to F6a-8): `supabase/checks/preview-merge-undo.sql`

Pinned: https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/checks/preview-merge-undo.sql

```sql
-- supabase/checks/preview-merge-undo.sql | 248 lines | last line: -- end of preview-merge-undo.sql
-- =============================================================================
-- READ-ONLY check (task F6a). Changes nothing: one SELECT.
-- For: feedbox-preview. When: right after supabase/apply/preview-merge-undo.sql.
-- It checks that this is feedbox-preview (project marker); that the database is the
-- Feedbox v1, O2 and F6a migrations, all unchanged; that the merge log
-- (public.idea_merges and public.idea_merge_votes) exists with row-level
-- security; that only signed-in owners read idea_merges, and nobody reads
-- idea_merge_votes or writes either table directly; that merge_ideas writes
-- the log and undo_merge exists, both security definer with search_path '' and
-- callable by signed-in people only; that the unvote trigger is in place; and
-- that every merge in the log that can still be undone names a merged idea.
-- Result: rows (n, check_name, result, message). Row 0 is the overall result.
-- =============================================================================

with
-- shared:project:begin (the project marker; never fails if it is missing)
project as (
  select (xpath('/table/row/name/text()',
           query_to_xml('select name from triad.project', false, false, '')))[1]::text as name
  where to_regclass('triad.project') is not null
),
-- shared:project:end
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
-- shared:counts:begin (rows per Feedbox table; NULL if the table does not exist)
counts as (
  select t.name,
         case when to_regclass('public.' || t.name) is not null then
           (xpath('/table/row/n/text()',
                  query_to_xml(format('select count(*) as n from public.%I', t.name), false, false, '')))[1]::text::bigint
         end as n
  from unnest(array['boards', 'profiles', 'board_owners', 'ideas', 'votes', 'comments',
                    'changelog_entries', 'changelog_items']) as t (name)
),
people as (
  select count(*) as all_people,
         count(*) filter (where u.email like '%@lumen.example') as lumen_people
  from auth.users u
),
-- shared:counts:end
logt as (
  select c.relname::text as name,
         c.relrowsecurity as rls,
         coalesce((select string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
                     from aclexplode(c.relacl) a where a.grantee = to_regrole('authenticated')), '') as auth_privs,
         coalesce((select string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
                     from aclexplode(c.relacl) a where a.grantee = 0 or a.grantee = to_regrole('anon')), '') as others_privs,
         (select count(*) from pg_attribute t, aclexplode(t.attacl) a
           where t.attrelid = c.oid and t.attnum > 0
             and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))) as column_grants,
         (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as policies,
         (select count(*) from pg_policies p
           where p.schemaname = 'public' and p.tablename = c.relname and p.cmd = 'SELECT'
             and p.roles = array['authenticated']::name[] and p.qual = 'is_board_owner(board_id)') as owner_read_policies
  from pg_class c
  where c.oid in (to_regclass('public.idea_merges'), to_regclass('public.idea_merge_votes'))
),
fns as (
  select p.proname::text as name,
         p.prosecdef as secdef,
         coalesce(array_to_string(p.proconfig, ','), '') as config,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
         (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0)) as public_exec,
         position('public.idea_merges' in p.prosrc) > 0 as uses_log
  from pg_proc p
  where p.oid in (to_regprocedure('public.merge_ideas(bigint, bigint)'), to_regprocedure('public.undo_merge(bigint)'))
),
trg as (
  select count(*) as n
  from pg_trigger t
  where t.tgrelid = to_regclass('public.votes') and t.tgname = 'votes_after_delete_merge_log' and t.tgenabled = 'O'
),
open_merges as (
  select (xpath('/table/row/open/text()', x))[1]::text::int as open,
         (xpath('/table/row/not_merged/text()', x))[1]::text::int as not_merged
  from (select query_to_xml(
                 'select count(*) as open,
                         count(*) filter (where s.merged_into_id is null) as not_merged
                  from public.idea_merges m join public.ideas s on s.id = m.source_id
                  where m.undone_at is null and m.target_id is not null', false, false, '') as x
         where to_regclass('public.idea_merges') is not null and to_regclass('public.ideas') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-preview',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-preview.'
              else format('this project is marked %s; this check is for feedbox-preview.', (select name from project)) end
  union all
  select 2, 'migrations', a.md5 = '2814d0ac55dce9fa93db839da532dec7',
         case when a.md5 = '2814d0ac55dce9fa93db839da532dec7'
              then 'the Feedbox v1, O2 and F6a migrations are present and unchanged (fingerprint 2814d0ac55dce9fa93db839da532dec7).'
              when a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d'
              then 'the database is the Feedbox v1 and O2 migrations WITHOUT the F6a migration (fingerprint ea60181fdd11e237aa19ee5d6d6c186d, expected 2814d0ac55dce9fa93db839da532dec7). Run supabase/apply/preview-merge-undo.sql first.'
              else format('the database does not match the Feedbox v1, O2 and F6a migrations (fingerprint %s, expected 2814d0ac55dce9fa93db839da532dec7).', a.md5) end
  from mig_all a
  union all
  select 3, 'merge log', (select count(*) filter (where rls) from logt) = 2,
         format('tables found: %s (expected idea_merge_votes and idea_merges); with row-level security on: %s (expected 2).',
                coalesce((select string_agg(name, ' and ' order by name) from logt), 'none'),
                (select count(*) filter (where rls) from logt))
  union all
  select 4, 'who reads the log',
         coalesce((select auth_privs = 'SELECT' and others_privs = '' and column_grants = 0 and policies = 1 and owner_read_policies = 1
                     from logt where name = 'idea_merges'), false)
         and coalesce((select auth_privs = '' and others_privs = '' and column_grants = 0 and policies = 0
                          from logt where name = 'idea_merge_votes'), false),
         case when (select count(*) from logt) < 2 then 'the merge log is missing, so there is nothing to look at.'
              else format('idea_merges: signed-in people may: %s (expected SELECT only), visitors and everyone else: %s (expected nothing), %s rule(s), of which %s let only the board''s owners read (expected 1 and 1). idea_merge_votes: signed-in people may: %s, everyone else: %s (expected nothing for both), %s rule(s) (expected 0: nobody reads who voted).',
                          (select coalesce(nullif(auth_privs, ''), 'nothing') from logt where name = 'idea_merges'),
                          (select coalesce(nullif(others_privs, ''), 'nothing') from logt where name = 'idea_merges'),
                          (select policies from logt where name = 'idea_merges'),
                          (select owner_read_policies from logt where name = 'idea_merges'),
                          (select coalesce(nullif(auth_privs, ''), 'nothing') from logt where name = 'idea_merge_votes'),
                          (select coalesce(nullif(others_privs, ''), 'nothing') from logt where name = 'idea_merge_votes'),
                          (select policies from logt where name = 'idea_merge_votes')) end
  union all
  select 5, 'merge_ideas', coalesce((select secdef and config = 'search_path=""' and auth_exec and not anon_exec and not public_exec and uses_log
                                       from fns where name = 'merge_ideas'), false),
         case when not exists (select 1 from fns where name = 'merge_ideas') then 'the function public.merge_ideas(bigint, bigint) is MISSING.'
              else (select format('writes the merge log: %s; security definer: %s; settings: %s (expected search_path=""); signed-in people may call it: %s; visitors: %s; everyone else: %s. Expected yes, yes, yes, no, no.',
                                  case when uses_log then 'yes' else 'no' end, case when secdef then 'yes' else 'no' end,
                                  coalesce(nullif(config, ''), 'none'), case when auth_exec then 'yes' else 'no' end,
                                  case when anon_exec then 'yes' else 'no' end, case when public_exec then 'yes' else 'no' end)
                    from fns where name = 'merge_ideas') end
  union all
  select 6, 'undo_merge', coalesce((select secdef and config = 'search_path=""' and auth_exec and not anon_exec and not public_exec and uses_log
                                      from fns where name = 'undo_merge'), false),
         case when not exists (select 1 from fns where name = 'undo_merge') then 'the function public.undo_merge(bigint) is MISSING.'
              else (select format('reads the merge log: %s; security definer: %s; settings: %s (expected search_path=""); signed-in people may call it: %s; visitors: %s; everyone else: %s. Expected yes, yes, yes, no, no.',
                                  case when uses_log then 'yes' else 'no' end, case when secdef then 'yes' else 'no' end,
                                  coalesce(nullif(config, ''), 'none'), case when auth_exec then 'yes' else 'no' end,
                                  case when anon_exec then 'yes' else 'no' end, case when public_exec then 'yes' else 'no' end)
                    from fns where name = 'undo_merge') end
  union all
  select 7, 'unvote trigger', (select n from trg) = 1,
         format('the trigger votes_after_delete_merge_log on public.votes, switched on: found %s (expected 1).', (select n from trg))
  union all
  select 8, 'open merges', coalesce((select not_merged = 0 from open_merges), false),
         case when not exists (select 1 from open_merges) then 'the merge log is missing, so nothing could be asked.'
              else (select format('%s merges in the log can be undone from the app; of these, %s name an idea that is not merged (expected 0).',
                                  open, not_merged) from open_merges) end
),
-- shared:result:begin (row 0 is the overall result; every check depends on check 1, the project)
gated as (
  select c.n, c.check_name,
         coalesce(c.ok, false) and (c.n = 1 or p.ok) as ok,
         case when c.n = 1 or p.ok then c.detail
              else 'not checked, because check 1 (project) failed.' end as detail
  from checks c
  cross join (select coalesce(bool_and(k.ok), false) as ok from checks k where k.n = 1) p
)
select 0 as n, 'overall' as check_name,
       case when bool_and(g.ok) then 'PASS' else 'FAIL' end as result,
       case when bool_and(g.ok) then format('PASS: all %s checks passed.', count(*))
            else format('FAIL: %s of %s checks failed. Stop here and send this result to Claude.ai.',
                        count(*) filter (where not g.ok), count(*)) end as message
from gated g
union all
select g.n, g.check_name,
       case when g.ok then 'PASS' else 'FAIL' end,
       case when g.ok then 'PASS: ' else 'FAIL: ' end || g.detail
from gated g
order by 1;
-- shared:result:end
-- end of preview-merge-undo.sql
```

### Apply on feedbox-prod (merge task, before the merge): `supabase/apply/prod-merge-undo.sql`

Pinned: https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/apply/prod-merge-undo.sql

```sql
-- supabase/apply/prod-merge-undo.sql | 459 lines | last line: -- end of prod-merge-undo.sql
-- =============================================================================
-- Applies the migration supabase/migrations/20261118120000_merge_undo.sql
-- on feedbox-prod only (task F6a: a merge can be undone). CHANGES the database: adds
-- the merge log (tables public.idea_merges and public.idea_merge_votes), a new
-- version of public.merge_ideas that writes it, public.undo_merge, and the
-- trigger that notes an unvote on a merged idea's target. Nothing else.
-- Run once in the Supabase SQL Editor of feedbox-prod, in the merge task of F6a, BEFORE the pull request is merged, so that Production
--   never runs code that calls a function its database does not have.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-prod; the merge log does not exist yet; and the
--   reviewed Feedbox v1 and O2 migrations are present unchanged (the same
--   fingerprint as the check scripts). If the script was pasted twice into
--   one query, the message says so.
-- * Section 4 is the migration's statements word for word;
--   tests/sql-files.test.ts keeps them identical to the migration file.
-- * Check afterwards with supabase/checks/prod-merge-undo.sql.
-- =============================================================================

do $f6a$
declare
  v_project  text;
  v_md5      text;
  v_same_txn boolean;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-prod. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-prod' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-prod. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse to run twice (also when pasted twice into one query).
  if to_regclass('public.idea_merges') is not null then
    select c.xmin::text = (pg_current_xact_id()::xid)::text into v_same_txn
    from pg_class c where c.oid = to_regclass('public.idea_merges');
    if v_same_txn then
      raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
    end if;
    raise exception 'Refused: the merge log (public.idea_merges) already exists in this project, so this script has run before. Nothing was changed by this copy. Run supabase/checks/prod-merge-undo.sql to see its state.';
  end if;

  -- 3. Refuse unless the reviewed Feedbox v1 and O2 migrations are present unchanged.
  if to_regclass('public.boards') is null or to_regclass('public.board_owners') is null then
    raise exception 'Refused: the Feedbox migration is not applied in this project (no table public.boards or public.board_owners). Nothing was changed.';
  end if;
  with
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
  fp as (select a.md5 from mig_all a)
  select fp.md5 into v_md5 from fp;
  if v_md5 is distinct from 'ea60181fdd11e237aa19ee5d6d6c186d' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 and O2 migrations (fingerprint %, expected ea60181fdd11e237aa19ee5d6d6c186d). Nothing was changed.', v_md5;
  end if;

  -- 4. The migration 20261118120000_merge_undo.sql, word for word.
-- migration:begin
create table public.idea_merges (
  id                bigint generated always as identity primary key,
  board_id          uuid not null references public.boards (id) on delete cascade,
  source_id         bigint references public.ideas (id) on delete set null,
  target_id         bigint references public.ideas (id) on delete set null,
  merged_by         uuid references public.profiles (id) on delete set null,
  merged_at         timestamptz not null default now(),
  moved_comment_ids bigint[] not null default '{}',
  rerouted_idea_ids bigint[] not null default '{}',
  undone_at         timestamptz,
  undone_by         uuid references public.profiles (id) on delete set null,
  constraint idea_merges_two_ideas check (source_id <> target_id)
);

create unique index idea_merges_one_open_per_source on public.idea_merges (source_id) where undone_at is null;
create index idea_merges_target_idx on public.idea_merges (target_id);
create index idea_merges_board_idx on public.idea_merges (board_id);

create table public.idea_merge_votes (
  merge_id               bigint not null references public.idea_merges (id) on delete cascade,
  user_id                uuid not null references public.profiles (id) on delete cascade,
  source_voted_at        timestamptz not null,
  added_to_target        boolean not null,
  target_vote_removed_at timestamptz,
  primary key (merge_id, user_id)
);

create index idea_merge_votes_user_idx on public.idea_merge_votes (user_id);

-- A person who removes their vote on the target after a merge: noted in the
-- log, so an undo neither gives them that vote back on the source nor takes a
-- later vote of theirs from the target. Only their own rows, by auth.uid().
create function private.note_merged_vote_removed(p_idea_id bigint)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.idea_merge_votes mv
    set target_vote_removed_at = now()
    from public.idea_merges m
    where m.id = mv.merge_id
      and m.target_id = p_idea_id
      and m.undone_at is null
      and mv.user_id = (select auth.uid())
      and mv.target_vote_removed_at is null;
$$;

-- Security INVOKER on purpose, like the rate-limit trigger: current_user is
-- then the role of the request. Only a person's own unvote through the app
-- counts; votes moved by merge_ideas and undo_merge (which run as the
-- function owner) do not.
create function private.votes_after_delete_merge_log()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    perform private.note_merged_vote_removed(old.idea_id);
  end if;
  return null;
end;
$$;

create trigger votes_after_delete_merge_log
  after delete on public.votes
  for each row execute function private.votes_after_delete_merge_log();

-- Merges the source idea into the target (F1 section 5) and writes the log.
-- Returns the target's new vote count. The same rules as in version 1.
create or replace function public.merge_ideas(p_source_id bigint, p_target_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source public.ideas;
  v_target public.ideas;
  v_merge  bigint;
  v_count  integer;
begin
  if p_source_id = p_target_id then
    raise exception 'An idea cannot be merged into itself.' using errcode = 'check_violation';
  end if;

  -- Lock both rows, always in id order, so two merges cannot deadlock.
  perform 1 from public.ideas
    where id in (p_source_id, p_target_id) order by id for update;
  select * into v_source from public.ideas where id = p_source_id;
  select * into v_target from public.ideas where id = p_target_id;

  if v_source.id is null or v_target.id is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_source.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_source.board_id <> v_target.board_id then
    raise exception 'Both ideas must be on the same board.' using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is not null then
    raise exception 'This idea has already been merged.' using errcode = 'check_violation';
  end if;
  if v_target.merged_into_id is not null then
    raise exception 'The target idea has itself been merged.' using errcode = 'check_violation';
  end if;
  if v_target.hidden_at is not null then
    raise exception 'The target idea is hidden. Unhide it first, or pick another idea.' using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.changelog_items ci where ci.idea_id = p_source_id) then
    raise exception 'This idea is in a changelog entry. Remove it from the entry first.' using errcode = 'check_violation';
  end if;

  -- The log, written before anything moves: the comments that will move and
  -- the ideas merged earlier into the source, which will point at the target.
  insert into public.idea_merges (board_id, source_id, target_id, merged_by, moved_comment_ids, rerouted_idea_ids)
  values (
    v_source.board_id, p_source_id, p_target_id, (select auth.uid()),
    array(select c.id from public.comments c where c.idea_id = p_source_id order by c.id),
    array(select i.id from public.ideas i where i.merged_into_id = p_source_id order by i.id)
  )
  returning id into v_merge;

  -- Every vote on the source, and whether the merge adds a vote on the target for that person.
  insert into public.idea_merge_votes (merge_id, user_id, source_voted_at, added_to_target)
    select v_merge, v.user_id, v.created_at,
           not exists (select 1 from public.votes t where t.idea_id = p_target_id and t.user_id = v.user_id)
    from public.votes v
    where v.idea_id = p_source_id;

  -- Votes: everyone who voted on the source gets a vote on the target unless
  -- they already have one; then the source's votes go. Triggers keep both
  -- counts right, so nobody is counted twice.
  insert into public.votes (idea_id, user_id, created_at)
    select p_target_id, v.user_id, v.created_at
    from public.votes v
    where v.idea_id = p_source_id
    on conflict (idea_id, user_id) do nothing;
  delete from public.votes where idea_id = p_source_id;

  -- Comments move to the target and remember where they came from.
  update public.comments
    set idea_id = p_target_id,
        moved_from_idea_id = coalesce(moved_from_idea_id, p_source_id)
    where idea_id = p_source_id;

  -- Ideas merged earlier into the source now point straight at the target.
  update public.ideas set merged_into_id = p_target_id where merged_into_id = p_source_id;
  update public.ideas set merged_into_id = p_target_id where id = p_source_id;

  select vote_count into v_count from public.ideas where id = p_target_id;
  return v_count;
end;
$$;

comment on function public.merge_ideas(bigint, bigint) is
  'Merges the source idea into the target and writes the merge log (task F6a). Owners only. Returns the target''s new vote count.';

-- Undoes one merge from the log (task F6a). Owners only. Returns the vote
-- count of the idea that is back on the board.
-- * The source idea is back on the board as it was: same row, same address;
--   ideas that pointed at it before the merge point at it again.
-- * Everyone whose vote on the source the merge took counts on it again,
--   unless they removed their vote on the target since.
-- * The target loses the votes the merge added to it, unless that person
--   removed the vote since (then there is nothing to take) or another merge
--   into the same target that is still in place took a vote of theirs too
--   (then that merge now holds the vote, and its own undo takes it).
--   A person who had voted for both before the merge keeps a vote on each.
-- * The comments the merge moved go back, with the mark they had before.
--   Anything else done in between (a new vote or comment on the target,
--   hiding, a status) stays where it was made.
create function public.undo_merge(p_merge_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_merge  public.idea_merges;
  v_source public.ideas;
  v_target public.ideas;
  v_count  integer;
begin
  select * into v_merge from public.idea_merges where id = p_merge_id for update;
  if v_merge.id is null then
    raise exception 'Merge not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_merge.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_merge.undone_at is not null then
    raise exception 'This merge has already been undone.' using errcode = 'check_violation';
  end if;
  if v_merge.source_id is null then
    raise exception 'The merged idea no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
  end if;
  if v_merge.target_id is null then
    raise exception 'The idea it was merged into no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
  end if;

  -- Lock both ideas, always in id order, as merge_ideas does.
  perform 1 from public.ideas
    where id in (v_merge.source_id, v_merge.target_id) order by id for update;
  select * into v_source from public.ideas where id = v_merge.source_id;
  select * into v_target from public.ideas where id = v_merge.target_id;

  if v_target.merged_into_id is not null then
    raise exception '“%” has itself been merged into another idea since. Undo that merge first, on the page of the idea it was merged into.', v_target.title
      using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is distinct from v_target.id then
    raise exception '“%” is no longer merged into “%”, so there is nothing to undo.', v_source.title, v_target.title
      using errcode = 'check_violation';
  end if;

  -- 1. The source is back on the board; ideas merged into it before point at it again.
  update public.ideas set merged_into_id = null where id = v_source.id;
  update public.ideas set merged_into_id = v_source.id
    where id = any (v_merge.rerouted_idea_ids) and merged_into_id = v_target.id;

  -- 2. Votes back on the source: everyone the merge took a vote from, who
  --    still has a vote on the target and has not removed it since.
  insert into public.votes (idea_id, user_id, created_at)
    select v_source.id, mv.user_id, mv.source_voted_at
    from public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.target_vote_removed_at is null
      and exists (select 1 from public.votes t where t.idea_id = v_target.id and t.user_id = mv.user_id)
    on conflict (idea_id, user_id) do nothing;

  -- 3. Votes the merge added to the target go, unless removed since, or
  --    another merge into the same target that is still in place also took a
  --    vote of that person's (then that merge holds the vote from now on).
  delete from public.votes t
    using public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.added_to_target
      and mv.target_vote_removed_at is null
      and t.idea_id = v_target.id
      and t.user_id = mv.user_id
      and not exists (
        select 1
        from public.idea_merge_votes other
        join public.idea_merges om on om.id = other.merge_id
        where om.target_id = v_target.id and om.undone_at is null and om.id <> v_merge.id
          and other.user_id = mv.user_id and other.target_vote_removed_at is null
      );
  update public.idea_merge_votes other
    set added_to_target = true
    from public.idea_merge_votes mv
    where mv.merge_id = v_merge.id
      and mv.added_to_target
      and mv.target_vote_removed_at is null
      and other.user_id = mv.user_id
      and other.target_vote_removed_at is null
      and other.merge_id = (
        select min(om.id)
        from public.idea_merges om
        join public.idea_merge_votes o2 on o2.merge_id = om.id
        where om.target_id = v_target.id and om.undone_at is null and om.id <> v_merge.id
          and o2.user_id = mv.user_id and o2.target_vote_removed_at is null
      );

  -- 4. The comments the merge moved go back to the source, with the mark
  --    they had before ("From the merged idea" only if they came from an
  --    earlier merge into the source).
  update public.comments
    set idea_id = v_source.id,
        moved_from_idea_id = case when moved_from_idea_id = v_source.id then null else moved_from_idea_id end
    where id = any (v_merge.moved_comment_ids) and idea_id = v_target.id;

  -- 5. The log says it was undone, when and by whom.
  update public.idea_merges
    set undone_at = now(), undone_by = (select auth.uid())
    where id = v_merge.id;

  select vote_count into v_count from public.ideas where id = v_source.id;
  return v_count;
end;
$$;

comment on function public.undo_merge(bigint) is
  'Undoes one merge from the merge log (task F6a). Owners only. Returns the vote count of the idea that is back on the board.';

-- Privileges. First take everything away, then grant back only what is needed.
revoke all on table public.idea_merges, public.idea_merge_votes from anon, authenticated;
revoke all on sequence public.idea_merges_id_seq from anon, authenticated;
revoke all on function
  public.merge_ideas(bigint, bigint),
  public.undo_merge(bigint),
  private.note_merged_vote_removed(bigint),
  private.votes_after_delete_merge_log()
  from public, anon, authenticated;

grant select on public.idea_merges to authenticated;
grant execute on function public.merge_ideas(bigint, bigint) to authenticated;
grant execute on function public.undo_merge(bigint) to authenticated;
-- The unvote trigger runs as the caller and notes the unvote through this
-- helper. "private" is not exposed by the API, so this does not make it callable.
grant execute on function private.note_merged_vote_removed(bigint) to authenticated;

-- Row-level security: owners of the board read the merges; nobody reads the
-- votes in the log, and nobody writes either table, except through the functions.
alter table public.idea_merges      enable row level security;
alter table public.idea_merge_votes enable row level security;

create policy idea_merges_read_owner on public.idea_merges
  for select to authenticated
  using (public.is_board_owner(board_id));
-- migration:end
end;
$f6a$;
-- end of prod-merge-undo.sql
```

### Check on feedbox-prod (merge task): `supabase/checks/prod-merge-undo.sql`

Pinned: https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/checks/prod-merge-undo.sql

```sql
-- supabase/checks/prod-merge-undo.sql | 248 lines | last line: -- end of prod-merge-undo.sql
-- =============================================================================
-- READ-ONLY check (task F6a). Changes nothing: one SELECT.
-- For: feedbox-prod. When: right after supabase/apply/prod-merge-undo.sql.
-- It checks that this is feedbox-prod (project marker); that the database is the
-- Feedbox v1, O2 and F6a migrations, all unchanged; that the merge log
-- (public.idea_merges and public.idea_merge_votes) exists with row-level
-- security; that only signed-in owners read idea_merges, and nobody reads
-- idea_merge_votes or writes either table directly; that merge_ideas writes
-- the log and undo_merge exists, both security definer with search_path '' and
-- callable by signed-in people only; that the unvote trigger is in place; and
-- that every merge in the log that can still be undone names a merged idea.
-- Result: rows (n, check_name, result, message). Row 0 is the overall result.
-- =============================================================================

with
-- shared:project:begin (the project marker; never fails if it is missing)
project as (
  select (xpath('/table/row/name/text()',
           query_to_xml('select name from triad.project', false, false, '')))[1]::text as name
  where to_regclass('triad.project') is not null
),
-- shared:project:end
-- shared:fingerprint:begin (what the migration created, read from the catalog)
mig as (
  select
    (select coalesce(string_agg(c.relname, ',' order by c.relname), '')
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')) as tables,
    (select count(*)
       from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity) as rls_on,
    (select coalesce(string_agg(e.enumlabel, ',' order by e.enumsortorder), '')
       from pg_enum e where e.enumtypid = to_regtype('public.idea_status')) as idea_status,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s', c.table_name, c.column_name, c.data_type,
                                           c.is_nullable, coalesce(c.column_default, '')),
                                    E'\n' order by c.table_name, c.ordinal_position)), '')
       from information_schema.columns c where c.table_schema = 'public') as columns_md5,
    (select coalesce(md5(string_agg(i.indexdef, E'\n' order by i.indexname)), '')
       from pg_indexes i where i.schemaname = 'public') as indexes_md5,
    (select count(*) from pg_policies p where p.schemaname = 'public') as policies_n,
    (select coalesce(md5(string_agg(format('%s.%s %s %s %s %s %s', p.tablename, p.policyname, p.permissive, p.cmd,
                                           p.roles, coalesce(p.qual, ''), coalesce(p.with_check, '')),
                                    E'\n' order by p.tablename, p.policyname)), '')
       from pg_policies p where p.schemaname = 'public') as policies_md5,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, string_agg(a.privilege_type, ',' order by a.privilege_type)) as x
               from pg_class c cross join lateral aclexplode(c.relacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'S')
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname) g) as table_grants,
    (select coalesce(string_agg(g.x, '; ' order by g.x), '')
       from (select format('%s %s %s %s', case a.grantee when 0 then 'PUBLIC' else a.grantee::regrole::text end,
                           c.relname, a.privilege_type, string_agg(t.attname, ',' order by t.attname)) as x
               from pg_class c
               join pg_attribute t on t.attrelid = c.oid and t.attnum > 0 and not t.attisdropped
               cross join lateral aclexplode(t.attacl) a
              where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
                and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))
              group by a.grantee, c.relname, a.privilege_type) g) as column_grants,
    (select count(*) from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_n,
    (select coalesce(md5(string_agg(format('%s.%s(%s) %s %s %s %s %s', p.pronamespace::regnamespace, p.proname,
                                           pg_get_function_identity_arguments(p.oid), pg_get_function_result(p.oid),
                                           p.prosecdef, p.provolatile, coalesce(array_to_string(p.proconfig, ','), ''),
                                           md5(p.prosrc)),
                                    E'\n' order by p.pronamespace::regnamespace::text, p.proname)), '')
       from pg_proc p
      where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))) as functions_md5,
    (select string_agg(format('%s: %s', r.role,
                              coalesce((select string_agg(p.proname, ',' order by p.proname)
                                          from pg_proc p
                                         where p.pronamespace in ('public'::regnamespace, to_regnamespace('private'))
                                           and has_function_privilege(r.role, p.oid, 'EXECUTE')), 'none')),
                       '; ' order by r.role)
       from (values ('anon'), ('authenticated')) as r (role)) as function_exec,
    (select coalesce(string_agg(r.role, ',' order by r.role), 'none')
       from (values ('anon'), ('authenticated')) as r (role)
      where to_regnamespace('private') is not null
        and has_schema_privilege(r.role, to_regnamespace('private'), 'USAGE')) as private_usage,
    (select count(*)
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_n,
    (select coalesce(md5(string_agg(pg_get_triggerdef(t.oid), E'\n' order by t.tgrelid::regclass::text, t.tgname)), '')
       from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and (c.relnamespace = 'public'::regnamespace
             or (t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created'))) as triggers_md5,
    (select count(*) from pg_trigger t
      where t.tgrelid = 'auth.users'::regclass and t.tgname = 'on_auth_user_created') as auth_trigger_n,
    (select coalesce(string_agg(e.extnamespace::regnamespace::text, ','), 'not installed')
       from pg_extension e where e.extname = 'pg_trgm') as trgm_schema,
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name ilike '%mail%') as mail_columns
),
mig_all as (
  select md5(concat_ws('|', m.tables, m.rls_on, m.idea_status, m.columns_md5, m.indexes_md5, m.policies_n,
                       m.policies_md5, m.table_grants, m.column_grants, m.functions_n, m.functions_md5,
                       m.function_exec, m.private_usage, m.triggers_n, m.triggers_md5, m.auth_trigger_n,
                       m.trgm_schema, m.mail_columns)) as md5
  from mig m
),
-- shared:fingerprint:end
-- shared:counts:begin (rows per Feedbox table; NULL if the table does not exist)
counts as (
  select t.name,
         case when to_regclass('public.' || t.name) is not null then
           (xpath('/table/row/n/text()',
                  query_to_xml(format('select count(*) as n from public.%I', t.name), false, false, '')))[1]::text::bigint
         end as n
  from unnest(array['boards', 'profiles', 'board_owners', 'ideas', 'votes', 'comments',
                    'changelog_entries', 'changelog_items']) as t (name)
),
people as (
  select count(*) as all_people,
         count(*) filter (where u.email like '%@lumen.example') as lumen_people
  from auth.users u
),
-- shared:counts:end
logt as (
  select c.relname::text as name,
         c.relrowsecurity as rls,
         coalesce((select string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
                     from aclexplode(c.relacl) a where a.grantee = to_regrole('authenticated')), '') as auth_privs,
         coalesce((select string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
                     from aclexplode(c.relacl) a where a.grantee = 0 or a.grantee = to_regrole('anon')), '') as others_privs,
         (select count(*) from pg_attribute t, aclexplode(t.attacl) a
           where t.attrelid = c.oid and t.attnum > 0
             and (a.grantee = 0 or a.grantee in (to_regrole('anon'), to_regrole('authenticated')))) as column_grants,
         (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as policies,
         (select count(*) from pg_policies p
           where p.schemaname = 'public' and p.tablename = c.relname and p.cmd = 'SELECT'
             and p.roles = array['authenticated']::name[] and p.qual = 'is_board_owner(board_id)') as owner_read_policies
  from pg_class c
  where c.oid in (to_regclass('public.idea_merges'), to_regclass('public.idea_merge_votes'))
),
fns as (
  select p.proname::text as name,
         p.prosecdef as secdef,
         coalesce(array_to_string(p.proconfig, ','), '') as config,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
         (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0)) as public_exec,
         position('public.idea_merges' in p.prosrc) > 0 as uses_log
  from pg_proc p
  where p.oid in (to_regprocedure('public.merge_ideas(bigint, bigint)'), to_regprocedure('public.undo_merge(bigint)'))
),
trg as (
  select count(*) as n
  from pg_trigger t
  where t.tgrelid = to_regclass('public.votes') and t.tgname = 'votes_after_delete_merge_log' and t.tgenabled = 'O'
),
open_merges as (
  select (xpath('/table/row/open/text()', x))[1]::text::int as open,
         (xpath('/table/row/not_merged/text()', x))[1]::text::int as not_merged
  from (select query_to_xml(
                 'select count(*) as open,
                         count(*) filter (where s.merged_into_id is null) as not_merged
                  from public.idea_merges m join public.ideas s on s.id = m.source_id
                  where m.undone_at is null and m.target_id is not null', false, false, '') as x
         where to_regclass('public.idea_merges') is not null and to_regclass('public.ideas') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-prod',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-prod.'
              else format('this project is marked %s; this check is for feedbox-prod.', (select name from project)) end
  union all
  select 2, 'migrations', a.md5 = '2814d0ac55dce9fa93db839da532dec7',
         case when a.md5 = '2814d0ac55dce9fa93db839da532dec7'
              then 'the Feedbox v1, O2 and F6a migrations are present and unchanged (fingerprint 2814d0ac55dce9fa93db839da532dec7).'
              when a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d'
              then 'the database is the Feedbox v1 and O2 migrations WITHOUT the F6a migration (fingerprint ea60181fdd11e237aa19ee5d6d6c186d, expected 2814d0ac55dce9fa93db839da532dec7). Run supabase/apply/prod-merge-undo.sql first.'
              else format('the database does not match the Feedbox v1, O2 and F6a migrations (fingerprint %s, expected 2814d0ac55dce9fa93db839da532dec7).', a.md5) end
  from mig_all a
  union all
  select 3, 'merge log', (select count(*) filter (where rls) from logt) = 2,
         format('tables found: %s (expected idea_merge_votes and idea_merges); with row-level security on: %s (expected 2).',
                coalesce((select string_agg(name, ' and ' order by name) from logt), 'none'),
                (select count(*) filter (where rls) from logt))
  union all
  select 4, 'who reads the log',
         coalesce((select auth_privs = 'SELECT' and others_privs = '' and column_grants = 0 and policies = 1 and owner_read_policies = 1
                     from logt where name = 'idea_merges'), false)
         and coalesce((select auth_privs = '' and others_privs = '' and column_grants = 0 and policies = 0
                          from logt where name = 'idea_merge_votes'), false),
         case when (select count(*) from logt) < 2 then 'the merge log is missing, so there is nothing to look at.'
              else format('idea_merges: signed-in people may: %s (expected SELECT only), visitors and everyone else: %s (expected nothing), %s rule(s), of which %s let only the board''s owners read (expected 1 and 1). idea_merge_votes: signed-in people may: %s, everyone else: %s (expected nothing for both), %s rule(s) (expected 0: nobody reads who voted).',
                          (select coalesce(nullif(auth_privs, ''), 'nothing') from logt where name = 'idea_merges'),
                          (select coalesce(nullif(others_privs, ''), 'nothing') from logt where name = 'idea_merges'),
                          (select policies from logt where name = 'idea_merges'),
                          (select owner_read_policies from logt where name = 'idea_merges'),
                          (select coalesce(nullif(auth_privs, ''), 'nothing') from logt where name = 'idea_merge_votes'),
                          (select coalesce(nullif(others_privs, ''), 'nothing') from logt where name = 'idea_merge_votes'),
                          (select policies from logt where name = 'idea_merge_votes')) end
  union all
  select 5, 'merge_ideas', coalesce((select secdef and config = 'search_path=""' and auth_exec and not anon_exec and not public_exec and uses_log
                                       from fns where name = 'merge_ideas'), false),
         case when not exists (select 1 from fns where name = 'merge_ideas') then 'the function public.merge_ideas(bigint, bigint) is MISSING.'
              else (select format('writes the merge log: %s; security definer: %s; settings: %s (expected search_path=""); signed-in people may call it: %s; visitors: %s; everyone else: %s. Expected yes, yes, yes, no, no.',
                                  case when uses_log then 'yes' else 'no' end, case when secdef then 'yes' else 'no' end,
                                  coalesce(nullif(config, ''), 'none'), case when auth_exec then 'yes' else 'no' end,
                                  case when anon_exec then 'yes' else 'no' end, case when public_exec then 'yes' else 'no' end)
                    from fns where name = 'merge_ideas') end
  union all
  select 6, 'undo_merge', coalesce((select secdef and config = 'search_path=""' and auth_exec and not anon_exec and not public_exec and uses_log
                                      from fns where name = 'undo_merge'), false),
         case when not exists (select 1 from fns where name = 'undo_merge') then 'the function public.undo_merge(bigint) is MISSING.'
              else (select format('reads the merge log: %s; security definer: %s; settings: %s (expected search_path=""); signed-in people may call it: %s; visitors: %s; everyone else: %s. Expected yes, yes, yes, no, no.',
                                  case when uses_log then 'yes' else 'no' end, case when secdef then 'yes' else 'no' end,
                                  coalesce(nullif(config, ''), 'none'), case when auth_exec then 'yes' else 'no' end,
                                  case when anon_exec then 'yes' else 'no' end, case when public_exec then 'yes' else 'no' end)
                    from fns where name = 'undo_merge') end
  union all
  select 7, 'unvote trigger', (select n from trg) = 1,
         format('the trigger votes_after_delete_merge_log on public.votes, switched on: found %s (expected 1).', (select n from trg))
  union all
  select 8, 'open merges', coalesce((select not_merged = 0 from open_merges), false),
         case when not exists (select 1 from open_merges) then 'the merge log is missing, so nothing could be asked.'
              else (select format('%s merges in the log can be undone from the app; of these, %s name an idea that is not merged (expected 0).',
                                  open, not_merged) from open_merges) end
),
-- shared:result:begin (row 0 is the overall result; every check depends on check 1, the project)
gated as (
  select c.n, c.check_name,
         coalesce(c.ok, false) and (c.n = 1 or p.ok) as ok,
         case when c.n = 1 or p.ok then c.detail
              else 'not checked, because check 1 (project) failed.' end as detail
  from checks c
  cross join (select coalesce(bool_and(k.ok), false) as ok from checks k where k.n = 1) p
)
select 0 as n, 'overall' as check_name,
       case when bool_and(g.ok) then 'PASS' else 'FAIL' end as result,
       case when bool_and(g.ok) then format('PASS: all %s checks passed.', count(*))
            else format('FAIL: %s of %s checks failed. Stop here and send this result to Claude.ai.',
                        count(*) filter (where not g.ok), count(*)) end as message
from gated g
union all
select g.n, g.check_name,
       case when g.ok then 'PASS' else 'FAIL' end,
       case when g.ok then 'PASS: ' else 'FAIL: ' end || g.detail
from gated g
order by 1;
-- shared:result:end
-- end of prod-merge-undo.sql
```

## docs/ARCHITECTURE.md and README changes

- **docs/ARCHITECTURE.md:**
  - 1.2: `undoMerge` added.
  - 1.3: the merge log tables, the new `merge_ideas` and `undo_merge`, the unvote trigger, and the private helper.
  - 3.10: the plain merge question, the redirect reason, a new point "Undo merge" with the rules, refusals and old merges, and "Guarded by" with `12_merge_undo.sql`.
  - 5: rule 17 now includes undoing a merge, and a new rule 20 ("A wrong merge never needs SQL to repair; nobody reads who voted from the merge log").
  - 6: the new apply scripts.
  - 7: "Built in task F6a" with F1-D8 replaced; "undoing a merge" removed from "Not built in version 1"; F6-D1 to F6-D3 recorded as taken by Claude.ai, and F6-D4 open.
- **README:**
  - Owners: the plain question, a new point "undo a merge" with the rules, and `undo_merge` in the list of owner functions.
  - Privacy: what the merge log keeps, and that nobody can read whose votes it moved; a removal also removes the person's votes in the merge log.
- **CLAUDE.md, Layout:** Undo merge on `/ideas/[id]`, `owner.spec.ts` (F6a), and `apply/` (tasks O2 and F6a).

The full diff from 5cca3a0 to 25fc4fe:

```diff
diff --git a/CLAUDE.md b/CLAUDE.md
index f15fe09..6883a2b 100644
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -194,15 +194,15 @@ One key per project, so either can be revoked without touching the other.
 
 ## Layout
 - **No link to the page you are on** (tasks F5c and F5d): not in the header, the footer, the board's tabs (the current tab is plain text) or the sort menu (the ticked order is not a link). `e2e/screens.spec.ts` checks every page a visitor can open
-- `app/`: Next.js App Router routes: `/`, `/ideas/[id]` (with the Owner tools for owners, task F6: `OwnerTools.tsx`, `owner-actions.ts`), `/ideas/new`, `/changelog`, `/changelog/new` (the changelog editor for owners, task F6), `/sign-in`, `/auth/confirm`, `/auth/sign-out`, `/welcome`
+- `app/`: Next.js App Router routes: `/`, `/ideas/[id]` (with the Owner tools for owners, task F6: `OwnerTools.tsx`, `owner-actions.ts`; on a merge's target, Undo merge, task F6a), `/ideas/new`, `/changelog`, `/changelog/new` (the changelog editor for owners, task F6), `/sign-in`, `/auth/confirm`, `/auth/sign-out`, `/welcome`
 - `proxy.ts`: Next.js 16's middleware: refreshes the Supabase session and sends a signed-in person without a display name to `/welcome`
 - `lib/supabase/`: the server client (`@supabase/ssr`, publishable key only), data reads and writes, generated database types. **The browser never calls Supabase itself** (task F5b): every read and write goes through a page, a server action or `proxy.ts`, with the person's session cookies. The fixture in `e2e/fixtures.ts` (task F6) blocks the browser from the Supabase API in every end-to-end test that imports it, and fails on any attempt
 - `components/`: shared pieces: the header with the sign-in state (on `/changelog` it reads "<board> Changelog" with "Back to the board", task F5c), the footer (`Footer`: no "See what shipped" link on `/changelog`, task F5d), the board's sort menu (`SortMenu`: "Most votes" or "Newest", task F5c), the vote button (`useVote`: votes and unvotes without a reload, through the server action `components/vote-action.ts`; the database is the authority), the status chip, the board's search box, `LocalDate` (a moment shown as the date in the viewer's own time zone, task F5b; a calendar date such as a changelog release is shown as written)
 - `app/globals.css`: the styles, taken from the six designs (colours, light and dark by the system setting, phone layout below 640 px)
-- `e2e/`: Playwright tests (local Supabase only): `auth.spec.ts` (F4, sign-in), `screens.spec.ts` (F5, the screens), `owner.spec.ts` (F6, the owner tools and the changelog editor), `screenshots.spec.ts` (only with `npm run screenshots`); `fixtures.ts` (the shared `test`, which blocks the browser from Supabase); `helpers.ts` (sign in as a test person, tidy up); `e2e/global-setup.ts` waits until local Supabase sends the Feedbox email templates
+- `e2e/`: Playwright tests (local Supabase only): `auth.spec.ts` (F4, sign-in), `screens.spec.ts` (F5, the screens), `owner.spec.ts` (F6, the owner tools and the changelog editor; F6a, undo of a merge), `screenshots.spec.ts` (only with `npm run screenshots`); `fixtures.ts` (the shared `test`, which blocks the browser from Supabase); `helpers.ts` (sign in as a test person, tidy up); `e2e/global-setup.ts` waits until local Supabase sends the Feedbox email templates
 - `screenshots/F5/`: the F5 screenshots, `<state>-<light|dark>-<1280|390>.png`
 - `lib/feedbox/`: core library. Pure TypeScript with **no** Supabase or Next imports; unit tests sit beside the code as `*.test.ts`
 - `design/`: design brief and the six screen sources (part of the app's definition)
-- `supabase/`: `config.toml` (local only), `migrations/`, `seed.sql`, `production/`, `apply/` (a migration as Nik pastes it, guarded by the project marker: `<project>-<topic>.sql`, task O2; `tests/sql-files.test.ts` keeps its statements identical to the migration file), `preview/` (changing scripts for feedbox-preview only, task F6), `people/` (removing a person on request: the template `remove-person.sql`, copied per request with only its block "request" changed, task F6), `checks/` (read-only check scripts), `marker/` (project markers), `tests/`, `templates/`
+- `supabase/`: `config.toml` (local only), `migrations/`, `seed.sql`, `production/`, `apply/` (a migration as Nik pastes it, guarded by the project marker: `<project>-<topic>.sql`, tasks O2 and F6a; `tests/sql-files.test.ts` keeps its statements identical to the migration file), `preview/` (changing scripts for feedbox-preview only, task F6), `people/` (removing a person on request: the template `remove-person.sql`, copied per request with only its block "request" changed, task F6), `checks/` (read-only check scripts), `marker/` (project markers), `tests/`, `templates/`
 - `scripts/`: `sql-files.ts` (header lines of pasted SQL), `test-sql-checks.sh` (tests of check and changing scripts) and `triad-ready.sh` (is TRIAD ready on the Mac); `tests/`: repository-level unit tests (`tests/sql-files.test.ts`, `tests/triad-ready.test.ts`, `tests/email-templates.test.ts`)
 - Later tasks add `TRIAD.md` and `templates/` (at the root)
diff --git a/README.md b/README.md
index 473a64d..b2af12b 100644
--- a/README.md
+++ b/README.md
@@ -30,11 +30,12 @@ npm run test:e2e       # Playwright, against the local database only
 An owner of a board looks after it. On each idea's page an owner sees the **Owner tools** box, and can:
 
 - **change the status**: Open, Planned, Building or Shipped, forward or back. An idea that is in a changelog entry stays Shipped;
-- **merge** an idea into another one (a duplicate into the original). Everyone who voted for the duplicate gets a vote on the original, unless they had one already, so nobody counts twice; the comments move along and say where they came from; the duplicate's address then leads to the original. The form says what will happen before the button, and **there is no undo**;
+- **merge** an idea into another one (a duplicate into the original). Everyone who voted for the duplicate gets a vote on the original, unless they had one already, so nobody counts twice; the comments move along and say where they came from; the duplicate's address then leads to the original. The form says what will happen before the button, and asks plainly: "Merge “…” into “…”? You can undo this from that idea's page.";
+- **undo a merge**: on the original's page an owner sees "“<duplicate>” was merged into this idea." with an **Undo merge** button. The duplicate comes back on the board exactly as before, at the same address; everyone who had voted for it counts on it again; the original loses the votes it gained only through the merge (a person who had voted for both keeps a vote on each); the comments go back. What happened in between stays where it was made: a new vote or comment on the original stays there, and a vote someone removed in the meantime is not added back. A wrong merge never needs SQL. Merges made before the undo existed (task F6a) show the note without the button;
 - **hide or unhide** an idea, and each comment. Hidden things vanish for everyone else and stay visible to owners, marked "Hidden";
 - **write the changelog** at `/changelog/new` (from the button "Write a changelog entry" on the changelog page): a title, a release date, and one line for each Shipped idea that is not in the changelog yet. Publishing shows the entry on `/changelog` at once.
 
-Owners also see hidden ideas in the board's lists. Everything an owner does goes through the owner functions in the database (`set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment`, `publish_changelog_entry`), which check that the person owns the board.
+Owners also see hidden ideas in the board's lists. Everything an owner does goes through the owner functions in the database (`set_idea_status`, `merge_ideas`, `undo_merge`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment`, `publish_changelog_entry`), which check that the person owns the board.
 
 **How a person becomes an owner:** only with reviewed SQL, never from the app. The person signs in once and sets a display name; then a script made for that one board and person adds a row to `board_owners`, and a read-only check confirms it. Examples: [`supabase/production/owner-nik.sql`](supabase/production/owner-nik.sql) with [`supabase/checks/prod-owner.sql`](supabase/checks/prod-owner.sql) (the board `feedbox` on Production), and [`supabase/preview/owner-nik.sql`](supabase/preview/owner-nik.sql) with [`supabase/checks/preview-owner-nik.sql`](supabase/checks/preview-owner-nik.sql) (the board `lumen` on the Preview). Each refuses to run in the wrong project, refuses unless it can tell the person apart without an email address, and is safe if pasted twice.
 
@@ -43,7 +44,7 @@ Owners also see hidden ideas in the board's lists. Everything an owner does goes
 What Feedbox stores, and where:
 
 - **Supabase Auth** (part of the Supabase project): each person's email address, when they signed up and last signed in, and Supabase's own sign-in log. Only the project's administrators can read it; the app never shows an email address to anyone.
-- **The Feedbox tables** (the same Supabase project): the display name the person chose (never an email address: a name with "@" is refused), and the ideas, votes and comments they wrote, each with its time. For owners also which ideas or comments they hid, and which changelog entries they wrote.
+- **The Feedbox tables** (the same Supabase project): the display name the person chose (never an email address: a name with "@" is refused), and the ideas, votes and comments they wrote, each with its time. For owners also which ideas or comments they hid, which changelog entries they wrote, and which merges they made or undid. The merge log also keeps, for each merge, whose votes it moved, so the merge can be undone; nobody can read that part through the app, not even an owner.
 - **The browser:** only the sign-in session, in HTTP-only cookies. No analytics, no tracking, no other cookies.
 - **Resend** sends the sign-in emails and keeps a log of what it sent, as its own terms say. **Vercel** hosts the app and keeps its request logs, as its own terms say.
 
@@ -53,7 +54,7 @@ Everything a person writes on a board (display name, ideas, comments, the number
 
 1. Find the person's **User UID** in the Supabase dashboard (the project, Authentication, Users, search by their email address). The email address itself is never written into the repository.
 2. A task copies the template [`supabase/people/remove-person.sql`](supabase/people/remove-person.sql) to `supabase/people/remove-<date>.sql`, and the check [`supabase/checks/person-removal.sql`](supabase/checks/person-removal.sql) to `supabase/checks/person-removal-<date>.sql`, changing only the two values in their block "request": the project and the User UID. A unit test makes sure nothing else differs.
-3. The check, run first, says what will go. The removal script then deletes the person; the database removes with them their profile, their ideas (with every vote, comment and changelog line on those ideas), their votes and their comments, and the vote and comment counts follow. The check, run again, must PASS.
+3. The check, run first, says what will go. The removal script then deletes the person; the database removes with them their profile, their ideas (with every vote, comment and changelog line on those ideas), their votes and their comments, and their votes in the merge log (so an undo of a merge does not bring them back), and the vote and comment counts follow. The check, run again, must PASS.
 
 The script refuses, and changes nothing, in the wrong project, for a person who owns a board (they are removed as an owner first), or when someone else's idea was merged into one of theirs. Backups of the Supabase project, and the Resend and Vercel logs, keep older data until they expire under those services' own terms.
 
diff --git a/docs/ARCHITECTURE.md b/docs/ARCHITECTURE.md
index f7c648c..bc96208 100644
--- a/docs/ARCHITECTURE.md
+++ b/docs/ARCHITECTURE.md
@@ -45,7 +45,7 @@ Next.js 16, App Router (`package.json`). It has five kinds of server code:
 | Kind | Files | What it does |
 |---|---|---|
 | Pages (server components) | `app/page.tsx` (the board), `app/ideas/[id]/page.tsx`, `app/ideas/new/page.tsx`, `app/changelog/page.tsx`, `app/changelog/new/page.tsx`, `app/sign-in/page.tsx`, `app/auth/confirm/page.tsx`, `app/welcome/page.tsx`, `app/not-found.tsx`, `app/layout.tsx` | Read from Supabase on the server and render HTML |
-| Server actions (`"use server"`) | `app/ideas/new/actions.ts` (`postIdea`, `findSimilar`), `app/ideas/[id]/actions.ts` (`addComment`), `app/ideas/[id]/owner-actions.ts` (`changeStatus`, `mergeInto`, `setIdeaHidden`, `setCommentHidden`; task F6), `app/changelog/new/actions.ts` (`publishEntry`; task F6), `components/vote-action.ts` (`vote`), `app/sign-in/actions.ts` (`sendLink`), `app/auth/confirm/actions.ts` (`finishSignIn`), `app/welcome/actions.ts` (`saveDisplayName`) | Called by the browser's forms and buttons; they run on the server and call Supabase |
+| Server actions (`"use server"`) | `app/ideas/new/actions.ts` (`postIdea`, `findSimilar`), `app/ideas/[id]/actions.ts` (`addComment`), `app/ideas/[id]/owner-actions.ts` (`changeStatus`, `mergeInto`, `setIdeaHidden`, `setCommentHidden`; task F6; `undoMerge`, task F6a), `app/changelog/new/actions.ts` (`publishEntry`; task F6), `components/vote-action.ts` (`vote`), `app/sign-in/actions.ts` (`sendLink`), `app/auth/confirm/actions.ts` (`finishSignIn`), `app/welcome/actions.ts` (`saveDisplayName`) | Called by the browser's forms and buttons; they run on the server and call Supabase |
 | Route handler | `app/auth/sign-out/route.ts` | `POST` signs out; `GET` answers 405 |
 | Proxy (Next.js 16's name for middleware) | `proxy.ts` | Runs before every page request: refreshes the session cookies and sends a person without a display name to /welcome |
 | Server-side Supabase access | `lib/supabase/server.ts` (the client), data.ts (all reads, and the vote write), `lib/supabase/env.ts` (settings), `lib/supabase/site.ts` (the site's own address) | The only way the app reaches Supabase |
@@ -58,18 +58,22 @@ Next.js 16, App Router (`package.json`). It has five kinds of server code:
 
 Each hosted project has two parts the app uses: Postgres and Supabase Auth.
 
-**Postgres.** Everything is created by the migration, except the function `board_owner_ids`, which the O2 migration adds.
+**Postgres.** Everything is created by the migration, except the function `board_owner_ids`, which the O2 migration adds, and the merge log with `undo_merge`, which the F6a migration (`supabase/migrations/20261118120000_merge_undo.sql`) adds. Line numbers below without a file name are those of the v1 migration.
 
 - **Eight tables** (migration lines 36-148): `boards`, `profiles`, `board_owners`, `ideas`, `votes`, `comments`, `changelog_entries`, `changelog_items`.
+- **The merge log, two tables more** (F6a migration lines 32-59):
+  - `idea_merges`: one row per merge (board, source, target, the owner, the time, the comments it moved, the ideas merged earlier into the source that it pointed at the target, and when and by whom it was undone). Owners of the board read it (policy `idea_merges_read_owner`, line 342); nobody writes it except through `merge_ideas` and `undo_merge`.
+  - `idea_merge_votes`: one row per vote the merge took from the source (who, when they voted, whether the merge added a vote for them on the target, whether they removed their vote on the target since). Nobody reads or writes it through the API, not even an owner, because who voted for what is private (a person reads only their own votes); RLS is on with no policy and no grant. Its rows go with the person (`on delete cascade` on `profiles`).
 - **Row-level security (RLS):** it is on for every table (lines 804-811), with policies at lines 813-928. The grants first revoke everything from `anon` and `authenticated` and then grant back only what is needed, column by column for writes (lines 726-797).
 - **Functions the app may call:**
   - `is_board_owner` (lines 172-185);
   - `has_display_name` (lines 190-203);
   - `similar_ideas` (lines 687-717);
   - `board_owner_ids` (O2 migration lines 21-38): the user ids of one board's owners, and nothing else, for everyone. It is security definer with `search_path` set to `''`, stable, and only `anon` and `authenticated` may execute it (`supabase/tests/11_board_owner_ids.sql`);
-  - the owner functions `set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment` and `publish_changelog_entry` (lines 463-677).
+  - the owner functions `set_idea_status`, `merge_ideas`, `hide_idea`, `unhide_idea`, `hide_comment`, `unhide_comment` and `publish_changelog_entry` (lines 463-677). Since F6a, `merge_ideas` is the version in the F6a migration (lines 104-188: the same name, arguments, result and rules, and it also writes the merge log);
+  - `undo_merge` (F6a migration lines 207-315), for owners only: see 3.10.
 
-  The app calls `is_board_owner` (data.ts:44), `similar_ideas` (data.ts:173, 199), since O2 `board_owner_ids` (`getOwnerIds` in data.ts), and since F6 every owner function, each from one server action (3.10).
+  The app calls `is_board_owner` (data.ts:44), `similar_ideas` (data.ts:173, 199), since O2 `board_owner_ids` (`getOwnerIds` in data.ts), since F6 every owner function, each from one server action (3.10), and since F6a `undo_merge` and a read of `idea_merges` (`getMergeNotes` in data.ts).
 - **Triggers** (lines 235-453):
   - a profile for every new user (5a);
   - rate limits of 5 ideas, 30 comments and 100 votes per person per hour (5b);
@@ -77,8 +81,9 @@ Each hosted project has two parts the app uses: Postgres and Supabase Auth.
   - posting an idea casts the author's vote (5d);
   - `vote_count` follows `votes` (5e);
   - `comment_count` counts visible comments (5f);
-  - changelog lines must name a Shipped idea of the same board (5g).
-- **Helpers in the schema `private`**, which the API does not expose (lines 24-26, 755): `recent_count` and the trigger functions.
+  - changelog lines must name a Shipped idea of the same board (5g);
+  - since F6a, `votes_after_delete_merge_log` (F6a migration lines 84-100): when a person removes their own vote on a merge's target through the app, the merge log notes it, so an undo neither gives that vote back nor takes a later vote of theirs. Security invoker, like 5b: votes moved by `merge_ideas` and `undo_merge` do not count.
+- **Helpers in the schema `private`**, which the API does not expose (lines 24-26, 755): `recent_count`, since F6a `note_merged_vote_removed` (the only two `authenticated` may execute; the triggers need them), and the trigger functions.
 - **Project marker:** each project also has a row in `triad.project` that names it (CLAUDE.md, "SQL is code"; `supabase/marker/*.sql`). Only the check scripts and changing scripts read it; the app never does.
 
 **Supabase Auth.**
@@ -334,11 +339,17 @@ flowchart LR
    - The table `board_owners` and its policy `board_owners_read` are unchanged: reading the table directly, an owner sees all owners of the board and anyone else at most their own row (migration lines 830-832).
 5. **The Owner tools** (task F6, as in `Idea.dc.html`): on every idea page an owner sees the box **Owner tools** (`OwnerTools` in `app/ideas/[id]/OwnerTools.tsx`). Visitors and members never get it: the page renders it only for the role `owner`, and every function behind it checks `is_board_owner` again (42501 otherwise). Each tool is a form that calls one server action in `app/ideas/[id]/owner-actions.ts`, which calls one owner function with the owner's own session; the browser never calls Supabase. Refusals come back in words (`ownerRefusalMessage`, `lib/feedbox/screens.ts`: the database's own message for 23514).
    - **Status:** a list of Open, Planned, Building and Shipped and **Change status** → `changeStatus` → `set_idea_status`. Any change but "the same again" is allowed; an idea in a changelog entry stays Shipped, so the list is disabled with a note (`isInChangelog` in data.ts; trigger 5c in the database).
-   - **Merge into another idea:** opens a panel. The owner picks the target from the visible, unmerged ideas (`mergeTargets`, `lib/feedbox/merge.ts`), and the panel says what will happen before the button: the target's new vote count as a range, since a person's votes are readable only by that person (`mergePreview`), the comments that move, that the idea leaves the board, and "There is no undo." The button → `mergeInto` → `merge_ideas` (migration lines 493-559): votes copied without double counting, comments moved with `moved_from_idea_id`, the idea marked `merged_into_id`.
-   - **After a merge:** the owner lands on the target at `/ideas/<target>?merged=<source>`, which says "“<source>” was merged into this idea. Its votes and comments are here now: N votes in all." The source's own address leads there too (a temporary redirect, since a wrong merge can be repaired by hand); the note shows only when the source really was merged into this idea.
+   - **Merge into another idea:** opens a panel. The owner picks the target from the visible, unmerged ideas (`mergeTargets`, `lib/feedbox/merge.ts`), and the panel says what will happen before the button: the target's new vote count as a range, since a person's votes are readable only by that person (`mergePreview`), the comments that move, that the idea leaves the board, and then plainly "Merge “<source>” into “<target>”? You can undo this from that idea's page." (task F6a; until then it said "There is no undo"). The button → `mergeInto` → `merge_ideas` (F6a migration lines 104-188): the merge log written first, votes copied without double counting, comments moved with `moved_from_idea_id`, the idea marked `merged_into_id`.
+   - **After a merge:** the owner lands on the target at `/ideas/<target>?merged=<source>`, which says "“<source>” was merged into this idea. Its votes and comments are here now: N votes in all." The source's own address leads there too (a temporary redirect, since a merge can be undone); for visitors and members the note shows only on that address, and only when the source really was merged into this idea.
+   - **Undo merge (task F6a, replaces decision F1-D8 "no undo in v1"):** on the target's page an owner always sees one note per idea merged into it ("“<source>” was merged into this idea.", `getMergeNotes` and `mergeNotes`, `lib/feedbox/merge.ts`), newest first. A merge in the log that is not undone has an **Undo merge** button → `undoMerge` → `undo_merge`. Afterwards the owner stays on the target at `/ideas/<target>?unmerged=<source>`, which says "Merge undone: “<source>” is back on the board, with N votes and M comments." with a link to it, and the note is gone.
+     - What the undo does: the source is back on the board as it was (same row, address, title, details, author, date and status); ideas merged into it before point at it again; everyone whose vote the merge took counts on it again; the target loses the votes the merge added; a person who had voted for both keeps a vote on each; the moved comments go back with the mark they had before.
+     - What happened in between stays where it was made: a new vote or comment on the target stays; a person who removed their vote on the target since gets it back on neither idea (trigger `votes_after_delete_merge_log`).
+     - Two merges into one target, the older undone first: a vote that the newer merge also needed stays on the target, and from then on belongs to the newer merge, whose own undo takes it.
+     - Refusals, in words, with nothing changed: not an owner (42501); already undone; the merged idea or the target no longer exists; the target has itself been merged since ("Undo that merge first"); the source is no longer merged into the target.
+     - Merges made before the F6a migration have no log row: their note stays, without the Undo merge button. So does the note for an idea that was merged into another idea that was then merged here; it can be undone in turn once that later merge is undone.
    - **Hide idea / Unhide idea:** → `setIdeaHidden` → `hide_idea` or `unhide_idea`.
 6. **The changelog editor:** see 3.9.
-7. **Guarded by:** `e2e/owner.spec.ts` (status, merge with its counts, hide and unhide of an idea and a comment, publishing; a member and a visitor never see the panel, the hidden items or the editor) and, in the database, `supabase/tests/06_owner_functions.sql`, `07_merge.sql` and `08_changelog.sql`.
+7. **Guarded by:** `e2e/owner.spec.ts` (status, merge with its counts, undo of a merge with every idea, vote and comment as before, hide and unhide of an idea and a comment, publishing; a member and a visitor never see the panel, Undo merge, the hidden items or the editor) and, in the database, `supabase/tests/06_owner_functions.sql`, `07_merge.sql`, `08_changelog.sql` and `12_merge_undo.sql` (task F6a: the log, the undo, the in-between cases, two merges into one target, refusals, who may read and write the log).
 
 ## 4. Keys: which key is used where
 
@@ -378,9 +389,10 @@ Each rule names the test or check that guards it.
 | 14 | A profile never holds an email address, and a display name never contains "@" | `profiles` has no email column; check `profiles_display_name_check` (migration lines 53-59); `supabase/tests/01_structure.sql`; `e2e/auth.spec.ts:68` |
 | 15 | A migration is never edited after it ran on feedbox-preview | `tests/sql-files.test.ts:68-74` pins the file's sha256 |
 | 16 | The tests never touch a hosted project | `e2e/local-supabase.ts:26-28`; `ci.yml` (no secrets; local Supabase only); CLAUDE.md, "Three rules" 2 |
-| 17 | Only an owner of the board changes a status, merges, hides or unhides, or publishes the changelog, and only through the owner functions | The functions check `is_board_owner` (migration section 6); no grant lets anyone write `status`, `merged_into_id`, `hidden_at` or `published_at` (rule 5); the app calls them only from server actions; `supabase/tests/06_owner_functions.sql`, `07_merge.sql`, `08_changelog.sql`; `e2e/owner.spec.ts` |
+| 17 | Only an owner of the board changes a status, merges or undoes a merge, hides or unhides, or publishes the changelog, and only through the owner functions | The functions check `is_board_owner` (migration section 6; `undo_merge` in the F6a migration); no grant lets anyone write `status`, `merged_into_id`, `hidden_at` or `published_at` (rule 5), or either merge log table; the app calls them only from server actions; `supabase/tests/06_owner_functions.sql`, `07_merge.sql`, `08_changelog.sql`, `12_merge_undo.sql`; `e2e/owner.spec.ts` |
 | 18 | Visitors and members never see the Owner tools, hidden ideas or comments, or the changelog editor | RLS (migration lines 836-838, 866-874, 888-890); the pages render the tools only for owners; `e2e/owner.spec.ts` (task F6) |
 | 19 | A person becomes an owner, or is removed, only by a reviewed script, never from the app | No insert policy on `board_owners`; `supabase/production/owner-nik.sql`, `supabase/preview/owner-nik.sql`, `supabase/people/remove-person.sql`, each with its check and tested in `scripts/test-sql-checks.sh`; a removal copy may change only its block "request" (`tests/sql-files.test.ts`) |
+| 20 | A wrong merge never needs SQL to repair: an owner undoes it from the app, and nobody, not even an owner, reads who voted from the merge log | `undo_merge` (F6a migration); RLS on `idea_merges` (owners read) and `idea_merge_votes` (nobody); `supabase/tests/12_merge_undo.sql`; `supabase/checks/<project>-merge-undo.sql` rows 4-6; `e2e/owner.spec.ts` (task F6a) |
 
 ## 6. Where settings live
 
@@ -390,16 +402,21 @@ Each rule names the test or check that guards it.
   - `NEXT_PUBLIC_SITE_URL` is optional, read in `lib/supabase/site.ts:10`.
   - In Vercel they are set per environment (CLAUDE.md, "App settings on Vercel"). Locally and in CI they come from `npx supabase status` (`playwright.config.ts:30-34`).
 - **Local Supabase settings:** `supabase/config.toml`. Where they differ from hosted, the difference is on purpose (CLAUDE.md, "Local Supabase against these settings").
-- **SQL that Nik runs on a hosted project:** files in `supabase/checks/`, `supabase/marker/`, `supabase/production/`, since task O2 `supabase/apply/` (a migration as Nik pastes it, guarded by the project marker), and since task F6 `supabase/preview/` (scripts for feedbox-preview only) and `supabase/people/` (removing a person on request: a template, copied per request), each reviewed and tested (CLAUDE.md, "SQL is code").
+- **SQL that Nik runs on a hosted project:** files in `supabase/checks/`, `supabase/marker/`, `supabase/production/`, since task O2 `supabase/apply/` (a migration as Nik pastes it, guarded by the project marker), and since task F6 `supabase/preview/` (scripts for feedbox-preview only), since task F6a `supabase/apply/<project>-merge-undo.sql`, and `supabase/people/` (removing a person on request: a template, copied per request), each reviewed and tested (CLAUDE.md, "SQL is code").
 
 ## 7. Not built yet, and open decisions
 
 **Built in task F6:** the owner tools on the idea page and the changelog editor (3.6, 3.9, 3.10).
 
-**Not built in version 1 (F1, section 11):** undoing a merge, CAPTCHA, many boards per deployment, and editing or unpublishing a changelog entry in the app (the database allows both for owners; no screen offers them). The check of the hosted Preview is task P1.
+**Built in task F6a:** undoing a merge from the app (3.10), with the merge log (1.3). Decision **F1-D8** ("no undo in v1") is replaced: Nik, TRIAD chat, 2026-11-18 5:54-6:06 PM, after running F6 on the Preview: an owner can undo any merge from the app, and a wrong merge never needs SQL.
 
-**Decisions** (from the F5 and A1 reports):
+**Not built in version 1 (F1, section 11):** CAPTCHA, many boards per deployment, and editing or unpublishing a changelog entry in the app (the database allows both for owners; no screen offers them). The check of the hosted Preview is task P1.
+
+**Decisions** (from the F5, A1, F6 and F6a reports):
 - **F5-D1 (decided 2026-11-18, done in task O2):** everyone may read who the board's owners are, so the Owner mark shows for every viewer (see 3.6 and 3.10).
 - **F5-D2 (open):** whether to build an end-to-end runner against the hosted Preview (`playwright.config.ts:4-7`).
 - **A1-D2 (decided 2026-11-18, fixed later):** the search limit of 20 applies to the whole board before the tab is chosen (see 3.2); it is fixed later, with F6's database work or when a board grows, not now. F6 needed no database change; see the F6 report, decision F6-D2.
-- **F6-D1 (open):** whether owners should find hidden ideas by the board's search (`similar_ideas` leaves them out, migration line 713).
+- **F6-D1 (recorded in task F6a; Nik did not answer, Claude.ai took the recommendation, Nik may change it):** owners do not find hidden ideas by the board's search; they find them in the tab lists, and never in similar ideas (`similar_ideas` leaves them out, migration line 713).
+- **F6-D2 (recorded in task F6a, the same way):** the search limit of 20 (A1-D2) is not fixed now.
+- **F6-D3 (recorded in task F6a, the same way):** the merge panel keeps the vote count as a range.
+- **F6-D4 (open):** whether a removal copy may name the person's User UID in this public repository.
```

## Steps for Nik

Paste this section into Mac Notes. Each step is one action with one expected result. Under each step, write what you saw after "Result".

**F6a-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://supabase.com/dashboard/project/qrbeiveyomidfafivuta/sql/new
Expected: the Supabase SQL Editor opens. The project name at the top of the page reads **feedbox-preview**, and the address bar contains `qrbeiveyomidfafivuta` (feedbox-prod would be `imlitxtkpvrcmijgdsrw`). If it does not read feedbox-preview, stop here: nothing has been changed.

Result

**F6a-2** In the same tab (SQL Editor of **feedbox-preview**), clear every existing query: click an "Untitled query" tab at the top of the SQL Editor, so its orange dot turns into an ×, and click the ×, which deletes that query. Repeat until no query tab is left.
Expected: no query tab is left, and the top of the page still reads **feedbox-preview**.

Result

**F6a-3** On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/apply/preview-merge-undo.sql
Expected: a plain text page whose first line is `-- supabase/apply/preview-merge-undo.sql | 458 lines | last line: -- end of preview-merge-undo.sql`.

Result

**F6a-4** On that text page press ⌘A and ⌘C, switch to the Supabase tab (feedbox-preview), click **+ New query**, click into the empty editor and press ⌘V.
Expected: the editor's line 1 is `-- supabase/apply/preview-merge-undo.sql | 458 lines | last line: -- end of preview-merge-undo.sql`, and, scrolled to the end, line 458 is `-- end of preview-merge-undo.sql`. If either does not match, close that query tab with its × and do this step again.

Result

**F6a-5** (CHANGES the database of feedbox-preview: adds the merge log and the undo.) In the same Supabase tab, click **Run**.
Expected: **"Success. No rows returned."** If it says "Refused: …", stop: nothing was changed, as the message says; copy the message here. If any other error appears, stop and do not run it again (nothing was changed, the script is all or nothing); copy the whole message here.

Result

**F6a-6** On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/25fc4fe8ce49112fb9143f422d56d0f1421c0808/supabase/checks/preview-merge-undo.sql
Expected: a plain text page whose first line is `-- supabase/checks/preview-merge-undo.sql | 248 lines | last line: -- end of preview-merge-undo.sql`.

Result

**F6a-7** On that text page press ⌘A and ⌘C, switch to the Supabase tab (feedbox-preview), click **+ New query**, click into the empty editor and press ⌘V.
Expected: line 1 is `-- supabase/checks/preview-merge-undo.sql | 248 lines | last line: -- end of preview-merge-undo.sql`, and line 248 is `-- end of preview-merge-undo.sql`. If either does not match, close that query tab with its × and do this step again.

Result

**F6a-8** (read-only.) In the same Supabase tab, click **Run**, then take a screenshot of the rows (⌘⇧4, drag over the rows) into this note.
Expected: 9 rows, n 0 to 8. Row 0 reads **"PASS: all 8 checks passed."** Row 2 names the fingerprint `2814d0ac55dce9fa93db839da532dec7`. Row 8 reads "0 merges in the log can be undone from the app; of these, 0 name an idea that is not merged (expected 0)." If row 0 says FAIL, stop: send all rows to Claude.ai and change nothing on your own.

Result

**F6a-9** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app
Expected: the Lumen board "What should Lumen do next?". At the top right it reads **"Viewing as visitor"**, because you signed out in F6-11.

Result

**F6a-10** In the same tab, click **Sign in** at the top right, type your own email address in **Email address**, and click **Send me a link**.
Expected: the page reads **"Check your email"**.

Result

**F6a-11** In Mac Mail, open the new email from **Feedbox <feedbox@pactresearch.net>** with the subject **Your Feedbox sign-in link**. Control-click its link **Sign in to Feedbox** and choose **Copy Link**.
Expected: the menu closes. The link is now copied; nothing opens.

Result

**F6a-12** Switch to the Chrome tab of the Preview, click the address bar, press ⌘V and press Return.
Expected: a page with the button **Finish signing in**.

Result

**F6a-13** On that page, click **Finish signing in**.
Expected: the board. At the top right it reads **"Signed in as owner"**.

Result

**F6a-14** In the same tab, click the address bar, type https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app/ideas/new and press Return.
Expected: the page **Post an idea**, with the boxes **Title** and **Details**.

Result

**F6a-15** In **Title**, type `F6a check: the target idea` and click **Post idea**. (Ideas that appear on the right as similar ones do not matter.)
Expected: the page of **F6a check: the target idea**, status **Open**, with **1** in the vote button (your own vote) and the heading **0 comments**.

Result

**F6a-16** On that page, under **Add a comment**, type `F6a: a comment on the target` and click **Post comment**.
Expected: the heading reads **1 comment**, and your comment shows below it.

Result

**F6a-17** In the same tab, click the address bar, type https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app/ideas/new and press Return.
Expected: the page **Post an idea**, with empty boxes.

Result

**F6a-18** In **Title**, type `F6a check: the duplicate idea` and click **Post idea**.
Expected: the page of **F6a check: the duplicate idea**, status **Open**, with **1** in the vote button and the heading **0 comments**.

Result

**F6a-19** On that page, under **Add a comment**, type `F6a: a comment on the duplicate` and click **Post comment**.
Expected: the heading reads **1 comment**, and your comment shows below it.

Result

**F6a-20** On the same page, in the box **Owner tools**, click **Merge into another idea**.
Expected: a panel opens with the list **Merge “F6a check: the duplicate idea” into**, set to "Pick an idea".

Result

**F6a-21** In that list, choose **F6a check: the target idea (1 vote)**.
Expected: under **What will happen** there are three points. Below them, in bold: **Merge “F6a check: the duplicate idea” into “F6a check: the target idea”? You can undo this from that idea’s page.** The words "There is no undo" appear nowhere.

Result

**F6a-22** Click the button **Merge into “F6a check: the target idea”**.
Expected:
- The page of **F6a check: the target idea** opens, with a blue note at the top: "“F6a check: the duplicate idea” was merged into this idea. Its votes and comments are here now: 1 vote in all." and a button **Undo merge** in that note.
- The vote button shows **1**: you voted for both ideas, so you are counted once.
- The heading reads **2 comments**. The comment "F6a: a comment on the duplicate" carries the line "From the merged idea “F6a check: the duplicate idea”".

Result

**F6a-23** In the blue note, click **Undo merge**.
Expected:
- The same page now shows at the top: "Merge undone: “F6a check: the duplicate idea” is back on the board, with 1 vote and 1 comment. Open “F6a check: the duplicate idea”".
- The note with Undo merge is gone.
- The vote button shows **1**. The heading reads **1 comment**, and the only comment is "F6a: a comment on the target".

Result

**F6a-24** In that message, click the link **Open “F6a check: the duplicate idea”**.
Expected: the page of **F6a check: the duplicate idea**, as it was before the merge: status **Open**, **1** in the vote button, the heading **1 comment**, and the comment "F6a: a comment on the duplicate" with no "From the merged idea" line. There is no note at the top.

Result

**F6a-25** On that page, click **← All ideas** at the top left.
Expected: the board's **Open** tab. Scrolled down, the list holds both **F6a check: the target idea** and **F6a check: the duplicate idea**, each with **1** vote.

Result

**F6a-26** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.
Expected: the PDF is in the TRIAD chat.

Result

## Decisions for Nik

**F6a-D1, your decision: a person who removes their vote on the target between the merge and the undo.**
- Your rule says "a vote removed in the meantime is not added back". I applied it to everyone the merge touched: such a person gets their vote back on neither idea, even if they had voted for both ideas before the merge.
- Example: Lee voted for A and for B. A is merged into B, then Lee removes the vote on B, then the merge is undone. Lee then has a vote on neither. The other way would give Lee the vote on A back.
- **Recommendation: keep it as built.** After the merge, Lee's one vote on B stood for both ideas, and Lee took it back. The rule is also simple to explain: "if you removed your vote after the merge, the undo does not give it back".

No other decision is needed: the prod scripts follow the O2 pattern and are run in the merge task, before the merge. F6-D4 and F5-D2 stay open (not repeated here). F6-D1, F6-D2 and F6-D3 are recorded in `docs/ARCHITECTURE.md` section 7 as taken by Claude.ai.
