begin;
select plan(91);

-- Accounts are created as postgres up front: once a test switches role it cannot write auth.users.
do $$
begin
  perform set_config('t.nr', tests.create_account('213550000400', 'men', 'customer')::text, true);
  perform set_config('t.a', tests.create_account('213550000401', 'men', 'barber', 'Amine')::text, true);
  perform set_config('t.b', tests.create_account('213550000402', 'men', 'barber')::text, true);
  perform set_config('t.h', tests.create_account('213550000403', 'women', 'home_artist')::text, true);
  perform set_config('t.cm', tests.create_account('213550000404', 'men', 'customer')::text, true);
  perform set_config('t.cw', tests.create_account('213550000405', 'women', 'customer')::text, true);
  -- B's profile stays unpublished; W is a published women pro (another space for t.cm).
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Salon Bilal',
                                              published => false)::text, true);
end;
$$;

-- Contract ----------------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('f_unaccent', 'is_listable', 'pro_missing_fields', 'create_pro_profile',
                      'set_pro_hours', 'publish_pro_profile', 'pro_contact_phone',
                      'pro_public_services', 'owns_pro', 'owns_pro_folder',
                      'pro_profiles_before_write', 'pro_services_before_write',
                      'pro_services_after_change', 'pro_photos_before_insert',
                      'trim_profile_full_name')
      and prosecdef
      and proconfig @> array['search_path=""']),
  15,
  'all 15 new non-search functions are security definer with search_path = '''''
);
select ok(
  (select not prosecdef and proconfig @> array['search_path=""'] and provolatile = 's'
     from pg_proc where oid = 'public.search_pros'::regproc),
  'search_pros is a stable security invoker function with search_path = '''''
);
select is(
  (select count(*)::int from pg_class
    where oid in ('public.pro_profiles'::regclass, 'public.service_presets'::regclass,
                  'public.pro_services'::regclass, 'public.pro_hours'::regclass,
                  'public.pro_photos'::regclass)
      and relrowsecurity),
  5,
  'RLS is enabled on all 5 new tables'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('f_unaccent', 'is_listable', 'pro_missing_fields', 'create_pro_profile',
                      'set_pro_hours', 'publish_pro_profile', 'pro_contact_phone', 'search_pros',
                      'pro_public_services', 'owns_pro', 'owns_pro_folder',
                      'pro_profiles_before_write', 'pro_services_before_write',
                      'pro_services_after_change', 'pro_photos_before_insert',
                      'trim_profile_full_name')
      and (has_function_privilege('anon', oid, 'execute')
           or has_function_privilege('public', oid, 'execute'))),
  0,
  'no new function is executable by anon or public'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('pro_missing_fields', 'pro_profiles_before_write',
                      'pro_services_before_write', 'pro_services_after_change',
                      'pro_photos_before_insert', 'trim_profile_full_name')
      and has_function_privilege('authenticated', oid, 'execute')),
  0,
  'internal helpers and trigger functions are not executable by authenticated'
);

-- Anon ----------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok($$ select public.create_pro_profile('barber', 'Anon', 'salon') $$,
  '42501', null, 'anon cannot call create_pro_profile');
select throws_ok($$ select public.set_pro_hours(gen_random_uuid(), '[]') $$,
  '42501', null, 'anon cannot call set_pro_hours');
select throws_ok($$ select public.publish_pro_profile(gen_random_uuid()) $$,
  '42501', null, 'anon cannot call publish_pro_profile');
select throws_ok($$ select public.pro_contact_phone(gen_random_uuid()) $$,
  '42501', null, 'anon cannot call pro_contact_phone');
select throws_ok($$ select * from public.search_pros() $$,
  '42501', null, 'anon cannot call search_pros');
select throws_ok($$ select * from public.pro_public_services(gen_random_uuid()) $$,
  '42501', null, 'anon cannot call pro_public_services');
select throws_ok($$ select public.is_listable(gen_random_uuid()) $$,
  '42501', null, 'anon cannot call is_listable');
select throws_ok($$ select public.f_unaccent('é') $$,
  '42501', null, 'anon cannot call f_unaccent');
