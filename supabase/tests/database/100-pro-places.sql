begin;
select plan(58);

-- Alger Centre (1601) is the commune of pa, pb and pc; Chebli (902) is 23.6 km and Blida (901)
-- 40.4 km from its centre. Fixtures are written as postgres.
do $$
begin
  perform set_config('t.a', tests.create_account('213550001000', 'men', 'barber', 'Amine')::text, true);
  perform set_config('t.b', tests.create_account('213550001001', 'men', 'barber', 'Bilal')::text, true);
  perform set_config('t.n', tests.create_account('213550001002', 'men', 'barber', 'Nadir')::text, true);
  perform set_config('t.k', tests.create_account('213550001003', 'men', 'barber', 'Karim')::text, true);
  perform set_config('t.c', tests.create_account('213550001004', 'men', 'customer', 'Chafik')::text, true);
  perform set_config('t.d', tests.create_account('213550001005', 'men', 'customer', 'Djamel')::text, true);
  perform set_config('t.w', tests.create_account('213550001006', 'women', 'customer', 'Wafa')::text, true);
  perform set_config('t.pa', tests.create_pro(current_setting('t.a')::uuid, 'barber', 'Salon Amine')::text, true);
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Hidden',
                                              published => false)::text, true);
  perform set_config('t.pn', tests.create_pro(current_setting('t.n')::uuid, 'barber', 'Nowhere',
                                              locality_id => null, published => false)::text, true);
  perform set_config('t.pk', tests.create_pro(current_setting('t.k')::uuid, 'barber', 'Salon Karim')::text, true);
end;
$$;
insert into public.pro_blocks (pro_id, customer_id)
values (current_setting('t.pa')::uuid, current_setting('t.d')::uuid);

-- Points due south of the Alger Centre centre, at the given distance in metres.
create function tests.south(p_m double precision)
returns double precision
language sql
as $$
  select extensions.st_y(extensions.st_project(
    extensions.st_point(3.0909, 36.76846, 4326)::extensions.geography, p_m, pi())::extensions.geometry);
$$;
grant execute on function tests.south(double precision) to authenticated;

-- P1 ------------------------------------------------------------------------------------------

select is(
  (select extnamespace::regnamespace::text from pg_extension where extname = 'postgis'),
  'extensions',
  'P1 postgis is installed in schema extensions'
);
select has_table('public', 'pro_places', 'P1 pro_places exists');
select is(
  (select count(*)::int from public.pro_profiles p
    where not exists (select 1 from public.pro_places pl where pl.pro_id = p.id)),
  0,
  'P1 every pro has a pro_places row (backfill + insert trigger)'
);
select is(
  (select place_mode::text from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  'none',
  'P1 a new pro starts with place_mode none'
);
select ok(
  (select bool_and(relrowsecurity) from pg_class
    where oid in ('public.pro_places'::regclass, 'public.pro_place_requests'::regclass)),
  'P1 RLS is enabled on pro_places and pro_place_requests'
);
select ok(
  has_table_privilege('authenticated', 'public.pro_places', 'select')
  and not has_table_privilege('authenticated', 'public.pro_places', 'insert')
  and not has_table_privilege('authenticated', 'public.pro_places', 'update')
  and not has_table_privilege('authenticated', 'public.pro_places', 'delete')
  and not has_table_privilege('anon', 'public.pro_places', 'select')
  and not has_table_privilege('authenticated', 'public.pro_place_requests', 'select')
  and not has_table_privilege('anon', 'public.pro_place_requests', 'select'),
  'P1 clients may only select pro_places, and never read the request ledger'
);

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  format($$ update public.pro_places set place_mode = 'none' where pro_id = %L $$, current_setting('t.pa')),
  '42501', null, 'P1 the owner cannot update pro_places directly');
select throws_ok(
  format($$ insert into public.pro_places (pro_id) values (%L) $$, current_setting('t.pa')),
  '42501', null, 'P1 the owner cannot insert into pro_places');
select throws_ok(
  format($$ delete from public.pro_places where pro_id = %L $$, current_setting('t.pa')),
  '42501', null, 'P1 the owner cannot delete from pro_places');
do $$ begin perform tests.clear_auth(); end; $$;

-- P2 ------------------------------------------------------------------------------------------

