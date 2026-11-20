-- supabase/apply/preview-messages.sql | 329 lines | last line: -- end of preview-messages.sql
-- =============================================================================
-- Applies the migration supabase/migrations/20261119120000_messages.sql
-- on feedbox-preview only (task CT1: contact the owner). CHANGES the database: adds
-- the table public.messages, the owner functions public.board_messages and
-- public.set_message_read, and the rate limit kind "message" (new versions
-- of private.recent_count and private.enforce_rate_limit). Nothing else.
-- Run once in the Supabase SQL Editor of feedbox-preview, in task CT1, before the pull request is merged.
--
-- * ONE statement (a do-block): all or nothing. No psql commands.
-- * It refuses, and changes nothing, unless: the project marker
--   (triad.project) says feedbox-preview; the table public.messages does not exist
--   yet; and the reviewed Feedbox v1, O2 and F6a migrations are present
--   unchanged (the same fingerprint as the check scripts). If the script was
--   pasted twice into one query, the message says so.
-- * Section 4 is the migration's statements word for word;
--   tests/sql-files.test.ts keeps them identical to the migration file.
-- * Check afterwards with supabase/checks/preview-messages.sql.
-- =============================================================================

do $ct1$
declare
  v_project  text;
  v_md5      text;
  v_same_txn boolean;
begin
  -- 1. Refuse in the wrong project.
  if to_regclass('triad.project') is null then
    raise exception 'Refused: this project has no project marker (triad.project), so this script cannot tell where it is. It is only for feedbox-preview. Nothing was changed.';
  end if;
  select p.name into v_project from triad.project p;
  if v_project is distinct from 'feedbox-preview' then
    raise exception 'Refused: this project is marked %. This script is only for feedbox-preview. Check the project name at the top of the page. Nothing was changed.', coalesce(v_project, '(no name)');
  end if;

  -- 2. Refuse to run twice (also when pasted twice into one query).
  if to_regclass('public.messages') is not null then
    select c.xmin::text = (pg_current_xact_id()::xid)::text into v_same_txn
    from pg_class c where c.oid = to_regclass('public.messages');
    if v_same_txn then
      raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
    end if;
    raise exception 'Refused: the table public.messages already exists in this project, so this script has run before. Nothing was changed by this copy. Run supabase/checks/preview-messages.sql to see its state.';
  end if;

  -- 3. Refuse unless the reviewed Feedbox v1, O2 and F6a migrations are present unchanged.
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
  if v_md5 is distinct from '081ca51dd5b60c7b98cf8a6309584fb0' then
    raise exception 'Refused: the database does not match the reviewed Feedbox v1, O2 and F6a migrations (fingerprint %, expected 081ca51dd5b60c7b98cf8a6309584fb0). Nothing was changed.', v_md5;
  end if;

  -- 4. The migration 20261119120000_messages.sql, word for word.
-- migration:begin
create table public.messages (
  id         bigint generated always as identity primary key,
  board_id   uuid not null references public.boards (id) on delete cascade,
  author_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now(),
  read_at    timestamptz,
  -- 1 to 2000 characters, with no space, tab or line break at either end.
  constraint messages_body_check check (
    char_length(body) between 1 and 2000
    and body = btrim(body, E' \t\r\n')
  )
);

create index messages_board_created_idx  on public.messages (board_id, created_at desc);
create index messages_author_created_idx on public.messages (author_id, created_at);

comment on table public.messages is
  'Messages from signed-in people to the owners of one board (task CT1). Read by the board''s owners only.';

