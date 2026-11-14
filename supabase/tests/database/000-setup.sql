-- Persists in the local DB (no begin/rollback); `supabase db reset` wipes it and it reruns first.
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

select plan(1);
select has_schema('tests');
select * from finish();
