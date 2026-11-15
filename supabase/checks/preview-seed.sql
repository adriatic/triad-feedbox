-- supabase/checks/preview-seed.sql | 219 lines | last line: -- end of preview-seed.sql
-- =============================================================================
-- READ-ONLY check (task F3c). Changes nothing: one SELECT.
-- For: feedbox-preview. When: any time after the Lumen seed (it ran there on
-- 2026-11-13).
-- It checks that this is feedbox-preview (project marker), that the reviewed
-- Feedbox v1 migration is present unchanged (one fingerprint of everything
-- prod-after-migration.sql checks), and that the Lumen seed is complete:
-- 221 people, 1 board, 1 owner (Ana), 10 ideas, 1059 votes, 9 comments,
-- 2 published changelog entries with 3 items, and every idea's status,
-- vote count and comment count as in the design brief.
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
lumen as (
  select (xpath('/row/title/text()', r))[1]::text as title,
         (xpath('/row/status/text()', r))[1]::text as status,
         (xpath('/row/vote_count/text()', r))[1]::text::int as votes,
         (xpath('/row/comment_count/text()', r))[1]::text::int as comments
  from unnest(xpath('/table/row', (
         select query_to_xml(
                  'select i.title, i.status, i.vote_count, i.comment_count
                     from public.ideas i join public.boards b on b.id = i.board_id
                    where b.slug = ''lumen''', false, false, '')
         where to_regclass('public.ideas') is not null and to_regclass('public.boards') is not null))) as r
),
lumen_extra as (
  select (xpath('/table/row/owner/text()', x))[1]::text as owner,
         (xpath('/table/row/published/text()', x))[1]::text::int as published
  from (select query_to_xml(
                 'select (select string_agg(p.display_name, '','' order by p.display_name)
                            from public.board_owners o
                            join public.boards b on b.id = o.board_id
                            join public.profiles p on p.id = o.user_id
                           where b.slug = ''lumen'') as owner,
                         (select count(*) from public.changelog_entries e
                           where e.published_at is not null) as published', false, false, '') as x
         where to_regclass('public.board_owners') is not null and to_regclass('public.changelog_entries') is not null) q
),
expected (n, title, status, votes, comments) as (
  values
    (21, 'Dark mode for the editor',           'planned',  214, 3),
    (22, 'Export notes to Markdown',           'building', 187, 2),
    (23, 'Offline mode',                       'planned',  132, 1),
    (24, 'Pin notes to the top of a notebook', 'shipped',  121, 0),
    (25, 'Keyboard shortcut cheat sheet',      'shipped',   96, 0),
    (26, 'Faster startup on large notebooks',  'shipped',   88, 0),
    (27, 'Sync between two laptops',           'open',      73, 2),
    (28, 'Search inside attachments',          'open',      58, 0),
    (29, 'Share a note by link',               'open',      49, 0),
    (30, 'Tag notes by colour',                'open',      41, 1)
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-preview',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-preview.'
              else format('this project is marked %s; this check is for feedbox-preview.', (select name from project)) end
  union all
  select 2, 'migration', a.md5 = '160138805f7dcd5baa26b543b24aede3',
         case when a.md5 = '160138805f7dcd5baa26b543b24aede3'
              then 'the Feedbox v1 migration is present and unchanged (fingerprint 160138805f7dcd5baa26b543b24aede3).'
              else format('the database does not match the reviewed Feedbox v1 migration (fingerprint %s, expected 160138805f7dcd5baa26b543b24aede3).', a.md5) end
  from mig_all a
  union all
  select 3, 'people', p.lumen_people = 221 and (select n from counts where name = 'profiles') = p.all_people,
         format('%s people at lumen.example (expected 221); %s profiles for %s people in auth.users (expected one each).',
                p.lumen_people, coalesce((select n from counts where name = 'profiles')::text, 'no table'), p.all_people)
  from people p
  union all
  select 4, 'rows',
         string_agg(c.name || ' ' || coalesce(c.n::text, 'missing'), ', ' order by c.name) filter (where c.name <> 'profiles')
           = 'board_owners 1, boards 1, changelog_entries 2, changelog_items 3, comments 9, ideas 10, votes 1059',
         format('%s (expected board_owners 1, boards 1, changelog_entries 2, changelog_items 3, comments 9, ideas 10, votes 1059).',
                string_agg(c.name || ' ' || coalesce(c.n::text, 'missing'), ', ' order by c.name) filter (where c.name <> 'profiles'))
  from counts c
  union all
  select 5, 'board and owner',
         (select count(*) from lumen) = 10 and (select owner from lumen_extra) = 'Ana' and (select published from lumen_extra) = 2,
         format('%s ideas on the Lumen board (expected 10); owner: %s (expected Ana); %s published changelog entries (expected 2).',
                (select count(*) from lumen), coalesce((select owner from lumen_extra), 'none'),
                coalesce((select published from lumen_extra)::text, 'none'))
  union all
  select e.n, 'idea ' || (e.n - 20),
         l.status = e.status and l.votes = e.votes and l.comments = e.comments,
         case when l.title is null then format('"%s" is missing.', e.title)
              else format('"%s": %s, %s votes, %s comments (expected %s, %s votes, %s comments).',
                          e.title, l.status, l.votes, l.comments, e.status, e.votes, e.comments) end
  from expected e left join lumen l on l.title = e.title
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
-- end of preview-seed.sql
