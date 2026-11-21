begin;
select plan(35);

-- Search results are compared whole, so pros left in the local database (an integration run
-- publishes one) must not count; the transaction rolls this back.
delete from public.pro_profiles;

-- Fixture: three published men pros, one unpublished men pro, one published women pro.
--   m1 'Salon Dégradé'  Alger (16/1601)  adults           + preset men_salon_beard_trim, phone public
--                                                          (contact +213661000501, login +213550000501)
--   m2 'Barber Oran'    Oran  (31/3101)  adults_and_kids  + custom 'Coupe Spéciale Zarzis',
--                                                          verified, prices hidden
--   m3 'Kids Corner'    Alger (16/1601)  kids_only        + preset men_home_cut_fade (home artist)
--   m4 'Hidden Salon'   unpublished, phone public
--   w1 'Lina Beauty'    women space, phone public
do $$
declare
  m1 uuid; m2 uuid; m3 uuid; m4 uuid; w1 uuid;
begin
  perform set_config('t.o1', tests.create_account('213550000501', 'men', 'barber')::text, true);
  perform set_config('t.o2', tests.create_account('213550000502', 'men', 'barber')::text, true);
  perform set_config('t.o3', tests.create_account('213550000503', 'men', 'home_artist')::text, true);
  perform set_config('t.o4', tests.create_account('213550000504', 'men', 'barber')::text, true);
  perform set_config('t.ow', tests.create_account('213550000505', 'women', 'home_artist')::text, true);
  perform set_config('t.cm', tests.create_account('213550000506', 'men', 'customer')::text, true);
  perform set_config('t.cw', tests.create_account('213550000507', 'women', 'customer')::text, true);

  m1 := tests.create_pro(current_setting('t.o1')::uuid, 'barber', 'Salon Dégradé', 1601, 'adults');
  m2 := tests.create_pro(current_setting('t.o2')::uuid, 'barber', 'Barber Oran', 3101,
                         'adults_and_kids', price => 600);
  m3 := tests.create_pro(current_setting('t.o3')::uuid, 'home_artist', 'Kids Corner', 1601,
                         'kids_only', price => 1500);
  m4 := tests.create_pro(current_setting('t.o4')::uuid, 'barber', 'Hidden Salon',
                         published => false);
  w1 := tests.create_pro(current_setting('t.ow')::uuid, 'home_artist', 'Lina Beauty');

  insert into public.pro_services (pro_id, preset_key, category, price_dzd, duration_min)
  values (m1, 'men_salon_beard_trim', 'beard', 1000, 25),
         (m3, 'men_home_cut_fade', 'hair', 1500, 45);
  insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
  values (m2, 'Coupe Spéciale Zarzis', 'hair', 700, 30);

  update public.pro_profiles set published_at = now() - interval '2 hours', phone_visibility = 'public',
                                 contact_phone = '+213661000501'
   where id = m1;
  update public.pro_profiles set is_verified = true, show_prices = false where id = m2;
  update public.pro_profiles set published_at = now() - interval '1 hour', phone_visibility = 'followers'
   where id = m3;
  update public.pro_profiles set phone_visibility = 'public', contact_phone = '+213661000599'
   where id in (m4, w1);

  perform set_config('t.m1', m1::text, true);
  perform set_config('t.m2', m2::text, true);
  perform set_config('t.m3', m3::text, true);
  perform set_config('t.m4', m4::text, true);
  perform set_config('t.w1', w1::text, true);
end;
$$;

select is(
  (select count(*)::int
     from unnest((select proargnames from pg_proc where oid = 'public.search_pros'::regproc)) n
    where n ilike '%phone%'),
  0, 'search_pros returns no phone column');
select is(
  (select proargnames[array_upper(proargnames, 1)]
     from pg_proc where oid = 'public.search_pros'::regproc),
  'live', 'search_pros ends with the live column');

-- Men customer ----------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;
select results_eq(
  $$ select display_name from public.search_pros() $$,
  $$ values ('Barber Oran'::text), ('Kids Corner'), ('Salon Dégradé') $$,
  'men customer: published men pros only, verified first, then newest');
select is(
  (select count(*)::int from public.search_pros() s
    where jsonb_typeof(s.live) = 'object' and (s.live ->> 'pro_id')::uuid = s.pro_id),
  3, 'each row carries its own pro''s live object');
select results_eq(
  $$ select display_name from public.search_pros(p_kids => true) $$,
  $$ values ('Barber Oran'::text), ('Kids Corner') $$,
  'kids filter keeps adults_and_kids and kids_only');
select results_eq(
  $$ select display_name from public.search_pros(p_category => 'beard') $$,
  $$ values ('Salon Dégradé'::text) $$,
  'category filter');
select results_eq(
  $$ select display_name, region_code, region_name_fr, locality_name_fr
       from public.search_pros(p_region_code => '31') $$,
  $$ values ('Barber Oran'::text, '31'::text, 'Oran'::text, 'Oran'::text) $$,
  'region filter, with region and locality names');
