-- Pro profiles: the barber / home-artist entity customers find, with its services, weekly hours
-- and work photos, plus the customer search.
--
-- POLICY PATTERN: the M1 pattern (20261114000100_accounts.sql header) still applies: roles held +
-- ownership + the data's space, helpers wrapped as (select ...), writes through definer RPCs
-- except fields the owner may freely edit (column grants). Added here:
--   * listable = published_at is not null + same space as the caller's (select current_space())
--     + the caller acts as customer. Only a listable profile (and its child rows) is readable by
--     someone other than its owner; public.is_listable(pro_id) backs the child-table policies.
--   * Customers never read pro_services directly (price_dzd must stay hidden when show_prices is
--     false): they go through public.pro_public_services(pro_id), which nulls hidden prices.
--   * pro_profiles.owner_id is not selectable by clients (column grants): it links a public card
--     to an account. Policies on other tables check ownership through the definer helpers
--     public.owns_pro(pro_id) / public.owns_pro_folder(object name), which may read it.
--   * pro_profiles.space is copied from profiles.pro_space at creation and is never writable,
--     so a pro cannot move into the other space's listings.
--   * Services are archived (archived_at), never deleted: M5 bookings will reference them.
--   * Media paths are '<pro id>/<file>', never the account id, because avatar_path is shown to
--     customers; the CHECKs below pin every stored path to its own pro's folder.

create extension if not exists unaccent with schema extensions;

create type public.pro_kind as enum ('barber', 'home_artist');
create type public.workplace_type as enum ('salon', 'own_studio', 'mobile');
create type public.customer_mix as enum ('adults', 'adults_and_kids', 'kids_only');
create type public.phone_visibility as enum ('public', 'followers', 'hidden');
create type public.service_category as enum
  ('hair', 'beard', 'coloring', 'nails', 'skincare', 'makeup', 'spa');

-- Immutable wrapper: extensions.unaccent is only stable (its dictionary could change), and search
-- folding belongs in one place so Arabic letter folding (M4) is a one-function change.
create function public.f_unaccent(p_text text)
returns text
language sql
immutable
parallel safe
strict
security definer
set search_path = ''
as $$
  select extensions.unaccent('extensions.unaccent'::regdictionary, p_text);
$$;

-- Tables ----------------------------------------------------------------------------------------

-- The name checks repeat the M1 name-hygiene class (20261114000200_name_hygiene.sql): keep all
-- copies identical.
create table public.pro_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles on delete cascade,
  kind public.pro_kind not null,
  space public.space not null,
  display_name text not null check (
    char_length(btrim(display_name)) between 2 and 60
    and display_name !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]'
  ),
  bio text check (char_length(bio) <= 500),
  experience_years smallint check (experience_years between 0 and 60),
  workplace_type public.workplace_type not null,
  workplace_name text check (
    workplace_name is null
    or (char_length(btrim(workplace_name)) between 1 and 80
        and workplace_name !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]')
  ),
  country_code text not null default 'DZ' references public.geo_countries,
  locality_id integer references public.geo_localities,
  customer_mix public.customer_mix,
  service_radius_km smallint check (service_radius_km between 1 and 100),
  travel_fee_dzd integer check (travel_fee_dzd between 0 and 200000),
  avatar_path text,
  phone_visibility public.phone_visibility not null default 'hidden',
  show_prices boolean not null default true,
  is_verified boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, kind),
  -- One file directly under this pro's own folder.
  constraint pro_profiles_avatar_path_own_folder check (
    avatar_path is null or avatar_path ~ ('^' || id::text || '/[A-Za-z0-9._-]+$')
  )
);

create index pro_profiles_listing_idx on public.pro_profiles (space, published_at desc)
  where published_at is not null;
create index pro_profiles_locality_idx on public.pro_profiles (locality_id);

create table public.service_presets (
  key text primary key check (key ~ '^[a-z0-9_]+$'),
  space public.space not null,
  home boolean not null,
  category public.service_category not null,
  name_ar text not null,
  name_fr text not null,
  name_en text not null,
  name_kab text not null,
  default_price_dzd integer not null check (default_price_dzd between 0 and 200000),
  default_duration_min smallint not null check (default_duration_min between 5 and 300),
  sort smallint not null
);

create table public.pro_services (
  id uuid primary key default gen_random_uuid(),
  pro_id uuid not null references public.pro_profiles on delete cascade,
  preset_key text references public.service_presets,
  name text check (
    name is null
    or (char_length(btrim(name)) between 2 and 60 and name !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]')
  ),
  category public.service_category not null,
  price_dzd integer not null check (price_dzd between 0 and 200000),
  duration_min smallint not null check (duration_min between 5 and 300),
  active boolean not null default true,
  archived_at timestamptz,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  check (preset_key is not null or name is not null)
);

