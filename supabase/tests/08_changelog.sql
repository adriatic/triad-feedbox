-- Changelog (F1 section 8, F2-D2).
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');
select tests.person('bo', 'Bo');
select tests.person('sam', 'Sam');
insert into public.board_owners (board_id, user_id) values (tests.board_id('b1'), tests.id('ana')), (tests.board_id('b2'), tests.id('bo'));
select tests.idea('b1', 'sam', 'Keyboard shortcut cheat sheet', 'shipped');
select tests.idea('b1', 'sam', 'Faster startup', 'shipped');
select tests.idea('b1', 'sam', 'Dark mode for the editor', 'planned');
select tests.idea('b1', 'sam', 'Synch shortcuts', 'shipped');
select tests.idea('b2', 'bo', 'Elsewhere', 'shipped');

-- Entries
select tests.as_person('sam');
select throws_ok($$ insert into public.changelog_entries (board_id, title, released_on) values (tests.board_id('b1'), 'Release 2.4', '2026-11-03') $$, '42501',
  'new row violates row-level security policy for table "changelog_entries"', 'someone who is not an owner cannot write the changelog');
reset role;
select tests.as_person('bo');
select throws_ok($$ insert into public.changelog_entries (board_id, title, released_on) values (tests.board_id('b1'), 'Release 2.4', '2026-11-03') $$, '42501',
  'new row violates row-level security policy for table "changelog_entries"', 'the owner of another board cannot write this board''s changelog');
reset role;
select tests.as_visitor();
select throws_ok($$ insert into public.changelog_entries (board_id, title, released_on) values (tests.board_id('b1'), 'Release 2.4', '2026-11-03') $$, '42501',
  'permission denied for table changelog_entries', 'a visitor cannot write the changelog');
reset role;

select tests.as_person('ana');
select lives_ok($$ insert into public.changelog_entries (board_id, title, released_on) values (tests.board_id('b1'), 'Release 2.4', '2026-11-03') $$,
  'the owner creates a changelog entry (a draft)');
select throws_ok($$ insert into public.changelog_entries (board_id, title, released_on) values (tests.board_id('b1'), repeat('v', 81), '2026-11-03') $$, '23514',
  null, 'an entry title has at most 80 characters (F2-D2)');
select lives_ok($$ insert into public.changelog_entries (board_id, title, released_on) values (tests.board_id('b1'), repeat('v', 80), '2026-11-04') $$,
  'an entry title of exactly 80 characters is accepted');
select throws_ok($$ update public.changelog_entries set published_at = now() $$, '42501',
  'permission denied for table changelog_entries', 'nobody publishes by writing published_at directly');
select results_eq($$ select count(*)::int from public.changelog_entries where board_id = tests.board_id('b1') $$, $$ values (2) $$,
  'the owner sees drafts');
reset role;

select tests.as_visitor();
select is_empty($$ select 1 from public.changelog_entries where board_id = tests.board_id('b1') $$, 'a visitor does not see drafts');
reset role;
select tests.as_person('sam');
select is_empty($$ select 1 from public.changelog_entries where board_id = tests.board_id('b1') $$, 'a signed-in person does not see drafts');
reset role;

-- Lines
select tests.as_person('sam');
select throws_ok($$ insert into public.changelog_items (entry_id, idea_id, note) values (tests.entry_id('Release 2.4'), tests.idea_id('Faster startup'), 'x') $$, '42501',
  'new row violates row-level security policy for table "changelog_items"', 'someone who is not an owner cannot add a line');
reset role;

select tests.as_person('ana');
select lives_ok($$ insert into public.changelog_items (entry_id, idea_id, note, position) values (tests.entry_id('Release 2.4'), tests.idea_id('Keyboard shortcut cheat sheet'), 'Press ? anywhere to see every shortcut on one page, grouped by task.', 1) $$,
  'the owner adds a line for a Shipped idea');
select throws_ok($$ insert into public.changelog_items (entry_id, idea_id, note) values (tests.entry_id('Release 2.4'), tests.idea_id('Faster startup'), repeat('n', 281)) $$, '23514',
  null, 'a line has at most 280 characters (F2-D2)');