select throws_ok($$ select count(*) from public.pro_profiles $$,
  '42501', null, 'anon cannot read pro_profiles');
do $$ begin perform tests.clear_auth(); end; $$;

-- Creation ------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.nr')::uuid); end; $$;
select throws_ok($$ select public.create_pro_profile('barber', 'Sans Role', 'salon') $$,
  'P0001', 'role_not_held', 'creating a barber profile needs the barber role');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select set_config('t.pa',
  (public.create_pro_profile('barber', '  Salon Amine ', 'salon')).id::text, true);
select results_eq(
  $$ select kind::text, space::text, display_name, published_at is null, phone_visibility::text,
            show_prices, is_verified, country_code
       from public.pro_profiles where id = current_setting('t.pa')::uuid $$,
  $$ values ('barber'::text, 'men'::text, 'Salon Amine'::text, true, 'hidden'::text, true, false,
             'DZ'::text) $$,
  'create_pro_profile: men space from pro_space, trimmed name, unpublished, safe defaults'
);
select throws_ok($$ select public.create_pro_profile('barber', 'Encore', 'salon') $$,
  'P0001', 'pro_profile_exists', 'a second barber profile for the same owner is refused');
select throws_ok($$ select public.create_pro_profile('barber', E'Zero​width', 'salon') $$,
  '23514', null, 'display_name gets the name-hygiene check');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.h')::uuid); end; $$;
select set_config('t.ph',
  (public.create_pro_profile('home_artist', 'Lina Beauty', 'mobile')).id::text, true);
select is(
  (select space::text from public.pro_profiles where id = current_setting('t.ph')::uuid),
  'women', 'space is copied from the owner''s pro_space (women)'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- Direct writes A may not make ----------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  $$ update public.pro_profiles set space = 'women' where id = current_setting('t.pa')::uuid $$,
  '42501', null, 'space is not client-writable');
select throws_ok(
  $$ update public.pro_profiles set owner_id = current_setting('t.b')::uuid
       where id = current_setting('t.pa')::uuid $$,
  '42501', null, 'owner_id is not client-writable');
select throws_ok(
  $$ update public.pro_profiles set published_at = now() where id = current_setting('t.pa')::uuid $$,
  '42501', null, 'published_at is not client-writable');
select throws_ok(
  $$ update public.pro_profiles set is_verified = true where id = current_setting('t.pa')::uuid $$,
  '42501', null, 'is_verified is not client-writable');
select throws_ok(
  $$ insert into public.pro_profiles (owner_id, kind, space, display_name, workplace_type)
     values (auth.uid(), 'home_artist', 'men', 'Direct', 'salon') $$,
  '42501', null, 'no direct insert into pro_profiles');
select throws_ok(
  $$ delete from public.pro_profiles where id = current_setting('t.pa')::uuid $$,
  '42501', null, 'no direct delete from pro_profiles');
select throws_ok(
  $$ update public.pro_profiles set avatar_path = current_setting('t.pb') || '/a.jpg'
       where id = current_setting('t.pa')::uuid $$,
  '23514', null, 'avatar_path under another pro''s folder is refused');
select lives_ok(
  $$ update public.pro_profiles
        set avatar_path = current_setting('t.pa') || '/a.jpg', bio = 'Coupes et barbes'
      where id = current_setting('t.pa')::uuid $$,
  'owner edits free fields and an avatar_path under its own folder');

-- Hours -----------------------------------------------------------------------------------------

select lives_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":1,"opens":"09:00","closes":"18:00","break_start":"12:00","break_end":"13:00"}]') $$,
  'a normal day with a lunch break is accepted');
select lives_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":1,"opens":"09:00","closes":"18:00"},{"weekday":5,"opens":"14:00","closes":"01:00"}]') $$,
  'a 14:00 -> 01:00 day (past midnight) is accepted');
