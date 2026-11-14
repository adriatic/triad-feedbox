-- supabase/seed.sql | 213 lines | last line: -- end of seed.sql
-- =============================================================================
-- Feedbox seed: the invented "Lumen" board from the design brief.
-- For LOCAL Supabase and feedbox-preview ONLY. Never run it on feedbox-prod.
--
-- * The whole seed is ONE statement: a single do-block. Nothing has to survive
--   from one statement to the next (no temporary table, no session setting),
--   so it runs the same way in the Supabase SQL Editor and in
--   `supabase db reset`. No psql commands. Run it after the migration
--   20261113000000_feedbox_v1.sql.
-- * A do-block is all or nothing: if any step or the final check fails,
--   nothing from the seed is saved.
-- * Creates invented people at @lumen.example (a reserved, undeliverable
--   domain). They cannot sign in. "Ana" is the owner of the Lumen board.
-- * Vote counts match the design exactly: every vote is a real row, so the
--   counts stay right when someone votes or unvotes. (Posting an idea casts the
--   author's vote; the other votes come from 213 invented voters.)
-- * It refuses to run twice: if a board "lumen" exists, it stops and changes
--   nothing. If the script was pasted twice into one query, the message says
--   so.
-- =============================================================================

do $seed$
declare
  v_board    uuid;
  v_wrong    text;
  v_same_txn boolean;
  v_at       timestamptz;
  -- Ideas (design brief and screens): title, body, status, votes, author,
  -- created_at, shipped_at. Read below with jsonb_to_recordset.
  v_ideas constant jsonb := $ideas$[
    {"title": "Dark mode for the editor",
     "body": "A true dark theme for the editor and sidebar that follows the system setting. Late at night the white editor is hard on the eyes, and the current grey theme still leaves the sidebar bright.\n\nIt should also remember my choice per device, so my laptop can stay dark while the tablet stays light.",
     "status": "planned", "votes": 214, "author": "mira", "created_at": "2026-10-03 09:12+00", "shipped_at": null},
    {"title": "Export notes to Markdown",
     "body": "Export one note or a whole notebook as plain .md files, with images alongside.",
     "status": "building", "votes": 187, "author": "tom", "created_at": "2026-09-20 14:30+00", "shipped_at": null},
    {"title": "Offline mode",
     "body": "Keep writing without a connection and merge changes when it returns.",
     "status": "planned", "votes": 132, "author": "lea", "created_at": "2026-09-01 08:05+00", "shipped_at": null},
    {"title": "Pin notes to the top of a notebook",
     "body": "Keep the notes I use every day above the rest.",
     "status": "shipped", "votes": 121, "author": "omar", "created_at": "2026-07-14 10:00+00", "shipped_at": "2026-09-18 12:00+00"},
    {"title": "Keyboard shortcut cheat sheet",
     "body": "A one-page list of every shortcut, opened with a single key.",
     "status": "shipped", "votes": 96, "author": "jun", "created_at": "2026-08-01 16:40+00", "shipped_at": "2026-11-03 12:00+00"},
    {"title": "Faster startup on large notebooks",
     "body": "Opening a notebook with thousands of notes takes several seconds.",
     "status": "shipped", "votes": 88, "author": "ines", "created_at": "2026-07-01 11:00+00", "shipped_at": "2026-11-02 12:00+00"},
    {"title": "Sync between two laptops",
     "body": "Keep the same notebooks on my work and home laptops without exporting by hand.",
     "status": "open", "votes": 73, "author": "sam", "created_at": "2026-10-20 19:25+00", "shipped_at": null},
    {"title": "Search inside attachments",
     "body": "Find words inside attached PDFs, not only in the note text.",
     "status": "open", "votes": 58, "author": "lea", "created_at": "2026-10-25 07:50+00", "shipped_at": null},
    {"title": "Share a note by link",
     "body": "Send someone a read-only link to one note.",
     "status": "open", "votes": 49, "author": "omar", "created_at": "2026-11-01 13:15+00", "shipped_at": null},
    {"title": "Tag notes by colour",
     "body": "Give a note a coloured tag and filter the sidebar by colour.",
     "status": "open", "votes": 41, "author": "jun", "created_at": "2026-11-05 18:00+00", "shipped_at": null}
  ]$ideas$::jsonb;
begin
  -- ---------------------------------------------------------------------------
  -- Refuse to run twice (also when pasted twice into one query).
  -- ---------------------------------------------------------------------------
  select b.xmin::text = (pg_current_xact_id()::xid)::text, b.created_at
    into v_same_txn, v_at
  from public.boards b where b.slug = 'lumen';
  if v_same_txn then
    raise exception 'Refused: this script was pasted twice into one query. Nothing was changed: the whole query is undone. Clear the editor, paste the script once and run it again.';
  end if;
  if v_at is not null then
    raise exception 'Refused: the Lumen board already exists (created %). The seed has run before, or this script was pasted twice into one query. Nothing was changed by this copy.', v_at;
  end if;

  -- ---------------------------------------------------------------------------
  -- People. The trigger on auth.users creates their profiles.
  -- ---------------------------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, reauthentication_token, phone_change, phone_change_token
  )
  select
    '00000000-0000-0000-0000-000000000000'::uuid,
    md5('lumen-person-' || p.handle)::uuid,
    'authenticated', 'authenticated',
    p.handle || '@lumen.example',
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    '{}'::jsonb,
    now(), now(),
    '', '', '', '', '', '', '', ''
  from (
    values ('ana'), ('mira'), ('tom'), ('sam'), ('lea'), ('omar'), ('jun'), ('ines')
    union all
    select 'voter-' || lpad(n::text, 3, '0') from generate_series(1, 213) as n
  ) as p (handle);

  update public.profiles pr
  set display_name = v.name
  from (values
    ('ana',  'Ana'),
    ('mira', 'Mira K.'),
    ('tom',  'Tom R.'),
    ('sam',  'Sam P.'),
    ('lea',  'Lea V.'),
    ('omar', 'Omar S.'),
    ('jun',  'Jun H.'),
    ('ines', 'Ines D.')
  ) as v (handle, name)
  where pr.id = md5('lumen-person-' || v.handle)::uuid;

  update public.profiles
  set display_name = 'Lumen user ' || ltrim(substr(u.email, 7, 3), '0')
  from auth.users u
  where u.id = public.profiles.id and u.email like 'voter-%@lumen.example';

  -- ---------------------------------------------------------------------------
  -- The board and its owner.
  -- ---------------------------------------------------------------------------
  insert into public.boards (slug, name, tagline, intro)
  values (
    'lumen',
    'Lumen',
    'What should Lumen do next?',
    'Vote for what you need, or post a new idea. The Lumen team moves ideas to Planned, Building and Shipped.'
  )
  returning id into v_board;

  insert into public.board_owners (board_id, user_id)
  values (v_board, md5('lumen-person-ana')::uuid);

  -- ---------------------------------------------------------------------------
  -- Ideas. The author's vote is added by a trigger.
  -- ---------------------------------------------------------------------------
  insert into public.ideas (board_id, author_id, title, body, status, created_at, shipped_at)
  select v_board, md5('lumen-person-' || li.author)::uuid, li.title, li.body, li.status, li.created_at, li.shipped_at
  from jsonb_to_recordset(v_ideas) as li (
    title text, body text, status public.idea_status, votes integer,
    author text, created_at timestamptz, shipped_at timestamptz)
  order by li.created_at;

  -- The seed's own times for status and shipping (the insert trigger stamps now()).
  update public.ideas i
  set status_changed_at = coalesce(li.shipped_at, li.created_at),
      shipped_at        = li.shipped_at,
      updated_at        = li.created_at
  from jsonb_to_recordset(v_ideas) as li (
    title text, created_at timestamptz, shipped_at timestamptz)
  where i.title = li.title and i.board_id = v_board;

  -- The remaining votes: idea with N votes gets the author's vote plus voters 1 to N-1.
  insert into public.votes (idea_id, user_id, created_at)
  select i.id, md5('lumen-person-voter-' || lpad(n::text, 3, '0'))::uuid, i.created_at + n * interval '17 minutes'
  from jsonb_to_recordset(v_ideas) as li (title text, votes integer)
  join public.ideas i on i.title = li.title and i.board_id = v_board
  cross join lateral generate_series(1, li.votes - 1) as n;

  -- ---------------------------------------------------------------------------
  -- Comments (from the Idea detail screen, plus a few more).
  -- ---------------------------------------------------------------------------
  insert into public.comments (idea_id, author_id, body, created_at)
  select i.id, md5('lumen-person-' || c.author)::uuid, c.body, c.created_at
  from (values
    ('Dark mode for the editor', 'tom',  'Yes please. I would also like the code blocks to keep their own colours.', '2026-10-05 08:00+00'::timestamptz),
    ('Dark mode for the editor', 'sam',  'Following the system setting would be perfect for me.', '2026-10-06 21:10+00'),
    ('Dark mode for the editor', 'ana',  'Planned for the December release. We will follow the system setting first and add a manual switch after that.', '2026-10-09 10:00+00'),
    ('Export notes to Markdown', 'mira', 'Please keep the folder structure when exporting a whole notebook.', '2026-09-22 09:30+00'),
    ('Export notes to Markdown', 'ana',  'We are building this now. Images will be saved next to each .md file.', '2026-10-28 15:00+00'),
    ('Offline mode',             'ines', 'This matters most on trains for me.', '2026-09-03 07:20+00'),
    ('Sync between two laptops', 'jun',  'Even a manual "sync now" button would help.', '2026-10-21 12:00+00'),
    ('Sync between two laptops', 'lea',  'Offline mode might cover part of this.', '2026-10-22 08:45+00'),
    ('Tag notes by colour',      'mira', 'Colour plus a name for each tag would be ideal.', '2026-11-06 10:00+00')
  ) as c (title, author, body, created_at)
  join public.ideas i on i.title = c.title and i.board_id = v_board;

  -- ---------------------------------------------------------------------------
  -- Changelog (design screen 5): two published releases.
  -- ---------------------------------------------------------------------------
  insert into public.changelog_entries (id, board_id, title, released_on, published_at, created_by)
  select md5('lumen-changelog-' || e.title)::uuid, v_board, e.title, e.released_on, e.published_at, md5('lumen-person-ana')::uuid
  from (values
    ('Lumen 2.3', date '2026-09-18', timestamptz '2026-09-18 12:30+00'),
    ('Lumen 2.4', date '2026-11-03', timestamptz '2026-11-03 12:30+00')
  ) as e (title, released_on, published_at);

  insert into public.changelog_items (entry_id, idea_id, note, position)
  select md5('lumen-changelog-' || x.entry)::uuid, i.id, x.note, x.position
  from (values
    ('Lumen 2.4', 'Keyboard shortcut cheat sheet',      'Press ? anywhere to see every shortcut on one page, grouped by task.', 1),
    ('Lumen 2.4', 'Faster startup on large notebooks',  'A notebook with 5,000 notes now opens in 1.6 seconds, down from 7.', 2),
    ('Lumen 2.3', 'Pin notes to the top of a notebook', 'Pinned notes stay above the rest, in the order you drag them.', 1)
  ) as x (entry, title, note, position)
  join public.ideas i on i.title = x.title and i.board_id = v_board;

  -- ---------------------------------------------------------------------------
  -- Check: the ten ideas exist and their vote counts match the design brief.
  -- If not, the exception undoes the whole seed.
  -- ---------------------------------------------------------------------------
  select string_agg(li.title || ' has ' || coalesce(i.vote_count::text, 'no idea row') || ', expected ' || li.votes, '; ')
    into v_wrong
  from jsonb_to_recordset(v_ideas) as li (title text, votes integer)
  left join public.ideas i on i.title = li.title and i.board_id = v_board
  where i.vote_count is distinct from li.votes;
  if v_wrong is not null then
    raise exception 'Seed check failed: %', v_wrong;
  end if;
end;
$seed$;
-- end of seed.sql
