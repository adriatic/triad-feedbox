-- Undoing a merge (task F6a, replaces decision F1-D8 "no undo in v1"): the merge
-- log, undo_merge, the in-between cases, two merges into one target, refusals,
-- and who may read or write the log.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');   -- owner of b1
select tests.person('bo', 'Bo');     -- owner of b2
select tests.person('sam', 'Sam');
select tests.person('kim', 'Kim');
select tests.person('lee', 'Lee');
select tests.person('max', 'Max');
select tests.person('ned', 'Ned');
select tests.person('joe', 'Joe');
select tests.person('pat', 'Pat');
insert into public.board_owners (board_id, user_id) values
  (tests.board_id('b1'), tests.id('ana')),
  (tests.board_id('b2'), tests.id('bo'));

-- Votes on an idea, as a sorted list of handles.
create function tests.voters(p_title text) returns text language sql stable security definer as $$
  select coalesce(string_agg(p.display_name, ',' order by p.display_name), '')
  from public.votes v join public.profiles p on p.id = v.user_id
  where v.idea_id = tests.idea_id(p_title);
$$;
-- The merge log row of the latest merge of an idea.
create function tests.merge_of(p_title text) returns bigint language sql stable security definer as $$
  select max(m.id) from public.idea_merges m where m.source_id = tests.idea_id(p_title);
$$;
grant execute on function tests.voters(text), tests.merge_of(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. One merge and its undo, with an earlier merge into the source and
--    everything that can happen in between.
--    Target "Sync between laptops": kim (author), lee.
--    Source "Synch notes": sam (author), lee, max, ned; comments by lee and max.
--    "Older duplicate" (joe, with a comment) is merged into the source first.
-- ---------------------------------------------------------------------------
select tests.idea('b1', 'kim', 'Sync between laptops');
select tests.idea('b1', 'sam', 'Synch notes');
select tests.idea('b1', 'joe', 'Older duplicate');
update public.ideas set body = 'Notes should sync.' where title = 'Synch notes';
insert into public.votes (idea_id, user_id) values
  (tests.idea_id('Sync between laptops'), tests.id('lee')),
  (tests.idea_id('Synch notes'), tests.id('lee')),
  (tests.idea_id('Synch notes'), tests.id('max')),
  (tests.idea_id('Synch notes'), tests.id('ned'));
insert into public.comments (idea_id, author_id, body) values
  (tests.idea_id('Synch notes'), tests.id('lee'), 'Same here.'),
  (tests.idea_id('Synch notes'), tests.id('max'), 'Over Wi-Fi, please.'),
  (tests.idea_id('Sync between laptops'), tests.id('kim'), 'Any sync would do.'),
  (tests.idea_id('Older duplicate'), tests.id('joe'), 'From the older one.');

select tests.as_person('ana');
select results_eq($$ select public.merge_ideas(tests.idea_id('Older duplicate'), tests.idea_id('Synch notes')) $$,
  $$ values (5) $$, 'merge 0: "Older duplicate" into "Synch notes", which now has 5 votes');
reset role;

-- The source as it is before the merge that will be undone.
create temp table before_source as
  select id, board_id, author_id, title, body, status, created_at, hidden_at, merged_into_id, vote_count, comment_count
  from public.ideas where title = 'Synch notes';
create temp table before_comments as
  select id, idea_id, moved_from_idea_id, body from public.comments
  where idea_id = tests.idea_id('Synch notes');
select results_eq($$ select tests.voters('Synch notes'), tests.voters('Sync between laptops') $$,
  $$ values ('Joe,Lee,Max,Ned,Sam', 'Kim,Lee') $$, 'before merge 1: the source has 5 voters, the target 2 (lee voted for both)');

select tests.as_person('ana');
select results_eq($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('Sync between laptops')) $$,
  $$ values (6) $$, 'merge 1: "Synch notes" into "Sync between laptops", which now has 6 votes');
reset role;

-- The log of merge 1.
select results_eq(
  $$ select m.board_id, m.source_id, m.target_id, m.merged_by, cardinality(m.moved_comment_ids), m.rerouted_idea_ids, m.undone_at
     from public.idea_merges m where m.id = tests.merge_of('Synch notes') $$,
  $$ values (tests.board_id('b1'), tests.idea_id('Synch notes'), tests.idea_id('Sync between laptops'), tests.id('ana'),
             3, array[tests.idea_id('Older duplicate')], null::timestamptz) $$,
  'the log names the board, the source, the target and the owner, the 3 moved comments and the idea merged earlier into the source');
