-- Comments (F1 sections 3 and 7): plain, flat, owner can hide.
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.person('ana', 'Ana');
select tests.person('sam', 'Sam');
select tests.person('nel');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana'));
select tests.idea('b1', 'ana', 'Idea with comments');
select tests.idea('b1', 'ana', 'Hidden idea');
select tests.idea('b1', 'ana', 'Merged idea');
update public.ideas set hidden_at = now() where title = 'Hidden idea';
update public.ideas set merged_into_id = tests.idea_id('Idea with comments') where title = 'Merged idea';
insert into public.comments (idea_id, author_id, body) values (tests.idea_id('Hidden idea'), tests.id('ana'), 'On a hidden idea');

-- Writing
select tests.as_person('sam');
select lives_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Idea with comments'), 'Yes please.') $$,
  'a signed-in person with a display name comments');
select throws_ok($$ insert into public.comments (idea_id, author_id, body) values (tests.idea_id('Idea with comments'), tests.id('ana'), 'As Ana') $$, '42501',
  'permission denied for table comments', 'nobody comments in someone else''s name');
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Idea with comments'), '   ') $$, '23514',
  null, 'an empty comment is refused');
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Idea with comments'), repeat('c', 2001)) $$, '23514',
  null, 'a comment has at most 2,000 characters');
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Hidden idea'), 'Hello') $$, '42501',
  'new row violates row-level security policy for table "comments"', 'nobody comments on a hidden idea');
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Merged idea'), 'Hello') $$, '42501',
  'new row violates row-level security policy for table "comments"', 'nobody comments on a merged idea');
select throws_ok($$ update public.comments set body = 'Edited' $$, '42501',
  'permission denied for table comments', 'comments are not edited in version 1');
select throws_ok($$ update public.comments set hidden_at = now() $$, '42501',
  'permission denied for table comments', 'nobody writes hidden_at on a comment directly');
select throws_ok($$ delete from public.comments $$, '42501',
  'permission denied for table comments', 'comments are not deleted');
reset role;
select results_eq($$ select c.author_id, i.comment_count from public.comments c join public.ideas i on i.id = c.idea_id where i.title = 'Idea with comments' $$,
  $$ values (tests.id('sam'), 1) $$, 'the comment is by its writer and the idea''s comment count is 1');

select tests.as_person('nel');
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Idea with comments'), 'Hi') $$, '42501',
  'new row violates row-level security policy for table "comments"', 'a person without a display name cannot comment');
reset role;
select tests.as_visitor();
select throws_ok($$ insert into public.comments (idea_id, body) values (tests.idea_id('Idea with comments'), 'Hi') $$, '42501',
  'permission denied for table comments', 'a visitor cannot comment');
select results_eq($$ select c.body from public.comments c join public.ideas i on i.id = c.idea_id where i.board_id = tests.board_id('b1') $$,
  $$ values ('Yes please.') $$, 'a visitor reads comments, but not those on a hidden idea');
reset role;

-- Hiding a comment (owner only)
select tests.as_person('sam');
select throws_ok($$ select public.hide_comment((select id from public.comments where body = 'Yes please.')) $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot hide a comment');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.hide_comment(1) $$, '42501',
  'permission denied for function hide_comment', 'a visitor cannot call hide_comment');
reset role;

select tests.as_person('ana');
select lives_ok($$ select public.hide_comment((select id from public.comments where body = 'Yes please.')) $$,
  'the owner hides a comment');
select results_eq($$ select count(*)::int from public.comments where body = 'Yes please.' $$, $$ values (1) $$,
  'the owner still sees the hidden comment');
reset role;
select results_eq($$ select comment_count from public.ideas where id = tests.idea_id('Idea with comments') $$,
  $$ values (0) $$, 'a hidden comment is not counted');
select tests.as_person('sam');
select results_eq($$ select count(*)::int from public.comments where body = 'Yes please.' $$, $$ values (0) $$,
  'a hidden comment is invisible to others, including its writer');
reset role;

select tests.as_person('ana');
select lives_ok($$ select public.unhide_comment((select id from public.comments where body = 'Yes please.')) $$,
  'the owner unhides the comment');
reset role;
select results_eq($$ select comment_count from public.ideas where id = tests.idea_id('Idea with comments') $$,
  $$ values (1) $$, 'an unhidden comment is counted again');
select tests.as_visitor();
select results_eq($$ select count(*)::int from public.comments where body = 'Yes please.' $$, $$ values (1) $$,
  'an unhidden comment is visible again');
reset role;

select * from finish();
rollback;
