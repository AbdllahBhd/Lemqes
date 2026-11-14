begin;
select plan(54);

-- Users are created as postgres up front: once a test switches role it cannot write auth.users.
do $$
begin
  perform set_config('t.u0', tests.create_user('213550000200', false)::text, true);
  perform set_config('t.a', tests.create_user('213550000201')::text, true);
  perform set_config('t.b', tests.create_user('213550000202')::text, true);
  perform set_config('t.c', tests.create_user('213550000203')::text, true);
end;
$$;

-- Contract: every RPC is security definer with an empty search_path.
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('complete_signup', 'add_role', 'set_active_role', 'set_customer_space',
                      'current_space', 'acts_as', 'has_role')
      and prosecdef
      and proconfig @> array['search_path=""']),
  7,
  'all 7 account functions are security definer with search_path = '''''
);
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'RLS on profiles');
select ok((select relrowsecurity from pg_class where oid = 'public.profile_roles'::regclass), 'RLS on profile_roles');
select has_trigger('public', 'profiles', 'profiles_set_updated_at', 'profiles has the updated_at trigger');

-- Unconfirmed phone
do $$ begin perform tests.authenticate_as(current_setting('t.u0')::uuid); end; $$;
select throws_ok(
  $$ select public.complete_signup('Zed', 'men', 'customer') $$,
  'P0001', 'phone_not_verified', 'unconfirmed phone cannot complete signup'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- A: barber in the men space
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(public.current_space(), null, 'no profile -> current_space() is null');
select ok(not public.has_role('customer'), 'no profile -> has_role false');
select ok(not public.acts_as('customer'), 'no profile -> acts_as false');
select throws_ok(
  $$ select public.add_role('barber', 'men') $$,
  'P0001', 'profile_missing', 'add_role without a profile'
);
select throws_ok(
  $$ select public.set_customer_space('women') $$,
  'P0001', 'profile_missing', 'set_customer_space without a profile'
);
select results_eq(
  $$ select pro_space::text, customer_space::text, active_role::text, full_name
       from public.complete_signup('  Amine ', 'men', 'barber') $$,
  $$ values ('men'::text, 'men'::text, 'barber'::text, 'Amine'::text) $$,
  'complete_signup returns the barber profile (name trimmed)'
);
select ok(public.has_role('customer'), 'pro signup also grants customer');
select ok(public.has_role('barber'), 'has_role barber');
select ok(public.acts_as('barber'), 'acts_as barber');
select ok(not public.acts_as('customer'), 'not acting as customer');
select is(public.current_space()::text, 'men', 'pro current_space is pro_space');
select throws_ok(
  $$ select public.complete_signup('Amine', 'men', 'barber') $$,
  'P0001', 'profile_exists', 'second complete_signup'
);
select throws_ok(
  $$ select public.add_role('salon_owner', 'women', 'Salon X') $$,
  'P0001', 'space_locked', 'pro roles share one pro space'
);
select lives_ok(
  $$ select public.add_role('salon_owner', null, 'Salon X') $$,
  'add salon_owner in the existing pro space'
);
select ok(public.has_role('salon_owner'), 'salon_owner held');
select is(
  (select business_name from public.profile_roles where role = 'salon_owner'),
  'Salon X', 'business_name stored on the salon_owner row'
);
select lives_ok($$ select public.add_role('barber', 'men') $$, 'held role -> no-op');
select lives_ok($$ select public.add_role('customer') $$, 'held customer -> no-op');
select is(
  (select count(*)::int from public.profile_roles),
  3, 'A holds exactly customer, barber, salon_owner'
);
select throws_ok(
  $$ select public.set_active_role('home_artist') $$,
  'P0001', 'role_not_held', 'cannot activate a role not held'
);
select lives_ok($$ select public.set_active_role('customer') $$, 'switch to customer');
select is(
  public.current_space(),
  (select customer_space from public.profiles),
  'customer current_space is customer_space'
);
select ok(public.acts_as('customer'), 'acts_as customer');
select ok(not public.acts_as('barber'), 'no longer acting as barber');
select lives_ok($$ select public.set_customer_space('women') $$, 'customer browses the women space');
select is(public.current_space()::text, 'women', 'current_space follows customer_space');
select is((select pro_space::text from public.profiles), 'men', 'pro_space untouched');
select lives_ok($$ select public.set_active_role('barber') $$, 'back to barber');
select is(public.current_space()::text, 'men', 'barber current_space is pro_space again');
do $$ begin perform tests.clear_auth(); end; $$;

-- C: fresh barber; salon_owner needs a business name
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select lives_ok($$ select public.complete_signup('Chakib', 'women', 'barber') $$, 'C signs up as barber');
select throws_ok(
  $$ select public.add_role('salon_owner', null, null) $$,
  '23514', null, 'salon_owner without business_name violates the check'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- B: customer only
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select results_eq(
  $$ select pro_space::text, active_role::text from public.complete_signup('Bilal', 'men', 'customer') $$,
  $$ values (null::text, 'customer'::text) $$,
  'customer signup has no pro_space'
);
select throws_ok(
  $$ select public.add_role('barber') $$,
  'P0001', 'space_required', 'first pro role needs a space'
);

-- RLS: B cannot see or touch A's rows; writes only through RPCs
select is(
  (select count(*)::int from public.profiles where id = current_setting('t.a')::uuid),
  0, 'B sees none of A''s profiles rows'
);
select is(
  (select count(*)::int from public.profile_roles where profile_id = current_setting('t.a')::uuid),
  0, 'B sees none of A''s profile_roles rows'
);
select is((select count(*)::int from public.profiles), 1, 'B sees only its own profile');
select throws_ok(
  $$ insert into public.profile_roles (profile_id, role) values (auth.uid(), 'home_artist') $$,
  '42501', null, 'no direct insert into profile_roles'
);
select throws_ok(
  $$ update public.profiles set pro_space = 'women' where id = auth.uid() $$,
  '42501', null, 'pro_space not directly writable'
);
select throws_ok(
  $$ update public.profiles set active_role = 'customer' where id = auth.uid() $$,
  '42501', null, 'active_role not directly writable'
);
with u as (update public.profiles set full_name = 'Amine B' where id = auth.uid() returning 1)
select is((select count(*)::int from u), 1, 'own full_name is writable');
with u as (
  update public.profiles set full_name = 'Amine B' where id = current_setting('t.a')::uuid returning 1
)
select is((select count(*)::int from u), 0, 'another''s full_name update affects 0 rows');
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select full_name from public.profiles where id = current_setting('t.a')::uuid),
  'Amine', 'A''s name unchanged'
);

-- anon reaches none of the functions
do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok($$ select public.complete_signup('Anon', 'men', 'customer') $$, '42501', null, 'anon: complete_signup');
select throws_ok($$ select public.add_role('customer') $$, '42501', null, 'anon: add_role');
select throws_ok($$ select public.set_active_role('customer') $$, '42501', null, 'anon: set_active_role');
select throws_ok($$ select public.set_customer_space('men') $$, '42501', null, 'anon: set_customer_space');
select throws_ok($$ select public.current_space() $$, '42501', null, 'anon: current_space');
select throws_ok($$ select public.acts_as('customer') $$, '42501', null, 'anon: acts_as');
select throws_ok($$ select public.has_role('customer') $$, '42501', null, 'anon: has_role');
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
