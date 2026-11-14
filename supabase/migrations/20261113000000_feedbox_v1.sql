-- =============================================================================
-- Feedbox v1: schema, access rules (row-level security), triggers and owner
-- functions. Task F3. Design: F1 sections 2, 3, 5, 6 and 8; rules F2-D2.
--
-- * Written to run as ONE script in the Supabase SQL Editor: no psql commands.
-- * Inserts no board and no ideas. (It does create a profile row for every
--   user who already exists in auth.users; see section 10.)
-- * The hosted projects expose new tables automatically. So section 8 first
--   revokes every privilege on every Feedbox object from anon and
--   authenticated (and from public, for functions), and then grants back only
--   what F1 section 3 allows, column by column where it says so.
-- * Every security definer function sets search_path to '' and names every
--   schema in full.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Extension, schema and type
-- -----------------------------------------------------------------------------

-- Trigram matching for similar ideas (F1 section 5). In the extensions schema.
create extension if not exists pg_trgm with schema extensions;

-- Internal helpers that must never be callable through the API. The schema
-- "private" is not in the API's exposed schemas.
create schema if not exists private;

create type public.idea_status as enum ('open', 'planned', 'building', 'shipped');


-- -----------------------------------------------------------------------------
-- 2. Tables
-- -----------------------------------------------------------------------------

-- One row per product board. Created by SQL only, never from the app (F1 sec 1).
create table public.boards (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique check (slug ~ '^[a-z0-9-]{2,40}$'),
  name       text not null check (char_length(name) between 1 and 80),
  tagline    text not null default '' check (char_length(tagline) <= 200),
  intro      text not null default '' check (char_length(intro) <= 500),
  created_at timestamptz not null default now()
);

-- The public face of a signed-in person. Never holds an email address.
-- Created by a trigger when someone signs up (section 5).
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  -- Display name (F1 sec 4, F2-D2): 2 to 40 characters, one line, single
  -- spaces, no spaces at either end, and no "@".
  constraint profiles_display_name_check check (
    display_name is null or (
      char_length(display_name) between 2 and 40
      and display_name = btrim(regexp_replace(display_name, '\s+', ' ', 'g'))
      and position('@' in display_name) = 0
    )
  )
);

