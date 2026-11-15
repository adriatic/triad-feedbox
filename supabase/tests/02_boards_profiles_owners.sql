-- Boards, profiles and board owners (F1 section 3, section 4).
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.person('ana', 'Ana');
select tests.person('sam', 'Sam');
select tests.person('nel');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana'));

-- A new person gets a profile with no display name.
select results_eq($$ select display_name from public.profiles where id = tests.id('nel') $$,
  $$ values (null::text) $$, 'signing up creates a profile without a display name');

-- boards
select tests.as_visitor();
select results_eq($$ select name from public.boards where slug = 'b1' $$, $$ values ('B1') $$, 'a visitor reads boards');
reset role;
select tests.as_person('ana');
select throws_ok($$ insert into public.boards (slug, name) values ('mine', 'Mine') $$, '42501',
  'permission denied for table boards', 'nobody creates a board through the app, not even an owner');
select throws_ok($$ update public.boards set name = 'Renamed' $$, '42501',
  'permission denied for table boards', 'nobody renames a board through the app');
select throws_ok($$ delete from public.boards $$, '42501',
  'permission denied for table boards', 'nobody deletes a board through the app');
reset role;

-- profiles
select tests.as_visitor();
select results_eq($$ select display_name from public.profiles where id = tests.id('sam') $$,
  $$ values ('Sam') $$, 'a visitor reads display names');
reset role;

select tests.as_person('nel');
select results_eq($$ with u as (update public.profiles set display_name = 'Nel B.' where id = tests.id('nel') returning 1) select count(*)::int from u $$,
  $$ values (1) $$, 'a person sets their own display name');
select results_eq($$ with u as (update public.profiles set display_name = 'Hacked' where id = tests.id('sam') returning 1) select count(*)::int from u $$,
  $$ values (0) $$, 'a person cannot change someone else''s display name');
select throws_ok($$ update public.profiles set display_name = 'nel@mail.example' where id = tests.id('nel') $$, '23514',
  null, 'a display name may not contain "@" (F2-D2)');
select throws_ok($$ update public.profiles set display_name = 'N' where id = tests.id('nel') $$, '23514',
  null, 'a display name needs at least 2 characters');
select throws_ok($$ update public.profiles set display_name = repeat('n', 41) where id = tests.id('nel') $$, '23514',
  null, 'a display name has at most 40 characters');
select throws_ok($$ update public.profiles set display_name = 'Nel  B.' where id = tests.id('nel') $$, '23514',
  null, 'a display name is one line with single spaces');
select lives_ok($$ update public.profiles set display_name = repeat('n', 40) where id = tests.id('nel') $$,
  'a display name of exactly 40 characters is accepted');
select throws_ok($$ update public.profiles set id = tests.id('ana') where id = tests.id('nel') $$, '42501',
  'permission denied for table profiles', 'a person cannot change their profile id');
select throws_ok($$ insert into public.profiles (id) values (gen_random_uuid()) $$, '42501',
  'permission denied for table profiles', 'nobody inserts a profile through the app');
select throws_ok($$ delete from public.profiles where id = tests.id('nel') $$, '42501',
  'permission denied for table profiles', 'nobody deletes a profile through the app');
reset role;

-- board_owners and is_board_owner
select tests.as_person('ana');
select results_eq($$ select count(*)::int from public.board_owners where board_id = tests.board_id('b1') $$,
  $$ values (1) $$, 'an owner sees the owners of their board');
select ok(public.is_board_owner(tests.board_id('b1')), 'is_board_owner is true for the owner');
reset role;

select tests.as_person('sam');
select results_eq($$ select count(*)::int from public.board_owners $$, $$ values (0) $$,
  'someone who is not an owner sees no owner rows');
select ok(not public.is_board_owner(tests.board_id('b1')), 'is_board_owner is false for someone who is not an owner');
select throws_ok($$ insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('sam')) $$, '42501',
  'permission denied for table board_owners', 'a person can never make themselves an owner');
reset role;

select tests.as_visitor();
select ok(not public.is_board_owner(tests.board_id('b1')), 'is_board_owner is false for a visitor');
select throws_ok($$ select * from public.board_owners $$, '42501',
  'permission denied for table board_owners', 'a visitor cannot read the owners list');
reset role;

select * from finish();
rollback;
