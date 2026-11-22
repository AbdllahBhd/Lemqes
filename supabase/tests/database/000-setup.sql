-- Persists for the run (no begin/rollback): every later file uses the tests schema, and
-- 999-teardown.sql drops it at the end so freeze_now/set_hours never outlive the suite.
create extension if not exists pgtap with schema extensions;
create schema if not exists tests;

create or replace function tests.create_user(phone text, confirmed boolean default true)
returns uuid
language plpgsql
as $$
declare
  uid uuid := gen_random_uuid();
begin
  insert into auth.users (id, aud, role, phone, phone_confirmed_at)
  values (
    uid,
    'authenticated',
    'authenticated',
    phone,
    case when confirmed then now() end
  );
  return uid;
end;
$$;

create or replace function tests.authenticate_as(uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

create or replace function tests.clear_auth()
returns void
language plpgsql
as $$
begin
  reset role;
end;
$$;

create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  set local role anon;
end;
$$;

-- Fixtures written as postgres (RLS bypassed) so a test only drives through the API what it
-- actually checks. Types are passed as text: this file runs before nothing else and must not
-- depend on a migration's enum to compile.
create or replace function tests.create_account(
  phone text,
  space text,
  active_role text,
  full_name text default 'Test User'
)
returns uuid
language plpgsql
as $$
declare
  uid uuid := tests.create_user(phone);
begin
  insert into public.profiles (id, full_name, pro_space, customer_space, active_role)
  values (
    uid,
    full_name,
    case when active_role <> 'customer' then space::public.space end,
    space::public.space,
    active_role::public.app_role
  );
  insert into public.profile_roles (profile_id, role) values (uid, 'customer');
  if active_role <> 'customer' then
    insert into public.profile_roles (profile_id, role)
    values (uid, active_role::public.app_role);
  end if;
  return uid;
end;
$$;

-- A pro profile owned by `owner`, with one active service and Monday hours; published unless
-- `published` is false. Space comes from the owner's pro_space, as create_pro_profile does.
create or replace function tests.create_pro(
  owner uuid,
  kind text,
  display_name text,
  locality_id integer default 1601,
  customer_mix text default 'adults',
  published boolean default true,
  price integer default 800
)
returns uuid
language plpgsql
as $$
declare
  pid uuid;
begin
  insert into public.pro_profiles (
    owner_id, kind, space, display_name, workplace_type, locality_id, customer_mix
  )
  select owner, kind::public.pro_kind, p.pro_space, display_name, 'salon', locality_id,
         customer_mix::public.customer_mix
  from public.profiles p where p.id = owner
  returning id into pid;

  insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
  values (pid, 'Base service', 'hair', price, 30);
  insert into public.pro_hours (pro_id, weekday, opens, closes) values (pid, 1, '09:00', '18:00');

  if published then
    update public.pro_profiles set published_at = now() where id = pid;
  end if;
  return pid;
end;
$$;

-- Runs `sql` as the current role and returns 'message|detail' of the error it raises (null when it
-- succeeds); pgTAP's throws_ok cannot see an exception's DETAIL.
create or replace function tests.error_detail(sql text)
returns text
language plpgsql
as $$
declare
  v_message text;
  v_detail text;
begin
  execute sql;
  return null;
exception when others then
  get stacked diagnostics v_message = message_text, v_detail = pg_exception_detail;
  return v_message || '|' || coalesce(v_detail, '');
end;
$$;

-- Freezes public.live_now() at `ts` by redefining it; the redefinition is transactional, so it
-- rolls back with the test (never a GUC: a client could set one). Security definer so a test can
-- call it while acting as a client role. Dynamic SQL: live_now() comes from a later migration.
create or replace function tests.freeze_now(ts timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  execute format(
    'create or replace function public.live_now() returns timestamptz language sql stable '
    'set search_path = '''' as %L',
    format('select %L::timestamptz', ts)
  );
end;
$$;

-- Sets one weekday's hours (no break) for a pro, replacing any existing row for that day.
create or replace function tests.set_hours(pro uuid, weekday int, opens time, closes time)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.pro_hours (pro_id, weekday, opens, closes)
  values (pro, weekday, opens, closes)
  on conflict on constraint pro_hours_pkey do update
    set opens = excluded.opens, closes = excluded.closes, break_start = null, break_end = null;
end;
$$;

-- Writes a pro's place directly (no set_pro_place checks), so a test that is not about the RPC can
-- seed any mode. Text mode and dynamic SQL: place_mode and PostGIS come from a later migration.
create or replace function tests.set_place(
  pro uuid,
  mode text,
  lat double precision default null,
  lng double precision default null,
  radius_m integer default null,
  landmark text default null
)
returns void
language plpgsql
security definer
as $$
begin
  execute
    'update public.pro_places
        set place_mode = $2::public.place_mode,
            place = case when $3 is null then null
                         else extensions.st_point($4, $3, 4326)::extensions.geography end,
            area_radius_m = $5,
            landmark = $6
      where pro_id = $1'
  using pro, mode, lat, lng, radius_m, landmark;
end;
$$;

-- Test-only schema (never shipped): tests switch to these roles and must still reach the helpers.
grant usage on schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated;
-- freeze_now runs as its owner: only the authenticated test role may reach it.
revoke execute on function tests.freeze_now(timestamptz) from public, anon;
-- set_hours is a definer too: tests call it as authenticated or postgres, never as anon.
revoke execute on function tests.set_hours(uuid, int, time, time) from public, anon;
-- set_place is a definer too, for the same reason.
revoke execute on function
  tests.set_place(uuid, text, double precision, double precision, integer, text)
from public, anon;

select plan(1);
select has_schema('tests');
select * from finish();
