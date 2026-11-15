-- supabase/checks/prod-after-migration.sql | 227 lines | last line: -- end of prod-after-migration.sql
-- =============================================================================
-- READ-ONLY check (task F3c). Changes nothing: one SELECT.
-- For: feedbox-prod. When: right after the Feedbox v1 migration is run there (M3).
-- It checks that this is feedbox-prod (project marker) and that the database
-- holds exactly what the reviewed migration creates: the 8 tables with
-- row-level security on, the 19 policies, the privileges of F1 section 3
-- (as in the F3 report), the 19 functions, the 10 triggers, and no
-- Feedbox rows except one profile per existing person. The long values
-- (columns, indexes, policies, functions, triggers) are compared as md5
-- fingerprints, taken from a fresh local install of the same migration.
-- Result: rows (n, check_name, result, message). Row 0 is the overall result:
-- go on only if it says PASS.
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
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-prod',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-prod.'
              else format('this project is marked %s; this check is for feedbox-prod.', (select name from project)) end
  union all
  select 2, 'tables', m.tables = 'board_owners,boards,changelog_entries,changelog_items,comments,ideas,profiles,votes',
         format('tables in public: %s (expected the 8 Feedbox tables).', coalesce(nullif(m.tables, ''), 'none'))
  from mig m
  union all
  select 3, 'row-level security', m.rls_on = 8,
         format('row-level security is on for %s tables in public (expected 8).', m.rls_on)
  from mig m
  union all
  select 4, 'type idea_status', m.idea_status = 'open,planned,building,shipped',
         format('public.idea_status has the values: %s (expected open,planned,building,shipped).',
                coalesce(nullif(m.idea_status, ''), 'type missing'))
  from mig m
  union all
  select 5, 'columns', m.columns_md5 = '30a628fd455a56470d5391ae76d443ed',
         format('the columns of the tables %s the reviewed migration (fingerprint %s).',
                case when m.columns_md5 = '30a628fd455a56470d5391ae76d443ed' then 'match' else 'DO NOT match' end,
                coalesce(nullif(m.columns_md5, ''), 'none'))
  from mig m
  union all
  select 6, 'indexes', m.indexes_md5 = 'fb3aa7edac7de169e867b1f440079872',
         format('the indexes %s the reviewed migration (fingerprint %s).',
                case when m.indexes_md5 = 'fb3aa7edac7de169e867b1f440079872' then 'match' else 'DO NOT match' end,
                coalesce(nullif(m.indexes_md5, ''), 'none'))
  from mig m
  union all
  select 7, 'policies', m.policies_n = 19 and m.policies_md5 = '8894562ea7c961dd1bfd3beb6336bb3e',
         format('%s row-level security policies (expected 19); their rules %s the reviewed migration (fingerprint %s).',
                m.policies_n,
                case when m.policies_md5 = '8894562ea7c961dd1bfd3beb6336bb3e' then 'match' else 'DO NOT match' end,
                coalesce(nullif(m.policies_md5, ''), 'none'))
  from mig m
  union all
  select 8, 'table privileges',
         m.table_grants = 'anon boards SELECT; anon changelog_entries SELECT; anon changelog_items SELECT; anon comments SELECT; anon ideas SELECT; anon profiles SELECT; authenticated board_owners SELECT; authenticated boards SELECT; authenticated changelog_entries DELETE,SELECT; authenticated changelog_items DELETE,SELECT; authenticated comments SELECT; authenticated ideas SELECT; authenticated profiles SELECT; authenticated votes DELETE,SELECT',
         format('anon and authenticated hold these table privileges (and none on sequences): %s.',
                coalesce(nullif(m.table_grants, ''), 'none'))
  from mig m
  union all
  select 9, 'column privileges',
         m.column_grants = 'authenticated changelog_entries INSERT board_id,released_on,title; authenticated changelog_entries UPDATE released_on,title; authenticated changelog_items INSERT entry_id,idea_id,note,position; authenticated changelog_items UPDATE note,position; authenticated comments INSERT body,idea_id; authenticated ideas INSERT board_id,body,title; authenticated profiles UPDATE display_name; authenticated votes INSERT idea_id',
         format('writes granted column by column: %s.', coalesce(nullif(m.column_grants, ''), 'none'))
  from mig m
  union all
  select 10, 'functions', m.functions_n = 19 and m.functions_md5 = '9ee35a2a9569dca2f742a177511dfee8',
         format('%s functions in public and private (expected 19); their code and settings %s the reviewed migration (fingerprint %s).',
                m.functions_n,
                case when m.functions_md5 = '9ee35a2a9569dca2f742a177511dfee8' then 'match' else 'DO NOT match' end,
                coalesce(nullif(m.functions_md5, ''), 'none'))
  from mig m
  union all
  select 11, 'who may call functions',
         m.function_exec = 'anon: has_display_name,is_board_owner,similar_ideas; authenticated: has_display_name,hide_comment,hide_idea,is_board_owner,merge_ideas,publish_changelog_entry,recent_count,set_idea_status,similar_ideas,unhide_comment,unhide_idea'
         and m.private_usage = 'authenticated',
         format('%s. Schema private usable by: %s (expected authenticated only).', m.function_exec, m.private_usage)
  from mig m
  union all
  select 12, 'triggers', m.triggers_n = 10 and m.auth_trigger_n = 1 and m.triggers_md5 = '2bf5d2dcfca187b7d9e5a7f787940967',
         format('%s triggers (expected 10), on_auth_user_created on auth.users: %s; they %s the reviewed migration (fingerprint %s).',
                m.triggers_n, case when m.auth_trigger_n = 1 then 'present' else 'MISSING' end,
                case when m.triggers_md5 = '2bf5d2dcfca187b7d9e5a7f787940967' then 'match' else 'DO NOT match' end,
                coalesce(nullif(m.triggers_md5, ''), 'none'))
  from mig m
  union all
  select 13, 'pg_trgm and no emails', m.trgm_schema = 'extensions' and m.mail_columns = 0,
         format('pg_trgm is in schema %s (expected extensions); %s email columns in public (expected 0).',
                m.trgm_schema, m.mail_columns)
  from mig m
  union all
  select 14, 'no Feedbox rows yet',
         coalesce(sum(c.n) filter (where c.name <> 'profiles'), -1) = 0
         and (select n from counts where name = 'profiles') = (select all_people from people),
         format('rows: %s (expected 0 everywhere, and one profile per person in auth.users: %s).',
                string_agg(c.name || ' ' || coalesce(c.n::text, 'missing'), ', ' order by c.name),
                (select all_people from people))
  from counts c
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
-- end of prod-after-migration.sql
