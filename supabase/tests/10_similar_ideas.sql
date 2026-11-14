-- Similar ideas while typing a title, and the search box (F1 section 5).
begin;
\ir _helpers.psql
select no_plan();

select tests.board('b1');
select tests.board('b2');
select tests.person('ana', 'Ana');
select tests.idea('b1', 'ana', 'Sync between two laptops');
select tests.idea('b1', 'ana', 'Offline mode');
select tests.idea('b1', 'ana', 'Export notes to Markdown');
select tests.idea('b1', 'ana', 'Search inside attachments');
select tests.idea('b1', 'ana', 'Tag notes by colour');
select tests.idea('b1', 'ana', 'Sync settings secretly');
select tests.idea('b1', 'ana', 'Synced folders merged');
select tests.idea('b2', 'ana', 'Sync on another board');
update public.ideas set body = 'Find words inside attached PDFs, not only in the note text.' where title = 'Search inside attachments';
update public.ideas set hidden_at = now() where title = 'Sync settings secretly';
update public.ideas set merged_into_id = tests.idea_id('Sync between two laptops') where title = 'Synced folders merged';

select tests.as_visitor();
select ok(
  'Sync between two laptops' in (select title from public.similar_ideas(tests.board_id('b1'), 'Sync notes')),
  'typing "Sync notes" suggests "Sync between two laptops" (as in design screen 3)');
select results_eq(
  $$ select title from public.similar_ideas(tests.board_id('b1'), 'sync laptops') limit 1 $$,
  $$ values ('Sync between two laptops') $$,
  'the closest title comes first');
select ok(
  'Export notes to Markdown' in (select title from public.similar_ideas(tests.board_id('b1'), 'Sync notes')),
  'a shared word ("notes") is enough to be listed');
select results_eq(
  $$ select title from public.similar_ideas(tests.board_id('b1'), 'synch') limit 1 $$,
  $$ values ('Sync between two laptops') $$,
  'a typo ("synch") still finds it');
select is_empty($$ select * from public.similar_ideas(tests.board_id('b1'), 'Sy') $$,
  'fewer than 3 characters return nothing');
select is_empty($$ select * from public.similar_ideas(tests.board_id('b1'), 'zebra crossing') $$,
  'unrelated words return nothing');
select ok(
  not exists (select 1 from public.similar_ideas(tests.board_id('b1'), 'sync settings secretly') where title = 'Sync settings secretly'),
  'hidden ideas are never suggested');
select ok(
  not exists (select 1 from public.similar_ideas(tests.board_id('b1'), 'synced folders merged') where title = 'Synced folders merged'),
  'merged ideas are never suggested');
select ok(
  not exists (select 1 from public.similar_ideas(tests.board_id('b1'), 'sync on another board') where title = 'Sync on another board'),
  'ideas from another board are never suggested');
select is((select count(*)::int from public.similar_ideas(tests.board_id('b1'), 'notes', 1)), 1,
  'the limit is respected');
select is_empty($$ select * from public.similar_ideas(tests.board_id('b1'), 'pdfs') $$,
  'by default only titles are matched');
select results_eq(
  $$ select title from public.similar_ideas(tests.board_id('b1'), 'pdfs', 5, true) $$,
  $$ values ('Search inside attachments') $$,
  'the search box can also match the details');
reset role;

select * from finish();
rollback;