-- Who may run the owner tools on a board. Rows are added by SQL only.
create table public.board_owners (
  board_id   uuid not null references public.boards (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (board_id, user_id)
);

create table public.ideas (
  id                bigint generated always as identity primary key,
  board_id          uuid not null references public.boards (id) on delete cascade,
  author_id         uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title             text not null,
  body              text not null default '',
  status            public.idea_status not null default 'open',
  vote_count        integer not null default 0 check (vote_count >= 0),
  comment_count     integer not null default 0 check (comment_count >= 0),
  merged_into_id    bigint references public.ideas (id),
  hidden_at         timestamptz,
  hidden_by         uuid references public.profiles (id) on delete set null,
  status_changed_at timestamptz not null default now(),
  shipped_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- Title: 4 to 120 characters, one line, single spaces, trimmed (F1 sec 2).
  constraint ideas_title_check check (
    char_length(title) between 4 and 120
    and title = btrim(regexp_replace(title, '\s+', ' ', 'g'))
  ),
  constraint ideas_body_check check (char_length(body) <= 4000),
  constraint ideas_not_merged_into_itself check (merged_into_id is null or merged_into_id <> id),
  -- shipped_at is set exactly while the idea is Shipped.
  constraint ideas_shipped_at_check check ((status = 'shipped') = (shipped_at is not null))
);

-- One row per person per idea. The primary key is what makes it one vote.
create table public.votes (
  idea_id    bigint not null references public.ideas (id) on delete cascade,
  user_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (idea_id, user_id)
);

-- Plain, flat comments (F1 sec 7).
create table public.comments (
  id                 bigint generated always as identity primary key,
  idea_id            bigint not null references public.ideas (id) on delete cascade,
  author_id          uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body               text not null,
  moved_from_idea_id bigint references public.ideas (id) on delete set null,
  hidden_at          timestamptz,
  hidden_by          uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now(),
  constraint comments_body_check check (
    char_length(body) <= 2000 and char_length(btrim(body)) >= 1
  )
);

-- One release in the changelog, for example "Lumen 2.4" (F1 sec 8).
create table public.changelog_entries (
  id           uuid primary key default gen_random_uuid(),
  board_id     uuid not null references public.boards (id) on delete cascade,
  title        text not null,
  released_on  date not null,
  published_at timestamptz,
  created_by   uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  -- F2-D2: entry title 1 to 80 characters, one line, trimmed.
  constraint changelog_entries_title_check check (
    char_length(title) between 1 and 80
    and title = btrim(regexp_replace(title, '\s+', ' ', 'g'))
  )
);

-- One line per shipped idea inside an entry. An idea is in at most one entry.
create table public.changelog_items (
  entry_id   uuid not null references public.changelog_entries (id) on delete cascade,
  idea_id    bigint not null unique references public.ideas (id) on delete cascade,
  note       text not null,
  position   integer not null default 0 check (position >= 0),
  primary key (entry_id, idea_id),
  -- F2-D2: each line 1 to 280 characters, one line, trimmed.
  constraint changelog_items_note_check check (
    char_length(note) between 1 and 280
    and note = btrim(regexp_replace(note, '\s+', ' ', 'g'))
  )
);


-- -----------------------------------------------------------------------------
-- 3. Indexes
-- -----------------------------------------------------------------------------

create index ideas_board_status_votes_idx on public.ideas (board_id, status, vote_count desc, created_at desc);
create index ideas_board_created_idx      on public.ideas (board_id, created_at desc);
create index ideas_author_created_idx     on public.ideas (author_id, created_at);
create index ideas_merged_into_idx        on public.ideas (merged_into_id) where merged_into_id is not null;
create index votes_user_created_idx       on public.votes (user_id, created_at);
create index comments_idea_created_idx    on public.comments (idea_id, created_at);
create index comments_author_created_idx  on public.comments (author_id, created_at);
create index board_owners_user_idx        on public.board_owners (user_id);
create index changelog_entries_board_idx  on public.changelog_entries (board_id, released_on desc);


-- -----------------------------------------------------------------------------
-- 4. Helper functions used by the access rules
-- -----------------------------------------------------------------------------

-- True when the signed-in person owns the board. Security definer, so that the
-- board_owners policy can call it without looping into itself.
create function public.is_board_owner(p_board_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.board_owners o
    where o.board_id = p_board_id
      and o.user_id = (select auth.uid())
  );
$$;

-- True when the signed-in person has set a display name (F1 sec 4: nobody
-- votes, posts or comments before that). Security invoker: profiles are
-- readable by everyone anyway.
create function public.has_display_name()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.display_name is not null
  );
$$;

-- How many ideas, comments or votes a person created in the last hour.
-- Security definer, so hidden rows count too. Lives in "private": not
-- callable through the API.
create function private.recent_count(p_kind text, p_user_id uuid)
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
  end if;
  raise exception 'Unknown kind: %', p_kind;
end;
$$;


-- -----------------------------------------------------------------------------
-- 5. Triggers
-- -----------------------------------------------------------------------------

-- 5a. A profile for every new user (no display name yet).
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- 5b. Rate limits per person per hour (F1 sec 6): 5 ideas, 30 comments,
-- 100 votes. Security INVOKER on purpose: current_user is then the role of
-- the request. Only requests from the app (anon, authenticated) are limited.
-- Rows written inside owner functions and triggers run as the function owner
-- and are not limited (for example votes moved by a merge).
create function private.enforce_rate_limit()
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

