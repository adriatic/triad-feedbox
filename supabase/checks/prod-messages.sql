-- supabase/checks/prod-messages.sql | 263 lines | last line: -- end of prod-messages.sql
-- =============================================================================
-- READ-ONLY check (task CT1). Changes nothing: one SELECT.
-- For: feedbox-prod. When: right after supabase/apply/prod-messages.sql.
-- It checks that this is feedbox-prod (project marker); that the database is the
-- Feedbox v1, O2, F6a and CT1 migrations, all unchanged; that the table
-- public.messages exists with row-level security; that signed-in people may
-- send a message only as themselves (the columns board_id and body) and only
-- the board's owners read them, with no rule to change or remove one; that
-- board_messages (the only way to the sender's email) and set_message_read
-- check that the caller owns the board, are security definer with
-- search_path '' and callable by signed-in people only; that the rate limit
-- of 5 messages an hour is on; and that no message is on a board without an
-- owner, where nobody could read it.
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
msgt as (
  select c.relrowsecurity as rls,
         coalesce((select string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
                     from aclexplode(c.relacl) a where a.grantee = to_regrole('authenticated')), '') as auth_privs,
         coalesce((select string_agg(distinct a.privilege_type, ',' order by a.privilege_type)
                     from aclexplode(c.relacl) a where a.grantee = 0 or a.grantee = to_regrole('anon')), '') as others_privs,
         coalesce((select string_agg(format('%s %s', a.privilege_type, t.attname), ',' order by a.privilege_type, t.attname)
                     from pg_attribute t, aclexplode(t.attacl) a
                    where t.attrelid = c.oid and t.attnum > 0 and a.grantee = to_regrole('authenticated')), '') as auth_columns,
         (select count(*) from pg_attribute t, aclexplode(t.attacl) a
           where t.attrelid = c.oid and t.attnum > 0
             and (a.grantee = 0 or a.grantee = to_regrole('anon'))) as others_columns,
         (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = 'messages') as policies,
         (select count(*) from pg_policies p
           where p.schemaname = 'public' and p.tablename = 'messages' and p.policyname = 'messages_read_owner'
             and p.cmd = 'SELECT' and p.roles = array['authenticated']::name[]
             and p.qual = 'is_board_owner(board_id)') as owner_read,
         (select count(*) from pg_policies p
           where p.schemaname = 'public' and p.tablename = 'messages' and p.policyname = 'messages_insert_own'
             and p.cmd = 'INSERT' and p.roles = array['authenticated']::name[]
             and position('auth.uid()' in p.with_check) > 0) as own_insert
  from pg_class c
  where c.oid = to_regclass('public.messages')
),
fns as (
  select p.proname::text as name,
         p.prosecdef as secdef,
         coalesce(array_to_string(p.proconfig, ','), '') as config,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
         (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0)) as public_exec,
         position('public.is_board_owner(' in p.prosrc) > 0 as owner_check,
         position('auth.users' in p.prosrc) > 0 as reads_email
  from pg_proc p
  where p.oid in (to_regprocedure('public.board_messages(uuid)'), to_regprocedure('public.set_message_read(bigint, boolean)'))
),
limiter as (
  select (select count(*) from pg_trigger t
           where t.tgenabled = 'O' and t.tgrelid = to_regclass('public.messages') and t.tgname = 'messages_rate_limit'
             and position('enforce_rate_limit(''message'')' in pg_get_triggerdef(t.oid)) > 0) as triggers,
         coalesce((select position('public.messages' in p.prosrc) > 0
                     from pg_proc p where p.oid = to_regprocedure('private.recent_count(text, uuid)')), false) as counts_messages,
         coalesce((select position('v_kind = ''message''' in p.prosrc) > 0
                     from pg_proc p where p.oid = to_regprocedure('private.enforce_rate_limit()')), false) as knows_message
),
msgs as (
  select (xpath('/table/row/total/text()', x))[1]::text::int as total,
         (xpath('/table/row/unread/text()', x))[1]::text::int as unread,
         (xpath('/table/row/unowned/text()', x))[1]::text::int as unowned
  from (select query_to_xml(
                 'select count(*) as total,
                         count(*) filter (where m.read_at is null) as unread,
                         count(*) filter (where not exists (select 1 from public.board_owners o where o.board_id = m.board_id)) as unowned
                  from public.messages m', false, false, '') as x
         where to_regclass('public.messages') is not null and to_regclass('public.board_owners') is not null) q
),
checks (n, check_name, ok, detail) as (
  select 1, 'project', (select name from project) = 'feedbox-prod',
         case when (select name from project) is null
              then 'this project has no project marker (triad.project). This check is for feedbox-prod.'
              else format('this project is marked %s; this check is for feedbox-prod.', (select name from project)) end
  union all
  select 2, 'migrations', a.md5 = 'f48a2386ba60d5b8353cc684891bdc25',
         case when a.md5 = 'f48a2386ba60d5b8353cc684891bdc25'
              then 'the Feedbox v1, O2, F6a and CT1 migrations are present and unchanged (fingerprint f48a2386ba60d5b8353cc684891bdc25).'
              when a.md5 = '081ca51dd5b60c7b98cf8a6309584fb0'
              then 'the database is the Feedbox v1, O2 and F6a migrations WITHOUT the CT1 migration (fingerprint 081ca51dd5b60c7b98cf8a6309584fb0, expected f48a2386ba60d5b8353cc684891bdc25). Run supabase/apply/prod-messages.sql first.'
              else format('the database does not match the Feedbox v1, O2, F6a and CT1 migrations (fingerprint %s, expected f48a2386ba60d5b8353cc684891bdc25).', a.md5) end
  from mig_all a
  union all
  select 3, 'messages table', coalesce((select rls from msgt), false),
         case when not exists (select 1 from msgt) then 'the table public.messages is MISSING.'
              else format('the table public.messages exists; row-level security is on: %s (expected yes).',
                          (select case when rls then 'yes' else 'no' end from msgt)) end
  union all
  select 4, 'who reads and writes',
         coalesce((select auth_privs = 'SELECT' and auth_columns = 'INSERT board_id,INSERT body' and others_privs = '' and others_columns = 0
                          and policies = 2 and owner_read = 1 and own_insert = 1 from msgt), false),
         case when not exists (select 1 from msgt) then 'the table public.messages is missing, so there is nothing to look at.'
              else (select format('signed-in people may: %s on the table (expected SELECT only), and %s on columns (expected INSERT board_id,INSERT body); visitors and everyone else: %s on the table and %s column rights (expected nothing and 0); %s rule(s) (expected 2): one that lets only the board''s owners read: %s, one that lets a person send only as themselves: %s (expected 1 and 1). No rule changes or removes a message.',
                                  coalesce(nullif(auth_privs, ''), 'nothing'), coalesce(nullif(auth_columns, ''), 'nothing'),
                                  coalesce(nullif(others_privs, ''), 'nothing'), others_columns, policies, owner_read, own_insert)
                    from msgt) end
  union all
  select 5, 'board_messages', coalesce((select secdef and config = 'search_path=""' and auth_exec and not anon_exec and not public_exec
                                               and owner_check and reads_email
                                          from fns where name = 'board_messages'), false),
         case when not exists (select 1 from fns where name = 'board_messages') then 'the function public.board_messages(uuid) is MISSING.'
              else (select format('checks that the caller owns the board: %s; reads the sender''s email from auth.users: %s; security definer: %s; settings: %s (expected search_path=""); signed-in people may call it: %s; visitors: %s; everyone else: %s. Expected yes, yes, yes, yes, no, no.',
                                  case when owner_check then 'yes' else 'no' end, case when reads_email then 'yes' else 'no' end,
                                  case when secdef then 'yes' else 'no' end, coalesce(nullif(config, ''), 'none'),
                                  case when auth_exec then 'yes' else 'no' end, case when anon_exec then 'yes' else 'no' end,
                                  case when public_exec then 'yes' else 'no' end)
                    from fns where name = 'board_messages') end
  union all
  select 6, 'set_message_read', coalesce((select secdef and config = 'search_path=""' and auth_exec and not anon_exec and not public_exec
                                                 and owner_check and not reads_email
                                            from fns where name = 'set_message_read'), false),
         case when not exists (select 1 from fns where name = 'set_message_read') then 'the function public.set_message_read(bigint, boolean) is MISSING.'
              else (select format('checks that the caller owns the board: %s; reads any email: %s; security definer: %s; settings: %s (expected search_path=""); signed-in people may call it: %s; visitors: %s; everyone else: %s. Expected yes, no, yes, yes, no, no.',
                                  case when owner_check then 'yes' else 'no' end, case when reads_email then 'yes' else 'no' end,
                                  case when secdef then 'yes' else 'no' end, coalesce(nullif(config, ''), 'none'),
                                  case when auth_exec then 'yes' else 'no' end, case when anon_exec then 'yes' else 'no' end,
                                  case when public_exec then 'yes' else 'no' end)
                    from fns where name = 'set_message_read') end
  union all
  select 7, 'rate limit', (select triggers = 1 and counts_messages and knows_message from limiter),
         (select format('rate limit trigger on public.messages for the kind "message", switched on: %s (expected 1); private.recent_count counts messages: %s; private.enforce_rate_limit knows the kind "message": %s (expected yes and yes).',
                        triggers, case when counts_messages then 'yes' else 'no' end, case when knows_message then 'yes' else 'no' end)
            from limiter)
  union all
  select 8, 'someone reads them', coalesce((select unowned = 0 from msgs), false),
         case when not exists (select 1 from msgs) then 'the table public.messages is missing, so nothing could be asked.'
              else (select format('%s messages, %s of them not read yet; on a board with no owner, so that nobody can read them: %s (expected 0).',
                                  total, unread, unowned) from msgs) end
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
-- end of prod-messages.sql
