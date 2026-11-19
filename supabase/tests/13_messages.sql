-- Messages to a board's owners (task CT1): who may send, who may read, the
-- sender's email for owners only, marking read and unread, the length rules,
-- the rate limit of 5 an hour, and removal of a person.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');   -- owner of b1
select tests.person('bo', 'Bo');     -- owner of b2
select tests.person('sam', 'Sam');   -- member
select tests.person('kim', 'Kim');   -- member
select tests.person('noname');       -- signed in, no display name yet
insert into public.board_owners (board_id, user_id) values
  (tests.board_id('b1'), tests.id('ana')),
  (tests.board_id('b2'), tests.id('bo'));

-- A message's id by its text, readable whatever role the test acts as.
create function tests.message_id(p_body text) returns bigint language sql stable security definer as $$
  select max(m.id) from public.messages m where m.body = p_body;
$$;
create function tests.message_read(p_body text) returns boolean language sql stable security definer as $$
  select m.read_at is not null from public.messages m where m.body = p_body;
$$;
create function tests.message_count(p_author text) returns bigint language sql stable security definer as $$
  select count(*) from public.messages m where m.author_id = tests.id(p_author);
$$;
grant execute on function tests.message_id(text), tests.message_read(text), tests.message_count(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. Who may send
-- ---------------------------------------------------------------------------
select tests.as_visitor();
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), 'From a visitor') $$,
  '42501', null, 'a visitor cannot send a message');
reset role;

select tests.as_person('noname');
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), 'No name yet') $$,
  '42501', 'new row violates row-level security policy for table "messages"',
  'a person without a display name cannot send a message yet');
reset role;

select tests.as_person('sam');
select lives_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), 'Hello from Sam') $$,
  'a member sends a message to the owners of b1');
select lives_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b2'), 'Sam to b2') $$,
  'a member sends a message to the owners of b2');
select throws_ok($$ insert into public.messages (board_id, author_id, body) values (tests.board_id('b1'), tests.id('kim'), 'Pretending to be Kim') $$,
  '42501', null, 'a member cannot send a message in someone else''s name (author_id is not writable)');
select throws_ok($$ insert into public.messages (board_id, body) values ('00000000-0000-0000-0000-000000000001', 'To no board') $$,
  '42501', 'new row violates row-level security policy for table "messages"',
  'a member cannot send a message to a board that does not exist');
select throws_ok($$ insert into public.messages (board_id, body, read_at) values (tests.board_id('b1'), 'Already read', now()) $$,
  '42501', null, 'a member cannot set read_at');
reset role;

select is((select author_id from public.messages where body = 'Hello from Sam'), tests.id('sam'),
  'the message is stored as written by Sam');
select is((select read_at from public.messages where body = 'Hello from Sam'), null,
  'a new message is unread (read_at is null)');

-- ---------------------------------------------------------------------------
-- 2. The length rules: 1 to 2000 characters, nothing to trim at either end
-- ---------------------------------------------------------------------------
select tests.as_person('kim');
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), '') $$,
  '23514', null, 'an empty message is refused');
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), E'  \n ') $$,
  '23514', null, 'a message of only spaces and line breaks is refused');
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), ' Untrimmed') $$,
  '23514', null, 'a message with a space at the start is refused (the app trims first)');
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), E'Untrimmed\n') $$,
  '23514', null, 'a message with a line break at the end is refused (the app trims first)');
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), repeat('x', 2001)) $$,
  '23514', null, 'a message of 2001 characters is refused');
select lives_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), repeat('é', 2000)) $$,
  'a message of exactly 2000 characters is accepted (characters, not bytes)');
select lives_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), E'Line one\n\nLine two') $$,
  'line breaks inside a message are kept');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Who may read: the board's owners only
-- ---------------------------------------------------------------------------
select tests.as_visitor();
select throws_ok($$ select count(*) from public.messages $$, '42501', null, 'a visitor cannot read messages');
select throws_ok($$ select * from public.board_messages(tests.board_id('b1')) $$, '42501', null,
  'a visitor cannot call board_messages');
reset role;

select tests.as_person('sam');
select is((select count(*) from public.messages), 0::bigint, 'a member reads no messages, not even their own');
select throws_ok($$ select * from public.board_messages(tests.board_id('b1')) $$, '42501',
  'Only an owner of this board can read its messages.', 'a member cannot read the messages with emails');
reset role;

select tests.as_person('ana');
select is((select count(*) from public.messages), 3::bigint, 'the owner of b1 reads b1''s three messages');
select is((select count(*) from public.messages where board_id = tests.board_id('b2')), 0::bigint,
  'the owner of b1 reads none of b2''s messages');