select tests.set_place(current_setting('t.pa')::uuid, 'exact', 36.76, 3.08);
select tests.set_place(current_setting('t.pb')::uuid, 'exact', 36.76, 3.08);

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select lat from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  36.76::double precision,
  'P2 the owner reads its own place'
);
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select is(
  (select count(*)::int from public.pro_places where pro_id = current_setting('t.pb')::uuid),
  1,
  'P2 the owner of an unpublished pro reads its own row'
);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is(
  (select lat from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  36.76::double precision,
  'P2 a same-space customer reads a listable pro''s place'
);
select is(
  (select count(*)::int from public.pro_places where pro_id = current_setting('t.pb')::uuid),
  0,
  'P2 an unpublished pro''s row is not readable by a customer'
);
do $$ begin perform tests.authenticate_as(current_setting('t.w')::uuid); end; $$;
select is(
  (select count(*)::int from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  0,
  'P2 a customer of the other space reads no row'
);
do $$ begin perform tests.authenticate_as(current_setting('t.d')::uuid); end; $$;
select is(
  (select count(*)::int from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  0,
  'P2 a blocked customer reads no row'
);
select is(
  (select lat from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  null,
  'P2 a direct select of lat returns nothing to a blocked customer'
);
select is(
  (select count(*)::int from public.pro_places where pro_id = current_setting('t.pk')::uuid),
  1,
  'P2 the blocked customer still reads a pro that did not block them'
);
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select is(
  (select count(*)::int from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  0,
  'P2 another pro (not acting as customer) reads no row'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- P3 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.n')::uuid); end; $$;
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'none', null, null, null, null) $$,
  'P0001', 'no_locality', 'P3 no_locality: the pro has no commune');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'none', null, null, null, null) $$,
  'P0001', 'not_owner', 'P3 a customer (no pro of the active role) is refused');
do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'customer' where id = current_setting('t.a')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'none', null, null, null, null) $$,
  'P0001', 'not_owner', 'P3 the owner acting as customer is refused');
do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'barber' where id = current_setting('t.a')::uuid;

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), null, 36.76, 3.08, null, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: no mode');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'none', 36.76, 3.08, null, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: none with a point');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'none', null, null, 500, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: none with a radius');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'none', null, null, null, 'Near the mosque') $$,
  'P0001', 'place_invalid', 'P3 place_invalid: none with a landmark');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'area', 36.76, 3.08, null, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: area without a radius');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'area', 36.76, 3.08, 750, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: area with a radius outside 500/1000/2000');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'area', 36.76, 3.08, 500, 'Near the mosque') $$,
  'P0001', 'place_invalid', 'P3 place_invalid: area with a landmark');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'area', null, null, 500, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: area without a point');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'exact', 36.76, 3.08, 500, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: exact with a radius');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'exact', 36.76, null, null, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: exact with half a point');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'exact', 'NaN', 3.08, null, null) $$,
  'P0001', 'place_invalid', 'P3 place_invalid: a non-finite coordinate');
select throws_ok(
  format($$ select public.set_pro_place(gen_random_uuid(), 'exact', 36.76, 3.08, null, %L) $$, repeat('x', 81)),
  'P0001', 'place_invalid', 'P3 place_invalid: a landmark over 80 characters');
select throws_ok(
  format($$ select public.set_pro_place(gen_random_uuid(), 'exact', 36.76, 3.08, null, %L) $$, E'Mosque​near'),
  'P0001', 'place_invalid', 'P3 place_invalid: a landmark with an invisible character (workplace_name hygiene)');
select throws_ok($$ select public.set_pro_place(gen_random_uuid(), 'exact', 38.5, 3.08, null, null) $$,
  'P0001', 'place_out_of_country', 'P3 place_out_of_country: north of the country bbox');
select throws_ok(
  format($$ select public.set_pro_place(gen_random_uuid(), 'exact', %s, 3.0909, null, null) $$, tests.south(30100)),
  'P0001', 'place_too_far', 'P3 place_too_far: 30.1 km from the commune centre');
select is(
  (select (public.set_pro_place('00000000-0000-4000-8000-000000000001', 'area',
                                tests.south(29900), 3.0909, 1000, null)).place_mode::text),
  'area',
  'P3 29.9 km from the commune centre is accepted'
);
select is(
  (select row(r.place_mode::text, r.area_radius_m, round(r.lat::numeric, 6))
     from public.set_pro_place('00000000-0000-4000-8000-000000000001', 'exact', 36.70, 3.05, null, null) r),
  (select row('area'::text, 1000::smallint, round(tests.south(29900)::numeric, 6))),
  'P3 a replayed request id returns the current row unchanged'
);
select is(
  (select place_mode::text from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  'area',
  'P3 the replay changed nothing'
);
select is(
  (select (public.set_pro_place('00000000-0000-4000-8000-000000000002', 'exact', 36.77, 3.06, null,
                                '  Next to the post office  ')).landmark),
  'Next to the post office',
  'P3 exact with a landmark is accepted and the landmark trimmed'
);
do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'home_artist' where id = current_setting('t.a')::uuid;
insert into public.profile_roles (profile_id, role) values (current_setting('t.a')::uuid, 'home_artist');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok($$ select public.set_pro_place('00000000-0000-4000-8000-000000000002', 'none', null, null, null, null) $$,
  'P0001', 'not_owner', 'P3 acting as a role the account has no pro for is refused');
do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'barber' where id = current_setting('t.a')::uuid;

select tests.freeze_now(now() + interval '3 days');
select public.queue_end_of_day();
select is(
  (select count(*)::int from public.pro_place_requests where actor = current_setting('t.a')::uuid),
  0,
  'P3 queue_end_of_day prunes place requests older than 2 days'
);

-- P4 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select row(r.place_mode::text, r.place is null, r.area_radius_m, r.landmark, r.lat, r.lng)
     from public.set_pro_place(gen_random_uuid(), 'none', null, null, null, null) r),
  row('none'::text, true, null::smallint, null::text, null::double precision, null::double precision),
  'P4 none clears place, radius, landmark, lat and lng'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- P5 ------------------------------------------------------------------------------------------