select results_eq(
  $$ select p.display_name::text, mv.added_to_target from public.idea_merge_votes mv join public.profiles p on p.id = mv.user_id
     where mv.merge_id = tests.merge_of('Synch notes') order by 1 $$,
  $$ values ('Joe', true), ('Lee', false), ('Max', true), ('Ned', true), ('Sam', true) $$,
  'the log holds every vote taken from the source, and which ones the merge added to the target (lee already had one)');
select is((select count(*)::int from public.idea_merges m where m.source_id = tests.idea_id('Older duplicate') and m.undone_at is null), 1,
  'merge 0 is in the log too');

-- Merge 0 cannot be undone while its target is itself merged.
select tests.as_person('ana');
select throws_ok($$ select public.undo_merge(tests.merge_of('Older duplicate')) $$, '23514',
  '“Synch notes” has itself been merged into another idea since. Undo that merge first, on the page of the idea it was merged into.',
  'an undo is refused when the target has itself been merged since');
reset role;
select is(tests.voters('Older duplicate'), '', 'and the refusal changed nothing');

-- In between: pat votes for the target; kim comments on it; max removes his
-- vote; ned removes his vote and votes again.
select tests.as_person('pat');
insert into public.votes (idea_id) values (tests.idea_id('Sync between laptops'));
reset role;
select tests.as_person('kim');
insert into public.comments (idea_id, body) values (tests.idea_id('Sync between laptops'), 'After the merge.');
reset role;
select tests.as_person('max');
select public.remove_my_vote(tests.idea_id('Sync between laptops'));
reset role;
select tests.as_person('ned');
select public.remove_my_vote(tests.idea_id('Sync between laptops'));
insert into public.votes (idea_id) values (tests.idea_id('Sync between laptops'));
reset role;
select results_eq(
  $$ select p.display_name::text from public.idea_merge_votes mv join public.profiles p on p.id = mv.user_id
     where mv.merge_id = tests.merge_of('Synch notes') and mv.target_vote_removed_at is not null order by 1 $$,
  $$ values ('Max'), ('Ned') $$, 'the log notes who removed their vote on the target after the merge');

-- Who may undo.
select tests.as_person('sam');
select throws_ok($$ select public.undo_merge(tests.merge_of('Synch notes')) $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot undo a merge');
reset role;
select tests.as_person('bo');
select throws_ok($$ select public.undo_merge(tests.merge_of('Synch notes')) $$, '42501',
  'Only an owner of this board can do this.', 'the owner of another board cannot undo it either');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.undo_merge(1) $$, '42501',
  'permission denied for function undo_merge', 'a visitor cannot call undo_merge');
reset role;
select tests.as_person('ana');
select throws_ok($$ select public.undo_merge(-1) $$, 'P0002', 'Merge not found.', 'an unknown merge is not found');
reset role;
select is(tests.voters('Synch notes'), '', 'the refusals changed nothing: the source is still merged');

-- The undo.
select tests.as_person('ana');
select results_eq($$ select public.undo_merge(tests.merge_of('Synch notes')) $$,
  $$ values (3) $$, 'the owner undoes merge 1; "Synch notes" is back with 3 votes');
reset role;

select results_eq(
  $$ select id, board_id, author_id, title, body, status, created_at, hidden_at, merged_into_id from public.ideas where title = 'Synch notes' $$,
  $$ select id, board_id, author_id, title, body, status, created_at, hidden_at, merged_into_id from before_source $$,
  'the source is back exactly as before: same id (address), board, author, title, details, status, date, not merged');
select results_eq($$ select tests.voters('Synch notes') $$, $$ values ('Joe,Lee,Sam') $$,
  'everyone whose vote the merge took counts on the source again, except max and ned, who removed their vote on the target in between');
select results_eq($$ select tests.voters('Sync between laptops') $$, $$ values ('Kim,Lee,Ned,Pat') $$,
  'the target loses the votes the merge added (sam, joe); lee, who voted for both, keeps it; pat''s and ned''s new votes stay');
