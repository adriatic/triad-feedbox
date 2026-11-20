-- =============================================================================
-- Feedbox CT1: messages to a board's owners ("Contact the owner"; Nik,
-- 2026-11-19 11:42 AM). Task CT1.
--
-- * A self-contained part, "messages", with plain, general names, so that it
--   can be carried over to another app (docs/ARCHITECTURE.md, "The messages
--   part"). It needs only a table of boards, a table of profiles with a
--   display name, the function public.is_board_owner(board) and the rate
--   limit trigger of the Feedbox v1 migration.
-- * Adds the table public.messages: one row per message a signed-in person
--   sends to the owners of one board. Plain text, 1 to 2000 characters, with
--   no space or line break at either end (the app trims before sending).
-- * Nothing is sent by email: the owners read the messages in the app, and
--   answer from their own email. That is why an owner, and only an owner of
--   that board, may see the email address the sender signs in with: through
--   public.board_messages(board), which reads it from auth.users for that
--   board's messages and refuses anyone else. No table gets an email column.
-- * Row-level security: a signed-in person with a display name sends a
--   message as themselves, to a board that exists. The owners of the board
--   read that board's messages; nobody else reads any, not even the sender
--   (the app shows "Your message was sent to the owner." instead). There is
--   no update or delete rule: a message is marked read or unread only through
--   public.set_message_read(message, read), for owners only.
-- * Rate limit: at most 5 messages per person per hour, through the existing
--   rate limit trigger with a new kind "message" (private.recent_count and
--   private.enforce_rate_limit are replaced with versions that know it; the
--   kinds idea, comment and vote do exactly as before).
-- * Removing a person (supabase/people/remove-person.sql) removes their
--   messages too: author_id cascades from the profile.
-- * Every security definer function sets search_path to '' and names every
--   schema in full. Execute is revoked from public, anon and authenticated
--   (the hosted projects grant new functions automatically), then granted to
--   authenticated where needed.
-- * The Feedbox v1 (20261113000000), O2 (20261118000000) and F6a
--   (20261118120000) migrations are never edited; this is a new migration.
--   Nik pastes it on a hosted project through the guarded copy in
--   supabase/apply/ (task CT1), which runs exactly the statements below.
-- =============================================================================

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
