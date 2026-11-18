-- Who owns a board, readable by everyone (task O2, decision F5-D1):
-- public.board_owner_ids returns the owners' user ids of one board, and nothing
-- else, to visitors and members alike. board_owners itself stays as it was.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');
select tests.person('bo', 'Bo');
select tests.person('sam', 'Sam');
select tests.person('cy', 'Cy');
insert into public.board_owners (board_id, user_id) values
  (tests.board_id('b1'), tests.id('ana')),
  (tests.board_id('b1'), tests.id('bo')),
  (tests.board_id('b2'), tests.id('cy'));

-- The function itself.
select has_function('public', 'board_owner_ids', array['uuid'], 'public.board_owner_ids(uuid) exists');
select function_returns('public', 'board_owner_ids', array['uuid'], 'setof uuid',
  'it returns user ids only (setof uuid): no email, no name, no other column');
select is_definer('public', 'board_owner_ids', array['uuid'], 'it is security definer');
select volatility_is('public', 'board_owner_ids', array['uuid'], 'stable', 'it is stable (it only reads)');
select is((select array_to_string(p.proconfig, ',') from pg_proc p
           where p.oid = 'public.board_owner_ids(uuid)'::regprocedure),
          'search_path=""', 'it sets search_path to empty');
select ok(not exists (select 1 from pg_proc p cross join lateral aclexplode(p.proacl) a
                      where p.oid = 'public.board_owner_ids(uuid)'::regprocedure and a.grantee = 0),
          'public (every role) may not execute it; only anon and authenticated (01_structure)');

-- A visitor gets exactly the owners of a board, and nothing of another board.
select tests.as_visitor();
select results_eq($$ select id from public.board_owner_ids(tests.board_id('b1')) as f (id) order by id $$,
  $$ select id from unnest(array[tests.id('ana'), tests.id('bo')]) as u (id) order by id $$,
  'a visitor gets exactly the two owners of b1');
select results_eq($$ select id from public.board_owner_ids(tests.board_id('b2')) as f (id) $$,
  $$ values (tests.id('cy')) $$, 'a visitor gets exactly the one owner of b2, not those of b1');
select is_empty($$ select * from public.board_owner_ids(gen_random_uuid()) $$,
  'a visitor gets nothing for a board that does not exist');
select throws_ok($$ select * from public.board_owners $$, '42501', null,
  'board_owners itself is still closed to a visitor (no privilege, unchanged)');
reset role;

-- A member (signed in, owns no board) gets the same.
select tests.as_person('sam');
select results_eq($$ select id from public.board_owner_ids(tests.board_id('b1')) as f (id) order by id $$,
  $$ select id from unnest(array[tests.id('ana'), tests.id('bo')]) as u (id) order by id $$,
  'a member gets exactly the two owners of b1');
select results_eq($$ select id from public.board_owner_ids(tests.board_id('b2')) as f (id) $$,
  $$ values (tests.id('cy')) $$, 'a member gets exactly the one owner of b2, not those of b1');
select is_empty($$ select * from public.board_owners $$,
  'board_owners itself still shows a member no row (they own no board)');
reset role;

-- An owner of b2 gets the owners of b1 too, and an owner of b1 still reads b1's rows directly.
select tests.as_person('cy');
select results_eq($$ select id from public.board_owner_ids(tests.board_id('b1')) as f (id) order by id $$,
  $$ select id from unnest(array[tests.id('ana'), tests.id('bo')]) as u (id) order by id $$,
  'an owner of another board gets exactly the owners of b1');
reset role;
select tests.as_person('ana');
select results_eq($$ select user_id from public.board_owners where board_id = tests.board_id('b1') order by user_id $$,
  $$ select id from unnest(array[tests.id('ana'), tests.id('bo')]) as u (id) order by id $$,
  'an owner of b1 still reads both owner rows of b1 directly');
reset role;

-- The ids lead to nothing private: a visitor reads a display name, never an email.
select tests.as_visitor();
select results_eq($$ select p.display_name from public.profiles p
                     join public.board_owner_ids(tests.board_id('b2')) as f (id) on f.id = p.id $$,
  $$ values ('Cy') $$, 'with an owner id a visitor reads only the display name, as for any person');
select throws_ok($$ select email from auth.users where id = tests.id('cy') $$, '42501', null,
  'a visitor still cannot read the owner''s email address');
reset role;

select * from finish();
rollback;