select results_eq(
  $$ select title, vote_count, comment_count from public.ideas where title in ('Synch notes', 'Sync between laptops') order by title $$,
  $$ values ('Sync between laptops', 4, 2), ('Synch notes', 3, 3) $$, 'the counts follow the votes and the comments');
select results_eq(
  $$ select id, idea_id, moved_from_idea_id, body from public.comments where idea_id = tests.idea_id('Synch notes') order by id $$,
  $$ select id, idea_id, moved_from_idea_id, body from before_comments order by id $$,
  'the comments the merge moved are back, with the mark they had before ("From the merged idea" only for the older duplicate''s)');
select results_eq(
  $$ select body from public.comments where idea_id = tests.idea_id('Sync between laptops') order by id $$,
  $$ values ('Any sync would do.'), ('After the merge.') $$, 'the comment written on the target in between stays there');
select results_eq($$ select merged_into_id from public.ideas where title = 'Older duplicate' $$,
  $$ values (tests.idea_id('Synch notes')) $$, 'the idea merged earlier into the source points at the source again');
select results_eq(
  $$ select undone_by, undone_at is not null from public.idea_merges where id = tests.merge_of('Synch notes') $$,
  $$ values (tests.id('ana'), true) $$, 'the log says the merge was undone, and by whom');

select tests.as_person('ana');
select throws_ok($$ select public.undo_merge((select max(id) from public.idea_merges where target_id = tests.idea_id('Sync between laptops'))) $$, '23514',
  'This merge has already been undone.', 'a merge cannot be undone twice');
-- Now merge 0 can be undone too: joe's vote and comment go back to "Older duplicate".
select results_eq($$ select public.undo_merge(tests.merge_of('Older duplicate')) $$,
  $$ values (1) $$, 'merge 0 can be undone now; "Older duplicate" is back with 1 vote');
reset role;
select results_eq($$ select tests.voters('Older duplicate'), tests.voters('Synch notes') $$,
  $$ values ('Joe', 'Lee,Sam') $$, 'joe''s vote is back on "Older duplicate" and gone from "Synch notes"');
select results_eq(
  $$ select body, moved_from_idea_id from public.comments where idea_id = tests.idea_id('Older duplicate') $$,
  $$ values ('From the older one.', null::bigint) $$, 'joe''s comment is back on "Older duplicate", without the merged mark');

-- An undone merge can be merged again, and undone again.
select tests.as_person('ana');
select results_eq($$ select public.merge_ideas(tests.idea_id('Synch notes'), tests.idea_id('Sync between laptops')) $$,
  $$ values (5) $$, 'the same two ideas can be merged again (5 votes: kim, lee, ned, pat, sam)');
select results_eq($$ select public.undo_merge(tests.merge_of('Synch notes')) $$,
  $$ values (2) $$, 'and that merge can be undone again');
reset role;
select results_eq($$ select tests.voters('Synch notes'), tests.voters('Sync between laptops') $$,
  $$ values ('Lee,Sam', 'Kim,Lee,Ned,Pat') $$, 'back to the same votes');
select is((select count(*)::int from public.idea_merges where source_id = tests.idea_id('Synch notes')), 2,
  'the log keeps both merges of "Synch notes"');

-- ---------------------------------------------------------------------------
-- 2. Two merges into the same target; the OLDER one is undone first.
--    Target "Dark mode": kim. "Night theme": sam, pat, kim. "Black background": lee, pat.
-- ---------------------------------------------------------------------------
select tests.idea('b1', 'kim', 'Dark mode');
select tests.idea('b1', 'sam', 'Night theme');
select tests.idea('b1', 'lee', 'Black background');
insert into public.votes (idea_id, user_id) values
  (tests.idea_id('Night theme'), tests.id('pat')),
  (tests.idea_id('Night theme'), tests.id('kim')),
  (tests.idea_id('Black background'), tests.id('pat'));
select tests.as_person('ana');
select results_eq($$ select public.merge_ideas(tests.idea_id('Night theme'), tests.idea_id('Dark mode')) $$,
  $$ values (3) $$, 'first merge into "Dark mode": 3 votes (kim voted for both)');
select results_eq($$ select public.merge_ideas(tests.idea_id('Black background'), tests.idea_id('Dark mode')) $$,
  $$ values (4) $$, 'second merge into "Dark mode": 4 votes (pat is counted once)');