select results_eq(
  $$ select weekday::int, crosses_midnight from public.pro_hours
      where pro_id = current_setting('t.pa')::uuid order by weekday $$,
  $$ values (1, false), (5, true) $$,
  'the week was replaced and crosses_midnight marks the late day');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"14:00","closes":"07:00"}]') $$,
  'P0001', 'invalid_hours', 'closing after 06:00 the next morning is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"09:00","closes":"09:00"}]') $$,
  'P0001', 'invalid_hours', 'opens = closes is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"09:00","closes":"18:00","break_start":"19:00","break_end":"20:00"}]') $$,
  'P0001', 'invalid_break', 'a break outside the opening span is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"09:00","closes":"18:00","break_start":"13:00","break_end":"12:00"}]') $$,
  'P0001', 'invalid_break', 'break_end before break_start is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"09:00","closes":"18:00","break_start":"12:00","break_end":"12:00"}]') $$,
  'P0001', 'invalid_break', 'break_end = break_start is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":0,"opens":"09:00","closes":"18:00"}]') $$,
  'P0001', 'invalid_weekday', 'ISO weekday 0 is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":8,"opens":"09:00","closes":"18:00"}]') $$,
  'P0001', 'invalid_weekday', 'ISO weekday 8 is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":3,"opens":"09:00","closes":"18:00"},{"weekday":3,"opens":"10:00","closes":"12:00"}]') $$,
  'P0001', 'invalid_weekday', 'the same weekday twice is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"09:00","closes":"24:00"}]') $$,
  'P0001', 'invalid_hours', 'closes = 24:00 is refused (use 00:00 past midnight)');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"24:00","closes":"02:00"}]') $$,
  'P0001', 'invalid_hours', 'opens = 24:00 is refused');
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":2,"opens":"9h","closes":"18:00"}]') $$,
  'P0001', 'invalid_hours', 'an unparsable time is refused with invalid_hours');
select is(
  (select count(*)::int from public.pro_hours where pro_id = current_setting('t.pa')::uuid),
  2, 'a refused call leaves the previous week untouched');
select throws_ok(
  $$ insert into public.pro_hours (pro_id, weekday, opens, closes)
     values (current_setting('t.pa')::uuid, 2, '09:00', '18:00') $$,
  '42501', null, 'pro_hours is written only through set_pro_hours');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid, '[]') $$,
  'P0001', 'not_owner', 'another pro cannot set my hours');
select throws_ok(
  $$ select public.publish_pro_profile(current_setting('t.pa')::uuid) $$,
  'P0001', 'not_owner', 'another pro cannot publish my profile');
select throws_ok(
  $$ insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
     values (current_setting('t.pa')::uuid, 'Intrus', 'hair', 500, 20) $$,
  '42501', null, 'another owner cannot insert services for my profile');
select is(
  (select count(*)::int from public.pro_profiles where id <> current_setting('t.pb')::uuid),
  0, 'a user acting as barber selects no other (unpublished) pro profile');
do $$ begin perform tests.clear_auth(); end; $$;

-- Publishing ----------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select lives_ok($$ select public.set_pro_hours(current_setting('t.pa')::uuid, '[]') $$,
  'an empty week (every day closed) is accepted');
select is(
  tests.error_detail(format('select public.publish_pro_profile(%L)', current_setting('t.pa'))),
  'profile_incomplete|locality,customer_mix,services,hours',
  'publishing an empty profile lists every missing part');
select lives_ok(
  $$ update public.pro_profiles set locality_id = 1601, customer_mix = 'adults_and_kids'
      where id = current_setting('t.pa')::uuid $$,
  'owner sets locality and customer mix');
select lives_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":1,"opens":"09:00","closes":"18:00"}]') $$,
  'owner sets one open day');
select is(
  tests.error_detail(format('select public.publish_pro_profile(%L)', current_setting('t.pa'))),
  'profile_incomplete|services',
  'only the missing services are reported');
select lives_ok(
  $$ insert into public.pro_services (pro_id, preset_key, category, price_dzd, duration_min)
     values (current_setting('t.pa')::uuid, 'men_salon_degrade', 'hair', 700, 25) $$,
  'owner adds a preset service');
select isnt(public.publish_pro_profile(current_setting('t.pa')::uuid), null,
  'a complete profile publishes and returns its timestamp');
