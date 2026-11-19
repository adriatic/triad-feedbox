-- supabase/checks/person-removal.sql | 202 lines | last line: -- end of person-removal.sql
-- =============================================================================
-- READ-ONLY check (task F6). Changes nothing: one SELECT.
-- THIS FILE IS THE TEMPLATE: it always FAILs as it is. For one request, a task
-- copies it to supabase/checks/person-removal-<yyyymmdd>.sql and changes ONLY
-- the two values in the block "request" (the same as in the removal script's
-- copy, see supabase/people/remove-person.sql).
-- When: before the removal script, to see what it will remove (row 3 then
-- FAILs and says what is still there), and right after it, when every row
-- must PASS: the person and everything of theirs are gone.
-- Result: rows (n, check_name, result, message). Row 0 is the overall result.
-- =============================================================================

with
-- request:begin (the only lines a copy for one request may change)
request as (
  select 'none'::text as for_project,
         '00000000-0000-0000-0000-000000000000'::uuid as person
),
-- request:end
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
person as (
  select (xpath('/table/row/users/text()', x))[1]::text::int as users,
         (xpath('/table/row/name/text()', x))[1]::text as name,
         (xpath('/table/row/profiles/text()', x))[1]::text::int as profiles,
         (xpath('/table/row/ideas/text()', x))[1]::text::int as ideas,
         (xpath('/table/row/others_on_ideas/text()', x))[1]::text::int as others_on_ideas,
         (xpath('/table/row/votes/text()', x))[1]::text::int as votes,
         (xpath('/table/row/comments/text()', x))[1]::text::int as comments,
         (xpath('/table/row/owns/text()', x))[1]::text::int as owns,
         (xpath('/table/row/merge_votes/text()', x))[1]::text::int as merge_votes
  from request r
  cross join lateral (select query_to_xml(format(
                 'select (select count(*) from auth.users u where u.id = %1$L) as users,
                         (select p.display_name from public.profiles p where p.id = %1$L) as name,
                         (select count(*) from public.profiles p where p.id = %1$L) as profiles,
                         (select count(*) from public.ideas i where i.author_id = %1$L) as ideas,
                         (select (select count(*) from public.comments c join public.ideas i on i.id = c.idea_id
                                   where i.author_id = %1$L and c.author_id <> %1$L)
                               + (select count(*) from public.votes v join public.ideas i on i.id = v.idea_id
                                   where i.author_id = %1$L and v.user_id <> %1$L)) as others_on_ideas,
                         (select count(*) from public.votes v where v.user_id = %1$L) as votes,
                         (select count(*) from public.comments c where c.author_id = %1$L) as comments,
                         (select count(*) from public.board_owners o where o.user_id = %1$L) as owns,
                         (select count(*) from public.idea_merge_votes mv where mv.user_id = %1$L) as merge_votes', r.person),
               false, false, '') as x
         where to_regclass('public.boards') is not null and to_regclass('public.board_owners') is not null
           and to_regclass('public.idea_merge_votes') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = (select for_project from request),
         case when (select for_project from request) not in ('feedbox-preview', 'feedbox-prod')
              then 'this is the template (no request in it). Use the copy made for one request.'
              when (select name from project) is null
              then format('this project has no project marker (triad.project). This check is for %s.', (select for_project from request))
              else format('this project is marked %s; this check is for %s.', (select name from project), (select for_project from request)) end
  union all
  select 2, 'migrations', a.md5 = '2814d0ac55dce9fa93db839da532dec7',
         case when a.md5 = '2814d0ac55dce9fa93db839da532dec7'
              then 'the Feedbox v1, O2 and F6a migrations are present and unchanged (fingerprint 2814d0ac55dce9fa93db839da532dec7).'
              else format('the database does not match the Feedbox v1, O2 and F6a migrations (fingerprint %s, expected 2814d0ac55dce9fa93db839da532dec7).', a.md5) end
  from mig_all a
  union all
  select 3, 'person removed', coalesce((select users = 0 from person), false),
         case when not exists (select 1 from person) then 'the Feedbox tables or the merge log are missing, so nothing could be asked.'
              when (select users from person) = 0 then 'there is no person with this id in this project.'
              else (select format('the person still exists: display name %s; %s ideas (with %s votes and comments by other people on them, which go too); %s votes; %s comments; owner of %s boards. The removal script removes all of this.',
                                  coalesce('"' || name || '"', '(none)'), ideas, others_on_ideas, votes, comments, owns) from person) end
  union all
  select 4, 'nothing left', coalesce((select profiles + ideas + votes + comments + owns + merge_votes = 0 from person), false),
         case when not exists (select 1 from person) then 'the Feedbox tables or the merge log are missing, so nothing could be asked.'
              else (select format('left with this id: %s profile, %s ideas, %s votes, %s comments, %s owner rows, %s votes in the merge log (expected 0 of each).',
                                  profiles, ideas, votes, comments, owns, merge_votes) from person) end
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
-- end of person-removal.sql