create trigger ideas_rate_limit
  before insert on public.ideas
  for each row execute function private.enforce_rate_limit('idea');
create trigger comments_rate_limit
  before insert on public.comments
  for each row execute function private.enforce_rate_limit('comment');
create trigger votes_rate_limit
  before insert on public.votes
  for each row execute function private.enforce_rate_limit('vote');

-- 5c. Ideas: shipped_at on insert (only SQL can insert a Shipped idea, for
-- example the seed); status_changed_at, shipped_at and updated_at on update;
-- an idea in a changelog entry stays Shipped (F2-D2).
create function private.ideas_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.status_changed_at := now();
  if new.status = 'shipped' then
    new.shipped_at := coalesce(new.shipped_at, now());
  else
    new.shipped_at := null;
  end if;
  return new;
end;
$$;

create trigger ideas_before_insert
  before insert on public.ideas
  for each row execute function private.ideas_before_insert();

create function private.ideas_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if old.status = 'shipped'
       and exists (select 1 from public.changelog_items ci where ci.idea_id = old.id) then
      raise exception 'This idea is in a changelog entry, so it stays Shipped. Remove it from the entry first.'
        using errcode = 'check_violation';
    end if;
    new.status_changed_at := now();
    if new.status = 'shipped' then
      new.shipped_at := now();
    else
      new.shipped_at := null;
    end if;
  end if;

  -- updated_at follows real changes, not vote or comment counts.
  if (new.title, new.body, new.status, new.merged_into_id, new.hidden_at)
     is distinct from (old.title, old.body, old.status, old.merged_into_id, old.hidden_at) then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

create trigger ideas_before_update
  before update on public.ideas
  for each row execute function private.ideas_before_update();

-- 5d. Posting an idea also casts the author's vote (F1 sec 2 default).
create function private.ideas_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.votes (idea_id, user_id)
  values (new.id, new.author_id)
  on conflict (idea_id, user_id) do nothing;
  return null;
end;
$$;

create trigger ideas_after_insert
  after insert on public.ideas
  for each row execute function private.ideas_after_insert();

-- 5e. vote_count follows the votes table. Nobody writes it directly.
create function private.votes_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.ideas set vote_count = vote_count + 1 where id = new.idea_id;
  elsif tg_op = 'DELETE' then
    update public.ideas set vote_count = greatest(vote_count - 1, 0) where id = old.idea_id;
  end if;
  return null;
end;
$$;

create trigger votes_after_change
  after insert or delete on public.votes
  for each row execute function private.votes_after_change();

-- 5f. comment_count counts the comments that are not hidden. It follows
-- inserts, deletes, hiding and unhiding, and comments moved by a merge.
create function private.comments_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.hidden_at is null then
    update public.ideas set comment_count = greatest(comment_count - 1, 0) where id = old.idea_id;
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.hidden_at is null then
    update public.ideas set comment_count = comment_count + 1 where id = new.idea_id;
  end if;
  return null;
end;
$$;

create trigger comments_after_change
  after insert or delete or update of idea_id, hidden_at on public.comments
  for each row execute function private.comments_after_change();

