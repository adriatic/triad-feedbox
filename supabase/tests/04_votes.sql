-- Votes (F1 section 3): one vote per person per idea.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.person('ana', 'Ana');
select tests.person('sam', 'Sam');
select tests.person('kim', 'Kim');
select tests.person('nel');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana'));
select tests.idea('b1', 'ana', 'Idea to vote on');
select tests.idea('b1', 'ana', 'Hidden idea');
select tests.idea('b1', 'ana', 'Merged idea');
update public.ideas set hidden_at = now() where title = 'Hidden idea';
update public.ideas set merged_into_id = tests.idea_id('Idea to vote on') where title = 'Merged idea';

select results_eq($$ select vote_count from public.ideas where id = tests.idea_id('Idea to vote on') $$,
  $$ values (1) $$, 'a new idea starts with its author''s vote');

-- Voting
select tests.as_person('sam');
select lives_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Idea to vote on')) $$,
  'a signed-in person with a display name votes');
reset role;
select results_eq($$ select vote_count from public.ideas where id = tests.idea_id('Idea to vote on') $$,
  $$ values (2) $$, 'the vote count goes up by one');

select tests.as_person('sam');
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Idea to vote on')) $$, '23505',
  'duplicate key value violates unique constraint "votes_pkey"', 'the same person cannot vote twice on one idea');
select lives_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Idea to vote on')) on conflict do nothing $$,
  'a double click (insert with on conflict do nothing) is harmless');
select throws_ok($$ insert into public.votes (idea_id, user_id) values (tests.idea_id('Idea to vote on'), tests.id('kim')) $$, '42501',
  'permission denied for table votes', 'nobody votes as someone else');
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Hidden idea')) $$, '42501',
  'new row violates row-level security policy for table "votes"', 'nobody votes on a hidden idea');
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Merged idea')) $$, 'P0001',
  'This idea was just merged into “Idea to vote on”. Vote there.', 'nobody votes on a merged idea, and is told where to vote (task F6b)');
select throws_ok($$ update public.votes set created_at = now() $$, '42501',
  'permission denied for table votes', 'votes are never changed');
reset role;
select results_eq($$ select vote_count from public.ideas where id = tests.idea_id('Idea to vote on') $$,
  $$ values (2) $$, 'refused votes did not change the count');

select tests.as_person('ana');
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Hidden idea')) $$, '42501',
  'new row violates row-level security policy for table "votes"', 'not even the owner votes on a hidden idea');
reset role;

select tests.as_person('nel');
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Idea to vote on')) $$, '42501',
  'new row violates row-level security policy for table "votes"', 'a person without a display name cannot vote');
reset role;

select tests.as_visitor();
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Idea to vote on')) $$, '42501',
  'permission denied for table votes', 'a visitor cannot vote');
select throws_ok($$ select * from public.votes $$, '42501',
  'permission denied for table votes', 'a visitor cannot read who voted');
reset role;

-- Reading: only your own votes
select tests.as_person('kim');
select lives_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Idea to vote on')) $$, 'kim votes too');
select results_eq($$ select user_id from public.votes $$, $$ values (tests.id('kim')) $$,
  'a person sees only their own votes, not who else voted');
reset role;

-- Unvoting: only through remove_my_vote (task F6b), which removes the caller's own vote and nobody else's.
select tests.as_person('sam');
select throws_ok($$ delete from public.votes where idea_id = tests.idea_id('Idea to vote on') $$, '42501', null,
  'votes are never deleted directly through the API');
select results_eq($$ select public.remove_my_vote(tests.idea_id('Idea to vote on')) $$,
  $$ values (true) $$, 'a person removes their own vote (and only theirs)');
select results_eq($$ select public.remove_my_vote(tests.idea_id('Idea to vote on')) $$,
  $$ values (false) $$, 'removing it again finds no vote');
select throws_ok($$ select public.remove_my_vote(tests.idea_id('Merged idea')) $$, 'P0001',
  'This idea was just merged into “Idea to vote on”. Your vote moved there with it; remove it there if you wish.',
  'on a merged idea it says where the vote is now');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.remove_my_vote(tests.idea_id('Idea to vote on')) $$, '42501', null,
  'a visitor cannot call remove_my_vote');
reset role;
select results_eq($$ select vote_count from public.ideas where id = tests.idea_id('Idea to vote on') $$,
  $$ values (2) $$, 'removing a vote takes the count down by one (ana and kim remain)');
select results_eq($$ select count(*)::int from public.votes where idea_id = tests.idea_id('Idea to vote on') $$,
  $$ values (2) $$, 'the count always equals the number of vote rows');

select * from finish();
rollback;
