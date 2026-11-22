begin;
select plan(12);

-- Search results are compared whole, so pros left in the local database must not count.
delete from public.pro_profiles;

-- Fixture (men space, all published):
--   'أحمد'  'Amine'  'أمين' (verified, so a plain verified-first order would put it before Amine)
--   'علي'   'Salon Test'
do $$
declare
  o uuid;
  pid uuid;
  names text[] := array['أحمد', 'Amine', 'أمين', 'علي', 'Salon Test'];
  i int;
begin
  perform set_config('t.cm', tests.create_account('213550000690', 'men', 'customer')::text, true);
  for i in 1 .. array_length(names, 1) loop
    o := tests.create_account('21355000069' || i, 'men', 'barber');
    pid := tests.create_pro(o, 'barber', names[i]);
    if names[i] = 'أمين' then
      update public.pro_profiles set is_verified = true where id = pid;
    end if;
  end loop;
end;
$$;

-- F1 ----------------------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_proc
    where oid in ('private.f_search_fold(text)'::regprocedure, 'private.f_name_skeleton(text)'::regprocedure)
      and provolatile = 'i' and proconfig @> array['search_path=""']),
  2,
  'F1: f_search_fold and f_name_skeleton are immutable with search_path = '''''
);
select is(
  (select count(*)::int from pg_proc
    where oid in ('private.f_search_fold(text)'::regprocedure, 'private.f_name_skeleton(text)'::regprocedure)
      and (has_function_privilege('anon', oid, 'execute')
           or has_function_privilege('public', oid, 'execute'))),
  0,
  'F1: neither fold function is executable by anon or public'
);

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;

select is(
  (select private.f_search_fold('أُمِين') || '|' || private.f_name_skeleton('Amine')),
  'امين|amn',
  'F1: authenticated can call both fold functions'
);

-- F2 ----------------------------------------------------------------------------------------
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'احمد') $$,
  $$ values ('أحمد') $$,
  'F2: search_pros(احمد) finds أحمد'
);

-- F3 ----------------------------------------------------------------------------------------
select set_eq(
  $$ select display_name from public.search_pros(p_query => 'Amine') $$,
  $$ values ('Amine'), ('أمين') $$,
  'F3: Amine finds Amine and أمين'
);
select set_eq(
  $$ select display_name from public.search_pros(p_query => 'أمين') $$,
  $$ values ('Amine'), ('أمين') $$,
  'F3: أمين finds Amine and أمين'
);

-- F4 ----------------------------------------------------------------------------------------
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'amine') $$,
  $$ values ('Amine'), ('أمين') $$,
  'F4: the fold match ranks before the verified skeleton-only match'
);

-- F5 ----------------------------------------------------------------------------------------
select is_empty(
  $$ select display_name from public.search_pros(p_query => 'Ali') $$,
  'F5: a query whose skeleton has fewer than 3 letters never skeleton-matches (Ali, علي)'
);
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'Ahmed') $$,
  $$ values ('أحمد') $$,
  'F5: a 3-letter skeleton matches across scripts (Ahmed, أحمد)'
);

do $$ begin perform tests.clear_auth(); end; $$;

-- F6 ----------------------------------------------------------------------------------------
select ok(
  (select indexdef ~ 'USING gin \(search_key gin_trgm_ops\)'
     from pg_indexes where schemaname = 'public' and indexname = 'pro_profiles_search_key_trgm_idx'),
  'F6: GIN trigram index on search_key'
);
select ok(
  (select indexdef ~ 'USING gin \(search_skeleton gin_trgm_ops\)'
     from pg_indexes where schemaname = 'public' and indexname = 'pro_profiles_search_skeleton_trgm_idx'),
  'F6: GIN trigram index on search_skeleton'
);

-- F7 ----------------------------------------------------------------------------------------
do $$
declare
  n int;
begin
  delete from public.pro_profiles;
  for n in 1 .. 2000 loop
    perform tests.create_account('21356' || lpad(n::text, 7, '0'), 'men', 'barber');
  end loop;
  insert into public.pro_profiles (owner_id, kind, space, display_name, workplace_type, locality_id)
  select p.id, 'barber', 'men',
         case when row_number() over () % 400 = 0 then 'Amine Barber ' else 'Pro ' end
           || md5(p.id::text),
         'salon', 1601
  from public.profiles p
  where p.id in (select id from auth.users where phone like '21356%');
end;
$$;
analyze public.pro_profiles;

-- Rolled back with the test.
create function tests.explain_text(p_sql text) returns text language plpgsql as $$
declare v_plan json;
begin
  execute 'explain (format json) ' || p_sql into v_plan;
  return v_plan::text;
end;
$$;

-- The name branches of search_pros (its `matched` CTE) with a query of Amine: one index-backed
-- id set per key. 2,000 rows fit in a few dozen pages, where a sequential scan is cheaper than
-- any index, so the test asks only whether the planner can answer the real predicates from the
-- trigram indexes.
set local enable_seqscan = off;
select ok(
  (select tests.explain_text($$
     with qp as (select '%' || private.f_search_fold('Amine') || '%' as pattern,
                        '%' || private.f_name_skeleton('Amine') || '%' as skel_pattern)
     select p.id from qp, public.pro_profiles p where p.search_key like qp.pattern
     union all
     select p.id from qp, public.pro_profiles p where p.search_skeleton like qp.skel_pattern
   $$) ~ 'pro_profiles_search_key_trgm_idx.*pro_profiles_search_skeleton_trgm_idx'),
  'F7: the name branches of search_pros on 2,000 pros use both trigram indexes'
);

select * from finish();
rollback;