select results_eq(
  $$ select sender_name, sender_email from public.board_messages(tests.board_id('b1')) where body = 'Hello from Sam' $$,
  $$ values ('Sam'::text, 'sam@feedbox.test'::text) $$,
  'board_messages gives the owner the sender''s name and sign-in email');
select results_eq(
  $$ select body from public.board_messages(tests.board_id('b1')) limit 1 $$,
  $$ values (E'Line one\n\nLine two'::text) $$,
  'board_messages lists the newest message first');
select throws_ok($$ select * from public.board_messages(tests.board_id('b2')) $$, '42501',
  'Only an owner of this board can read its messages.', 'the owner of b1 cannot read b2''s messages with emails');
select throws_ok($$ select email from auth.users $$, '42501', null, 'an owner still cannot read auth.users directly');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Mark read and unread: owners only, through set_message_read
-- ---------------------------------------------------------------------------
select tests.as_person('ana');
select lives_ok($$ select public.set_message_read(tests.message_id('Hello from Sam'), true) $$, 'the owner marks a message read');
select ok(tests.message_read('Hello from Sam'), 'the message is read');
create temporary table first_read as select read_at from public.messages where body = 'Hello from Sam';
select lives_ok($$ select public.set_message_read(tests.message_id('Hello from Sam')) $$, 'marking it read again does no harm (read is the default)');
select is((select read_at from public.messages where body = 'Hello from Sam'), (select read_at from first_read),
  'marking it read again keeps the first time it was read');
select lives_ok($$ select public.set_message_read(tests.message_id('Hello from Sam'), false) $$, 'the owner marks it unread');
select ok(not tests.message_read('Hello from Sam'), 'the message is unread again');
select throws_ok($$ select public.set_message_read(tests.message_id('Sam to b2'), true) $$, '42501',
  'Only an owner of this board can do this.', 'the owner of b1 cannot mark b2''s message');
select throws_ok($$ select public.set_message_read(999999999, true) $$, 'P0002', 'Message not found.',
  'a message that does not exist is not found');
select throws_ok($$ update public.messages set read_at = now() where body = 'Hello from Sam' $$, '42501', null,
  'an owner cannot change a message directly');
select throws_ok($$ delete from public.messages where body = 'Hello from Sam' $$, '42501', null,
  'an owner cannot delete a message directly');
reset role;

select tests.as_person('sam');
select throws_ok($$ select public.set_message_read(tests.message_id('Hello from Sam'), true) $$, '42501',
  'Only an owner of this board can do this.', 'a member cannot mark a message read, not even their own');
select throws_ok($$ update public.messages set body = 'Changed' where body = 'Hello from Sam' $$, '42501', null,
  'a member cannot change their message');
select throws_ok($$ delete from public.messages where body = 'Hello from Sam' $$, '42501', null,
  'a member cannot delete their message');
reset role;

select tests.as_visitor();
select throws_ok($$ select public.set_message_read(1, true) $$, '42501', null, 'a visitor cannot call set_message_read');
reset role;

-- ---------------------------------------------------------------------------
-- 5. The rate limit: 5 messages per person per hour
-- ---------------------------------------------------------------------------
select tests.person('lee', 'Lee');
-- Two messages from two hours ago do not count (written as the database owner, which is never limited).
insert into public.messages (board_id, author_id, body, created_at)
  values (tests.board_id('b1'), tests.id('lee'), 'Old one', now() - interval '2 hours'),
         (tests.board_id('b1'), tests.id('lee'), 'Old two', now() - interval '2 hours');
-- Five ideas in the last hour count for ideas only, not for messages.
select tests.idea('b1', 'lee', 'Lee idea ' || n) from generate_series(1, 5) n;

select tests.as_person('lee');
select lives_ok(format($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), 'Quick %s') $$, n),
  format('message %s of 5 in the hour goes through', n))
from generate_series(1, 5) n;
select throws_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b2'), 'Quick 6') $$,
  'P0001', 'You are posting quickly. Try again in a few minutes.',
  'the sixth message in the hour is refused in words, to any board');
reset role;
select is(tests.message_count('lee'), 7::bigint, 'Lee has 7 messages: 2 old ones and 5 in the last hour');

select tests.as_person('kim');
select lives_ok($$ insert into public.messages (board_id, body) values (tests.board_id('b1'), 'Kim is not limited by Lee') $$,
  'the limit is per person: another member can still send');
reset role;

-- ---------------------------------------------------------------------------
-- 6. Removing a person removes their messages
-- ---------------------------------------------------------------------------
delete from auth.users where id = tests.id('sam');
select is(tests.message_count('sam'), 0::bigint, 'when a person is removed, their messages go too');

select * from finish();
rollback;