select lives_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":1,"opens":"09:00","closes":"18:00"},{"weekday":2,"opens":"09:00","closes":"18:00"},
         {"weekday":3,"opens":"09:00","closes":"18:00"},{"weekday":4,"opens":"09:00","closes":"18:00"},
         {"weekday":5,"opens":"14:00","closes":"01:00"},{"weekday":6,"opens":"09:00","closes":"18:00"},
         {"weekday":7,"opens":"10:00","closes":"14:00"}]') $$,
  'replacing a full week on a published profile');
select isnt(
  (select published_at from public.pro_profiles where id = current_setting('t.pa')::uuid),
  null, 'replacing the week keeps the profile published');
select lives_ok($$ select public.set_pro_hours(current_setting('t.pa')::uuid, '[]') $$,
  'closing every day');
select is(
  (select published_at from public.pro_profiles where id = current_setting('t.pa')::uuid),
  null, 'closing every day un-publishes');
select lives_ok(
  $$ select public.set_pro_hours(current_setting('t.pa')::uuid,
       '[{"weekday":1,"opens":"09:00","closes":"18:00"}]');
     select public.publish_pro_profile(current_setting('t.pa')::uuid) $$,
  'reopening and republishing');

-- Services ------------------------------------------------------------------------------------

select throws_ok(
  $$ insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
     values (current_setting('t.pa')::uuid, null, 'hair', 500, 20) $$,
  '23514', null, 'a service needs a preset or a name');
select lives_ok(
  $$ insert into public.pro_services (pro_id, name, category, price_dzd, duration_min, sort)
     select current_setting('t.pa')::uuid, 'Service ' || i, 'hair', 500, 20, i
       from generate_series(2, 30) i $$,
  'owner fills the profile up to 30 services');
select throws_ok(
  $$ insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
     values (current_setting('t.pa')::uuid, 'Trente et un', 'hair', 500, 20) $$,
  'P0001', 'too_many_services', 'the 31st non-archived service is refused');
select throws_ok(
  $$ delete from public.pro_services where pro_id = current_setting('t.pa')::uuid $$,
  '42501', null, 'services cannot be deleted');
select throws_ok(
  $$ update public.pro_services set pro_id = current_setting('t.pb')::uuid
      where pro_id = current_setting('t.pa')::uuid $$,
  '42501', null, 'a service cannot be moved to another profile');
select lives_ok(
  $$ update public.pro_services set archived_at = now()
      where pro_id = current_setting('t.pa')::uuid and name like 'Service %' $$,
  'archiving 29 services works');
select isnt(
  (select published_at from public.pro_profiles where id = current_setting('t.pa')::uuid),
  null, 'still published while one active service remains');
select lives_ok(
  $$ insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
     values (current_setting('t.pa')::uuid, 'Coupe signature', 'hair', 900, 30) $$,
  'archived services do not count toward the cap');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;
select is((select count(*)::int from public.search_pros('signature')), 1,
  'search finds the pro by an active service name');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select lives_ok(
  $$ update public.pro_services set archived_at = now()
      where pro_id = current_setting('t.pa')::uuid and name = 'Coupe signature' $$,
  'archiving a service');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;
select is((select count(*)::int from public.search_pros('signature')), 0,
  'an archived service no longer matches in search');
select is(
  (select count(*)::int from public.pro_public_services(current_setting('t.pa')::uuid)
    where name = 'Coupe signature'),
  0, 'customers do not see archived services');
do $$ begin perform tests.clear_auth(); end; $$;

-- Photos --------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  $$ insert into public.pro_photos (pro_id, path)
     values (current_setting('t.pa')::uuid, current_setting('t.pb') || '/x.jpg') $$,
  '23514', null, 'a photo row pointing into another pro''s folder is refused');
select lives_ok(
  $$ insert into public.pro_photos (pro_id, path)
     values (current_setting('t.pa')::uuid, current_setting('t.pa') || '/x.jpg') $$,
  'a photo row under my own folder is accepted');
select throws_ok(
  $$ update public.pro_photos set sort = 1 where pro_id = current_setting('t.pa')::uuid $$,
  '42501', null, 'photo rows cannot be updated');
