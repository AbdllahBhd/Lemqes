-- Accounts: profiles, the roles a person holds, and the helpers every later RLS policy uses.
--
-- POLICY PATTERN (later milestones copy this):
--   * Security = roles held + ownership + the data's space. A policy checks all that apply, e.g.
--       using (owner_id = (select auth.uid()) and (select public.acts_as('barber'))
--              and space = (select public.current_space()))
--   * Always wrap helpers in a scalar subquery: (select auth.uid()), (select public.current_space()),
--     (select public.acts_as('barber')), (select public.has_role('salon_owner')). Postgres then
--     evaluates them once per statement (initPlan) instead of once per row.
--   * acts_as(r) = holds r AND it is the active role (what the user is doing now);
--     has_role(r) = holds r (what the user may switch to).
--   * Tables get RLS + SELECT for authenticated, never table-level INSERT/UPDATE/DELETE; writes go
--     through security definer RPCs (set search_path = '', fully-qualified names,
--     execute revoked from public/anon, granted to authenticated). Column-level UPDATE grants
--     are allowed only for fields the user may freely edit.
--
-- WARNING: roles are self-declared. Any signed-in user can call add_role and become a barber,
-- home artist or salon owner; holding a role is NOT a trust boundary. Anything that must only
-- reach vetted professionals (payouts, verified badges, ranking) needs its own explicit
-- verification flag set by a trusted path, never has_role()/acts_as() alone.

create type public.space as enum ('men', 'women');
create type public.app_role as enum ('customer', 'barber', 'home_artist', 'salon_owner');

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 80),
  pro_space public.space,
  customer_space public.space not null,
  active_role public.app_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- business_name is interim: M7 moves it into a salons table (decision D5).
create table public.profile_roles (
  profile_id uuid not null references public.profiles on delete cascade,
  role public.app_role not null,
  business_name text,
  created_at timestamptz not null default now(),
  primary key (profile_id, role),
  check (
    role <> 'salon_owner'
    or (business_name is not null and char_length(btrim(business_name)) between 2 and 80)
  )
);

-- Trigger functions cannot be called directly, so this one stays security invoker (least privilege).
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.profile_roles enable row level security;

revoke all on public.profiles, public.profile_roles from anon, authenticated;
grant select on public.profiles, public.profile_roles to authenticated;
grant update (full_name) on public.profiles to authenticated;

create policy profiles_select_own on public.profiles
for select to authenticated
using (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy profile_roles_select_own on public.profile_roles
for select to authenticated
using (profile_id = (select auth.uid()));

-- Helpers -------------------------------------------------------------------------------------

create function public.current_space()
returns public.space
language sql
stable
security definer
set search_path = ''
as $$
  select case when p.active_role = 'customer' then p.customer_space else p.pro_space end
  from public.profiles p
  where p.id = auth.uid();
$$;

create function public.has_role(p_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profile_roles r
    where r.profile_id = auth.uid() and r.role = p_role
  );
$$;

create function public.acts_as(p_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join public.profile_roles r on r.profile_id = p.id and r.role = p.active_role
    where p.id = auth.uid() and p.active_role = p_role
  );
$$;

-- RPCs ----------------------------------------------------------------------------------------

create function public.complete_signup(
  p_full_name text,
  p_space public.space,
  p_role public.app_role,
  p_business_name text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
begin
  if not exists (
    select 1 from auth.users u where u.id = v_uid and u.phone_confirmed_at is not null
  ) then
    raise exception 'phone_not_verified';
  end if;

  -- on conflict instead of a pre-check, so two concurrent calls cannot both pass.
  insert into public.profiles (id, full_name, pro_space, customer_space, active_role)
  values (
    v_uid,
    btrim(p_full_name),
    case when p_role <> 'customer' then p_space end,
    p_space,
    p_role
  )
  on conflict (id) do nothing
  returning * into v_profile;

  if v_profile.id is null then
    raise exception 'profile_exists';
  end if;

  insert into public.profile_roles (profile_id, role, business_name)
  values (
    v_uid,
    p_role,
    case when p_role = 'salon_owner' then btrim(p_business_name) end
  );

  -- Every account can book.
  if p_role <> 'customer' then
    insert into public.profile_roles (profile_id, role) values (v_uid, 'customer');
  end if;

  return v_profile;
end;
$$;

create function public.add_role(
  p_role public.app_role,
  p_space public.space default null,
  p_business_name text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_pro_space public.space;
begin
  -- Row lock serialises concurrent add_role calls that would both set pro_space.
  select p.pro_space into v_pro_space
  from public.profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'profile_missing';
  end if;

  if exists (
    select 1 from public.profile_roles r where r.profile_id = v_uid and r.role = p_role
  ) then
    return;
  end if;

  if p_role <> 'customer' then
    if v_pro_space is null then
      if p_space is null then
        raise exception 'space_required';
      end if;
      update public.profiles set pro_space = p_space where id = v_uid;
    elsif p_space is not null and p_space <> v_pro_space then
      raise exception 'space_locked';
    end if;
  end if;

  insert into public.profile_roles (profile_id, role, business_name)
  values (
    v_uid,
    p_role,
    case when p_role = 'salon_owner' then btrim(p_business_name) end
  );
end;
$$;

create function public.set_active_role(p_role public.app_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profile_roles r where r.profile_id = auth.uid() and r.role = p_role
  ) then
    raise exception 'role_not_held';
  end if;

  update public.profiles set active_role = p_role where id = auth.uid();
end;
$$;

create function public.set_customer_space(p_space public.space)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set customer_space = p_space where id = auth.uid();

  if not found then
    raise exception 'profile_missing';
  end if;
end;
$$;

revoke execute on function
  public.current_space(),
  public.has_role(public.app_role),
  public.acts_as(public.app_role),
  public.complete_signup(text, public.space, public.app_role, text),
  public.add_role(public.app_role, public.space, text),
  public.set_active_role(public.app_role),
  public.set_customer_space(public.space)
from public, anon;

grant execute on function
  public.current_space(),
  public.has_role(public.app_role),
  public.acts_as(public.app_role),
  public.complete_signup(text, public.space, public.app_role, text),
  public.add_role(public.app_role, public.space, text),
  public.set_active_role(public.app_role),
  public.set_customer_space(public.space)
to authenticated;
