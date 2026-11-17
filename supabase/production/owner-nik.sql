-- supabase/production/owner-nik.sql | 171 lines | last line: -- end of owner-nik.sql
-- =============================================================================
-- Makes Nik the owner of the Feedbox board, on feedbox-prod only (task O1,
-- decision M5-D1). CHANGES the database: adds ONE row to public.board_owners.
-- Run once in the Supabase SQL Editor of feedbox-prod, after Nik's first
-- sign-in on Production (M5, 2026-11-17).
--
-- Nik's email address is not written here. His person is identified this way:
-- feedbox-prod holds exactly ONE person (auth.users), and that person's
-- display name is "Nikolaj Ivancic". If either is not true, the script refuses.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-prod; the Feedbox v1 migration is present
--   unchanged (the same fingerprint as the check scripts); the board
--   "feedbox" exists; there is exactly one person and it is named
--   "Nikolaj Ivancic"; and that person is not yet an owner of the board.
--   If the script was pasted twice into one query, the message says so.
-- * Check afterwards with supabase/checks/prod-owner.sql.
-- =============================================================================

do $owner$
declare
  v_project  text;
  v_md5      text;
  v_board    uuid;
  v_people   bigint;
  v_person   uuid;
  v_name     text;
  v_same_txn boolean;
  v_since    timestamptz;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-prod. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-prod' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-prod. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse unless the reviewed Feedbox v1 migration is present unchanged.
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
  if v_md5 is distinct from '160138805f7dcd5baa26b543b24aede3' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1 migration (fingerprint %, expected 160138805f7dcd5baa26b543b24aede3). Nothing was changed.', v_md5;
  end if;

  -- 3. Refuse unless the board "feedbox" exists.
  select b.id into v_board from public.boards b where b.slug = 'feedbox';
  if v_board is null then
    raise exception 'Refused: this project has no board "feedbox" (supabase/production/board-feedbox.sql has not run). Nothing was changed.';
  end if;

  -- 4. Identify Nik: exactly one person, named "Nikolaj Ivancic".
  select count(*) into v_people from auth.users;
  if v_people = 0 then
    raise exception 'Refused: this project has no person yet. Sign in once on https://triad-feedbox-delta.vercel.app and set your display name first. Nothing was changed.';
  end if;
  if v_people > 1 then
    raise exception 'Refused: this project has % people, so this script cannot tell which one is Nik (it expects exactly one). Nothing was changed.', v_people;
  end if;
  select u.id, p.display_name into v_person, v_name
  from auth.users u left join public.profiles p on p.id = u.id;
  if v_name is distinct from 'Nikolaj Ivancic' then
    raise exception 'Refused: the one person in this project has the display name %, not "Nikolaj Ivancic". Nothing was changed.', coalesce('"' || v_name || '"', '(none yet)');
  end if;

  -- 5. Refuse to run twice (also when pasted twice into one query).
  select o.xmin::text = (pg_current_xact_id()::xid)::text, o.created_at
    into v_same_txn, v_since
  from public.board_owners o
  where o.board_id = v_board and o.user_id = v_person;
  if v_same_txn then
    raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
  end if;
  if v_since is not null then
    raise exception 'Refused: "Nikolaj Ivancic" is already an owner of the board "feedbox" (since %). This script has run before, or was pasted twice into one query. Nothing was changed by this copy.', v_since;
  end if;

  insert into public.board_owners (board_id, user_id) values (v_board, v_person);
end;
$owner$;
-- end of owner-nik.sql
