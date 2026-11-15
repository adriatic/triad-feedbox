-- Structure: RLS on every table, safe functions, exact privileges, no emails.
begin;
\ir _helpers.psql
select no_plan();

select tables_are('public',
  array['boards', 'profiles', 'board_owners', 'ideas', 'votes', 'comments', 'changelog_entries', 'changelog_items'],
  'Feedbox has exactly these eight tables');

select ok(c.relrowsecurity, 'row-level security is enabled on ' || c.relname)
from pg_class c
where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
order by c.relname;

select is(array_to_string(p.proconfig, ','), 'search_path=""',
          'security definer function ' || n.nspname || '.' || p.proname || ' sets search_path to empty')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private') and p.prosecdef
order by n.nspname, p.proname;

select is(array_to_string(p.proconfig, ','), 'search_path=""',
          'function ' || n.nspname || '.' || p.proname || ' sets search_path to empty')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private') and not p.prosecdef
order by n.nspname, p.proname;

-- Table privileges left to anon and authenticated: exactly F1 section 3.
select results_eq(
  $$ select grantee::text collate "default", table_name::text collate "default", string_agg(privilege_type::text, ',' order by privilege_type::text) collate "default"
     from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('anon', 'authenticated')
     group by 1, 2 order by 2, 1 $$,
  $$ values
       ('authenticated', 'board_owners', 'SELECT'),
       ('anon', 'boards', 'SELECT'),
       ('authenticated', 'boards', 'SELECT'),
       ('anon', 'changelog_entries', 'SELECT'),
       ('authenticated', 'changelog_entries', 'DELETE,SELECT'),
       ('anon', 'changelog_items', 'SELECT'),
       ('authenticated', 'changelog_items', 'DELETE,SELECT'),
       ('anon', 'comments', 'SELECT'),
       ('authenticated', 'comments', 'SELECT'),
       ('anon', 'ideas', 'SELECT'),
       ('authenticated', 'ideas', 'SELECT'),
       ('anon', 'profiles', 'SELECT'),
       ('authenticated', 'profiles', 'SELECT'),
       ('authenticated', 'votes', 'DELETE,SELECT') $$,
  'anon and authenticated hold exactly the table privileges of F1 section 3');

select results_eq(
  $$ select grantee::text collate "default", table_name::text collate "default", privilege_type::text collate "default", string_agg(column_name::text, ',' order by column_name::text) collate "default"
     from information_schema.column_privileges
     where table_schema = 'public' and grantee in ('anon', 'authenticated') and privilege_type <> 'SELECT'
     group by 1, 2, 3 order by 2, 3, 1 $$,
  $$ values
       ('authenticated', 'changelog_entries', 'INSERT', 'board_id,released_on,title'),
       ('authenticated', 'changelog_entries', 'UPDATE', 'released_on,title'),
       ('authenticated', 'changelog_items', 'INSERT', 'entry_id,idea_id,note,position'),
       ('authenticated', 'changelog_items', 'UPDATE', 'note,position'),
       ('authenticated', 'comments', 'INSERT', 'body,idea_id'),
       ('authenticated', 'ideas', 'INSERT', 'board_id,body,title'),
       ('authenticated', 'profiles', 'UPDATE', 'display_name'),
       ('authenticated', 'votes', 'INSERT', 'idea_id') $$,
  'writes are granted column by column, and only these columns');

select ok(not has_sequence_privilege(r, s, p), r || ' has no ' || p || ' on ' || s)
from unnest(array['anon', 'authenticated']) r,
     unnest(array['public.ideas_id_seq', 'public.comments_id_seq']) s,
     unnest(array['USAGE', 'SELECT', 'UPDATE']) p;

-- Functions: what each role may call.
select results_eq(
  $$ select r, p.proname::text collate "default", has_function_privilege(r, p.oid, 'EXECUTE')
     from pg_proc p, unnest(array['anon', 'authenticated']) r
     where p.pronamespace = 'public'::regnamespace
     order by 2, 1 $$,
  $$ values
       ('anon', 'has_display_name', true),           ('authenticated', 'has_display_name', true),
       ('anon', 'hide_comment', false),              ('authenticated', 'hide_comment', true),
       ('anon', 'hide_idea', false),                 ('authenticated', 'hide_idea', true),
       ('anon', 'is_board_owner', true),             ('authenticated', 'is_board_owner', true),
       ('anon', 'merge_ideas', false),               ('authenticated', 'merge_ideas', true),
       ('anon', 'publish_changelog_entry', false),   ('authenticated', 'publish_changelog_entry', true),
       ('anon', 'set_idea_status', false),           ('authenticated', 'set_idea_status', true),
       ('anon', 'similar_ideas', true),              ('authenticated', 'similar_ideas', true),
       ('anon', 'unhide_comment', false),            ('authenticated', 'unhide_comment', true),
       ('anon', 'unhide_idea', false),               ('authenticated', 'unhide_idea', true) $$,
  'anon may call only the read helpers; owner functions need a signed-in person (and then check ownership)');

select ok(not has_schema_privilege('anon', 'private', 'USAGE'), 'anon cannot use the private schema');
select results_eq(
  $$ select p.proname::text collate "default" from pg_proc p
     where p.pronamespace = 'private'::regnamespace and has_function_privilege('authenticated', p.oid, 'EXECUTE')
     order by 1 $$,
  $$ values ('recent_count') $$,
  'authenticated may call only private.recent_count (needed by the rate-limit trigger); the schema is not exposed by the API');

-- Email addresses are never readable.
select hasnt_column('public', 'profiles', 'email', 'profiles has no email column');
select is_empty(
  $$ select table_name, column_name from information_schema.columns
     where table_schema = 'public' and column_name ilike '%mail%' $$,
  'no Feedbox table has an email column');

select tests.person('sam', 'Sam');

select tests.as_visitor();
select throws_ok($$ select email from auth.users $$, '42501', null, 'a visitor cannot read email addresses');
reset role;

select tests.as_person('sam');
select throws_ok($$ select email from auth.users $$, '42501', null, 'a signed-in person cannot read email addresses, not even their own');
reset role;

select * from finish();
rollback;
