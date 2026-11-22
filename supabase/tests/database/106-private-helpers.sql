begin;
select plan(11);

-- 20261122000500: the helpers that answer "am I blocked?" and the fold functions live in
-- `private`, which PostgREST does not expose; search_pros caps its query.
delete from public.pro_profiles;

do $$
declare
  o uuid;
begin
  perform set_config('t.c', tests.create_account('213550001060', 'men', 'customer')::text, true);
  o := tests.create_account('213550001061', 'men', 'barber');
  perform set_config('t.o', o::text, true);
  perform set_config('t.p', tests.create_pro(o, 'barber', 'Amine Coupe')::text, true);
end;
$$;

-- H1 ------------------------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('viewer_blocked', 'live_topic_allowed', 'f_search_fold', 'f_name_skeleton',
                      'search_args_check')),
  0, 'H1 no block, fold or argument helper is left in public (none is an RPC)');
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'private'::regnamespace
      and proname in ('viewer_blocked', 'live_topic_allowed', 'f_search_fold', 'f_name_skeleton',
                      'search_args_check')
      and proconfig @> array['search_path=""']
      and not has_function_privilege('anon', oid, 'execute')
      and not has_function_privilege('public', oid, 'execute')
      and has_function_privilege('authenticated', oid, 'execute')),
  5, 'H1 the five helpers are in private, search_path = '''', executable by authenticated only');
select ok(
  has_schema_privilege('authenticated', 'private', 'usage')
  and not has_schema_privilege('anon', 'private', 'usage')
  and not has_schema_privilege('public', 'private', 'usage')
  and not has_schema_privilege('authenticated', 'private', 'create'),
  'H1 private: usage for authenticated only, create for nobody');
select ok(
  (select pg_get_expr(polqual, polrelid) ~ 'private\.viewer_blocked\('
     from pg_policy where polname = 'pro_places_select' and polrelid = 'public.pro_places'::regclass)
  and (select pg_get_expr(polqual, polrelid) ~ 'private\.live_topic_allowed\('
         from pg_policy where polname = 'live_topics' and polrelid = 'realtime.messages'::regclass),
  'H1 the pro_places and realtime.messages policies call the private helpers');

-- H2: the generated search columns still compute when an authenticated owner renames the pro.
do $$ begin perform tests.authenticate_as(current_setting('t.o')::uuid); end; $$;
select lives_ok(
  format($$ update public.pro_profiles set display_name = 'Yacine Coupe' where id = %L $$,
         current_setting('t.p')),
  'H2 an owner renames the pro as authenticated');
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select search_key || '|' || search_skeleton from public.pro_profiles
    where id = current_setting('t.p')::uuid),
  'yacine coupe|ysnkp ', 'H2 the generated keys follow the new name');

-- H3: the invoker search folds the query as the caller, and the query is capped.
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is(
  (select array_agg(display_name) from public.search_pros(p_query => 'yassine')),
  array['Yacine Coupe'], 'H3 a customer search folds and matches as authenticated');
select lives_ok(
  format($$ select * from public.search_pros(p_query => %L) $$, repeat('a', 100)),
  'H3 a 100-character query is accepted');
select throws_ok(
  format($$ select * from public.search_pros(p_query => %L) $$, repeat('a', 101)),
  'P0001', 'query_invalid', 'H3 a 101-character query is query_invalid');
select throws_ok(
  format($$ select * from public.search_pros(p_query => %L, p_bbox => array[3.0, 36.7, 3.2, 36.8]) $$,
         repeat('ب', 101)),
  'P0001', 'query_invalid', 'H3 the cap counts characters and holds on the map too');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok($$ select private.f_search_fold('x') $$, '42501', null,
  'H1 anon cannot reach the private schema');
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
