-- Ideas (F1 section 3): reading, posting, and what nobody may write directly.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.person('ana', 'Ana');
select tests.person('sam', 'Sam');
select tests.person('nel');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana'));
select tests.idea('b1', 'ana', 'Visible idea');
select tests.idea('b1', 'ana', 'Hidden idea');
update public.ideas set hidden_at = now(), hidden_by = tests.id('ana') where title = 'Hidden idea';

-- Reading
select tests.as_visitor();
select results_eq($$ select title from public.ideas where board_id = tests.board_id('b1') order by title $$, $$ values ('Visible idea') $$,
  'a visitor reads ideas that are not hidden');
reset role;
select tests.as_person('sam');
select results_eq($$ select title from public.ideas where board_id = tests.board_id('b1') order by title $$, $$ values ('Visible idea') $$,
  'a signed-in person does not see hidden ideas');
reset role;
select tests.as_person('ana');
select results_eq($$ select title from public.ideas where board_id = tests.board_id('b1') order by title $$, $$ values ('Hidden idea'), ('Visible idea') $$,
  'the owner also sees hidden ideas');
reset role;

-- Posting
select tests.as_person('sam');
select lives_ok($$ insert into public.ideas (board_id, title, body) values (tests.board_id('b1'), 'Sync between work and home', 'Please.') $$,
  'a signed-in person with a display name posts an idea');
reset role;
select results_eq(
  $$ select author_id, status::text, vote_count, comment_count, hidden_at is null, merged_into_id is null
     from public.ideas where title = 'Sync between work and home' $$,
  $$ values (tests.id('sam'), 'open', 1, 0, true, true) $$,
  'the new idea is by its poster, Open, with the author''s own vote, and not hidden or merged');
select results_eq($$ select user_id from public.votes where idea_id = tests.idea_id('Sync between work and home') $$,
  $$ values (tests.id('sam')) $$, 'posting an idea also casts the author''s vote');

select tests.as_person('nel');
select throws_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), 'No name yet') $$, '42501',
  'new row violates row-level security policy for table "ideas"', 'a person without a display name cannot post');
reset role;
select tests.as_visitor();
select throws_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), 'Anonymous idea') $$, '42501',
  'permission denied for table ideas', 'a visitor cannot post');
reset role;

select tests.as_person('sam');
select throws_ok($$ insert into public.ideas (board_id, author_id, title) values (tests.board_id('b1'), tests.id('ana'), 'In Ana''s name') $$, '42501',
  'permission denied for table ideas', 'nobody posts in someone else''s name');
select throws_ok($$ insert into public.ideas (board_id, title, status) values (tests.board_id('b1'), 'Already shipped', 'shipped') $$, '42501',
  'permission denied for table ideas', 'nobody posts an idea with a status other than Open');
select throws_ok($$ insert into public.ideas (board_id, title, vote_count) values (tests.board_id('b1'), 'Many votes', 500) $$, '42501',
  'permission denied for table ideas', 'nobody posts an idea with a vote count');
select throws_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), 'Abc') $$, '23514',
  null, 'a title needs at least 4 characters');
select throws_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), repeat('t', 121)) $$, '23514',
  null, 'a title has at most 120 characters');
select throws_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), 'Two  spaces') $$, '23514',
  null, 'a title is one line with single spaces');
select throws_ok($$ insert into public.ideas (board_id, title, body) values (tests.board_id('b1'), 'Long details', repeat('d', 4001)) $$, '23514',
  null, 'details have at most 4,000 characters');

-- What nobody writes directly (vote_count, status, hidden_at, and no edits in v1)
select throws_ok($$ update public.ideas set title = 'Edited' where author_id = tests.id('sam') $$, '42501',
  'permission denied for table ideas', 'an author cannot edit their idea in version 1');
select throws_ok($$ update public.ideas set vote_count = 999 $$, '42501',
  'permission denied for table ideas', 'nobody writes vote_count directly');
select throws_ok($$ update public.ideas set status = 'shipped' $$, '42501',
  'permission denied for table ideas', 'nobody writes status directly');
select throws_ok($$ update public.ideas set hidden_at = now() $$, '42501',
  'permission denied for table ideas', 'nobody writes hidden_at directly');
select throws_ok($$ delete from public.ideas where author_id = tests.id('sam') $$, '42501',
  'permission denied for table ideas', 'nobody deletes an idea, not even their own');
reset role;

select tests.as_person('ana');
select throws_ok($$ update public.ideas set status = 'planned' $$, '42501',
  'permission denied for table ideas', 'not even the owner writes status directly (only set_idea_status)');
select throws_ok($$ update public.ideas set hidden_at = now() $$, '42501',
  'permission denied for table ideas', 'not even the owner writes hidden_at directly (only hide_idea)');
select throws_ok($$ delete from public.ideas $$, '42501',
  'permission denied for table ideas', 'the owner hides, never deletes');
reset role;

select tests.as_visitor();
select throws_ok($$ update public.ideas set vote_count = 999 $$, '42501',
  'permission denied for table ideas', 'a visitor cannot write vote_count');
reset role;

select * from finish();
rollback;
