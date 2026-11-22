begin;
select plan(40);

-- Results are compared whole, so pros left in the local database must not count; rolled back.
delete from public.pro_profiles;

-- Latitude of the point p_m metres due south of O (north when negative).
create function tests.south_of_alger(p_m double precision)
returns double precision
language sql
as $$
  select extensions.st_y(extensions.st_project(
    extensions.st_point(3.0909, 36.76846, 4326)::extensions.geography, abs(p_m),
    case when p_m < 0 then 0 else pi() end)::extensions.geometry);
$$;
grant execute on function tests.south_of_alger(double precision) to authenticated;

-- Origin O = the Alger Centre (1601) commune centre (36.76846, 3.0909). Men pros, metres due south
-- of O unless said otherwise (fixtures written as postgres):
--   pz 'Zone Commune'  none, 1601 (its point is O itself)
--   pa 'Amine Coupe'   exact    740
--   pb 'أمين'          area   1 260 (radius 1 000)
--   pl 'Bilal Studio'  exact  2 000, has blocked customer d
--   pm 'Mobile Karim'  exact  3 000, mobile, service radius 5 km
--   pn 'Mobile Nabil'  exact  4 000, mobile, service radius 1 km
--   pv 'Salon Amine'   exact  5 000, verified (first in the old order)
--   pc 'Chebli Coupe'  none, Chebli (902), 23.6 km away
--   px 'No Place'      null search_point (as a commune without coordinates would give),
--                      published an hour earlier
--   pw 'Wafa Beauty'   women space, exact 500 (inside every bbox below)
do $$
declare
  v_owner uuid;
  v_pro uuid;
  r record;
begin
  perform set_config('t.c', tests.create_account('213550002000', 'men', 'customer', 'Chafik')::text, true);
  perform set_config('t.d', tests.create_account('213550002001', 'men', 'customer', 'Djamel')::text, true);
  for r in
    select * from (values
      ('pz', '213550002010', 'men',   'Zone Commune',  1601, 'none',  null::int, 'salon'),
      ('pa', '213550002011', 'men',   'Amine Coupe',   1601, 'exact', 740,       'salon'),
      ('pb', '213550002012', 'men',   'أمين',          1601, 'area',  1260,      'salon'),
      ('pl', '213550002013', 'men',   'Bilal Studio',  1601, 'exact', 2000,      'salon'),
      ('pm', '213550002014', 'men',   'Mobile Karim',  1601, 'exact', 3000,      'mobile'),
      ('pn', '213550002015', 'men',   'Mobile Nabil',  1601, 'exact', 4000,      'mobile'),
      ('pv', '213550002016', 'men',   'Salon Amine',   1601, 'exact', 5000,      'salon'),
      ('pc', '213550002017', 'men',   'Chebli Coupe',  902,  'none',  null,      'salon'),
      ('px', '213550002018', 'men',   'No Place',      1601, 'none',  null,      'salon'),
      ('pw', '213550002019', 'women', 'Wafa Beauty',   1601, 'exact', 500,       'salon')
    ) as v(key, phone, space, name, locality, mode, south_m, workplace)
  loop
    v_owner := tests.create_account(r.phone, r.space, 'barber');
    v_pro := tests.create_pro(v_owner, 'barber', r.name, r.locality);
    if r.mode <> 'none' then
      perform tests.set_place(v_pro, r.mode, tests.south_of_alger(r.south_m::double precision), 3.0909,
                              case when r.mode = 'area' then 1000 end);
    end if;
    if r.workplace = 'mobile' then
      update public.pro_profiles
         set workplace_type = 'mobile', workplace_name = null,
             service_radius_km = case r.key when 'pm' then 5 else 1 end
       where id = v_pro;
    end if;
    perform set_config('t.' || r.key, v_pro::text, true);
  end loop;
  update public.pro_profiles set is_verified = true where id = current_setting('t.pv')::uuid;
  update public.pro_profiles set published_at = now() - interval '1 hour'
   where id = current_setting('t.px')::uuid;
  update public.pro_places set search_point = null where pro_id = current_setting('t.px')::uuid;
end;
$$;
insert into public.pro_blocks (pro_id, customer_id)
values (current_setting('t.pl')::uuid, current_setting('t.d')::uuid);

-- Names of a search, in result order.
create function tests.near_names(p_sql text)
returns text[]
language plpgsql
as $$
declare v text[];
begin
  execute format('select array_agg(s.display_name order by s.ord) from (%s) s', p_sql) into v;
  return v;
end;
$$;
grant execute on function tests.near_names(text) to authenticated;

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;

