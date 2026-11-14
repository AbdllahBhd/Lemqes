begin;
select plan(9);

-- Users are created as postgres up front: once a test switches role it cannot write auth.users.
do $$
begin
  perform set_config('t.zw', tests.create_user('213550000300')::text, true);
  perform set_config('t.ctl', tests.create_user('213550000301')::text, true);
  perform set_config('t.ar', tests.create_user('213550000302')::text, true);
  perform set_config('t.lat', tests.create_user('213550000303')::text, true);
  perform set_config('t.bidi', tests.create_user('213550000304')::text, true);
end;
$$;

-- Invisible and control characters are refused in names others will see.
do $$ begin perform tests.authenticate_as(current_setting('t.zw')::uuid); end; $$;
select throws_ok(
  $$ select public.complete_signup(E'Ami​ne', 'men', 'customer') $$,
  '23514', null, 'zero-width space in full_name is refused'
);
select throws_ok(
  $$ select public.complete_signup(E'﻿Amine', 'men', 'customer') $$,
  '23514', null, 'byte order mark in full_name is refused'
);
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.ctl')::uuid); end; $$;
select throws_ok(
  $$ select public.complete_signup(E'Amine\nBenali', 'men', 'customer') $$,
  '23514', null, 'a newline in full_name is refused'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- Ordinary Arabic and Latin names with spaces are accepted.
do $$ begin perform tests.authenticate_as(current_setting('t.ar')::uuid); end; $$;
select lives_ok(
  $$ select public.complete_signup('أمين بن علي', 'men', 'customer') $$,
  'an Arabic name with spaces is accepted'
);
-- The column-level UPDATE grant is held to the same rule.
select throws_ok(
  $$ update public.profiles set full_name = E'‮نيمأ' where id = auth.uid() $$,
  '23514', null, 'a bidi override cannot be written by a direct update'
);
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.lat')::uuid); end; $$;
select lives_ok(
  $$ select public.complete_signup('Lina Haddad-Aït', 'women', 'salon_owner', 'Institut Lina & Co') $$,
  'a Latin name and business name with spaces are accepted'
);
select is(
  (select business_name from public.profile_roles where profile_id = auth.uid() and role = 'salon_owner'),
  'Institut Lina & Co',
  'the business name is stored'
);
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.bidi')::uuid); end; $$;
select throws_ok(
  $$ select public.complete_signup('Amine', 'men', 'salon_owner', E'Salon ‮niam') $$,
  '23514', null, 'a bidi override in business_name is refused'
);
select lives_ok(
  $$ select public.complete_signup('Amine', 'men', 'barber') $$,
  'the refused sign-up left nothing behind'
);
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
