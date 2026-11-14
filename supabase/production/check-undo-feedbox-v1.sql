-- supabase/production/check-undo-feedbox-v1.sql | 19 lines | last line: -- end of check-undo-feedbox-v1.sql
-- Read-only check after undo-feedbox-v1.sql (task F3b). Changes nothing.
-- Kept as run on 2026-11-13; superseded by supabase/checks/prod-before-migration.sql.
-- Expected: one row with boards_table NULL, private_schema NULL,
-- idea_status_type NULL, auth_trigger_count 0 and feedbox_function_count 0.
select
  to_regclass('public.boards')       as boards_table,
  to_regnamespace('private')         as private_schema,
  to_regtype('public.idea_status')   as idea_status_type,
  (select count(*) from pg_trigger
    where tgname = 'on_auth_user_created'
      and tgrelid = 'auth.users'::regclass) as auth_trigger_count,
  (select count(*) from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('is_board_owner', 'has_display_name', 'set_idea_status',
                      'merge_ideas', 'hide_idea', 'unhide_idea', 'hide_comment',
                      'unhide_comment', 'publish_changelog_entry', 'similar_ideas')
  ) as feedbox_function_count;
-- end of check-undo-feedbox-v1.sql