select ok(
  (select extensions.st_equals(search_point::extensions.geometry,
                               extensions.st_point(3.0909, 36.76846, 4326))
     from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  'P5 a none pro''s search_point is its commune centre'
);
select tests.set_place(current_setting('t.pk')::uuid, 'exact', 36.75, 3.07);
select ok(
  (select extensions.st_equals(search_point::extensions.geometry, extensions.st_point(3.07, 36.75, 4326))
     from public.pro_places where pro_id = current_setting('t.pk')::uuid),
  'P5 an exact pro''s search_point is its place'
);
select is(
  (select search_point from public.pro_places where pro_id = current_setting('t.pn')::uuid),
  null,
  'P5 no place and no commune: search_point is null'
);
update public.geo_localities set lat = 36.7700, lng = 3.0950 where id = 1601;
select ok(
  (select extensions.st_equals(search_point::extensions.geometry, extensions.st_point(3.0950, 36.7700, 4326))
     from public.pro_places where pro_id = current_setting('t.pa')::uuid),
  'P5 a commune coordinate update moves the search_point of its none pros'
);
select ok(
  (select extensions.st_equals(search_point::extensions.geometry, extensions.st_point(3.07, 36.75, 4326))
     from public.pro_places where pro_id = current_setting('t.pk')::uuid),
  'P5 a commune coordinate update leaves a placed pro''s search_point on its place'
);
update public.geo_localities set lat = 36.76846, lng = 3.0909 where id = 1601;

-- P6 ------------------------------------------------------------------------------------------

select tests.set_place(current_setting('t.pk')::uuid, 'exact', 36.76846, 3.0909, landmark => 'Door');
update public.pro_profiles set locality_id = 902 where id = current_setting('t.pk')::uuid;
select is(
  (select place_mode::text from public.pro_places where pro_id = current_setting('t.pk')::uuid),
  'exact',
  'P6 moving to a commune 23.6 km away keeps the place'
);
update public.pro_profiles set locality_id = 901 where id = current_setting('t.pk')::uuid;
select is(
  (select row(place_mode::text, place is null, landmark) from public.pro_places
    where pro_id = current_setting('t.pk')::uuid),
  row('none'::text, true, null::text),
  'P6 moving to a commune 40.4 km away resets the place to none'
);
select ok(
  (select extensions.st_equals(pl.search_point::extensions.geometry, extensions.st_point(l.lng, l.lat, 4326))
     from public.pro_places pl join public.geo_localities l on l.id = 901
    where pl.pro_id = current_setting('t.pk')::uuid),
  'P6 after the reset the search_point is the new commune centre'
);

-- P7 ------------------------------------------------------------------------------------------

delete from realtime.messages;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select lives_ok($$ select public.set_pro_place(gen_random_uuid(), 'exact', 36.77, 3.06, null, null) $$,
  'P7 set_pro_place succeeds');
do $$ begin perform tests.clear_auth(); end; $$;
select is((select count(*)::int from realtime.messages), 0, 'P7 set_pro_place broadcasts nothing');

-- P8 ------------------------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'private.viewer_blocked(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.f_pro_search_point(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.set_pro_place(uuid, public.place_mode, double precision, double precision, integer, text)', 'execute')
  and not has_function_privilege('authenticated', 'public.f_pro_search_point(uuid)', 'execute'),
  'P8 viewer_blocked, f_pro_search_point and set_pro_place are not executable by anon'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace in ('public'::regnamespace, 'private'::regnamespace)
      and proname in ('viewer_blocked', 'f_pro_search_point', 'set_pro_place', 'pro_places_create',
                      'pro_places_after_place', 'pro_places_after_locality',
                      'pro_places_after_locality_coords')
      and prosecdef
      and proconfig @> array['search_path=""']),
  7,
  'P8 every new function is security definer with search_path = '''''
);
do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok(format($$ select private.viewer_blocked(%L) $$, current_setting('t.pa')),
  '42501', null, 'P8 anon cannot call viewer_blocked');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is(private.viewer_blocked(current_setting('t.pa')::uuid), false,
  'P8 viewer_blocked is false for a customer the pro did not block (another one is blocked)');
do $$ begin perform tests.authenticate_as(current_setting('t.d')::uuid); end; $$;
select is(private.viewer_blocked(current_setting('t.pa')::uuid), true,
  'P8 viewer_blocked is true for the blocked caller');
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
