-- Pro places (M4): what location of a pro customers see, in its own table.
--
--   * The server stores only what the pro chose to show: an exact pin, the centre of an area
--     circle the pro placed (500 m / 1 km / 2 km), or nothing (commune only). Nothing hidden is
--     stored, so nothing hidden can leak.
--   * Why not columns on pro_profiles: pro_profiles_select lets every same-space customer read a
--     published row and cannot see blocks, so a place there would hand a blocked customer the
--     pin. pro_places has its own policy: the owner, or a listable pro that has not blocked the
--     reader (viewer_blocked, a definer helper because pro_blocks is not client-readable). The
--     invoker search_pros (Task 3b) left-joins it, so a blocked reader gets the none shape.
--   * set_pro_place is the only writer (no client insert/update/delete grant). It is idempotent
--     through pro_place_requests (the M3 queue_requests contract) and never broadcasts: a place
--     is not live state.
--   * search_point (the ranking point) = place, else the commune centre, else null; it is held
--     in f_pro_search_point and kept current by triggers on pro_places.place,
--     pro_profiles.locality_id and geo_localities.lat/lng.
--   * The 30 km rule is checked against the commune centre (geo_localities.lat/lng). A commune
--     without coordinates cannot be measured: the place is then only checked against the
--     country bbox (geo_countries.bbox, [min_lng, min_lat, max_lng, max_lat]).
--
-- PostGIS 3.3 (local stack: 3.3.7) in schema extensions. st_point(x, y, srid) exists since 3.2;
-- st_dwithin / st_distance on geography measure on the spheroid by default (PostGIS reference,
-- https://postgis.net/docs/ST_DWithin.html).

create extension if not exists postgis with schema extensions;

create type public.place_mode as enum ('none', 'area', 'exact');

-- Tables ----------------------------------------------------------------------------------------

-- The landmark check repeats pro_profiles.workplace_name (20261115000200_pro_profiles.sql): keep
-- the copies identical.
create table public.pro_places (
  pro_id uuid primary key references public.pro_profiles on delete cascade,
  place_mode public.place_mode not null default 'none',
  place extensions.geography(Point, 4326),
  area_radius_m smallint,
  landmark text check (
    landmark is null
    or (char_length(btrim(landmark)) between 1 and 80
        and landmark !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]')
  ),
  lat double precision generated always as (extensions.st_y(place::extensions.geometry)) stored,
  lng double precision generated always as (extensions.st_x(place::extensions.geometry)) stored,
  search_point extensions.geography(Point, 4326),
  updated_at timestamptz not null default now(),
  constraint pro_places_mode_coherent check (
    (place_mode = 'none' and place is null and area_radius_m is null and landmark is null)
    or (place_mode = 'area' and place is not null and area_radius_m in (500, 1000, 2000)
        and landmark is null)
    or (place_mode = 'exact' and place is not null and area_radius_m is null)
  )
);

create index pro_places_search_point_idx on public.pro_places using gist (search_point);

-- One action only, so no action column: a reused id is detected by its pro (an account with two
-- pro profiles switches roles, and with them the pro set_pro_place writes).
create table public.pro_place_requests (
  actor uuid not null references public.profiles on delete cascade,
  request_id uuid not null,
  pro_id uuid not null references public.pro_profiles on delete cascade,
  created_at timestamptz not null default public.live_now(),
  primary key (actor, request_id)
);

create index pro_place_requests_created_idx on public.pro_place_requests (created_at);
create index pro_place_requests_pro_idx on public.pro_place_requests (pro_id);

-- Helpers ---------------------------------------------------------------------------------------

-- Only ever about the caller: a pro cannot ask whether someone else is blocked.
create function public.viewer_blocked(p_pro_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pro_blocks b
    where b.pro_id = p_pro_id and b.customer_id = auth.uid()
  );
$$;

-- The one definition of the ranking point (M7 salons will add their door here).
create function public.f_pro_search_point(p_pro_id uuid)
returns extensions.geography
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(pl.place, extensions.st_point(l.lng, l.lat, 4326)::extensions.geography)
  from public.pro_profiles p
  left join public.pro_places pl on pl.pro_id = p.id
  left join public.geo_localities l on l.id = p.locality_id
  where p.id = p_pro_id;
$$;

-- Triggers --------------------------------------------------------------------------------------
-- Security definer: they write pro_places, which clients have no write grant on.

create function public.pro_places_create()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pro_places (pro_id) values (new.id) on conflict (pro_id) do nothing;
  return null;
end;
$$;

create trigger pro_places_create
after insert on public.pro_profiles
for each row execute function public.pro_places_create();

-- Sets only search_point, so it never re-fires itself (it listens to place).
create function public.pro_places_after_place()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.pro_places pl
     set search_point = public.f_pro_search_point(new.pro_id)
   where pl.pro_id = new.pro_id;
  return null;
end;
$$;

create trigger pro_places_after_place
after insert or update of place on public.pro_places
for each row execute function public.pro_places_after_place();

-- A new commune more than 30 km from the place (or no commune at all) drops the place to none,
-- so a stale pin never sits in a commune it does not belong to; the reset fires
-- pro_places_after_place, which moves search_point. Otherwise search_point is recomputed here.
create function public.pro_places_after_locality()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_centre extensions.geography;
begin
  select extensions.st_point(l.lng, l.lat, 4326)::extensions.geography into v_centre
  from public.geo_localities l
  where l.id = new.locality_id;

  update public.pro_places pl
     set place_mode = 'none', place = null, area_radius_m = null, landmark = null,
         updated_at = now()
   where pl.pro_id = new.id
     and pl.place is not null
     and (new.locality_id is null
          or (v_centre is not null and not extensions.st_dwithin(pl.place, v_centre, 30000)));
  if not found then
    update public.pro_places pl
       set search_point = public.f_pro_search_point(new.id)
     where pl.pro_id = new.id;
  end if;
  return null;
end;
$$;

create trigger pro_places_after_locality
after update of locality_id on public.pro_profiles
for each row
when (old.locality_id is distinct from new.locality_id)
execute function public.pro_places_after_locality();

-- A corrected commune point moves the pros that rank by it (none mode); placed pros keep theirs.
create function public.pro_places_after_locality_coords()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.pro_places pl
     set search_point = public.f_pro_search_point(pl.pro_id)
    from public.pro_profiles p
   where p.id = pl.pro_id
     and p.locality_id = new.id
     and pl.place_mode = 'none';
  return null;
end;
$$;

create trigger pro_places_after_locality_coords
after update of lat, lng on public.geo_localities
for each row
when (old.lat is distinct from new.lat or old.lng is distinct from new.lng)
execute function public.pro_places_after_locality_coords();

-- Backfill: every existing pro starts as none (commune only); the insert trigger above sets
-- search_point to its commune centre, so no published pro drops out of search.
insert into public.pro_places (pro_id)
select p.id from public.pro_profiles p
on conflict (pro_id) do nothing;

-- RPC -------------------------------------------------------------------------------------------

-- The pro is the caller's pro of their active role (unique per owner and kind), so acting as a
-- pro and owning it are one check. Returns the pro_places row, like set_live_status returns
-- pro_live. p_radius_m only with area, p_landmark only with exact; none clears everything.
create function public.set_pro_place(
  p_request_id uuid,
  p_mode public.place_mode,
  p_lat double precision,
  p_lng double precision,
  p_radius_m integer,
  p_landmark text
)
returns public.pro_places
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_pro_id uuid;
  v_locality_id integer;
  v_bbox double precision[];
  v_centre extensions.geography;
  v_point extensions.geography;
  v_landmark text := nullif(btrim(p_landmark), '');
  v_seen_pro uuid;
  v_place public.pro_places;
begin
  select p.id, p.locality_id, c.bbox into v_pro_id, v_locality_id, v_bbox
  from public.profiles a
  join public.pro_profiles p on p.owner_id = a.id and p.kind::text = a.active_role::text
  join public.geo_countries c on c.code = p.country_code
  where a.id = v_uid
    and public.acts_as(a.active_role);
  if v_pro_id is null then
    raise exception 'not_owner';
  end if;

  -- Serializes this pro's place writes (and the ledger check below) like the M3 row locks.
  select pl.* into v_place from public.pro_places pl where pl.pro_id = v_pro_id for update;

  if p_request_id is null then
    raise exception 'request_id_required';
  end if;
  insert into public.pro_place_requests (actor, request_id, pro_id)
  values (v_uid, p_request_id, v_pro_id)
  on conflict (actor, request_id) do nothing;
  if not found then
    select r.pro_id into v_seen_pro
    from public.pro_place_requests r
    where r.actor = v_uid and r.request_id = p_request_id;
    if v_seen_pro <> v_pro_id then
      raise exception 'request_reused';
    end if;
    return v_place;
  end if;

  if v_locality_id is null then
    raise exception 'no_locality';
  end if;

  -- NaN and infinity fail the range tests, so they are refused here too.
  if p_mode is null
     or (p_mode = 'none'
         and (p_lat is not null or p_lng is not null or p_radius_m is not null
              or v_landmark is not null))
     or (p_mode <> 'none'
         and (p_lat is null or p_lng is null
              or not (p_lat between -90 and 90) or not (p_lng between -180 and 180)))
     or (p_mode = 'area' and (p_radius_m is null or p_radius_m not in (500, 1000, 2000)
                              or v_landmark is not null))
     or (p_mode = 'exact' and p_radius_m is not null) then
    raise exception 'place_invalid';
  end if;

  if p_mode <> 'none' then
    if v_bbox is not null
       and not (p_lng between v_bbox[1] and v_bbox[3] and p_lat between v_bbox[2] and v_bbox[4]) then
      raise exception 'place_out_of_country';
    end if;

    v_point := extensions.st_point(p_lng, p_lat, 4326)::extensions.geography;
    select extensions.st_point(l.lng, l.lat, 4326)::extensions.geography into v_centre
    from public.geo_localities l
    where l.id = v_locality_id;
    if v_centre is not null and not extensions.st_dwithin(v_point, v_centre, 30000) then
      raise exception 'place_too_far';
    end if;
  end if;

  begin
    update public.pro_places pl
       set place_mode = p_mode,
           place = v_point,
           area_radius_m = p_radius_m,
           landmark = v_landmark,
           updated_at = now()
     where pl.pro_id = v_pro_id;
  exception when check_violation then
    -- The landmark length / hygiene check lives on the column; the client gets one code.
    raise exception 'place_invalid';
  end;

  -- Re-read: pro_places_after_place has just set search_point.
  select pl.* into v_place from public.pro_places pl where pl.pro_id = v_pro_id;
  return v_place;
end;
$$;

-- Ledger pruning --------------------------------------------------------------------------------

-- Unchanged from 20261120000300_live_realtime.sql but for the last delete: the M3 daily job also
-- prunes the place ledger (same 2-day horizon).
create or replace function public.queue_end_of_day()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := public.live_now();
  v_pros uuid[];
  v_pro_id uuid;
  v_count integer;
begin
  perform 1
  from public.pro_live l
  where l.pro_id in (
    select e.pro_id
    from public.queue_entries e
    join public.pro_profiles p on p.id = e.pro_id
    join public.geo_countries c on c.code = p.country_code
    where e.state in ('waiting', 'serving')
      and e.service_day < public.service_day(v_now, c.timezone))
  order by l.pro_id
  for update;

  with ended as (
    update public.queue_entries e
       set state = 'cancelled', end_reason = 'end_of_day', ended_at = v_now
      from public.pro_profiles p
      join public.geo_countries c on c.code = p.country_code
     where p.id = e.pro_id
       and e.state in ('waiting', 'serving')
       and e.service_day < public.service_day(v_now, c.timezone)
    returning e.pro_id
  )
  select array_agg(distinct x.pro_id), count(*)::integer into v_pros, v_count from ended x;

  foreach v_pro_id in array coalesce(v_pros, '{}'::uuid[]) loop
    perform public.live_broadcast(v_pro_id, true);
  end loop;

  delete from public.queue_requests r where r.created_at < v_now - interval '2 days';
  delete from public.pro_place_requests r where r.created_at < v_now - interval '2 days';
  return v_count;
end;
$$;

-- RLS and grants --------------------------------------------------------------------------------

alter table public.pro_places enable row level security;
alter table public.pro_place_requests enable row level security;

revoke all on public.pro_places, public.pro_place_requests from anon, authenticated;
grant select on public.pro_places to authenticated;

create policy pro_places_select on public.pro_places
for select to authenticated
using (
  (select public.owns_pro(pro_id))
  or ((select public.is_listable(pro_id)) and not (select public.viewer_blocked(pro_id)))
);

revoke execute on function
  public.viewer_blocked(uuid),
  public.f_pro_search_point(uuid),
  public.pro_places_create(),
  public.pro_places_after_place(),
  public.pro_places_after_locality(),
  public.pro_places_after_locality_coords(),
  public.set_pro_place(uuid, public.place_mode, double precision, double precision, integer, text)
from public, anon;

revoke execute on function
  public.f_pro_search_point(uuid),
  public.pro_places_create(),
  public.pro_places_after_place(),
  public.pro_places_after_locality(),
  public.pro_places_after_locality_coords()
from authenticated;

grant execute on function
  public.viewer_blocked(uuid),
  public.set_pro_place(uuid, public.place_mode, double precision, double precision, integer, text)
to authenticated;
