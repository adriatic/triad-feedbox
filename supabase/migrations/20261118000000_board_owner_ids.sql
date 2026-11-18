-- =============================================================================
-- Feedbox O2: who owns a board, readable by everyone (decision F5-D1, Nik,
-- 2026-11-18 1:08 PM). Task O2.
--
-- * Adds ONE function, public.board_owner_ids(p_board_id), that returns the
--   user ids of the board's owners and nothing else: no email, no name, no
--   other column. The app uses it to show the "Owner" mark next to a comment
--   written by an owner, for every viewer (visitors and members too).
-- * public.board_owners and its policy board_owners_read are NOT changed: a
--   direct read of the table still shows an owner every owner, and anyone
--   else at most their own row.
-- * Security definer, so it can read board_owners past row-level security;
--   search_path is '' and every name is written in full. Stable: it only reads.
-- * Execute is revoked from public, anon and authenticated (the hosted projects
--   grant new functions automatically), then granted to anon and authenticated.
-- * The Feedbox v1 migration (20261113000000) is never edited; this is a new
--   migration. Nik pastes it on a hosted project through the guarded copy in
--   supabase/apply/ (task O2), which runs exactly the statements below.
-- =============================================================================

create function public.board_owner_ids(p_board_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.user_id
  from public.board_owners o
  where o.board_id = p_board_id
  order by o.user_id;
$$;

comment on function public.board_owner_ids(uuid) is
  'The user ids of the owners of one board, and nothing else. Readable by everyone (decision F5-D1, task O2).';

revoke all on function public.board_owner_ids(uuid) from public, anon, authenticated;
grant execute on function public.board_owner_ids(uuid) to anon, authenticated;
