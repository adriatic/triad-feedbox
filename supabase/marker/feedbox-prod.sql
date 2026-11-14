-- supabase/marker/feedbox-prod.sql | 65 lines | last line: -- end of feedbox-prod.sql
-- =============================================================================
-- One-time project marker for feedbox-prod (task F3c). CHANGES the database.
--
-- Supabase gives a SQL script no documented way to learn which project it runs
-- in (the database is called "postgres" in every project). So every Feedbox
-- script reads a marker that is set ONCE per project with this reviewed
-- script: one row in triad.project. Every check in supabase/checks/ and every
-- changing script then refuses to run in the wrong project.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, if this project already has a marker,
--   or if the project does not look like feedbox-prod today: feedbox-prod has
--   no Feedbox tables, no schema "private" and no Lumen people (the migration
--   was undone there on 2026-11-13). feedbox-preview has all of these.
-- * The schema "triad" is not exposed by the API (only the schemas listed in
--   the project's API settings are). Its privileges are also revoked from
--   anon and authenticated, and row-level security is on with no policy.
-- * The undo script and the Feedbox migration never touch the schema "triad".
-- =============================================================================

do $marker$
declare
  v_name     constant text := 'feedbox-prod';
  v_existing text;
  v_at       timestamptz;
  v_same_txn boolean;
begin
  -- 1. Already marked? This also catches a double paste.
  if to_regclass('triad.project') is not null then
    select p.name, p.marked_at, p.xmin::text = (pg_current_xact_id()::xid)::text
      into v_existing, v_at, v_same_txn
    from triad.project p;
    if v_same_txn then
      raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
    end if;
    if v_existing is not null then
      raise exception 'Refused: this project is already marked as % (since %). A marker is set once. If you pasted this script twice into one query, that is the cause. Nothing was changed by this copy.', v_existing, v_at;
    end if;
  end if;

  -- 2. Does the project look like feedbox-prod today?
  if to_regclass('public.boards') is not null
     or to_regnamespace('private') is not null
     or to_regtype('public.idea_status') is not null then
    raise exception 'Refused: this project has Feedbox tables, but feedbox-prod has none today. Are you in feedbox-preview? Check the project selector. Nothing was changed.';
  end if;
  if exists (select 1 from auth.users where email like '%@lumen.example') then
    raise exception 'Refused: this project has Lumen people (the preview seed), so it is not feedbox-prod. Nothing was changed.';
  end if;

  -- 3. The marker.
  create schema if not exists triad;
  revoke all on schema triad from public, anon, authenticated;
  create table if not exists triad.project (
    id        boolean primary key default true check (id),
    name      text not null check (name in ('local', 'feedbox-preview', 'feedbox-prod')),
    marked_at timestamptz not null default now()
  );
  revoke all on table triad.project from public, anon, authenticated;
  alter table triad.project enable row level security;
  insert into triad.project (name) values (v_name);
end;
$marker$;
-- end of feedbox-prod.sql