create index pro_services_pro_idx on public.pro_services (pro_id);
create index pro_services_preset_idx on public.pro_services (preset_key);

-- ISO weekdays 1 (Monday) .. 7 (Sunday); a missing weekday is a closed day. Times are wall-clock
-- in the country's timezone (geo_countries.timezone).
create table public.pro_hours (
  pro_id uuid not null references public.pro_profiles on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  opens time not null,
  closes time not null,
  crosses_midnight boolean generated always as (closes < opens) stored,
  break_start time,
  break_end time,
  primary key (pro_id, weekday),
  check (opens <> closes),
  check (opens < '24:00' and closes < '24:00'),
  check (not (closes < opens) or closes <= '06:00'),
  check ((break_start is null) = (break_end is null)),
  check (break_end is null or break_end > break_start)
);

create table public.pro_photos (
  id uuid primary key default gen_random_uuid(),
  pro_id uuid not null references public.pro_profiles on delete cascade,
  path text not null unique,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  constraint pro_photos_path_own_folder check (path ~ ('^' || pro_id::text || '/[A-Za-z0-9._-]+$'))
);

create index pro_photos_pro_idx on public.pro_photos (pro_id);

-- Helpers ---------------------------------------------------------------------------------------

create function public.is_listable(p_pro_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pro_profiles p
    where p.id = p_pro_id
      and p.published_at is not null
      and p.space = public.current_space()
      and public.acts_as('customer')
  );
$$;

create function public.owns_pro(p_pro_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pro_profiles p where p.id = p_pro_id and p.owner_id = auth.uid()
  );
$$;

-- Storage object names are '<pro id>/<file>'; the folder is compared as text, so a segment that
-- is not a uuid is simply no match (no cast error).
create function public.owns_pro_folder(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pro_profiles p
    where p.id::text = (storage.foldername(p_name))[1] and p.owner_id = auth.uid()
  );
$$;