select lives_ok($$ insert into public.changelog_items (entry_id, idea_id, note, position) values (tests.entry_id('Release 2.4'), tests.idea_id('Faster startup'), repeat('n', 280), 2) $$,
  'a line of exactly 280 characters is accepted');
select throws_ok($$ insert into public.changelog_items (entry_id, idea_id, note) values (tests.entry_id('Release 2.4'), tests.idea_id('Dark mode for the editor'), 'Soon.') $$, '23514',
  '"Dark mode for the editor" is not Shipped yet.', 'an idea that is not Shipped cannot be in the changelog');
select throws_ok($$ insert into public.changelog_items (entry_id, idea_id, note) values (tests.entry_id('Release 2.4'), tests.idea_id('Elsewhere'), 'x') $$, '23514',
  'Every idea in a changelog entry must be on the same board.', 'an idea from another board cannot be in this changelog');
select throws_ok($$ insert into public.changelog_items (entry_id, idea_id, note) values (tests.entry_id(repeat('v', 80)), tests.idea_id('Keyboard shortcut cheat sheet'), 'Again.') $$, '23505',
  null, 'an idea appears in at most one changelog entry');

-- Publishing
select throws_ok($$ select public.publish_changelog_entry(tests.entry_id(repeat('v', 80))) $$, '23514',
  'Pick at least one shipped idea.', 'an entry with no lines cannot be published');
reset role;
select tests.as_person('sam');
select throws_ok($$ select public.publish_changelog_entry(tests.entry_id('Release 2.4')) $$, '42501',
  'Only an owner of this board can do this.', 'someone who is not an owner cannot publish');
reset role;
select tests.as_person('bo');
select throws_ok($$ select public.publish_changelog_entry(tests.entry_id('Release 2.4')) $$, '42501',
  'Only an owner of this board can do this.', 'the owner of another board cannot publish this entry');
reset role;
select tests.as_visitor();
select throws_ok($$ select public.publish_changelog_entry(gen_random_uuid()) $$, '42501',
  'permission denied for function publish_changelog_entry', 'a visitor cannot call publish_changelog_entry');
reset role;

select tests.as_person('ana');
select lives_ok($$ select public.publish_changelog_entry(tests.entry_id('Release 2.4')) $$,
  'the owner publishes the entry');
reset role;
select tests.as_visitor();
select results_eq($$ select e.title, count(ci.idea_id)::int from public.changelog_entries e join public.changelog_items ci on ci.entry_id = e.id where e.board_id = tests.board_id('b1') group by e.title $$,
  $$ values ('Release 2.4', 2) $$, 'a visitor sees the published entry and its lines');
reset role;

-- F2-D2: an idea in a changelog entry stays Shipped
select tests.as_person('ana');
select throws_ok($$ select public.set_idea_status(tests.idea_id('Keyboard shortcut cheat sheet'), 'building') $$, '23514',
  'This idea is in a changelog entry, so it stays Shipped. Remove it from the entry first.', 'an idea in a changelog entry stays Shipped');
select throws_ok($$ select public.merge_ideas(tests.idea_id('Keyboard shortcut cheat sheet'), tests.idea_id('Synch shortcuts')) $$, '23514',
  'This idea is in a changelog entry. Remove it from the entry first.', 'an idea in a changelog entry cannot be merged away');
reset role;
select throws_ok($$ update public.ideas set status = 'building' where id = tests.idea_id('Keyboard shortcut cheat sheet') $$, '23514',
  'This idea is in a changelog entry, so it stays Shipped. Remove it from the entry first.', 'the rule holds even for a direct SQL update by the database owner');

select tests.as_person('ana');
select lives_ok($$ delete from public.changelog_items where idea_id = tests.idea_id('Keyboard shortcut cheat sheet') $$,
  'the owner removes the line from the entry');
select lives_ok($$ select public.set_idea_status(tests.idea_id('Keyboard shortcut cheat sheet'), 'building') $$,
  'after that, the idea may leave Shipped');
select lives_ok($$ select public.publish_changelog_entry(tests.entry_id('Release 2.4'), false) $$,
  'the owner unpublishes the entry');
reset role;
select tests.as_visitor();
select is_empty($$ select 1 from public.changelog_entries where board_id = tests.board_id('b1') $$, 'an unpublished entry is hidden again');
reset role;

select * from finish();
rollback;
