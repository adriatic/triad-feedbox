-- Merging duplicates (F1 section 5): votes counted once, comments moved.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');
select tests.person('sam', 'Sam');
select tests.person('kim', 'Kim');
select tests.person('lee', 'Lee');
select tests.person('max', 'Max');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana'));

-- Source "Synch notes" (votes: sam as author, lee, max). Target "Sync between laptops" (votes: kim as author, lee).
select tests.idea('b1', 'sam', 'Synch notes');
select tests.idea('b1', 'kim', 'Sync between laptops');
select tests.idea('b1', 'max', 'Older duplicate');
select tests.idea('b1', 'ana', 'Hidden idea');
select tests.idea('b2', 'ana', 'On another board');
insert into public.votes (idea_id, user_id) values
  (tests.idea_id('Synch notes'), tests.id('lee')),
  (tests.idea_id('Synch notes'), tests.id('max')),
  (tests.idea_id('Sync between laptops'), tests.id('lee'));
insert into public.comments (idea_id, author_id, body) values
  (tests.idea_id('Synch notes'), tests.id('lee'), 'Same here.'),
  (tests.idea_id('Synch notes'), tests.id('max'), 'Over Wi-Fi, please.'),
  (tests.idea_id('Sync between laptops'), tests.id('kim'), 'Any sync would do.');
update public.ideas set merged_into_id = tests.idea_id('Synch notes') where title = 'Older duplicate';
update public.ideas set hidden_at = now() where title = 'Hidden idea';

select results_eq($$ select title, vote_count, comment_count from public.ideas where title in ('Synch notes', 'Sync between laptops') order by title $$,
  $$ values ('Sync between laptops', 2, 1), ('Synch notes', 3, 2) $$, 'before the merge: 3 + 2 votes, with lee on both');

-- Who may merge
select tests.as_person('sam');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('Sync between laptops')) $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot merge');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.merge_ideas(1, 2) $$, '42501',
  'permission denied for function merge_ideas', 'a visitor cannot call merge_ideas');
reset role;

-- What may not be merged
select tests.as_person('ana');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('Synch notes')) $$, '23514',
  'An idea cannot be merged into itself.', 'an idea cannot be merged into itself');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('On another board')) $$, '23514',
  'Both ideas must be on the same board.', 'ideas on different boards cannot be merged');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('Hidden idea')) $$, '23514',
  'The target idea is hidden. Unhide it first, or pick another idea.', 'nothing is merged into a hidden idea');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Older duplicate'), tests.idea_id('Sync between laptops')) $$, '23514',
  'This idea has already been merged.', 'an idea that was already merged cannot be merged again');

-- The merge
select results_eq($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('Sync between laptops')) $$,
  $$ values (4) $$, 'the owner merges, and the target now has 4 votes (lee is counted once)');
reset role;

select results_eq($$ select user_id from public.votes where idea_id = tests.idea_id('Sync between laptops') order by user_id $$,
  $$ select unnest(array[tests.id('kim'), tests.id('lee'), tests.id('max'), tests.id('sam')]) order by 1 $$,
  'every person who voted on either idea has exactly one vote on the target');
select results_eq($$ select vote_count, comment_count, merged_into_id from public.ideas where id = tests.idea_id('Synch notes') $$,
  $$ values (0, 0, tests.idea_id('Sync between laptops')) $$, 'the source has no votes or comments left and points to the target');
select results_eq($$ select comment_count from public.ideas where id = tests.idea_id('Sync between laptops') $$,
  $$ values (3) $$, 'the target counts the moved comments');
select results_eq($$ select body, moved_from_idea_id from public.comments where idea_id = tests.idea_id('Sync between laptops') order by id $$,
  $$ values ('Same here.', tests.idea_id('Synch notes')), ('Over Wi-Fi, please.', tests.idea_id('Synch notes')), ('Any sync would do.', null::bigint) $$,
  'moved comments keep their text and remember where they came from');
select results_eq($$ select merged_into_id from public.ideas where title = 'Older duplicate' $$,
  $$ values (tests.idea_id('Sync between laptops')) $$, 'an idea merged earlier into the source now points straight at the target');

select tests.as_person('ana');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Sync between laptops'), tests.idea_id('Synch notes')) $$, '23514',
  'The target idea has itself been merged.', 'nothing is merged into an idea that was merged');
reset role;

select tests.as_visitor();
select results_eq($$ select merged_into_id from public.ideas where title = 'Synch notes' $$,
  $$ values (tests.idea_id('Sync between laptops')) $$, 'a visitor can still open the merged idea, to be redirected');
reset role;

select * from finish();
rollback;