-- N1 ------------------------------------------------------------------------------------------

select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909) with ordinality $$),
  array['Zone Commune', 'Amine Coupe', 'أمين', 'Bilal Studio', 'Mobile Karim', 'Mobile Nabil',
        'Salon Amine', 'Chebli Coupe', 'No Place'],
  'N1 with an origin and no query, pros come nearest first and a null point last'
);
select isnt(
  (select display_name from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909) limit 1),
  'Salon Amine',
  'N1 the verified pro is no longer first'
);
select is(
  (select display_name from public.search_pros() limit 1),
  'Salon Amine',
  'N1 without an origin the old order holds (verified first)'
);
select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909,
                                              p_limit => 3, p_offset => 2) with ordinality $$),
  array['أمين', 'Bilal Studio', 'Mobile Karim'],
  'N1 limit and offset page through the distance order'
);

-- N2 ------------------------------------------------------------------------------------------

select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_query => 'Amine',
                                              p_origin_lat => 36.76846, p_origin_lng => 3.0909) with ordinality $$),
  array['Amine Coupe', 'Salon Amine', 'أمين'],
  'N2 a query orders by match tier, then distance (the nearer skeleton match comes last)'
);
select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_query => 'Amine') with ordinality $$),
  array['Salon Amine', 'Amine Coupe', 'أمين'],
  'N2 the same query without an origin keeps tier, then verified'
);

-- N3 ------------------------------------------------------------------------------------------