-- 5g. A changelog line must name a Shipped idea from the entry's own board.
-- This trigger runs BEFORE the row-level security check, so its messages
-- never name the idea (a non-owner must not learn a hidden idea's title).
create function private.changelog_items_check()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_board uuid;
  v_idea        public.ideas;
begin
  select e.board_id into v_entry_board from public.changelog_entries e where e.id = new.entry_id;
  select * into v_idea from public.ideas i where i.id = new.idea_id;

  if v_idea.id is null or v_idea.board_id is distinct from v_entry_board then
    raise exception 'Every idea in a changelog entry must be on the same board.'
      using errcode = 'check_violation';
  end if;
  if v_idea.status <> 'shipped' then
    raise exception 'Only Shipped ideas can be in the changelog.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger changelog_items_check
  before insert or update of entry_id, idea_id on public.changelog_items
  for each row execute function private.changelog_items_check();


-- -----------------------------------------------------------------------------
-- 6. Owner functions (F1 sec 3, 5, 8). Each checks is_board_owner first and
-- does its whole job in one transaction. They are the only way to change an
-- idea's status, merge, hide or unhide, and publish the changelog.
-- Errors: 42501 = not an owner, P0002 = not found, 23514 = a rule refuses it.
-- -----------------------------------------------------------------------------

create function public.set_idea_status(p_idea_id bigint, p_status public.idea_status)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_idea public.ideas;
begin
  select * into v_idea from public.ideas where id = p_idea_id for update;
  if v_idea.id is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_idea.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_idea.merged_into_id is not null then
    raise exception 'This idea has been merged.' using errcode = 'check_violation';
  end if;
  if v_idea.status = p_status then
    raise exception 'The idea is already %.', initcap(p_status::text) using errcode = 'check_violation';
  end if;
  -- The trigger ideas_before_update keeps an idea in a changelog entry Shipped
  -- and sets status_changed_at and shipped_at.
  update public.ideas set status = p_status where id = p_idea_id;
end;
$$;

-- Merges the source idea into the target (F1 sec 5). Returns the target's new
-- vote count. No undo in version 1.
create function public.merge_ideas(p_source_id bigint, p_target_id bigint)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source public.ideas;
  v_target public.ideas;
  v_count  integer;
begin
  if p_source_id = p_target_id then
    raise exception 'An idea cannot be merged into itself.' using errcode = 'check_violation';
  end if;

  -- Lock both rows, always in id order, so two merges cannot deadlock.
  perform 1 from public.ideas
    where id in (p_source_id, p_target_id) order by id for update;
  select * into v_source from public.ideas where id = p_source_id;
  select * into v_target from public.ideas where id = p_target_id;

  if v_source.id is null or v_target.id is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_source.board_id) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if v_source.board_id <> v_target.board_id then
    raise exception 'Both ideas must be on the same board.' using errcode = 'check_violation';
  end if;
  if v_source.merged_into_id is not null then
    raise exception 'This idea has already been merged.' using errcode = 'check_violation';
  end if;
  if v_target.merged_into_id is not null then
    raise exception 'The target idea has itself been merged.' using errcode = 'check_violation';
  end if;
  if v_target.hidden_at is not null then
    raise exception 'The target idea is hidden. Unhide it first, or pick another idea.' using errcode = 'check_violation';
  end if;
  if exists (select 1 from public.changelog_items ci where ci.idea_id = p_source_id) then
    raise exception 'This idea is in a changelog entry. Remove it from the entry first.' using errcode = 'check_violation';
  end if;

  -- Votes: everyone who voted on the source gets a vote on the target unless
  -- they already have one; then the source's votes go. Triggers keep both
  -- counts right, so nobody is counted twice.
  insert into public.votes (idea_id, user_id, created_at)
    select p_target_id, v.user_id, v.created_at
    from public.votes v
    where v.idea_id = p_source_id
    on conflict (idea_id, user_id) do nothing;
  delete from public.votes where idea_id = p_source_id;

  -- Comments move to the target and remember where they came from.
  update public.comments
    set idea_id = p_target_id,
        moved_from_idea_id = coalesce(moved_from_idea_id, p_source_id)
    where idea_id = p_source_id;

  -- Ideas merged earlier into the source now point straight at the target.
  update public.ideas set merged_into_id = p_target_id where merged_into_id = p_source_id;
  update public.ideas set merged_into_id = p_target_id where id = p_source_id;

  select vote_count into v_count from public.ideas where id = p_target_id;
  return v_count;
end;
$$;

create function public.hide_idea(p_idea_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board uuid;
begin
  select board_id into v_board from public.ideas where id = p_idea_id;
  if v_board is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_board) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  update public.ideas
    set hidden_at = coalesce(hidden_at, now()),
        hidden_by = coalesce(hidden_by, (select auth.uid()))
    where id = p_idea_id;
