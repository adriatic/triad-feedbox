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
-- * Races (task F6b): a vote or a comment waits for a merge or an undo of its
--   idea that is in progress, and then refuses in words if the idea was just
--   merged (trigger refuse_merged_idea, which takes over the "not merged"
--   rule from the policies votes_insert_own and comments_insert_own, whose
--   check uses the moment the request started and so cannot see a merge that
--   committed while it waited). An unvote goes through
--   public.remove_my_vote(p_idea_id), which locks the idea first for the
--   same reason and so never deadlocks with an undo; votes are no longer
--   deleted directly through the API. merge_ideas and undo_merge lock every
--   idea they change in one statement, in id order, so two of them never
--   deadlock either. scripts/test-races.sh runs each case in two sessions at
--   the same time.
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

-- Races (task F6b). A vote or a comment on an idea that a merge or an undo
-- holds waits for it (the key share lock conflicts with their "for update"),
-- then reads the idea as it is now. If it was just merged, the request is
-- refused in words and nothing is written: no vote or comment is ever left
-- unseen on a merged idea. Security definer, so it may lock the row.
create function private.refuse_merged_idea()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_merged_into bigint;
  v_target      public.ideas;
  v_where       text;
begin
  select i.merged_into_id into v_merged_into
  from public.ideas i
  where i.id = new.idea_id
  for key share;
  if v_merged_into is not null then
    select * into v_target from public.ideas t where t.id = v_merged_into;
    -- Never name a hidden idea to someone who may not see it.
    v_where := case when v_target.hidden_at is null then '“' || v_target.title || '”' else 'another idea' end;
    if tg_table_name = 'votes' then
      raise exception 'This idea was just merged into %. Vote there.', v_where
        using errcode = 'P0001', detail = 'merged:' || v_merged_into;
    end if;
    raise exception 'This idea was just merged into %. Post your comment there.', v_where
      using errcode = 'P0001', detail = 'merged:' || v_merged_into;
  end if;
  return new;
end;
$$;

create trigger votes_refuse_merged
  before insert on public.votes
  for each row execute function private.refuse_merged_idea();
create trigger comments_refuse_merged
  before insert on public.comments
  for each row execute function private.refuse_merged_idea();

-- The trigger above is now the one place that refuses a merged idea, and it
-- sees the idea as it is now. The policies keep every other rule.
alter policy votes_insert_own on public.votes
  with check (
    user_id = (select auth.uid())
    and public.has_display_name()
    and exists (select 1 from public.ideas i where i.id = idea_id and i.hidden_at is null)
  );
alter policy comments_insert_own on public.comments
  with check (
    author_id = (select auth.uid())
    and public.has_display_name()
    and exists (select 1 from public.ideas i where i.id = idea_id and i.hidden_at is null)
  );

-- Removes the signed-in person's own vote (task F6b; the app's only way to
-- unvote). It locks the idea first, so it waits for a merge or an undo of
-- that idea in progress instead of deadlocking with it, and then:
-- * if the idea was just merged, it refuses in words (the vote moved with the
--   merge, so the person is told where it is now);
-- * otherwise it removes the vote, and notes in the merge log that the person
--   removed their vote on this idea after a merge into it, so an undo neither
--   gives that vote back on the source nor takes a later vote of theirs.
-- Returns true if a vote was removed, false if there was none.
create function public.remove_my_vote(p_idea_id bigint)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user    uuid := (select auth.uid());
  v_idea    public.ideas;
  v_target  public.ideas;
  v_removed integer;
begin
  if v_user is null then
    raise exception 'Sign in to remove your vote.' using errcode = '42501';
  end if;
  select * into v_idea from public.ideas where id = p_idea_id for key share;
  if v_idea.id is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if v_idea.merged_into_id is not null then
    select * into v_target from public.ideas t where t.id = v_idea.merged_into_id;
    raise exception 'This idea was just merged into %. Your vote moved there with it; remove it there if you wish.',
      case when v_target.hidden_at is null then '“' || v_target.title || '”' else 'another idea' end
      using errcode = 'P0001', detail = 'merged:' || v_idea.merged_into_id;
  end if;

  delete from public.votes where idea_id = p_idea_id and user_id = v_user;
  get diagnostics v_removed = row_count;
  if v_removed > 0 then
    update public.idea_merge_votes mv
      set target_vote_removed_at = now()
      from public.idea_merges m
      where m.id = mv.merge_id
        and m.target_id = p_idea_id
        and m.undone_at is null
        and mv.user_id = v_user
        and mv.target_vote_removed_at is null;
  end if;
  return v_removed > 0;
end;
$$;

-- Votes are removed through remove_my_vote only, never deleted directly.
drop policy votes_delete_own on public.votes;
revoke delete on public.votes from authenticated;

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

  -- Lock every idea this merge changes (both ideas and the ideas merged
  -- earlier into the source) in ONE statement, in id order, so two merges,
  -- or a merge and an undo, never deadlock (task F6b).
  perform 1 from public.ideas
    where id in (p_source_id, p_target_id) or merged_into_id = p_source_id
    order by id for update;
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

  -- Lock every idea this undo changes (both ideas and the ideas the merge
  -- pointed at the target) in ONE statement, in id order, as merge_ideas
  -- does, so a merge and an undo never deadlock (task F6b).
  perform 1 from public.ideas
    where id in (v_merge.source_id, v_merge.target_id) or id = any (v_merge.rerouted_idea_ids)
    order by id for update;
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
  public.remove_my_vote(bigint),
  private.refuse_merged_idea()
  from public, anon, authenticated;

grant select on public.idea_merges to authenticated;
grant execute on function public.merge_ideas(bigint, bigint) to authenticated;
grant execute on function public.undo_merge(bigint) to authenticated;
grant execute on function public.remove_my_vote(bigint) to authenticated;

-- Row-level security: owners of the board read the merges; nobody reads the
-- votes in the log, and nobody writes either table, except through the functions.
alter table public.idea_merges      enable row level security;
alter table public.idea_merge_votes enable row level security;

create policy idea_merges_read_owner on public.idea_merges
  for select to authenticated
  using (public.is_board_owner(board_id));