select is(
  (select distance_m from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pa')::uuid),
  700, 'N3 740 m is shown as 700 m');
select is(
  (select distance_m from public.search_pros(p_origin_lat => tests.south_of_alger(20), p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pa')::uuid),
  700, 'N3 720 m is shown as 700 m');
select is(
  (select distance_m from public.search_pros(p_origin_lat => tests.south_of_alger(-20), p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pa')::uuid),
  800, 'N3 760 m is shown as 800 m');
select is(
  (select distance_m from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pb')::uuid),
  1500, 'N3 1.26 km is shown as 1 500 m');
select is(
  (select distance_m from public.search_pros(p_origin_lat => tests.south_of_alger(-1000), p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pb')::uuid),
  2500, 'N3 2.26 km is shown as 2 500 m');
select is(
  (select distance_m from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pc')::uuid),
  24000, 'N3 a none pro 23.6 km away is shown in whole km');
select is(
  (select distance_m from public.search_pros(p_origin_lat => tests.south_of_alger(-1300), p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pz')::uuid),
  1000, 'N3 a none pro 1.3 km away is shown as 1 km, not 1 500 m');
select is(
  (select distance_m from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pz')::uuid),
  1000, 'N3 a none pro at the origin is shown as 1 km (never 0)');
select is(
  (select distance_m from public.search_pros(p_origin_lat => tests.south_of_alger(730), p_origin_lng => 3.0909)
    where pro_id = current_setting('t.pa')::uuid),
  100, 'N3 10 m is shown as 100 m (never 0)');
select is(
  (select count(*)::int from public.search_pros() where distance_m is not null),
  0, 'N3 no distance without an origin');

-- N4 ------------------------------------------------------------------------------------------

-- The bbox holds everything within ~3.1 km south of O; its centre is (36.77, 3.1). The origin is
-- Chebli, to the south, so origin order would be the reverse of the centre order.
select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_bbox => array[3.0, 36.74, 3.2, 36.80],
                                              p_origin_lat => 36.58, p_origin_lng => 3.0) with ordinality $$),
  array['Zone Commune', 'Amine Coupe', 'أمين', 'Bilal Studio', 'Mobile Karim'],
  'N4 a bbox returns only the points inside, in this space, nearest the bbox centre first'
);
select is(
  (select count(*)::int from public.search_pros(p_bbox => array[3.0, 36.74, 3.2, 36.80],
                                                p_limit => 1, p_offset => 3)),
  5, 'N4 a bbox ignores p_limit and p_offset');
select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_query => 'amine', p_bbox => array[3.0, 36.74, 3.2, 36.80]) with ordinality $$),
  array['Amine Coupe', 'أمين'],
  'N4 a bbox keeps the text filter'
);
select throws_ok(
  $$ select * from public.search_pros(p_bbox => array[3.0, 36.74, 3.2]) $$,
  'P0001', 'bbox_invalid', 'N4 a bbox of 3 values is bbox_invalid');
select throws_ok(
  $$ select * from public.search_pros(p_bbox => array[0.0, 30.0, 8.5, 31.0]) $$,
  'P0001', 'bbox_invalid', 'N4 a bbox side over 8 degrees is bbox_invalid');
select throws_ok(
  $$ select * from public.search_pros(p_bbox => array[3.2, 36.74, 3.0, 36.80]) $$,
  'P0001', 'bbox_invalid', 'N4 a bbox with min >= max is bbox_invalid');
select throws_ok(
  $$ select * from public.search_pros(p_bbox => array[3.0, null, 3.2, 36.80]) $$,
  'P0001', 'bbox_invalid', 'N4 a bbox with a null value is bbox_invalid');
select throws_ok(
  $$ select * from public.search_pros(p_origin_lat => 36.76846) $$,
  'P0001', 'origin_invalid', 'N4 an origin with one coordinate is origin_invalid');
select throws_ok(
  $$ select * from public.search_pros(p_origin_lat => 95, p_origin_lng => 3.0) $$,
  'P0001', 'origin_invalid', 'N4 an origin out of range is origin_invalid');
select throws_ok(
  $$ select * from public.search_pros(p_origin_lng => 3.0, p_limit => 0) $$,
  'P0001', 'origin_invalid', 'N4 the origin is checked even for an empty page');

-- N5 ------------------------------------------------------------------------------------------

select results_eq(
  $$ select place_mode::text, lat, lng, locality_id
       from public.search_pros(p_bbox => array[3.0, 36.74, 3.2, 36.80])
      where display_name = 'Zone Commune' $$,
  $$ values ('none'::text, null::double precision, null::double precision, 1601) $$,
  'N5 a none row in a bbox has null lat/lng and its commune'
);
select results_eq(
  $$ select place_mode::text, round(lat::numeric, 5), round(lng::numeric, 4), area_radius_m::int,
            locality_id
       from public.search_pros(p_bbox => array[3.0, 36.74, 3.2, 36.80])
      where display_name = 'أمين' $$,
  format($$ values ('area'::text, %s::numeric, 3.0909::numeric, 1000, 1601) $$,
         round(tests.south_of_alger(1260)::numeric, 5)),
  'N5 an area row has its circle centre and radius'
);

do $$ begin perform tests.clear_auth(); end; $$;

-- N6 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.d')::uuid); end; $$;
do $$
begin
  perform set_config('t.blocked_live',
    (select s.live::text from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909) s
      where s.pro_id = current_setting('t.pl')::uuid), true);
end;
$$;
select results_eq(
  $$ select lat, lng, distance_m, place_mode::text, comes_to_you
       from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
      where display_name = 'Bilal Studio' $$,
  $$ values (null::double precision, null::double precision, null::int, null::text, false) $$,
  'N6 a blocked customer gets the row with no place and no distance'
);
select is(
  (select distance_m from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
    where display_name = 'Amine Coupe'),
  700, 'N6 the blocked customer still gets the distance of a pro that did not block them');
select is(
  tests.near_names($$ select display_name, ordinality as ord
                      from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909) with ordinality $$),
  array['Zone Commune', 'Amine Coupe', 'أمين', 'Mobile Karim', 'Mobile Nabil',
        'Salon Amine', 'Chebli Coupe', 'Bilal Studio', 'No Place'],
  'N6 the blocked pro sorts with the null points, revealing nothing of its place'
);
select is(
  (select count(*)::int from public.search_pros(p_bbox => array[3.0, 36.74, 3.2, 36.80])
    where display_name = 'Bilal Studio'),
  0, 'N6 the blocked pro is absent from a bbox');
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  current_setting('t.blocked_live')::jsonb,
  public.live_snapshot(current_setting('t.pl')::uuid, current_setting('t.d')::uuid),
  'N6 the blocked row carries the closed live shape (live_snapshot(pro, viewer))'
);

-- N7 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select results_eq(
  $$ select display_name, comes_to_you
       from public.search_pros(p_origin_lat => 36.76846, p_origin_lng => 3.0909)
      where display_name in ('Mobile Karim', 'Mobile Nabil', 'Amine Coupe')
      order by display_name $$,
  $$ values ('Amine Coupe'::text, false), ('Mobile Karim', true), ('Mobile Nabil', false) $$,
  'N7 comes_to_you only for a mobile pro within its service radius'
);
select is(
  (select count(*)::int from public.search_pros() where comes_to_you),
  0, 'N7 comes_to_you is false without an origin');
do $$ begin perform tests.clear_auth(); end; $$;

-- N8 ------------------------------------------------------------------------------------------

select is(
  (select format('%s %s %s', p.provolatile, l.lanname, p.prosecdef)
     from pg_proc p join pg_language l on l.oid = p.prolang
    where p.oid = 'public.search_pros'::regproc),
  's sql f',
  'N8 search_pros is stable, language sql, security invoker'
);
select is(
  (select count(*)::int from pg_proc p, unnest(p.proargnames) n
    where p.pronamespace = 'public'::regnamespace
      and p.proname <> 'search_pros'
      and n like 'p\_origin\_%'),
  0, 'N8 no other public function takes an origin parameter');
select ok(
  not has_function_privilege('anon', 'public.search_args_check(double precision, double precision, double precision[])', 'execute')
  and not has_function_privilege('public', 'public.search_args_check(double precision, double precision, double precision[])', 'execute')
  and has_function_privilege('authenticated', 'public.search_args_check(double precision, double precision, double precision[])', 'execute'),
  'N8 search_args_check is executable by authenticated only'
);

-- N4 (101 cap) and N9: 2,000 men pros placed around O -------------------------------------------

do $$
declare
  n int;
begin
  for n in 1 .. 2000 loop
    perform tests.create_account('21357' || lpad(n::text, 7, '0'), 'men', 'barber');
  end loop;
  insert into public.pro_profiles (owner_id, kind, space, display_name, workplace_type, locality_id,
                                   published_at)
  select p.id, 'barber', 'men', 'Pro ' || md5(p.id::text), 'salon', 1601, now()
  from public.profiles p
  where p.id in (select id from auth.users where phone like '21357%');
  -- Spread within ~0.1 degree of O, every point inside the bbox below.
  update public.pro_places pl
     set place_mode = 'exact',
         place = extensions.st_point(3.0909 + (random() - 0.5) * 0.2,
                                     36.76846 + (random() - 0.5) * 0.2, 4326)::extensions.geography
    from public.pro_profiles p
   where p.id = pl.pro_id and p.display_name like 'Pro %';
end;
$$;
analyze public.pro_profiles;
analyze public.pro_places;

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is(
  (select count(*)::int from public.search_pros(p_bbox => array[2.9, 36.6, 3.3, 36.9])),
  101, 'N4 a bbox returns at most 101 rows');
do $$ begin perform tests.clear_auth(); end; $$;

-- The function is not inlined (it has a SET clause), so its statement runs with a generic plan
-- over its parameters. N9 prepares the very body stored in pg_proc, with each named parameter
-- turned into $n, and explains it as a forced generic plan: the plan the function itself gets.
-- 2,000 rows fit in few pages, where a scan and a sort are cheaper than any index, so the question
-- asked (seqscan and sort disabled) is only whether the planner can serve the origin order from
-- the GiST index: an Index Scan on pro_places_search_point_idx whose Order By is the distance to
-- the origin ($8/$9; the map branch orders by the bbox centre, $10).
create function tests.search_pros_plan(p_args text)
returns jsonb
language plpgsql
as $$
declare
  v_body text;
  v_names text[] := array['p_query', 'p_region_code', 'p_locality_id', 'p_kids', 'p_category',
                          'p_limit', 'p_offset', 'p_origin_lat', 'p_origin_lng', 'p_bbox'];
  v_plan json;
  i int;
begin
  select prosrc into v_body from pg_proc where oid = 'public.search_pros'::regproc;
  for i in 1 .. array_length(v_names, 1) loop
    v_body := regexp_replace(v_body, '\m' || v_names[i] || '\M', '$' || i, 'g');
  end loop;
  v_body := regexp_replace(v_body, ';\s*$', '');
  execute 'prepare tests_search_pros(text, text, integer, boolean, public.service_category, int,'
          ' int, double precision, double precision, double precision[]) as ' || v_body;
  execute 'explain (format json) execute tests_search_pros(' || p_args || ')' into v_plan;
  deallocate tests_search_pros;
  return v_plan::jsonb;
end;
$$;

grant execute on function tests.search_pros_plan(text) to authenticated;

set local plan_cache_mode = force_generic_plan;
set local enable_seqscan = off;
set local enable_sort = off;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
do $$
begin
  perform set_config('t.plan',
    tests.search_pros_plan('null, null, null, null, null, 30, 0, 36.76846, 3.0909, null')::text, true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  jsonb_path_exists(current_setting('t.plan')::jsonb,
    '$.** ? (@."Index Name" == "pro_places_search_point_idx" && @."Order By" like_regex "<->.*\\$9")'),
  'N9 the origin order (no text) is an ordered scan of the GiST index on search_point'
);

select * from finish();
rollback;
