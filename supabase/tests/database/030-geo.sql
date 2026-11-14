begin;
select plan(18);

select is(
  (select count(*)::int from public.geo_regions where country_code = 'DZ'),
  69, 'Algeria has 69 wilayas'
);
select is(
  (select count(*)::int from public.geo_localities where country_code = 'DZ'),
  1541, 'Algeria has 1,541 communes'
);
select results_eq(
  $$ select code, name_ar, name_fr, name_en, timezone, currency from public.geo_countries $$,
  $$ values ('DZ', 'الجزائر', 'Algérie', 'Algeria', 'Africa/Algiers', 'DZD') $$,
  'the DZ country row is seeded'
);

select is_empty(
  $$ select r.code from public.geo_regions r
     where not exists (select 1 from public.geo_localities l
                       where l.country_code = r.country_code and l.region_code = r.code) $$,
  'every wilaya has at least one commune'
);
-- Commune counts of the 2026 wilayas as listed in Loi n° 26-06 (JORA n° 25, 5 April 2026).
select results_eq(
  $$ select region_code, count(*)::int from public.geo_localities
     where country_code = 'DZ' and region_code between '59' and '69'
     group by region_code order by region_code $$,
  $$ values ('59', 12), ('60', 8), ('61', 5), ('62', 4), ('63', 4), ('64', 6),
            ('65', 10), ('66', 8), ('67', 21), ('68', 23), ('69', 7) $$,
  'each wilaya 59-69 has the communes Law 26-06 gives it'
);

-- id is the official commune code, so later coordinate updates keep foreign keys pointing right.
select is_empty(
  $$ select id from public.geo_localities where official_code <> lpad(id::text, 4, '0') $$,
  'locality id equals its official commune code'
);
select results_eq(
  $$ select id, region_code, name_fr from public.geo_localities where id in (703, 1601, 2820) order by id $$,
  $$ values (703, '61', 'Branis'), (1601, '16', 'Alger Centre'), (2820, '68', 'Bou Saada') $$,
  'known communes keep their official ids'
);
select is_empty(
  $$ select country_code, official_code from public.geo_localities
     group by country_code, official_code having count(*) > 1 $$,
  'no duplicate official_code'
);

select is(
  (select name_fr from public.geo_regions where country_code = 'DZ' and code = '16'),
  'Alger', 'wilaya 16 is Alger'
);
select results_eq(
  $$ select name_ar, name_fr, parent_code from public.geo_regions where country_code = 'DZ' and code = '68' $$,
  $$ values ('بوسعادة', 'Bou Saâda', '28') $$,
  'wilaya 68 is Bou Saâda, split from M''Sila'
);
select results_eq(
  $$ select code, parent_code from public.geo_regions where parent_code is not null order by code $$,
  $$ values ('59', '03'), ('60', '05'), ('61', '07'), ('62', '12'), ('63', '13'), ('64', '14'),
            ('65', '17'), ('66', '17'), ('67', '26'), ('68', '28'), ('69', '32') $$,
  'exactly the 2026 wilayas carry their mother wilaya'
);

select ok(
  (select bool_and(relrowsecurity) from pg_class
   where oid in ('public.geo_countries'::regclass, 'public.geo_regions'::regclass,
                 'public.geo_localities'::regclass)),
  'RLS is enabled on all geo tables'
);

do $$ begin perform tests.authenticate_as_anon(); end; $$;
select is(
  (select count(*)::int from public.geo_localities),
  1541, 'anon can read communes'
);
select is(
  (select count(*)::int from public.geo_regions),
  69, 'anon can read wilayas'
);
select throws_ok(
  $$ insert into public.geo_localities (id, country_code, region_code, official_code, name_ar, name_fr)
     values (9999, 'DZ', '16', '9999', 'س', 'X') $$,
  '42501', null, 'anon cannot insert communes'
);
do $$ begin perform tests.clear_auth(); end; $$;

do $$
begin
  perform set_config('t.geo', tests.create_user('213550000400')::text, true);
  perform tests.authenticate_as(current_setting('t.geo')::uuid);
end;
$$;
select is(
  (select count(*)::int from public.geo_countries),
  1, 'authenticated can read countries'
);
select throws_ok(
  $$ insert into public.geo_regions (country_code, code, name_ar, name_fr) values ('DZ', '70', 'س', 'X') $$,
  '42501', null, 'authenticated cannot insert wilayas'
);
select throws_ok(
  $$ update public.geo_regions set name_fr = 'X' where code = '16' $$,
  '42501', null, 'authenticated cannot rename wilayas'
);
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
