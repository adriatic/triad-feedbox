-- supabase/production/board-feedbox.sql | 60 lines | last line: -- end of board-feedbox.sql
-- =============================================================================
-- Feedbox production board: ONE row, for feedbox-prod only (decision D2).
-- Run once in the Supabase SQL Editor of feedbox-prod, after the migration
-- (task M3). It adds no ideas, no people and no owner. Making Nik an owner is
-- a later task.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless the project marker
--   (triad.project, task F3c) says feedbox-prod, the migration is applied,
--   there are no Lumen people and there is no board yet. If the script was
--   pasted twice into one query, the message says so.
-- * Check afterwards with supabase/checks/prod-board.sql.
-- =============================================================================

do $board$
declare
  v_project  text;
  v_same_txn boolean;
  v_slug     text;
  v_at       timestamptz;
begin
  -- Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. The Feedbox board is only for feedbox-prod. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-prod' and v_project is distinct from 'local' then
    raise exception 'Refused: this project is marked %. The Feedbox board is only for feedbox-prod. Check the project selector. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- Refuse unless the migration is applied and no Lumen data is here.
  if to_regclass('public.boards') is null then
    raise exception 'Refused: the Feedbox migration is not applied in this project (no table public.boards). Nothing was changed.';
  end if;
  if exists (select 1 from auth.users where email like '%@lumen.example') then
    raise exception 'Refused: this project has Lumen people (the preview seed). Nothing was changed.';
  end if;

  -- Refuse to run twice (also when pasted twice into one query).
  select b.xmin::text = (pg_current_xact_id()::xid)::text, b.slug, b.created_at
    into v_same_txn, v_slug, v_at
  from public.boards b order by b.created_at limit 1;
  if v_same_txn then
    raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
  end if;
  if v_slug is not null then
    raise exception 'Refused: this project already has a board (%, created %). This script has run before, or was pasted twice into one query. Nothing was changed by this copy.', v_slug, v_at;
  end if;

  insert into public.boards (slug, name, tagline, intro)
  values (
    'feedbox',
    'Feedbox',
    'What should Feedbox do next?',
    'Vote for what you need, or post a new idea. Ideas move to Planned, Building and Shipped as Feedbox grows.'
  );
end;
$board$;
-- end of board-feedbox.sql
