-- supabase/production/undo-feedbox-v1.sql | 103 lines | last line: -- end of undo-feedbox-v1.sql
-- =============================================================================
-- Undo the Feedbox v1 migration (20261113000000_feedbox_v1.sql) on a project
-- where it was applied but no Feedbox data was ever saved. Task F3b, for
-- feedbox-prod (Nik's decision B); the migration is applied there again in M3.
--
-- * ONE statement: a single do-block, so it runs the same way in the Supabase
--   SQL Editor whatever way the editor sends it. No psql commands.
-- * All or nothing: if the guard refuses, or any drop fails, nothing changes.
-- * The guard runs first. It refuses unless all eight Feedbox tables exist and
--   are empty, and auth.users has no person at @lumen.example. So it can
--   never drop a Feedbox row.
-- * Drops are named one by one, without CASCADE: if anything outside the
--   migration depends on a Feedbox object, the drop fails and the whole block
--   is undone, instead of silently taking that other object with it.
-- * The extension pg_trgm is LEFT in the schema "extensions". The migration
--   only ran "create extension if not exists", so this script cannot tell
--   whether the migration created it or it was there before; it is harmless
--   on its own (not in an exposed schema, no data); and the migration's
--   "if not exists" simply finds it again when it is re-applied in M3.
-- =============================================================================

do $undo$
declare
  v_table text;
  v_tables constant text[] := array[
    'boards', 'profiles', 'board_owners', 'ideas', 'votes',
    'comments', 'changelog_entries', 'changelog_items'];
  v_has_rows boolean;
begin
  -- ---------------------------------------------------------------------------
  -- Guard: nothing is changed before every check has passed.
  -- ---------------------------------------------------------------------------
  foreach v_table in array v_tables loop
    if to_regclass('public.' || v_table) is null then
      raise exception 'Refused: table public.% does not exist. The undo has already run, this script was pasted twice into one query, or this is the wrong project. Nothing was changed by this copy.', v_table;
    end if;
    execute format('select exists (select 1 from public.%I)', v_table) into v_has_rows;
    if v_has_rows then
      raise exception 'Refused: table public.% has rows. This script only removes an empty Feedbox schema. Nothing was changed.', v_table;
    end if;
  end loop;

  if exists (select 1 from auth.users where email like '%@lumen.example') then
    raise exception 'Refused: auth.users has people at lumen.example (the Lumen seed). Nothing was changed.';
  end if;

  -- ---------------------------------------------------------------------------
  -- 1. The trigger on auth.users (it calls private.handle_new_user).
  -- ---------------------------------------------------------------------------
  drop trigger on_auth_user_created on auth.users;

  -- ---------------------------------------------------------------------------
  -- 2. The eight tables, in one statement. This also removes everything that
  --    belongs to them: their row-level security policies, indexes, triggers,
  --    constraints, grants and the identity sequences of ideas and comments.
  -- ---------------------------------------------------------------------------
  drop table
    public.changelog_items,
    public.changelog_entries,
    public.comments,
    public.votes,
    public.ideas,
    public.board_owners,
    public.profiles,
    public.boards;

  -- ---------------------------------------------------------------------------
  -- 3. Functions in public (10).
  -- ---------------------------------------------------------------------------
  drop function public.is_board_owner(uuid);
  drop function public.has_display_name();
  drop function public.set_idea_status(bigint, public.idea_status);
  drop function public.merge_ideas(bigint, bigint);
  drop function public.hide_idea(bigint);
  drop function public.unhide_idea(bigint);
  drop function public.hide_comment(bigint);
  drop function public.unhide_comment(bigint);
  drop function public.publish_changelog_entry(uuid, boolean);
  drop function public.similar_ideas(uuid, text, integer, boolean);

  -- ---------------------------------------------------------------------------
  -- 4. Functions in private (9).
  -- ---------------------------------------------------------------------------
  drop function private.recent_count(text, uuid);
  drop function private.handle_new_user();
  drop function private.enforce_rate_limit();
  drop function private.ideas_before_insert();
  drop function private.ideas_before_update();
  drop function private.ideas_after_insert();
  drop function private.votes_after_change();
  drop function private.comments_after_change();
  drop function private.changelog_items_check();

  -- ---------------------------------------------------------------------------
  -- 5. The type, then the schema "private" (it must be empty by now; without
  --    CASCADE the drop fails if anything else was put in it).
  -- ---------------------------------------------------------------------------
  drop type public.idea_status;
  drop schema private;
end;
$undo$;
-- end of undo-feedbox-v1.sql
