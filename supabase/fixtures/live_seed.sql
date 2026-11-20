-- Fixtures for the live-queue integration paths (flutter_app/integration_test/live_queue_*):
-- applied as postgres by scripts/integration.sh right after `supabase db reset`, for those files
-- only. Local stack only; the ids are fixed so the tests can name them.
--
--   213550000004  men barber "Yacine", password lemqes-test-1, published pro b…04
--                 (two services, open 00:00-23:59 every day so a run never meets a closing time)
--   213550000008  men customer "Walid", password lemqes-test-1: the same-space control client
--   213550000014  women barber "Samira", published pro b…14: the other space's card
--
-- 213550000005 (men customer) and 213550000006 (women customer) are left free: the tests sign
-- them up through the app and the auth API.

begin;

create temporary table seed_account (
  id uuid,
  phone text,
  full_name text,
  space public.space,
  role public.app_role
) on commit drop;

insert into seed_account values
  ('a0000000-0000-4000-8000-000000000004', '213550000004', 'Yacine', 'men', 'barber'),
  ('a0000000-0000-4000-8000-000000000008', '213550000008', 'Walid', 'men', 'customer'),
  ('a0000000-0000-4000-8000-000000000014', '213550000014', 'Samira', 'women', 'barber');

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

-- The pros (pro_live rows come from the pro_profiles insert trigger).
insert into public.pro_profiles (
  id, owner_id, kind, space, display_name, workplace_type, workplace_name, locality_id,
  customer_mix
) values
  ('b0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000004', 'barber',
   'men', 'Yacine Coiffure', 'salon', 'Salon Yacine', 1601, 'adults'),
  ('b0000000-0000-4000-8000-000000000014', 'a0000000-0000-4000-8000-000000000014', 'barber',
   'women', 'Samira Beauté', 'salon', 'Salon Samira', 1601, 'adults');

insert into public.pro_services (id, pro_id, name, category, price_dzd, duration_min, sort)
values
  ('c0000000-0000-4000-8000-000000000041', 'b0000000-0000-4000-8000-000000000004', 'Coupe',
   'hair', 800, 30, 0),
  ('c0000000-0000-4000-8000-000000000042', 'b0000000-0000-4000-8000-000000000004', 'Barbe',
   'beard', 400, 20, 1),
  ('c0000000-0000-4000-8000-000000000141', 'b0000000-0000-4000-8000-000000000014', 'Brushing',
   'hair', 1200, 45, 0);

insert into public.pro_hours (pro_id, weekday, opens, closes)
select p.id, d.weekday, '00:00', '23:59'
from (values ('b0000000-0000-4000-8000-000000000004'::uuid),
             ('b0000000-0000-4000-8000-000000000014'::uuid)) p (id)
cross join generate_series(1, 7) d (weekday);

update public.pro_profiles set published_at = now()
where id in ('b0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000014');

commit;