select results_eq(
  $$ select display_name from public.search_pros(p_locality_id => 1601) $$,
  $$ values ('Kids Corner'::text), ('Salon Dégradé') $$,
  'locality filter');
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'اللحية') $$,
  $$ values ('Salon Dégradé'::text) $$,
  'query matches a preset name in Arabic');
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'TAILLE barbe') $$,
  $$ values ('Salon Dégradé'::text) $$,
  'query matches a preset name in French, case-insensitively');
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'beard trim') $$,
  $$ values ('Salon Dégradé'::text) $$,
  'query matches a preset name in English');
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'zarzis') $$,
  $$ values ('Barber Oran'::text) $$,
  'query matches a custom service name');
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'Degrade') $$,
  $$ values ('Kids Corner'::text), ('Salon Dégradé') $$,
  '"Degrade" finds "Dégradé" in a preset name and in a display name');
select results_eq(
  $$ select display_name from public.search_pros(p_query => 'specia') $$,
  $$ values ('Barber Oran'::text) $$,
  '"specia" finds the accented custom name "Spéciale"');
select is((select count(*)::int from public.search_pros(p_query => '%')), 0,
  'LIKE wildcards in the query are literal');
select is((select count(*)::int from public.search_pros(p_query => 'hidden')), 0,
  'an unpublished profile is excluded');
select is((select count(*)::int from public.search_pros(p_query => 'lina')), 0,
  'a women pro is excluded for a men customer even when the query matches');
select results_eq(
  $$ select display_name, min_price_dzd from public.search_pros() order by display_name $$,
  $$ values ('Barber Oran'::text, null::int), ('Kids Corner', 1500), ('Salon Dégradé', 800) $$,
  'min_price_dzd is the cheapest active service, null when prices are hidden');
select is(
  (select count(*)::int from public.pro_services where pro_id = current_setting('t.m2')::uuid),
  0, 'customers have no direct read of pro_services (so no hidden price leaks)');
select results_eq(
  $$ select coalesce(name, preset_key), price_dzd
       from public.pro_public_services(current_setting('t.m2')::uuid) order by 1 $$,
  $$ values ('Base service'::text, null::int), ('Coupe Spéciale Zarzis', null) $$,
  'pro_public_services hides every price when show_prices is false');
select results_eq(
  $$ select coalesce(name, preset_key), price_dzd
       from public.pro_public_services(current_setting('t.m1')::uuid) order by 1 $$,
  $$ values ('Base service'::text, 800), ('men_salon_beard_trim', 1000) $$,
  'pro_public_services shows prices when show_prices is true');
select is(public.pro_contact_phone(current_setting('t.m1')::uuid), '+213661000501',
  'a public phone of a listable pro is its contact number, never its login number');
select is(public.pro_contact_phone(current_setting('t.m3')::uuid), null,
  'a followers-only phone is not returned');
select is(public.pro_contact_phone(current_setting('t.m4')::uuid), null,
  'an unpublished pro''s phone is not returned');
select is(public.pro_contact_phone(current_setting('t.w1')::uuid), null,
  'a pro of another space: no phone');
do $$ begin perform tests.clear_auth(); end; $$;

-- Women customer and a pro acting as pro ---------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.cw')::uuid); end; $$;
select results_eq(
  $$ select display_name from public.search_pros() $$,
  $$ values ('Lina Beauty'::text) $$,
  'women customer: only the women pro');
select results_eq(
  $$ select s.live ->> 'pro_id' from public.search_pros() s $$,
  format($$ values (%L::text) $$, current_setting('t.w1')),
  'women customer: the only live object is the women pro''s');
select is(public.pro_contact_phone(current_setting('t.m1')::uuid), null,
  'a women customer gets no phone of a men pro');
select is(
  (select count(*)::int from public.pro_public_services(current_setting('t.m1')::uuid)),
  0, 'a customer of another space gets no services from the RPC');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.o1')::uuid); end; $$;
select is((select count(*)::int from public.search_pros()), 0,
  'a user acting as barber gets no search results');
select is(public.pro_contact_phone(current_setting('t.m1')::uuid), null,
  'no phone while not acting as customer');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.o2')::uuid); end; $$;
select results_eq(
  $$ select price_dzd from public.pro_services
      where pro_id = current_setting('t.m2')::uuid order by price_dzd $$,
  $$ values (600), (700) $$,
  'the owner always reads its own prices, even hidden ones');
do $$ begin perform tests.clear_auth(); end; $$;

-- Limit cap ---------------------------------------------------------------------------------------

do $$
declare
  i int;
begin
  for i in 1..55 loop
    perform tests.create_pro(
      tests.create_account('2135500006' || lpad(i::text, 2, '0'), 'men', 'barber'),
      'barber', 'Bulk ' || i);
  end loop;
end;
$$;

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;
select is((select count(*)::int from public.search_pros(p_limit => 500)), 50,
  'p_limit is capped at 50');
select is((select count(*)::int from public.search_pros(p_limit => 5, p_offset => 56)), 2,
  'p_offset pages past the first rows');
do $$ begin perform tests.clear_auth(); end; $$;

-- Offset cap: 1008 listable men pros, so an offset past 1000 would otherwise return nothing.

do $$
declare
  i int;
begin
  for i in 1..950 loop
    perform tests.create_pro(
      tests.create_account('213551' || lpad(i::text, 6, '0'), 'men', 'barber'),
      'barber', 'Bulk more ' || i);
  end loop;
end;
$$;

do $$ begin perform tests.authenticate_as(current_setting('t.cm')::uuid); end; $$;
select is((select count(*)::int from public.search_pros(p_limit => 50, p_offset => 5000)), 8,
  'p_offset is clamped at 1000');
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
