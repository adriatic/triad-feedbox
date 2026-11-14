-- Rate limits per person per hour (F1 section 6): 5 ideas, 30 comments, 100 votes.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.person('ana', 'Ana');
select tests.person('sam', 'Sam');
select tests.person('kim', 'Kim');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana'));
-- 101 ideas for kim to vote on, and one for comments.
insert into public.ideas (board_id, author_id, title)
  select tests.board_id('b1'), tests.id('ana'), 'Vote target ' || n from generate_series(1, 101) n;

-- Ideas
select tests.as_person('sam');
select lives_ok($$ insert into public.ideas (board_id, title) select tests.board_id('b1'), 'Sam idea ' || n from generate_series(1, 5) n $$,
  'five ideas in an hour are allowed');
select throws_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), 'Sam idea 6') $$, 'P0001',
  'You are posting quickly. Try again in a few minutes.', 'the sixth idea in an hour is refused');
reset role;
update public.ideas set created_at = now() - interval '61 minutes' where author_id = tests.id('sam');
select tests.as_person('sam');
select lives_ok($$ insert into public.ideas (board_id, title) values (tests.board_id('b1'), 'Sam idea 6') $$,
  'ideas older than an hour no longer count');
reset role;

-- Comments
select tests.as_person('sam');
select lives_ok($$ insert into public.comments (idea_id, body) select tests.idea_id('Vote target 1'), 'Comment ' || n from generate_series(1, 30) n $$,
  'thirty comments in an hour are allowed');
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Vote target 1'), 'Comment 31') $$, 'P0001',
  'You are posting quickly. Try again in a few minutes.', 'the 31st comment in an hour is refused');
reset role;

-- Votes
select tests.as_person('kim');
select lives_ok($$ insert into public.votes (idea_id) select tests.idea_id('Vote target ' || n) from generate_series(1, 100) n $$,
  'a hundred votes in an hour are allowed');
select throws_ok($$ insert into public.votes (idea_id) values (tests.idea_id('Vote target 101')) $$, 'P0001',
  'You are posting quickly. Try again in a few minutes.', 'the 101st vote in an hour is refused');
reset role;

-- Owner actions are not limited: a merge may give kim a 101st vote.
select tests.as_person('ana');
select lives_ok($$ select public.merge_ideas(tests.idea_id('Vote target 1'), tests.idea_id('Vote target 101')) $$,
  'a merge moves votes even for someone at their hourly limit');
reset role;
select results_eq($$ select count(*)::int from public.votes where user_id = tests.id('kim') and idea_id = tests.idea_id('Vote target 101') $$,
  $$ values (1) $$, 'kim''s vote moved to the target');

select * from finish();
rollback;
