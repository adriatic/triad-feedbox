-- supabase/checks/prod-merge-undo.sql | 260 lines | last line: -- end of prod-merge-undo.sql
-- =============================================================================
-- READ-ONLY check (task F6a). Changes nothing: one SELECT.
-- For: feedbox-prod. When: right after supabase/apply/prod-merge-undo.sql.
-- It checks that this is feedbox-prod (project marker); that the database is the
-- Feedbox v1, O2 and F6a migrations, all unchanged; that the merge log
-- (public.idea_merges and public.idea_merge_votes) exists with row-level
-- security; that only signed-in owners read idea_merges, and nobody reads
-- idea_merge_votes or writes either table directly; that merge_ideas writes
-- the log and undo_merge exists, both security definer with search_path '' and
-- callable by signed-in people only; that the race guards of task F6b are in
-- place (a vote or comment on a merged idea is refused after waiting for the
-- merge; votes are removed only through remove_my_vote); and that every merge
-- in the log that can still be undone names a merged idea.
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
guards as (
  select (select count(*) from pg_trigger t
           where t.tgenabled = 'O' and t.tgfoid = to_regprocedure('private.refuse_merged_idea()')
             and ((t.tgrelid = to_regclass('public.votes') and t.tgname = 'votes_refuse_merged')
                  or (t.tgrelid = to_regclass('public.comments') and t.tgname = 'comments_refuse_merged'))) as triggers,
         coalesce((select p.prosecdef and coalesce(array_to_string(p.proconfig, ','), '') = 'search_path=""'
                          and has_function_privilege('authenticated', p.oid, 'EXECUTE')
                          and not has_function_privilege('anon', p.oid, 'EXECUTE')
                          and not (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0))
                     from pg_proc p where p.oid = to_regprocedure('public.remove_my_vote(bigint)')), false) as unvote_fn,
         coalesce((select has_table_privilege('authenticated', c.oid, 'DELETE') or has_table_privilege('anon', c.oid, 'DELETE')
                     from pg_class c where c.oid = to_regclass('public.votes')), true) as votes_deletable
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
  select 2, 'migrations', a.md5 = '081ca51dd5b60c7b98cf8a6309584fb0',
         case when a.md5 = '081ca51dd5b60c7b98cf8a6309584fb0'
              then 'the Feedbox v1, O2 and F6a migrations are present and unchanged (fingerprint 081ca51dd5b60c7b98cf8a6309584fb0).'
              when a.md5 = 'ea60181fdd11e237aa19ee5d6d6c186d'
              then 'the database is the Feedbox v1 and O2 migrations WITHOUT the F6a migration (fingerprint ea60181fdd11e237aa19ee5d6d6c186d, expected 081ca51dd5b60c7b98cf8a6309584fb0). Run supabase/apply/prod-merge-undo.sql first.'
              else format('the database does not match the Feedbox v1, O2 and F6a migrations (fingerprint %s, expected 081ca51dd5b60c7b98cf8a6309584fb0).', a.md5) end
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
  select 7, 'race guards', (select triggers = 2 and unvote_fn and not votes_deletable from guards),
         (select format('triggers that refuse a vote or comment on a merged idea after waiting for the merge, switched on: %s (expected 2, on votes and on comments); public.remove_my_vote is security definer with search_path "", callable by signed-in people only: %s (expected yes); votes can be deleted directly through the API: %s (expected no).',
                        triggers, case when unvote_fn then 'yes' else 'no' end, case when votes_deletable then 'yes' else 'no' end)
            from guards)
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
