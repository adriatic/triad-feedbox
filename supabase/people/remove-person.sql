-- supabase/people/remove-person.sql | 175 lines | last line: -- end of remove-person.sql
-- =============================================================================
-- Removes ONE person and everything they wrote, on request (task F6; README,
-- "Privacy"). CHANGES the database. THIS FILE IS THE TEMPLATE and refuses to
-- run as it is.
--
-- For one request, a task copies this file to
-- supabase/people/remove-<yyyymmdd>.sql and changes ONLY the two values in the
-- block "request" below: the project, and the person's user id (the "User
-- UID" in the Supabase dashboard, Authentication, Users; never an email
-- address, which must not appear in this public repository).
-- tests/sql-files.test.ts checks that a copy differs from this template only
-- inside that block. The copy is reviewed and run from its pinned link like
-- every other script. Run supabase/checks/person-removal-<yyyymmdd>.sql (the
-- copy of supabase/checks/person-removal.sql with the same two values) first,
-- to see what will be removed, and again afterwards: it must then PASS.
--
-- What goes: the person (auth.users), and through the database's own
-- "on delete cascade" rules their profile, their ideas (with every vote,
-- comment and changelog line on those ideas, also other people's), their
-- votes and their comments. Where they hid something as an owner, or wrote a
-- changelog entry, only the link to them is cleared.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the block "request" names
--   feedbox-preview or feedbox-prod and the project marker says the same; the
--   database is the Feedbox v1 and O2 migrations, unchanged; the person
--   exists; the person owns no board (an owner is removed as an owner first,
--   with its own reviewed script); and no other idea has been merged into one
--   of their ideas. If the script was pasted twice into one query, the second
--   copy finds no person, and the message says that nothing was changed.
-- =============================================================================

do $remove$
declare
-- request:begin (the only lines a copy for one request may change)
  v_for    constant text := 'none';
  v_person constant uuid := '00000000-0000-0000-0000-000000000000';
-- request:end
  v_project  text;
  v_md5      text;
  v_owner    bigint;
  v_merged   bigint;
begin
  -- 1. The template itself never runs.
  if v_for not in ('feedbox-preview', 'feedbox-prod') then
    raise exception 'Refused: this is the template. Make a copy for one request, with the project and the person''s user id in the block "request". Nothing was changed.';
  end if;

  -- 2. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for %. Nothing was changed.', v_for;
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from v_for then
    raise exception 'Refused: this project is marked %. This script is only for %. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)'), v_for;
  end if;

  -- 3. Refuse unless the reviewed migrations (Feedbox v1 and O2) are present unchanged.
  if to_regclass('public.boards') is null or to_regclass('public.board_owners') is null then
    raise exception 'Refused: the Feedbox migration is not applied in this project (no table public.boards or public.board_owners). Nothing was changed.';
  end if;
  with
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
  fp as (select a.md5 from mig_all a)
  select fp.md5 into v_md5 from fp;
  if v_md5 is distinct from 'ea60181fdd11e237aa19ee5d6d6c186d' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 and O2 migrations (fingerprint %, expected ea60181fdd11e237aa19ee5d6d6c186d). Nothing was changed.', v_md5;
  end if;

  -- 4. The person must exist (a double paste ends here: the first copy removed them).
  if not exists (select 1 from auth.users u where u.id = v_person) then
    raise exception 'Refused: there is no person with the id % in this project. Either the person was removed already, or this script was pasted twice into one query: then nothing was changed, because the whole query is undone. Run the check script to see.', v_person;
  end if;

  -- 5. An owner is removed as an owner first, with its own reviewed script.
  select count(*) into v_owner from public.board_owners o where o.user_id = v_person;
  if v_owner > 0 then
    raise exception 'Refused: this person owns % board(s). Remove them as an owner first, with its own reviewed script. Nothing was changed.', v_owner;
  end if;

  -- 6. Ideas merged into one of theirs would point at nothing (merged_into_id has no cascade).
  select count(*) into v_merged
  from public.ideas m join public.ideas i on i.id = m.merged_into_id
  where i.author_id = v_person and m.author_id <> v_person;
  if v_merged > 0 then
    raise exception 'Refused: % idea(s) by other people were merged into ideas by this person, and would point at nothing. This needs its own reviewed script. Nothing was changed.', v_merged;
  end if;

  delete from auth.users u where u.id = v_person;
end;
$remove$;
-- end of remove-person.sql
