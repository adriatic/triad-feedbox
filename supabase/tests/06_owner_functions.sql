-- Owner functions: set_idea_status, hide_idea, unhide_idea (F1 sections 3 and 8).
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');
select tests.person('bo', 'Bo');
select tests.person('sam', 'Sam');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana')), (tests.board_id('b2'), tests.id('bo'));
select tests.idea('b1', 'sam', 'Dark mode for the editor');
update public.ideas set status_changed_at = now() - interval '1 day' where title = 'Dark mode for the editor';

-- set_idea_status
select tests.as_person('sam');
select throws_ok($$ select public.set_idea_status(tests.idea_id('Dark mode for the editor'), 'planned') $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot change status');
reset role;
select tests.as_person('bo');
select throws_ok($$ select public.set_idea_status(tests.idea_id('Dark mode for the editor'), 'planned') $$, '42501',
  'Only an owner of this board can do this.', 'the owner of another board cannot change status');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.set_idea_status(1, 'planned') $$, '42501',
  'permission denied for function set_idea_status', 'a visitor cannot call set_idea_status');
reset role;

select tests.as_person('ana');
select lives_ok($$ select public.set_idea_status(tests.idea_id('Dark mode for the editor'), 'planned') $$,
  'the owner moves an idea to Planned');
reset role;
select results_eq($$ select status::text, status_changed_at > now() - interval '1 minute', shipped_at is null from public.ideas where id = tests.idea_id('Dark mode for the editor') $$,
  $$ values ('planned', true, true) $$, 'the status is Planned and status_changed_at is updated');

select tests.as_person('ana');
select throws_ok($$ select public.set_idea_status(tests.idea_id('Dark mode for the editor'), 'planned') $$, '23514',
  'The idea is already Planned.', 'setting the same status again is refused');
select lives_ok($$ select public.set_idea_status(tests.idea_id('Dark mode for the editor'), 'shipped') $$,
  'the owner moves an idea to Shipped');
reset role;
select results_eq($$ select status::text, shipped_at is not null from public.ideas where id = tests.idea_id('Dark mode for the editor') $$,
  $$ values ('shipped', true) $$, 'Shipped sets shipped_at');

select tests.as_person('ana');
select lives_ok($$ select public.set_idea_status(tests.idea_id('Dark mode for the editor'), 'building') $$,
  'the owner may move an idea back, to correct a mistake');
reset role;
select results_eq($$ select status::text, shipped_at is null from public.ideas where id = tests.idea_id('Dark mode for the editor') $$,
  $$ values ('building', true) $$, 'leaving Shipped clears shipped_at');

select tests.as_person('ana');
select throws_ok($$ select public.set_idea_status(999999999, 'planned') $$, 'P0002',
  'Idea not found.', 'an unknown idea is reported as not found');
reset role;

-- hide_idea and unhide_idea
select tests.as_person('sam');
select throws_ok($$ select public.hide_idea(tests.idea_id('Dark mode for the editor')) $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot hide an idea');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.hide_idea(1) $$, '42501',
  'permission denied for function hide_idea', 'a visitor cannot call hide_idea');
reset role;

select tests.as_person('ana');
select lives_ok($$ select public.hide_idea(tests.idea_id('Dark mode for the editor')) $$, 'the owner hides an idea');
reset role;
select results_eq($$ select hidden_at is not null, hidden_by from public.ideas where id = tests.idea_id('Dark mode for the editor') $$,
  $$ values (true, tests.id('ana')) $$, 'hidden_at and hidden_by are set');
select tests.as_visitor();
select is_empty($$ select 1 from public.ideas where board_id = tests.board_id('b1') $$, 'a hidden idea vanishes for visitors');
reset role;
select tests.as_person('sam');
select is_empty($$ select 1 from public.ideas where board_id = tests.board_id('b1') $$, 'a hidden idea vanishes even for its author');
select throws_ok($$ select public.unhide_idea(tests.idea_id('Dark mode for the editor')) $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot unhide an idea');
reset role;

select tests.as_person('ana');
select lives_ok($$ select public.unhide_idea(tests.idea_id('Dark mode for the editor')) $$, 'the owner unhides the idea');
reset role;
select tests.as_visitor();
select results_eq($$ select count(*)::int from public.ideas where board_id = tests.board_id('b1') $$, $$ values (1) $$,
  'an unhidden idea is visible again');
reset role;

select * from finish();
rollback;
