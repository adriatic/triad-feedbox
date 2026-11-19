# Task F6b: merge and undo while other people vote and comment (race conditions)

Repository `adriatic/triad-feedbox`, branch `f6-owner-tools`, pull request #10 (https://github.com/adriatic/triad-feedbox/pull/10), not merged.

- **Previous head:** `25fc4fe8ce49112fb9143f422d56d0f1421c0808` (task F6a).
- **New head:** `900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549`.
- **Your question** (TRIAD chat, 2026-11-18 6:19 PM): "Explain to me whether Feedbox handles any race conditions. Example: I do something which made me execute the undo. In the same time, several users do their things. Are they negatively impacted."
- **Short answer:**
  - Before this task, yes, in a few cases. A vote or a comment made while you merged could be left on the merged idea where nobody sees it. An unvote at that moment did nothing, and nobody was told. A vote or a comment made while you undid a merge was refused with a vague message. An undo and a merge could block each other until the database cancelled one.
  - Now nobody is harmed: whoever comes second waits a moment for whoever came first. Then their action either goes through where they made it, or is refused with a sentence that says where to vote or comment instead. Nothing anyone did is lost or counted twice.
  - The wait lasts as long as the merge or undo itself, which is a fraction of a second in practice.
- **How this was found out:** not by reasoning alone. The new test `scripts/test-races.sh` runs every case in two database sessions at the same time.
  - The first session (for example your undo) does its work and then holds it open for 3 seconds before finishing.
  - The second session (for example someone's vote) starts 1 second later, while the first still holds the ideas.
  - The test records that the second session had to wait, what it was told, and what ended up in the database.
  - Two cases (d6 and d7) add a third request that holds an idea, to force the most awkward order.
  - I ran the same test on the F6a code (head 25fc4fe) and on the new code. On the F6a code, 16 of its 56 expectations failed; now all 56 pass, locally and in CI.
- **Hosted databases:** nothing was run against feedbox-preview or feedbox-prod. The F6a migration has not run anywhere hosted, so it was changed in place, and its new sha256 is pinned. The v1 and O2 migrations are unchanged. No dashboard setting changed.

## The cases, in plain words

| # | What happens at the same moment | Before F6b | Now | Test |
|---|---|---|---|---|
| a1 | Someone votes for an idea while you merge it into another | The vote was saved on the merged idea, which nobody sees any more. It was not moved to the other idea: **lost from view** | The vote waits for the merge, then is refused: "This idea was just merged into “<other idea>”. Vote there." Nothing is saved; the person votes there | a1 |
| a2 | Someone removes their vote from an idea while you merge it | The removal silently did nothing. The vote was moved to the other idea, and the person was **not told** | The removal waits, then says: "This idea was just merged into “<other idea>”. Your vote moved there with it; remove it there if you wish." The vote is on the other idea, counted once | a2 |
| b | Someone comments on an idea while you merge it | The comment was saved on the merged idea, which nobody sees any more: **lost from view** | The comment waits, then is refused: "This idea was just merged into “<other idea>”. Post your comment there." Nothing is saved; the text stays in the box | b |
| b2 | Someone comments on the idea you merge into, while you merge | Saved there | The same: it waits a moment, then is saved there | b2 |
| c1 | Someone votes for the idea you merged into, while you undo the merge | Saved there, and it stays | The same | c1 |
| c2 | Someone removes their vote from the idea you merged into, while you undo (your undo first) | The undo takes back the vote the merge had added and gives the person's vote back on the idea that returns; their removal then finds nothing left to remove | The same (see decision F6b-D1) | c2 |
| c3 | The same, but their removal comes first | Removed in the meantime: the undo gives it back on neither idea | The same | c3 |
| c4 | Someone votes for the merged idea (from a page they opened earlier) while you undo the merge | Refused at once with "Voting did not work. Reload the page and try again.", although a moment later the vote would have been fine | The vote waits for the undo, then is saved on the idea that is back, and stays there | c4 |
| c5 | Someone comments on the merged idea, and on the other one, while you undo | The comment on the merged idea was refused with "Posting your comment did not work. Reload the page and try again."; the other one was saved | Both wait for the undo, then each is saved where it was written | c5 |
| d1 | Two owners merge the same idea into two different ideas at the same moment | The second owner was told "This idea has already been merged."; merged once | The same | d1 |
| d2 | Two owners undo the same merge at the same moment | The second owner was told "This merge has already been undone."; undone once | The same | d2 |
| d3, d4 | One owner undoes a merge while another merges the idea it went into into a third idea | In the order they came: the merge first, then the undo is refused in words ("Undo that merge first"), or the undo first, then the merge goes through | The same | d3, d4 |
| d5 | The same, when an older merge into that idea is involved too | Went through in order | The same | d5 |
| d6 | An undo and that merge both wait behind someone's vote on the merged idea; the undo was first in line | The merge jumped ahead and the undo was refused in words. That was a fair outcome, but out of order | They go in the order they came: the undo, then the merge | d6 |
| d7 | The same, the merge first in line, waiting behind someone's vote on the idea it merges | **"deadlock detected"**: each waited for the other, and the database cancelled the undo with a technical error | The merge goes through, then the undo is refused in words ("Undo that merge first"). No deadlock | d7 |

"Lost from view" in a1 and b means: the vote or comment was saved, but on an idea that nobody can see any more and that no count shows. It would only have reappeared if that merge was undone.

## What changed, and why

All the changes are in the F6a migration (`supabase/migrations/20261118120000_merge_undo.sql`) and in two app files.

1. **A vote or a comment checks for a merge, and waits for one in progress.** This is the new trigger `refuse_merged_idea` on `votes` and on `comments`, before the row is written.
   - It first takes a light lock on the idea's row. A merge or an undo holds that row strongly, so the vote or comment waits until the merge or undo has finished.
   - Then it reads the idea as it is now, and refuses in words if the idea was just merged. If the idea it went into is hidden, the sentence says "another idea" instead of its title.
   - Before, this rule was in the access rules (policies) `votes_insert_own` and `comments_insert_own`. An access rule sees the database as it was when the request started, so it could not see a merge that finished while the request waited. The rule moved into the trigger; the policies keep their other rules (the person's own row, a display name, an idea that is not hidden).
2. **Removing a vote goes through a new function, `remove_my_vote`.**
   - It locks the idea first, waits for a merge or undo in progress, and says where the vote went if the idea was just merged. Otherwise it removes the person's own vote, and notes it in the merge log as the F6a trigger did.
   - Votes can no longer be deleted directly through the API: the delete grant and the policy `votes_delete_own` are gone, and the F6a unvote trigger and its helper are removed.
   - With a direct delete, the vote row would be locked before the idea, the opposite order to a merge or undo, and that order can deadlock.
3. **`merge_ideas` and `undo_merge` lock every idea they change in one statement, in id order.** That is both ideas, plus the ideas merged earlier into the source. Before, they locked two ideas first and the others later, which could deadlock (case d7).
4. **The app:**
   - The vote button's "remove vote" calls `remove_my_vote` (`lib/supabase/data.ts`).
   - A refusal with the database detail `merged:` is shown word for word (`isMergedRefusal` and `refusalMessage` in `lib/feedbox/screens.ts`), for votes, unvotes and comments. Every other database error is still shown as "… did not work. Reload the page and try again."

### The migration diff (25fc4fe to 900434c)

```diff
diff --git a/supabase/migrations/20261118120000_merge_undo.sql b/supabase/migrations/20261118120000_merge_undo.sql
index bce3acd..309c4c8 100644
--- a/supabase/migrations/20261118120000_merge_undo.sql
+++ b/supabase/migrations/20261118120000_merge_undo.sql
@@ -23,6 +23,18 @@
 --   authenticated where needed.
 -- * Merges made before this migration have no log row: their note stays on
 --   the target's page, without an Undo merge button.
+-- * Races (task F6b): a vote or a comment waits for a merge or an undo of its
+--   idea that is in progress, and then refuses in words if the idea was just
+--   merged (trigger refuse_merged_idea, which takes over the "not merged"
+--   rule from the policies votes_insert_own and comments_insert_own, whose
+--   check uses the moment the request started and so cannot see a merge that
+--   committed while it waited). An unvote goes through
+--   public.remove_my_vote(p_idea_id), which locks the idea first for the
+--   same reason and so never deadlocks with an undo; votes are no longer
+--   deleted directly through the API. merge_ideas and undo_merge lock every
+--   idea they change in one statement, in id order, so two of them never
+--   deadlock either. scripts/test-races.sh runs each case in two sessions at
+--   the same time.
 -- * The Feedbox v1 (20261113000000) and O2 (20261118000000) migrations are
 --   never edited; this is a new migration. Nik pastes it on a hosted project
 --   through the guarded copy in supabase/apply/ (task F6a), which runs
@@ -58,46 +70,117 @@ create table public.idea_merge_votes (
 
 create index idea_merge_votes_user_idx on public.idea_merge_votes (user_id);
 
--- A person who removes their vote on the target after a merge: noted in the
--- log, so an undo neither gives them that vote back on the source nor takes a
--- later vote of theirs from the target. Only their own rows, by auth.uid().
-create function private.note_merged_vote_removed(p_idea_id bigint)
-returns void
-language sql
+-- Races (task F6b). A vote or a comment on an idea that a merge or an undo
+-- holds waits for it (the key share lock conflicts with their "for update"),
+-- then reads the idea as it is now. If it was just merged, the request is
+-- refused in words and nothing is written: no vote or comment is ever left
+-- unseen on a merged idea. Security definer, so it may lock the row.
+create function private.refuse_merged_idea()
+returns trigger
+language plpgsql
 security definer
 set search_path = ''
 as $$
-  update public.idea_merge_votes mv
-    set target_vote_removed_at = now()
-    from public.idea_merges m
-    where m.id = mv.merge_id
-      and m.target_id = p_idea_id
-      and m.undone_at is null
-      and mv.user_id = (select auth.uid())
-      and mv.target_vote_removed_at is null;
+declare
+  v_merged_into bigint;
+  v_target      public.ideas;
+  v_where       text;
+begin
+  select i.merged_into_id into v_merged_into
+  from public.ideas i
+  where i.id = new.idea_id
+  for key share;
+  if v_merged_into is not null then
+    select * into v_target from public.ideas t where t.id = v_merged_into;
+    -- Never name a hidden idea to someone who may not see it.
+    v_where := case when v_target.hidden_at is null then '“' || v_target.title || '”' else 'another idea' end;
+    if tg_table_name = 'votes' then
+      raise exception 'This idea was just merged into %. Vote there.', v_where
+        using errcode = 'P0001', detail = 'merged:' || v_merged_into;
+    end if;
+    raise exception 'This idea was just merged into %. Post your comment there.', v_where
+      using errcode = 'P0001', detail = 'merged:' || v_merged_into;
+  end if;
+  return new;
+end;
 $$;
 
--- Security INVOKER on purpose, like the rate-limit trigger: current_user is
--- then the role of the request. Only a person's own unvote through the app
--- counts; votes moved by merge_ideas and undo_merge (which run as the
--- function owner) do not.
-create function private.votes_after_delete_merge_log()
-returns trigger
+create trigger votes_refuse_merged
+  before insert on public.votes
+  for each row execute function private.refuse_merged_idea();
+create trigger comments_refuse_merged
+  before insert on public.comments
+  for each row execute function private.refuse_merged_idea();
+
+-- The trigger above is now the one place that refuses a merged idea, and it
+-- sees the idea as it is now. The policies keep every other rule.
+alter policy votes_insert_own on public.votes
+  with check (
+    user_id = (select auth.uid())
+    and public.has_display_name()
+    and exists (select 1 from public.ideas i where i.id = idea_id and i.hidden_at is null)
+  );
+alter policy comments_insert_own on public.comments
+  with check (
+    author_id = (select auth.uid())
+    and public.has_display_name()
+    and exists (select 1 from public.ideas i where i.id = idea_id and i.hidden_at is null)
+  );
+
+-- Removes the signed-in person's own vote (task F6b; the app's only way to
+-- unvote). It locks the idea first, so it waits for a merge or an undo of
+-- that idea in progress instead of deadlocking with it, and then:
+-- * if the idea was just merged, it refuses in words (the vote moved with the
+--   merge, so the person is told where it is now);
+-- * otherwise it removes the vote, and notes in the merge log that the person
+--   removed their vote on this idea after a merge into it, so an undo neither
+--   gives that vote back on the source nor takes a later vote of theirs.
+-- Returns true if a vote was removed, false if there was none.
+create function public.remove_my_vote(p_idea_id bigint)
+returns boolean
 language plpgsql
-security invoker
+security definer
 set search_path = ''
 as $$
+declare
+  v_user    uuid := (select auth.uid());
+  v_idea    public.ideas;
+  v_target  public.ideas;
+  v_removed integer;
 begin
-  if current_user in ('anon', 'authenticated') then
-    perform private.note_merged_vote_removed(old.idea_id);
+  if v_user is null then
+    raise exception 'Sign in to remove your vote.' using errcode = '42501';
+  end if;
+  select * into v_idea from public.ideas where id = p_idea_id for key share;
+  if v_idea.id is null then
+    raise exception 'Idea not found.' using errcode = 'P0002';
+  end if;
+  if v_idea.merged_into_id is not null then
+    select * into v_target from public.ideas t where t.id = v_idea.merged_into_id;
+    raise exception 'This idea was just merged into %. Your vote moved there with it; remove it there if you wish.',
+      case when v_target.hidden_at is null then '“' || v_target.title || '”' else 'another idea' end
+      using errcode = 'P0001', detail = 'merged:' || v_idea.merged_into_id;
+  end if;
+
+  delete from public.votes where idea_id = p_idea_id and user_id = v_user;
+  get diagnostics v_removed = row_count;
+  if v_removed > 0 then
+    update public.idea_merge_votes mv
+      set target_vote_removed_at = now()
+      from public.idea_merges m
+      where m.id = mv.merge_id
+        and m.target_id = p_idea_id
+        and m.undone_at is null
+        and mv.user_id = v_user
+        and mv.target_vote_removed_at is null;
   end if;
-  return null;
+  return v_removed > 0;
 end;
 $$;
 
-create trigger votes_after_delete_merge_log
-  after delete on public.votes
-  for each row execute function private.votes_after_delete_merge_log();
+-- Votes are removed through remove_my_vote only, never deleted directly.
+drop policy votes_delete_own on public.votes;
+revoke delete on public.votes from authenticated;
 
 -- Merges the source idea into the target (F1 section 5) and writes the log.
 -- Returns the target's new vote count. The same rules as in version 1.
@@ -117,9 +200,12 @@ begin
     raise exception 'An idea cannot be merged into itself.' using errcode = 'check_violation';
   end if;
 
-  -- Lock both rows, always in id order, so two merges cannot deadlock.
+  -- Lock every idea this merge changes (both ideas and the ideas merged
+  -- earlier into the source) in ONE statement, in id order, so two merges,
+  -- or a merge and an undo, never deadlock (task F6b).
   perform 1 from public.ideas
-    where id in (p_source_id, p_target_id) order by id for update;
+    where id in (p_source_id, p_target_id) or merged_into_id = p_source_id
+    order by id for update;
   select * into v_source from public.ideas where id = p_source_id;
   select * into v_target from public.ideas where id = p_target_id;
 
@@ -233,9 +319,12 @@ begin
     raise exception 'The idea it was merged into no longer exists, so this merge cannot be undone.' using errcode = 'check_violation';
   end if;
 
-  -- Lock both ideas, always in id order, as merge_ideas does.
+  -- Lock every idea this undo changes (both ideas and the ideas the merge
+  -- pointed at the target) in ONE statement, in id order, as merge_ideas
+  -- does, so a merge and an undo never deadlock (task F6b).
   perform 1 from public.ideas
-    where id in (v_merge.source_id, v_merge.target_id) order by id for update;
+    where id in (v_merge.source_id, v_merge.target_id) or id = any (v_merge.rerouted_idea_ids)
+    order by id for update;
   select * into v_source from public.ideas where id = v_merge.source_id;
   select * into v_target from public.ideas where id = v_merge.target_id;
 
@@ -323,16 +412,14 @@ revoke all on sequence public.idea_merges_id_seq from anon, authenticated;
 revoke all on function
   public.merge_ideas(bigint, bigint),
   public.undo_merge(bigint),
-  private.note_merged_vote_removed(bigint),
-  private.votes_after_delete_merge_log()
+  public.remove_my_vote(bigint),
+  private.refuse_merged_idea()
   from public, anon, authenticated;
 
 grant select on public.idea_merges to authenticated;
 grant execute on function public.merge_ideas(bigint, bigint) to authenticated;
 grant execute on function public.undo_merge(bigint) to authenticated;
--- The unvote trigger runs as the caller and notes the unvote through this
--- helper. "private" is not exposed by the API, so this does not make it callable.
-grant execute on function private.note_merged_vote_removed(bigint) to authenticated;
+grant execute on function public.remove_my_vote(bigint) to authenticated;
 
 -- Row-level security: owners of the board read the merges; nobody reads the
 -- votes in the log, and nobody writes either table, except through the functions.
```

## Hashes and fingerprints

| What | Value |
|---|---|
| F6a migration sha256, new (pinned in `tests/sql-files.test.ts`) | `bfa9404f0988121cad0fe1a3c0aa3b7414e850fc4aabbf7d19337f88a6d9409f` |
| F6a migration sha256 in the F6a report (replaced; it never ran anywhere hosted) | `60a9681b612a90a1c7db046bee0b75fe598499d490da993d60f7707d51e037f7` |
| Fingerprint expected BEFORE the apply script (v1 + O2, as feedbox-preview and feedbox-prod are now) | `ea60181fdd11e237aa19ee5d6d6c186d` (unchanged) |
| Fingerprint AFTER (v1 + O2 + F6a), new; also expected by the removal template and its check | `081ca51dd5b60c7b98cf8a6309584fb0` |
| Fingerprint after, in the F6a report (replaced) | `2814d0ac55dce9fa93db839da532dec7` |

The SQL harness confirms that the pasted apply script and `supabase db reset` with the migration file build the same database, with the same fingerprint (sections L and M).

## The four scripts, pinned at the new head

| Script | Lines | Pinned link |
|---|---|---|
| Apply on feedbox-preview | 533 | https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/apply/preview-merge-undo.sql |
| Check on feedbox-preview | 260 | https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/checks/preview-merge-undo.sql |
| Apply on feedbox-prod (merge task, before the merge) | 536 | https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/apply/prod-merge-undo.sql |
| Check on feedbox-prod (merge task) | 260 | https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/checks/prod-merge-undo.sql |

- The migration itself: https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/migrations/20261118120000_merge_undo.sql
- **The apply scripts** are regenerated from the migration, word for word, which a unit test checks. Their header now names the race guards.
- **The check scripts** still have 8 checks. Row 2 expects the new fingerprint. Row 7 is now "race guards", which must show:
  - both triggers on;
  - `remove_my_vote` safe and callable by signed-in people only;
  - votes not deletable directly through the API.

## Tests

- **New: `scripts/test-races.sh`** (`npm run test:races`, and a new step in the CI job `db`): the 18 cases a1 to d7 above, 56 expectations, all met.
  - On the F6a code, 16 failed, in cases a1, a2, b, c4, c5, d6 and d7.
  - In CI run 44451117485 the step printed "Race tests: all 56 expectations met."
- **pgTAP: 302** (was 299).
  - `04_votes.sql`: a vote on a merged idea is refused with the sentence naming the other idea; votes cannot be deleted directly; `remove_my_vote` removes one's own vote and then finds none, says where the vote went on a merged idea, and is refused for a visitor.
  - `05_comments.sql`: a comment on a merged idea is refused with its sentence.
  - `12_merge_undo.sql`: the in-between unvotes now go through `remove_my_vote`, and all its F6a cases still pass.
  - `01_structure.sql`: votes are SELECT only for signed-in people, `remove_my_vote` is callable by signed-in people only, and `private.recent_count` is again the only private function they may call.
- **SQL harness: 202 expectations** (was 200). The check FAILs if a race guard is switched off, if votes become deletable directly, or if `remove_my_vote` is taken away from signed-in people.
- **Unit: 185** (was 182): the refusal with `merged:` is recognised and shown word for word; other database errors are never shown as they are.
- **e2e: 17**, all passing. The unvote in "signed in: post with similar ideas, vote twice gives one vote, unvote, comment" now goes through `remove_my_vote`.
- **Local runs:** lint, typecheck, unit 185, pgTAP 302, SQL harness 202/202, races 56/56, e2e 17; all pass.

## Head and CI

| What | Result |
|---|---|
| Head | `900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549` |
| CI push run 44451117485 | lint, typecheck, unit, db (with the race tests), e2e: all pass |
| CI pull request run 44451125100 | lint, typecheck, unit, db, e2e: all pass |
| Vercel | success |
| Pull request #10 | open, not merged |

## docs/ARCHITECTURE.md, README and CLAUDE.md

- **docs/ARCHITECTURE.md:**
  - 1.3: `remove_my_vote` and the two triggers; the private helper of F6a is gone; line numbers updated.
  - 3.5 Voting and 3.6 Commenting: the unvote path, where "not merged" is checked now, and the words shown.
  - 3.10: a new point, "At the same moment as other people (task F6b)", with the table of cases and their tests.
  - 5: a new rule 21 ("a vote, unvote or comment is never lost or counted twice because a merge or an undo runs at the same moment; two owners never deadlock"), guarded by `scripts/test-races.sh`.
  - 7: "Built in task F6b".
- **README, Owners:** a new point on people voting and commenting while an owner merges or undoes.
- **CLAUDE.md:** `npm run test:races` in Commands and in the CI job `db`, and `test-races.sh` in Layout.

## Steps for Nik

Paste this section into Mac Notes. Each step is one action with one expected result. Under each step, write what you saw after "Result".

**F6b-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://supabase.com/dashboard/project/qrbeiveyomidfafivuta/sql/new
Expected: the Supabase SQL Editor opens. The project name at the top of the page reads **feedbox-preview**, and the address bar contains `qrbeiveyomidfafivuta` (feedbox-prod would be `imlitxtkpvrcmijgdsrw`). If it does not read feedbox-preview, stop here: nothing has been changed.

Result

**F6b-2** In the same tab (SQL Editor of **feedbox-preview**), clear every existing query: click an "Untitled query" tab at the top of the SQL Editor, so its orange dot turns into an ×, and click the ×, which deletes that query. Repeat until no query tab is left.
Expected: no query tab is left, and the top of the page still reads **feedbox-preview**.

Result

**F6b-3** On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/apply/preview-merge-undo.sql
Expected: a plain text page whose first line is `-- supabase/apply/preview-merge-undo.sql | 533 lines | last line: -- end of preview-merge-undo.sql`.

Result

**F6b-4** On that text page press ⌘A and ⌘C, switch to the Supabase tab (feedbox-preview), click **+ New query**, click into the empty editor and press ⌘V.
Expected: the editor's line 1 is `-- supabase/apply/preview-merge-undo.sql | 533 lines | last line: -- end of preview-merge-undo.sql`, and, scrolled to the end, line 533 is `-- end of preview-merge-undo.sql`. If either does not match, close that query tab with its × and do this step again.

Result

**F6b-5** (CHANGES the database of feedbox-preview: adds the merge log and the undo.) In the same Supabase tab, click **Run**.
Expected: **"Success. No rows returned."** If it says "Refused: …", stop: nothing was changed, as the message says; copy the message here. If any other error appears, stop and do not run it again (nothing was changed, the script is all or nothing); copy the whole message here.

Result

**F6b-6** On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/900434c9342b6e7a2cf9d0f95cb5b6f85f8f4549/supabase/checks/preview-merge-undo.sql
Expected: a plain text page whose first line is `-- supabase/checks/preview-merge-undo.sql | 260 lines | last line: -- end of preview-merge-undo.sql`.

Result

**F6b-7** On that text page press ⌘A and ⌘C, switch to the Supabase tab (feedbox-preview), click **+ New query**, click into the empty editor and press ⌘V.
Expected: line 1 is `-- supabase/checks/preview-merge-undo.sql | 260 lines | last line: -- end of preview-merge-undo.sql`, and line 260 is `-- end of preview-merge-undo.sql`. If either does not match, close that query tab with its × and do this step again.

Result

**F6b-8** (read-only.) In the same Supabase tab, click **Run**, then take a screenshot of the rows (⌘⇧4, drag over the rows) into this note.
Expected: 9 rows, n 0 to 8. Row 0 reads **"PASS: all 8 checks passed."** Row 2 names the fingerprint `081ca51dd5b60c7b98cf8a6309584fb0`. Row 7 (race guards) ends with "votes can be deleted directly through the API: no (expected no)." Row 8 reads "0 merges in the log can be undone from the app; of these, 0 name an idea that is not merged (expected 0)." If row 0 says FAIL, stop: send all rows to Claude.ai and change nothing on your own.

Result

**F6b-9** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app
Expected: the Lumen board "What should Lumen do next?". At the top right it reads **"Viewing as visitor"**, because you signed out in F6-11.

Result

**F6b-10** In the same tab, click **Sign in** at the top right, type your own email address in **Email address**, and click **Send me a link**.
Expected: the page reads **"Check your email"**.

Result

**F6b-11** In Mac Mail, open the new email from **Feedbox <feedbox@pactresearch.net>** with the subject **Your Feedbox sign-in link**. Control-click its link **Sign in to Feedbox** and choose **Copy Link**.
Expected: the menu closes. The link is now copied; nothing opens.

Result

**F6b-12** Switch to the Chrome tab of the Preview, click the address bar, press ⌘V and press Return.
Expected: a page with the button **Finish signing in**.

Result

**F6b-13** On that page, click **Finish signing in**.
Expected: the board. At the top right it reads **"Signed in as owner"**.

Result

**F6b-14** In the same tab, click the address bar, type https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app/ideas/new and press Return.
Expected: the page **Post an idea**, with the boxes **Title** and **Details**.

Result

**F6b-15** In **Title**, type `F6b check: the target idea` and click **Post idea**. (Ideas that appear on the right as similar ones do not matter.)
Expected: the page of **F6b check: the target idea**, status **Open**, with **1** in the vote button (your own vote) and the heading **0 comments**.

Result

**F6b-16** On that page, under **Add a comment**, type `F6b: a comment on the target` and click **Post comment**.
Expected: the heading reads **1 comment**, and your comment shows below it.

Result

**F6b-17** In the same tab, click the address bar, type https://triad-feedbox-git-f6-owner-tools-nikolaj-ivancics-projects.vercel.app/ideas/new and press Return.
Expected: the page **Post an idea**, with empty boxes.

Result

**F6b-18** In **Title**, type `F6b check: the duplicate idea` and click **Post idea**.
Expected: the page of **F6b check: the duplicate idea**, status **Open**, with **1** in the vote button and the heading **0 comments**.

Result

**F6b-19** On that page, under **Add a comment**, type `F6b: a comment on the duplicate` and click **Post comment**.
Expected: the heading reads **1 comment**, and your comment shows below it.

Result

**F6b-20** On the same page, in the box **Owner tools**, click **Merge into another idea**.
Expected: a panel opens with the list **Merge “F6b check: the duplicate idea” into**, set to "Pick an idea".

Result

**F6b-21** In that list, choose **F6b check: the target idea (1 vote)**.
Expected: under **What will happen** there are three points. Below them, in bold: **Merge “F6b check: the duplicate idea” into “F6b check: the target idea”? You can undo this from that idea’s page.** The words "There is no undo" appear nowhere.

Result

**F6b-22** Click the button **Merge into “F6b check: the target idea”**.
Expected:
- The page of **F6b check: the target idea** opens, with a blue note at the top: "“F6b check: the duplicate idea” was merged into this idea. Its votes and comments are here now: 1 vote in all." and a button **Undo merge** in that note.
- The vote button shows **1**: you voted for both ideas, so you are counted once.
- The heading reads **2 comments**. The comment "F6b: a comment on the duplicate" carries the line "From the merged idea “F6b check: the duplicate idea”".

Result

**F6b-23** In the blue note, click **Undo merge**.
Expected:
- The same page now shows at the top: "Merge undone: “F6b check: the duplicate idea” is back on the board, with 1 vote and 1 comment. Open “F6b check: the duplicate idea”".
- The note with Undo merge is gone.
- The vote button shows **1**. The heading reads **1 comment**, and the only comment is "F6b: a comment on the target".

Result

**F6b-24** In that message, click the link **Open “F6b check: the duplicate idea”**.
Expected: the page of **F6b check: the duplicate idea**, as it was before the merge: status **Open**, **1** in the vote button, the heading **1 comment**, and the comment "F6b: a comment on the duplicate" with no "From the merged idea" line. There is no note at the top.

Result

**F6b-25** On that page, click **← All ideas** at the top left.
Expected: the board's **Open** tab. Scrolled down, the list holds both **F6b check: the target idea** and **F6b check: the duplicate idea**, each with **1** vote.

Result

**F6b-26** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.
Expected: the PDF is in the TRIAD chat.

Result

## Decisions for Nik

**F6b-D1, your decision: someone removes their vote from the idea you merged into, at the same moment as you undo the merge, and your undo comes first (case c2).**
- **What happens:** the undo gives that person's vote back on the idea that returns, and takes away the vote the merge had added for them. Their removal then finds nothing left to remove on that idea, and their button there shows "not voted", which is true. Their vote is on the returned idea, as before the merge.
- **The other way:** treat their click as "remove my vote everywhere it came from", so the returned idea would not get it back either. That needs the database to guess what the click meant after it already lost the race.
- **Recommendation: keep it as built.** It is exactly what happens when the two arrive one after the other in that order, and it agrees with what the person sees on the page they are on.

F6a-D1 stays open as written in the F6a report. F6-D4 and F5-D2 stay open too.