select is(
  (select count(*)::int from public.pro_profiles where id = current_setting('t.pb')::uuid),
  0, 'a pro does not see another pro''s unpublished profile');
do $$ begin perform tests.clear_auth(); end; $$;

-- Acting as barber vs acting as customer, same space, A published -------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select results_eq(
  $$ select (select count(*) from public.pro_profiles where id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_hours where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_photos where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_services where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_public_services(current_setting('t.pa')::uuid))::int $$,
  $$ values (0, 0, 0, 0, 0) $$,
  'acting as barber: nothing of another published same-space pro (profile, hours, photos, services)');
select public.set_active_role('customer');
select results_eq(
  $$ select (select count(*) from public.pro_profiles where id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_hours where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_photos where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_services where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_public_services(current_setting('t.pa')::uuid))::int $$,
  $$ values (1, 1, 1, 0, 1) $$,
  'the same user acting as customer: profile, hours, photos, and services only through the RPC');
select public.set_active_role('barber');
do $$ begin perform tests.clear_auth(); end; $$;

-- Space separation and visibility -----------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.cw')::uuid); end; $$;
select is((select count(*)::int from public.pro_profiles where space = 'men'), 0,
  'a women-space customer selects no men pro');
select is(
  (select count(*)::int from public.pro_services where pro_id = current_setting('t.pa')::uuid)
  + (select count(*)::int from public.pro_public_services(current_setting('t.pa')::uuid)),
  0, 'a women-space customer gets none of a men pro''s services (table or RPC)');
select is(
  (select count(*)::int from public.pro_photos where pro_id = current_setting('t.pa')::uuid),
  0, 'a women-space customer selects none of a men pro''s photos');
select is(
  (select count(*)::int from public.pro_hours where pro_id = current_setting('t.pa')::uuid),
  0, 'a women-space customer selects none of a men pro''s hours');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;
select results_eq(
  $$ select (select count(*) from public.pro_profiles where id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_public_services(current_setting('t.pa')::uuid))::int,
            (select count(*) from public.pro_photos where pro_id = current_setting('t.pa')::uuid)::int,
            (select count(*) from public.pro_hours where pro_id = current_setting('t.pa')::uuid)::int $$,
  $$ values (1, 1, 1, 1) $$,
  'a men-space customer sees the published profile, its active service, photo and hours');
select throws_ok(
  $$ select owner_id from public.pro_profiles where id = current_setting('t.pa')::uuid $$,
  '42501', null, 'a customer cannot read owner_id');
select is(
  (select count(*)::int from public.pro_profiles where id = current_setting('t.pb')::uuid),
  0, 'an unpublished profile is invisible to customers');
select is((select count(*)::int from public.service_presets where space = 'women'), 13,
  'every signed-in user reads the presets catalogue');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select is(
  (select count(*)::int from public.pro_profiles where id = current_setting('t.pb')::uuid),
  1, 'the owner sees its own unpublished profile');
do $$ begin perform tests.clear_auth(); end; $$;

-- Un-publishing when the last service goes ------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select lives_ok(
  $$ update public.pro_services set active = false
      where pro_id = current_setting('t.pa')::uuid and preset_key = 'men_salon_degrade' $$,
  'deactivating the last active service');
select is(
  (select published_at from public.pro_profiles where id = current_setting('t.pa')::uuid),
  null, 'losing the last active service un-publishes');
select lives_ok(
  $$ update public.pro_profiles set locality_id = null where id = current_setting('t.pa')::uuid $$,
  'owner may clear the locality');

-- Name trim on profiles -----------------------------------------------------------------------

update public.profiles set full_name = '  Amine Benali  ' where id = auth.uid();
select is((select full_name from public.profiles where id = auth.uid()), 'Amine Benali',
  'full_name is trimmed on update');
do $$ begin perform tests.clear_auth(); end; $$;

select throws_ok(
  $$ insert into public.pro_hours (pro_id, weekday, opens, closes)
     values (current_setting('t.pb')::uuid, 0, '09:00', '18:00') $$,
  '23514', null, 'the table itself refuses weekday 0');

select * from finish();
rollback;