end;
$$;

create function public.unhide_idea(p_idea_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board uuid;
begin
  select board_id into v_board from public.ideas where id = p_idea_id;
  if v_board is null then
    raise exception 'Idea not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_board) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  update public.ideas set hidden_at = null, hidden_by = null where id = p_idea_id;
end;
$$;

create function public.hide_comment(p_comment_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board uuid;
begin
  select i.board_id into v_board
    from public.comments c join public.ideas i on i.id = c.idea_id
    where c.id = p_comment_id;
  if v_board is null then
    raise exception 'Comment not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_board) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  update public.comments
    set hidden_at = coalesce(hidden_at, now()),
        hidden_by = coalesce(hidden_by, (select auth.uid()))
    where id = p_comment_id;
end;
$$;

create function public.unhide_comment(p_comment_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board uuid;
begin
  select i.board_id into v_board
    from public.comments c join public.ideas i on i.id = c.idea_id
    where c.id = p_comment_id;
  if v_board is null then
    raise exception 'Comment not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_board) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  update public.comments set hidden_at = null, hidden_by = null where id = p_comment_id;
end;
$$;

-- Publishes (p_publish = true) or unpublishes (false) a changelog entry.
-- An entry needs at least one line before it can be published.
create function public.publish_changelog_entry(p_entry_id uuid, p_publish boolean default true)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_board uuid;
begin
  select board_id into v_board from public.changelog_entries where id = p_entry_id for update;
  if v_board is null then
    raise exception 'Changelog entry not found.' using errcode = 'P0002';
  end if;
  if not public.is_board_owner(v_board) then
    raise exception 'Only an owner of this board can do this.' using errcode = '42501';
  end if;
  if p_publish and not exists (select 1 from public.changelog_items ci where ci.entry_id = p_entry_id) then
    raise exception 'Pick at least one shipped idea.' using errcode = 'check_violation';
  end if;
  update public.changelog_entries
    set published_at = case when p_publish then coalesce(published_at, now()) else null end
    where id = p_entry_id;
end;
$$;


-- -----------------------------------------------------------------------------
-- 7. Similar ideas while typing a title, and the board's search box
-- (F1 sec 5). Trigram word similarity on the title (and optionally the
-- details), threshold 0.3, best first, then most votes. Security invoker:
-- the caller's own access rules apply. Queries shorter than 3 characters
-- return nothing.
-- -----------------------------------------------------------------------------

create function public.similar_ideas(
  p_board_id     uuid,
  p_query        text,
  p_limit        integer default 5,
  p_include_body boolean default false
)
returns table (id bigint, title text, status public.idea_status, vote_count integer, score real)
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (
    select lower(btrim(regexp_replace(coalesce(p_query, ''), '\s+', ' ', 'g'))) as text
  )
  select i.id, i.title, i.status, i.vote_count, s.score
  from q
  join public.ideas i on i.board_id = p_board_id
  cross join lateral (
    select greatest(
      extensions.word_similarity(q.text, i.title),
      case when p_include_body then extensions.word_similarity(q.text, i.body) else 0 end
    ) as score
  ) s
  where char_length(q.text) >= 3
    and i.merged_into_id is null
    and i.hidden_at is null
    and s.score >= 0.3
  order by s.score desc, i.vote_count desc, i.id desc
  limit least(greatest(coalesce(p_limit, 5), 1), 20);
$$;


-- -----------------------------------------------------------------------------
-- 8. Privileges. First take everything away from anon and authenticated (and
-- from public for functions), then grant back only what F1 section 3 allows.
-- service_role keeps the platform defaults (it is never used by the app).
-- -----------------------------------------------------------------------------

revoke all on table
  public.boards, public.profiles, public.board_owners, public.ideas, public.votes,
  public.comments, public.changelog_entries, public.changelog_items
  from anon, authenticated;

revoke all on sequence public.ideas_id_seq, public.comments_id_seq from anon, authenticated;

revoke all on function
  public.is_board_owner(uuid),
  public.has_display_name(),
  public.set_idea_status(bigint, public.idea_status),
  public.merge_ideas(bigint, bigint),
  public.hide_idea(bigint),
  public.unhide_idea(bigint),
  public.hide_comment(bigint),
  public.unhide_comment(bigint),
  public.publish_changelog_entry(uuid, boolean),
  public.similar_ideas(uuid, text, integer, boolean),
  private.recent_count(text, uuid),
  private.handle_new_user(),
  private.enforce_rate_limit(),
  private.ideas_before_insert(),
  private.ideas_before_update(),
  private.ideas_after_insert(),
  private.votes_after_change(),
  private.comments_after_change(),
  private.changelog_items_check()
  from public, anon, authenticated;

revoke all on schema private from public, anon, authenticated;

-- Tables: read
grant select on public.boards            to anon, authenticated;
grant select on public.profiles          to anon, authenticated;
grant select on public.ideas             to anon, authenticated;
grant select on public.comments          to anon, authenticated;
grant select on public.changelog_entries to anon, authenticated;
grant select on public.changelog_items   to anon, authenticated;
grant select on public.board_owners      to authenticated;
grant select on public.votes             to authenticated;

-- Tables: write, column by column. Everything else (author_id, status,
-- vote_count, comment_count, merged_into_id, hidden_at, published_at, ...)
-- is set by defaults, triggers and owner functions only.
grant update (display_name)                          on public.profiles          to authenticated;
grant insert (board_id, title, body)                 on public.ideas             to authenticated;
grant insert (idea_id)                               on public.votes             to authenticated;
grant delete                                         on public.votes             to authenticated;
grant insert (idea_id, body)                         on public.comments          to authenticated;
grant insert (board_id, title, released_on)          on public.changelog_entries to authenticated;
grant update (title, released_on)                    on public.changelog_entries to authenticated;
grant delete                                         on public.changelog_entries to authenticated;
grant insert (entry_id, idea_id, note, position)     on public.changelog_items   to authenticated;
grant update (note, position)                        on public.changelog_items   to authenticated;
grant delete                                         on public.changelog_items   to authenticated;

-- Functions
grant execute on function public.is_board_owner(uuid)                          to anon, authenticated;
grant execute on function public.has_display_name()                            to anon, authenticated;
grant execute on function public.similar_ideas(uuid, text, integer, boolean)   to anon, authenticated;
grant execute on function public.set_idea_status(bigint, public.idea_status)   to authenticated;
grant execute on function public.merge_ideas(bigint, bigint)                   to authenticated;
grant execute on function public.hide_idea(bigint)                             to authenticated;
grant execute on function public.unhide_idea(bigint)                           to authenticated;
grant execute on function public.hide_comment(bigint)                          to authenticated;
grant execute on function public.unhide_comment(bigint)                        to authenticated;
grant execute on function public.publish_changelog_entry(uuid, boolean)        to authenticated;

-- The rate-limit trigger runs as the caller and counts through this helper.
-- "private" is not exposed by the API, so this does not make it callable.
grant usage on schema private to authenticated;
grant execute on function private.recent_count(text, uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- 9. Row-level security on EVERY table, and the policies (F1 sec 3).
-- -----------------------------------------------------------------------------

alter table public.boards            enable row level security;
alter table public.profiles          enable row level security;
alter table public.board_owners      enable row level security;
alter table public.ideas             enable row level security;
alter table public.votes             enable row level security;
alter table public.comments          enable row level security;
alter table public.changelog_entries enable row level security;
alter table public.changelog_items   enable row level security;

-- boards: anyone reads. No one writes through the API.
create policy boards_read on public.boards
  for select to anon, authenticated
  using (true);

-- profiles: anyone reads (id, display_name, created_at; there is no email
-- here). A person changes only their own display name.
create policy profiles_read on public.profiles
  for select to anon, authenticated
  using (true);
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- board_owners: a person sees their own rows; owners see their board's owners.
-- No insert, update or delete for anyone through the API.
create policy board_owners_read on public.board_owners
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_board_owner(board_id));

-- ideas: anyone reads ideas that are not hidden; owners also read hidden ones.
-- A signed-in person with a display name posts as themselves.
create policy ideas_read on public.ideas
  for select to anon, authenticated
  using (hidden_at is null or public.is_board_owner(board_id));
create policy ideas_insert_own on public.ideas
  for insert to authenticated
  with check (author_id = (select auth.uid()) and public.has_display_name());

-- votes: a person sees only their own votes (counts are on ideas), votes as
-- themselves on an idea that is visible and not merged, and removes only
-- their own vote.
create policy votes_read_own on public.votes
  for select to authenticated
  using (user_id = (select auth.uid()));
create policy votes_insert_own on public.votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and public.has_display_name()
    and exists (
      select 1 from public.ideas i
      where i.id = idea_id and i.hidden_at is null and i.merged_into_id is null
    )
  );
create policy votes_delete_own on public.votes
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- comments: anyone reads comments that are not hidden, on ideas they can see;
-- owners also read hidden ones. A signed-in person with a display name
-- comments as themselves on a visible idea that is not merged.
create policy comments_read on public.comments
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.ideas i
      where i.id = comments.idea_id
        and (comments.hidden_at is null or public.is_board_owner(i.board_id))
    )
  );
