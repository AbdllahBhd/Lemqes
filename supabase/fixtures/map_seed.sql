-- Fixtures for the map + near-me integration path (flutter_app/integration_test/map_customer_test):
-- applied as postgres by scripts/integration.sh right after `supabase db reset`, for that file
-- only. Local stack only; the ids are fixed so the test can name them. Points sit around the
-- test's fake device position (36.7538, 3.0588, Sidi M'hamed).
--
--   213550000007  women barber "Lina", password lemqes-test-1, published pro b…07 "Studio Lina":
--                 a 1 km area ~250 m from the device, the nearest women's pro
--   213550000015  women barber "Amel", published pro b…15 "Salon Amel": an exact pin ~1.8 km
--                 north, the women's positive control (seen by the blocked customer too)
--   213550000008  women customer "Sara", password lemqes-test-1: blocked by b…07
--   213550000019  men barber, published pro b…19 "أمين": an exact pin ~1.4 km, the men's control
--                 and the "Amine" search target
--   213550000020  men barber, published pro b…20 "Yacine Coiffure": commune only, the search's
--                 negative control
--
-- 213550000006 (women customer) is left free: the test signs it up through the app.

begin;

create temporary table seed_account (
  id uuid,
  phone text,
  full_name text,
  space public.space,
  role public.app_role
) on commit drop;

insert into seed_account values
  ('a0000000-0000-4000-8000-000000000007', '213550000007', 'Lina', 'women', 'barber'),
  ('a0000000-0000-4000-8000-000000000015', '213550000015', 'Amel', 'women', 'barber'),
  ('a0000000-0000-4000-8000-000000000008', '213550000008', 'Sara', 'women', 'customer'),
  ('a0000000-0000-4000-8000-000000000019', '213550000019', 'أمين', 'men', 'barber'),
  ('a0000000-0000-4000-8000-000000000020', '213550000020', 'Yacine', 'men', 'barber');

-- GoTrue reads the token columns as strings: NULL there fails every sign-in.
insert into auth.users (
  instance_id, id, aud, role, phone, phone_confirmed_at, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select '00000000-0000-0000-0000-000000000000', a.id, 'authenticated', 'authenticated', a.phone,
       now(), extensions.crypt('lemqes-test-1', extensions.gen_salt('bf')),
       '{"provider": "phone", "providers": ["phone"]}', '{}', now(), now(), '', '', '', ''
from seed_account a;

insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
select a.id::text, a.id,
       jsonb_build_object('sub', a.id::text, 'phone', a.phone, 'phone_verified', true),
       'phone', now(), now(), now()
from seed_account a;

-- What complete_signup writes for each account.
insert into public.profiles (id, full_name, pro_space, customer_space, active_role)
select a.id, a.full_name, case when a.role <> 'customer' then a.space end, a.space, a.role
from seed_account a;

insert into public.profile_roles (profile_id, role)
select a.id, 'customer' from seed_account a
union all
select a.id, a.role from seed_account a where a.role <> 'customer';

-- The pros (pro_live and pro_places rows come from the pro_profiles insert triggers).
insert into public.pro_profiles (
  id, owner_id, kind, space, display_name, workplace_type, workplace_name, locality_id,
  customer_mix
) values
  ('b0000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000007', 'barber',
   'women', 'Studio Lina', 'salon', 'Studio Lina', 1602, 'adults'),
  ('b0000000-0000-4000-8000-000000000015', 'a0000000-0000-4000-8000-000000000015', 'barber',
   'women', 'Salon Amel', 'salon', 'Salon Amel', 1601, 'adults'),
  ('b0000000-0000-4000-8000-000000000019', 'a0000000-0000-4000-8000-000000000019', 'barber',
   'men', 'أمين', 'salon', 'Salon El Bahdja', 1604, 'adults'),
  ('b0000000-0000-4000-8000-000000000020', 'a0000000-0000-4000-8000-000000000020', 'barber',
   'men', 'Yacine Coiffure', 'salon', 'Salon Yacine', 1601, 'adults');

insert into public.pro_services (id, pro_id, name, category, price_dzd, duration_min, sort)
values
  ('c0000000-0000-4000-8000-000000000071', 'b0000000-0000-4000-8000-000000000007', 'Brushing',
   'hair', 1200, 45, 0),
  ('c0000000-0000-4000-8000-000000000151', 'b0000000-0000-4000-8000-000000000015', 'Coupe',
   'hair', 1500, 45, 0),
  ('c0000000-0000-4000-8000-000000000191', 'b0000000-0000-4000-8000-000000000019', 'Coupe',
   'hair', 800, 30, 0),
  ('c0000000-0000-4000-8000-000000000201', 'b0000000-0000-4000-8000-000000000020', 'Coupe',
   'hair', 700, 30, 0);

insert into public.pro_hours (pro_id, weekday, opens, closes)
select p.id, d.weekday, '00:00', '23:59'
from (values ('b0000000-0000-4000-8000-000000000007'::uuid),
             ('b0000000-0000-4000-8000-000000000015'::uuid),
             ('b0000000-0000-4000-8000-000000000019'::uuid),
             ('b0000000-0000-4000-8000-000000000020'::uuid)) p (id)
cross join generate_series(1, 7) d (weekday);

-- The places, written directly (set_pro_place is the owner's RPC); the pro_places triggers keep
-- search_point in step.
update public.pro_places
set place_mode = 'area',
    place = extensions.st_point(3.0600, 36.7560, 4326)::extensions.geography,
    area_radius_m = 1000
where pro_id = 'b0000000-0000-4000-8000-000000000007';

update public.pro_places
set place_mode = 'exact',
    place = extensions.st_point(3.0560, 36.7700, 4326)::extensions.geography
where pro_id = 'b0000000-0000-4000-8000-000000000015';

update public.pro_places
set place_mode = 'exact',
    place = extensions.st_point(3.0701, 36.7505, 4326)::extensions.geography
where pro_id = 'b0000000-0000-4000-8000-000000000019';

update public.pro_profiles set published_at = now()
where id in ('b0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000015',
             'b0000000-0000-4000-8000-000000000019', 'b0000000-0000-4000-8000-000000000020');

-- Lina blocked Sara.
insert into public.pro_blocks (pro_id, customer_id)
values ('b0000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000008');

commit;
