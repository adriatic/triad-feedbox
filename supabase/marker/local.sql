-- supabase/marker/local.sql | 25 lines | last line: -- end of local.sql
-- =============================================================================
-- Project marker for the LOCAL database only (Docker on the Mac and in CI).
-- NEVER paste this into the Supabase SQL Editor. It is run by
-- `supabase db reset` and `supabase db start` before seed.sql (see
-- [db.seed] in supabase/config.toml), so local scripts know they are local.
-- The hosted projects are marked with supabase/marker/feedbox-preview.sql and
-- supabase/marker/feedbox-prod.sql instead.
-- =============================================================================

do $marker$
begin
  create schema if not exists triad;
  revoke all on schema triad from public, anon, authenticated;
  create table if not exists triad.project (
    id        boolean primary key default true check (id),
    name      text not null check (name in ('local', 'feedbox-preview', 'feedbox-prod')),
    marked_at timestamptz not null default now()
  );
  revoke all on table triad.project from public, anon, authenticated;
  alter table triad.project enable row level security;
  insert into triad.project (name) values ('local') on conflict (id) do nothing;
end;
$marker$;
-- end of local.sql