-- What still blocks publishing, in a fixed order the client maps to messages.
create function public.pro_missing_fields(p_pro_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array_remove(array[
    case when p.locality_id is null then 'locality' end,
    case when p.customer_mix is null then 'customer_mix' end,
    case when not exists (
      select 1 from public.pro_services s
      where s.pro_id = p.id and s.active and s.archived_at is null
    ) then 'services' end,
    case when not exists (select 1 from public.pro_hours h where h.pro_id = p.id) then 'hours' end
  ], null)
  from public.pro_profiles p
  where p.id = p_pro_id;
$$;

-- Triggers --------------------------------------------------------------------------------------
-- Security definer: they write columns (published_at) clients have no grant on.

create function public.pro_profiles_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.display_name := btrim(new.display_name);
  new.workplace_name := nullif(btrim(new.workplace_name), '');
  if tg_op = 'UPDATE' then
    new.updated_at := now();
    -- Clearing a required field takes the profile out of the listings instead of leaving an
    -- incomplete card visible.
    if new.published_at is not null and (new.locality_id is null or new.customer_mix is null) then
      new.published_at := null;
    end if;
  end if;
  return new;
end;
$$;

create trigger pro_profiles_before_write
before insert or update on public.pro_profiles
for each row execute function public.pro_profiles_before_write();

create function public.pro_services_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_space public.space;
begin
  new.name := nullif(btrim(new.name), '');

  -- A non-owner's write is left to RLS (which runs after this trigger) so it neither locks
  -- another pro's row nor learns its service count from the error.
  if auth.uid() is not null and not public.owns_pro(new.pro_id) then
    return new;
  end if;

  -- The parent row lock serialises concurrent inserts, so two of them cannot both pass the cap.
  -- Lock-then-count relies on READ COMMITTED (PostgREST's default): the count after the lock sees
  -- rows committed by the transaction that held it.
  select p.space into v_space from public.pro_profiles p where p.id = new.pro_id for update;

  if new.preset_key is not null
     and (tg_op = 'INSERT' or new.preset_key is distinct from old.preset_key)
     and not exists (
       select 1 from public.service_presets sp where sp.key = new.preset_key and sp.space = v_space
     ) then
    raise exception 'preset_space_mismatch';
  end if;

  if new.archived_at is null and (tg_op = 'INSERT' or old.archived_at is not null) then
    if (select count(*) from public.pro_services s
         where s.pro_id = new.pro_id and s.archived_at is null) >= 30 then
      raise exception 'too_many_services';
    end if;
  end if;
  return new;
end;
$$;

create trigger pro_services_before_write
before insert or update on public.pro_services
for each row execute function public.pro_services_before_write();

create function public.pro_services_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.pro_profiles p
     set published_at = null
   where p.id = old.pro_id
     and p.published_at is not null
     and not exists (
       select 1 from public.pro_services s
       where s.pro_id = p.id and s.active and s.archived_at is null
     );
  return null;
end;
$$;

create trigger pro_services_after_change
after update of active, archived_at or delete on public.pro_services
for each row execute function public.pro_services_after_change();

create function public.pro_photos_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Same as pro_services_before_write: a non-owner's insert is left to RLS.
  if auth.uid() is not null and not public.owns_pro(new.pro_id) then
    return new;
  end if;

  -- Lock-then-count relies on READ COMMITTED (PostgREST's default), as in the services cap.
  perform 1 from public.pro_profiles p where p.id = new.pro_id for update;
  if (select count(*) from public.pro_photos ph where ph.pro_id = new.pro_id) >= 9 then
    raise exception 'too_many_photos';
  end if;
  return new;
end;
$$;

create trigger pro_photos_before_insert
before insert on public.pro_photos
for each row execute function public.pro_photos_before_insert();

-- RLS and grants --------------------------------------------------------------------------------

alter table public.pro_profiles enable row level security;
alter table public.service_presets enable row level security;
alter table public.pro_services enable row level security;
alter table public.pro_hours enable row level security;
alter table public.pro_photos enable row level security;

revoke all on public.pro_profiles, public.service_presets, public.pro_services,
  public.pro_hours, public.pro_photos
  from anon, authenticated;

grant select on public.service_presets, public.pro_services, public.pro_hours, public.pro_photos
  to authenticated;
-- Every column but owner_id (clients use explicit column lists, never select *).
grant select (id, kind, space, display_name, bio, experience_years, workplace_type, workplace_name,
  country_code, locality_id, customer_mix, service_radius_km, travel_fee_dzd, avatar_path,
  phone_visibility, show_prices, is_verified, published_at, created_at, updated_at)
  on public.pro_profiles to authenticated;
grant update (display_name, bio, experience_years, workplace_type, workplace_name, locality_id,
  customer_mix, service_radius_km, travel_fee_dzd, avatar_path, phone_visibility, show_prices)
  on public.pro_profiles to authenticated;
grant insert (pro_id, preset_key, name, category, price_dzd, duration_min, active, sort)
  on public.pro_services to authenticated;
grant update (preset_key, name, category, price_dzd, duration_min, active, archived_at, sort)
  on public.pro_services to authenticated;
grant insert (pro_id, path, sort), delete on public.pro_photos to authenticated;

create policy pro_profiles_select on public.pro_profiles
for select to authenticated
using (
  owner_id = (select auth.uid())
  or (
    published_at is not null
    and space = (select public.current_space())
    and (select public.acts_as('customer'))
  )
);

create policy pro_profiles_update_own on public.pro_profiles
for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy service_presets_select_all on public.service_presets
for select to authenticated
using (true);

create policy pro_services_select on public.pro_services
for select to authenticated
using (
  public.owns_pro(pro_id)
);

create policy pro_services_insert_own on public.pro_services
for insert to authenticated
with check (
  public.owns_pro(pro_id)
);

create policy pro_services_update_own on public.pro_services
for update to authenticated
using (
  public.owns_pro(pro_id)
)
with check (
  public.owns_pro(pro_id)
);

create policy pro_hours_select on public.pro_hours
for select to authenticated
using (
  public.owns_pro(pro_id)
  or public.is_listable(pro_id)
);

create policy pro_photos_select on public.pro_photos
for select to authenticated
using (
  public.owns_pro(pro_id)
  or public.is_listable(pro_id)
);

create policy pro_photos_insert_own on public.pro_photos
for insert to authenticated
with check (
  public.owns_pro(pro_id)
);

create policy pro_photos_delete_own on public.pro_photos
for delete to authenticated
using (
  public.owns_pro(pro_id)
);

-- RPCs ------------------------------------------------------------------------------------------

create function public.create_pro_profile(
  p_kind public.pro_kind,
  p_display_name text,
  p_workplace_type public.workplace_type
)
returns public.pro_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_space public.space;
  v_profile public.pro_profiles;
begin
  if not public.has_role(p_kind::text::public.app_role) then
    raise exception 'role_not_held';
  end if;

  select p.pro_space into v_space from public.profiles p where p.id = v_uid;
  if v_space is null then
    raise exception 'profile_missing';
  end if;

  -- on conflict instead of a pre-check, so two concurrent calls cannot both pass.
  insert into public.pro_profiles (owner_id, kind, space, display_name, workplace_type)
  values (v_uid, p_kind, v_space, p_display_name, p_workplace_type)
  on conflict (owner_id, kind) do nothing
  returning * into v_profile;

  if v_profile.id is null then
    raise exception 'pro_profile_exists';
  end if;

  return v_profile;
end;
$$;

-- p_week: a JSON array of {"weekday": 1..7, "opens": "HH:MM", "closes": "HH:MM",
-- "break_start"?: "HH:MM", "break_end"?: "HH:MM"}; weekdays left out are closed. Replaces the
-- whole week atomically, then re-checks completeness once (no hours trigger, so the transient
-- empty week never un-publishes).
create function public.set_pro_hours(p_pro_id uuid, p_week jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day jsonb;
  v_weekday smallint;
  v_opens time;
  v_closes time;
  v_break_start time;
  v_break_end time;
  v_seen smallint[] := array[]::smallint[];
begin
  perform 1 from public.pro_profiles p
  where p.id = p_pro_id and p.owner_id = auth.uid()
  for update;
  if not found then
    raise exception 'not_owner';
  end if;

  if p_week is null or jsonb_typeof(p_week) <> 'array' then
    raise exception 'invalid_hours';
  end if;

  delete from public.pro_hours h where h.pro_id = p_pro_id;

  for v_day in select * from jsonb_array_elements(p_week) loop
    begin
      v_weekday := (v_day ->> 'weekday')::smallint;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'invalid_weekday';
    end;
    if v_weekday is null or v_weekday not between 1 and 7 or v_weekday = any (v_seen) then
      raise exception 'invalid_weekday';
    end if;
    v_seen := v_seen || v_weekday;

    begin
      v_opens := (v_day ->> 'opens')::time;
      v_closes := (v_day ->> 'closes')::time;
      v_break_start := (v_day ->> 'break_start')::time;
      v_break_end := (v_day ->> 'break_end')::time;
    exception when invalid_datetime_format or datetime_field_overflow then
      raise exception 'invalid_hours';
    end;

    -- '24:00' is a valid Postgres time but not a wall-clock reading; midnight is '00:00'.
    if v_opens is null or v_closes is null or v_opens = v_closes
       or v_opens = '24:00' or v_closes = '24:00'
       or (v_closes < v_opens and v_closes > '06:00') then
      raise exception 'invalid_hours';
    end if;

    if v_break_start is not null or v_break_end is not null then
      if v_break_start is null or v_break_end is null or v_break_end <= v_break_start
         or v_break_end = '24:00' then
        raise exception 'invalid_break';
      end if;
      -- Strictly inside the open span. Past midnight the span is [opens, 24:00) + [00:00, closes].
      if v_closes > v_opens then
        if v_break_start <= v_opens or v_break_end >= v_closes then
          raise exception 'invalid_break';
        end if;
      elsif not (v_break_start > v_opens or v_break_end < v_closes) then
        raise exception 'invalid_break';
      end if;
    end if;

    insert into public.pro_hours (pro_id, weekday, opens, closes, break_start, break_end)
    values (p_pro_id, v_weekday, v_opens, v_closes, v_break_start, v_break_end);
  end loop;

  update public.pro_profiles p
     set published_at = null
   where p.id = p_pro_id
     and p.published_at is not null
     and cardinality(public.pro_missing_fields(p_pro_id)) > 0;
end;
$$;

create function public.publish_pro_profile(p_pro_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_missing text[];
  v_published_at timestamptz;
begin
  perform 1 from public.pro_profiles p
  where p.id = p_pro_id and p.owner_id = auth.uid()
  for update;
  if not found then
    raise exception 'not_owner';
  end if;

  v_missing := public.pro_missing_fields(p_pro_id);
  if cardinality(v_missing) > 0 then
    raise exception 'profile_incomplete' using detail = array_to_string(v_missing, ',');
  end if;

  -- Re-publishing keeps the first timestamp, so it cannot be used to jump to the top of search.
  update public.pro_profiles p
     set published_at = coalesce(p.published_at, now())
   where p.id = p_pro_id
  returning p.published_at into v_published_at;

  return v_published_at;
end;
$$;

-- E.164 with '+' (auth.users.phone is stored without it). 'followers' is reserved for a later
-- milestone and returns null for now.
create function public.pro_contact_phone(p_pro_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select '+' || u.phone
  from public.pro_profiles p
  join auth.users u on u.id = p.owner_id
  where p.id = p_pro_id
    and p.phone_visibility = 'public'
    and public.is_listable(p.id)
    and u.phone is not null;
$$;

-- The customer view of a listable pro's services: active, non-archived, prices null when the pro
-- hides them. Empty for anything not listable to the caller (other space, unpublished, not acting
-- as customer). search_pros reads services only through this function.
create function public.pro_public_services(p_pro_id uuid)
returns table (
  id uuid,
  preset_key text,
  name text,
  category public.service_category,
  price_dzd integer,
  duration_min smallint,
  sort smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.preset_key, s.name, s.category,
         case when p.show_prices then s.price_dzd end,
         s.duration_min, s.sort
  from public.pro_profiles p
  join public.pro_services s on s.pro_id = p.id
  where p.id = p_pro_id
    and public.is_listable(p.id)
    and s.active
    and s.archived_at is null
  order by s.sort, s.id;
$$;

-- Security invoker: RLS on every table it reads still applies; the filters below repeat the
-- listable predicate so the owner's own unpublished row never shows up in search.
create function public.search_pros(
  p_query text default null,
  p_region_code text default null,
  p_locality_id integer default null,
  p_kids boolean default null,
  p_category public.service_category default null,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  pro_id uuid,
  kind public.pro_kind,
  display_name text,
  avatar_path text,
  workplace_type public.workplace_type,
  workplace_name text,
  region_code text,
  region_name_ar text,
  region_name_fr text,
  locality_name_ar text,
  locality_name_fr text,
  customer_mix public.customer_mix,
  min_price_dzd integer,
  is_verified boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (
    select '%' || replace(replace(replace(
             lower(public.f_unaccent(nullif(btrim(p_query), ''))),
             '\', '\\'), '%', '\%'), '_', '\_') || '%' as pattern
  )
  select p.id, p.kind, p.display_name, p.avatar_path, p.workplace_type, p.workplace_name,
         l.region_code, r.name_ar, r.name_fr, l.name_ar, l.name_fr, p.customer_mix,
         (select min(s.price_dzd) from public.pro_public_services(p.id) s),
         p.is_verified
  from public.pro_profiles p
  cross join q
  left join public.geo_localities l on l.id = p.locality_id
  left join public.geo_regions r on r.country_code = l.country_code and r.code = l.region_code
  where p.published_at is not null
    and p.space = (select public.current_space())
    and (select public.acts_as('customer'))
    and (p_region_code is null or l.region_code = p_region_code)
    and (p_locality_id is null or p.locality_id = p_locality_id)
    and (p_kids is not true or p.customer_mix in ('adults_and_kids', 'kids_only'))
    and (p_category is null or exists (
      select 1 from public.pro_public_services(p.id) s where s.category = p_category
    ))
    and (q.pattern is null
      or lower(public.f_unaccent(p.display_name)) like q.pattern
      or lower(public.f_unaccent(coalesce(p.workplace_name, ''))) like q.pattern
      or exists (
        select 1
        from public.pro_public_services(p.id) s
        left join public.service_presets sp on sp.key = s.preset_key
        where lower(public.f_unaccent(concat_ws(' ', s.name, sp.name_ar, sp.name_fr, sp.name_en,
                                                sp.name_kab))) like q.pattern
      ))
  order by p.is_verified desc, p.published_at desc, p.id
  limit least(greatest(coalesce(p_limit, 30), 0), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke execute on function
  public.f_unaccent(text),
  public.is_listable(uuid),
  public.owns_pro(uuid),
  public.owns_pro_folder(text),
  public.pro_public_services(uuid),
  public.pro_missing_fields(uuid),
  public.pro_profiles_before_write(),
  public.pro_services_before_write(),
  public.pro_services_after_change(),
  public.pro_photos_before_insert(),
  public.create_pro_profile(public.pro_kind, text, public.workplace_type),
  public.set_pro_hours(uuid, jsonb),
  public.publish_pro_profile(uuid),
  public.pro_contact_phone(uuid),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int)
from public, anon;

revoke execute on function
  public.pro_missing_fields(uuid),
  public.pro_profiles_before_write(),
  public.pro_services_before_write(),
  public.pro_services_after_change(),
  public.pro_photos_before_insert()
from authenticated;

grant execute on function
  public.f_unaccent(text),
  public.is_listable(uuid),
  public.owns_pro(uuid),
  public.owns_pro_folder(text),
  public.pro_public_services(uuid),
  public.create_pro_profile(public.pro_kind, text, public.workplace_type),
  public.set_pro_hours(uuid, jsonb),
  public.publish_pro_profile(uuid),
  public.pro_contact_phone(uuid),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int)
to authenticated;
