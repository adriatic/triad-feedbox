-- =============================================================================
-- Feedbox production board: ONE row, for feedbox-prod only (decision D2).
-- Run once in the Supabase SQL Editor of feedbox-prod, after the migration.
-- It adds no ideas, no people and no owner. Making Nik an owner is a later task.
-- If the board already exists, it changes nothing.
-- =============================================================================

insert into public.boards (slug, name, tagline, intro)
values (
  'feedbox',
  'Feedbox',
  'What should Feedbox do next?',
  'Vote for what you need, or post a new idea. Ideas move to Planned, Building and Shipped as Feedbox grows.'
)
on conflict (slug) do nothing;