-- The rate limit: the v1 helper, with the new kind "message".
create or replace function private.recent_count(p_kind text, p_user_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_kind = 'idea' then
    return (select count(*) from public.ideas
            where author_id = p_user_id and created_at > now() - interval '1 hour');
  elsif p_kind = 'comment' then
    return (select count(*) from public.comments
            where author_id = p_user_id and created_at > now() - interval '1 hour');
  elsif p_kind = 'vote' then
    return (select count(*) from public.votes
            where user_id = p_user_id and created_at > now() - interval '1 hour');
  elsif p_kind = 'message' then
    return (select count(*) from public.messages
            where author_id = p_user_id and created_at > now() - interval '1 hour');
  end if;
  raise exception 'Unknown kind: %', p_kind;
end;
$$;

-- The v1 trigger function, with the limit for "message" written out: 5 ideas,
-- 30 comments, 100 votes and 5 messages per person per hour. Security
-- INVOKER, as before: only requests from the app (anon, authenticated) are
-- limited.
create or replace function private.enforce_rate_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_kind  text := tg_argv[0];
  v_limit integer;
  v_user  uuid;
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  -- Separate branches: each table has only one of the two person columns.
  if v_kind = 'vote' then
    v_limit := 100;
    v_user  := new.user_id;
  elsif v_kind = 'comment' then
    v_limit := 30;
    v_user  := new.author_id;
  elsif v_kind = 'message' then
    v_limit := 5;
    v_user  := new.author_id;
  else
    v_limit := 5;
    v_user  := new.author_id;
  end if;

  if private.recent_count(v_kind, v_user) >= v_limit then
    raise exception 'You are posting quickly. Try again in a few minutes.'
      using errcode = 'P0001', detail = 'rate_limit:' || v_kind;
  end if;
  return new;
end;
$$;

create trigger messages_rate_limit
  before insert on public.messages
  for each row execute function private.enforce_rate_limit('message');

-- The Messages page: one board's messages, newest first, each with the
-- sender's display name and the email address they sign in with, so an owner
-- can answer from their own email. Owners of that board only; anyone else is
-- refused (42501), visitors included.
create function public.board_messages(p_board_id uuid)
returns table (
  id           bigint,
  body         text,
  created_at   timestamptz,
  read_at      timestamptz,
  sender_id    uuid,
  sender_name  text,
  sender_email text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_board_owner(p_board_id) then
    raise exception 'Only an owner of this board can read its messages.' using errcode = '42501';
  end if;
  return query
    select m.id, m.body, m.created_at, m.read_at, m.author_id, p.display_name, u.email::text
    from public.messages m
    join public.profiles p on p.id = m.author_id
    left join auth.users u on u.id = m.author_id
    where m.board_id = p_board_id
    order by m.created_at desc, m.id desc;
end;
$$;

comment on function public.board_messages(uuid) is
  'One board''s messages with each sender''s name and sign-in email, newest first (task CT1). Owners of that board only.';

-- Mark a message read (p_read = true) or unread (false). Owners only.
create function public.set_message_read(p_message_id bigint, p_read boolean default true)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board uuid;
begin
  select board_id into v_board from public.messages where id = p_message_id;
  if v_board is null then
    raise exception 'Message not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_board) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  update public.messages
    set read_at = case when p_read then coalesce(read_at, now()) else null end
    where id = p_message_id;
end;
$$;

comment on function public.set_message_read(bigint, boolean) is
  'Marks one message read or unread (task CT1). Owners of its board only.';

-- Privileges. First take everything away, then grant back only what is needed.
revoke all on table public.messages from anon, authenticated;
revoke all on sequence public.messages_id_seq from anon, authenticated;
revoke all on function
  public.board_messages(uuid),
  public.set_message_read(bigint, boolean)
  from public, anon, authenticated;

grant select on public.messages to authenticated;
grant insert (board_id, body) on public.messages to authenticated;
grant execute on function public.board_messages(uuid) to authenticated;
grant execute on function public.set_message_read(bigint, boolean) to authenticated;

-- Row-level security: a signed-in person with a display name sends as
-- themselves, to a board that exists; the board's owners read its messages.
-- No rule for update or delete: nobody changes or removes a message through
-- the API.
alter table public.messages enable row level security;

create policy messages_insert_own on public.messages
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and public.has_display_name()
    and exists (select 1 from public.boards b where b.id = board_id)
  );

create policy messages_read_owner on public.messages
  for select to authenticated
  using (public.is_board_owner(board_id));
-- migration:end
end;
$ct1$;
-- end of preview-messages.sql