create policy comments_insert_own on public.comments
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and public.has_display_name()
    and exists (
      select 1 from public.ideas i
      where i.id = idea_id and i.hidden_at is null and i.merged_into_id is null
    )
  );

-- changelog_entries: anyone reads published entries; owners also read drafts
-- and write their board's entries. Publishing is publish_changelog_entry only.
create policy changelog_entries_read on public.changelog_entries
  for select to anon, authenticated
  using (published_at is not null or public.is_board_owner(board_id));
create policy changelog_entries_insert_owner on public.changelog_entries
  for insert to authenticated
  with check (public.is_board_owner(board_id));
create policy changelog_entries_update_owner on public.changelog_entries
  for update to authenticated
  using (public.is_board_owner(board_id))
  with check (public.is_board_owner(board_id));
create policy changelog_entries_delete_owner on public.changelog_entries
  for delete to authenticated
  using (public.is_board_owner(board_id));

-- changelog_items: readable when their entry is; written by the entry's
-- board owners.
create policy changelog_items_read on public.changelog_items
  for select to anon, authenticated
  using (exists (select 1 from public.changelog_entries e where e.id = entry_id));
create policy changelog_items_insert_owner on public.changelog_items
  for insert to authenticated
  with check (exists (
    select 1 from public.changelog_entries e
    where e.id = entry_id and public.is_board_owner(e.board_id)
  ));
create policy changelog_items_update_owner on public.changelog_items
  for update to authenticated
  using (exists (
    select 1 from public.changelog_entries e
    where e.id = entry_id and public.is_board_owner(e.board_id)
  ))
  with check (exists (
    select 1 from public.changelog_entries e
    where e.id = entry_id and public.is_board_owner(e.board_id)
  ));
create policy changelog_items_delete_owner on public.changelog_items
  for delete to authenticated
  using (exists (
    select 1 from public.changelog_entries e
    where e.id = entry_id and public.is_board_owner(e.board_id)
  ));


-- -----------------------------------------------------------------------------
-- 10. Profiles for people who signed up before this migration ran.
-- -----------------------------------------------------------------------------

insert into public.profiles (id)
  select u.id from auth.users u
  on conflict (id) do nothing;