select results_eq($$ select public.undo_merge(tests.merge_of('Night theme')) $$,
  $$ values (3) $$, 'the older merge is undone: "Night theme" is back with its 3 votes');
reset role;
select results_eq($$ select tests.voters('Night theme'), tests.voters('Dark mode'), tests.voters('Black background') $$,
  $$ values ('Kim,Pat,Sam', 'Kim,Lee,Pat', '') $$,
  'kim keeps a vote on each; pat keeps the vote on "Dark mode", which the second merge still needs; sam''s goes');
select is((select mv.added_to_target from public.idea_merge_votes mv where mv.merge_id = tests.merge_of('Black background') and mv.user_id = tests.id('pat')),
  true, 'the second merge now holds pat''s vote on the target, so its own undo takes it');
select tests.as_person('ana');
select results_eq($$ select public.undo_merge(tests.merge_of('Black background')) $$,
  $$ values (2) $$, 'then the second merge is undone: "Black background" is back with 2 votes');
reset role;
select results_eq($$ select tests.voters('Night theme'), tests.voters('Dark mode'), tests.voters('Black background') $$,
  $$ values ('Kim,Pat,Sam', 'Kim', 'Lee,Pat') $$, 'all three ideas have exactly the votes they had before both merges');
select results_eq(
  $$ select title, vote_count from public.ideas where title in ('Dark mode', 'Night theme', 'Black background') order by title $$,
  $$ values ('Black background', 2), ('Dark mode', 1), ('Night theme', 3) $$, 'and the counts say so');

-- ---------------------------------------------------------------------------
-- 3. Refused when the source was removed.
-- ---------------------------------------------------------------------------
select tests.idea('b1', 'sam', 'Removed later');
select tests.as_person('ana');
select public.merge_ideas(tests.idea_id('Removed later'), tests.idea_id('Dark mode'));
reset role;
create temp table removed_merge as select tests.merge_of('Removed later') as id;
grant select on removed_merge to authenticated;
delete from public.ideas where title = 'Removed later';
select tests.as_person('ana');
select throws_ok($$ select public.undo_merge((select id from removed_merge)) $$, '23514',
  'The merged idea no longer exists, so this merge cannot be undone.', 'an undo is refused when the merged idea was removed');
reset role;
select is(tests.voters('Dark mode'), 'Kim,Sam', 'and the refusal changed nothing on the target');

-- ---------------------------------------------------------------------------
-- 4. Who may read and write the log.
-- ---------------------------------------------------------------------------
select tests.idea('b2', 'bo', 'B2 target');
select tests.idea('b2', 'bo', 'B2 source');
select tests.as_person('bo');
select public.merge_ideas(tests.idea_id('B2 source'), tests.idea_id('B2 target'));
reset role;

select tests.as_person('ana');
select results_eq($$ select count(*)::int from public.idea_merges $$,
  $$ select count(*)::int from public.idea_merges m where m.board_id = tests.board_id('b1') $$,
  'an owner reads the merges of their own board, and none of another board');
select isnt_empty($$ select 1 from public.idea_merges $$, 'and does read them');
select throws_ok($$ select * from public.idea_merge_votes $$, '42501', null,
  'not even an owner reads the votes in the log (who voted is private)');
select throws_ok($$ insert into public.idea_merges (board_id) values (tests.board_id('b1')) $$, '42501', null,
  'an owner cannot write the log directly');
select throws_ok($$ update public.idea_merges set undone_at = now() $$, '42501', null,
  'an owner cannot mark a merge undone directly');
select throws_ok($$ delete from public.idea_merges $$, '42501', null, 'an owner cannot delete the log');
reset role;

select tests.as_person('sam');
select is_empty($$ select * from public.idea_merges $$, 'a member reads no merge');
select throws_ok($$ select * from public.idea_merge_votes $$, '42501', null, 'a member cannot read the votes in the log');
reset role;

select tests.as_visitor();
select throws_ok($$ select * from public.idea_merges $$, '42501', null, 'a visitor cannot read the log');
select throws_ok($$ select * from public.idea_merge_votes $$, '42501', null, 'a visitor cannot read the votes in the log');
reset role;

select * from finish();
rollback;
