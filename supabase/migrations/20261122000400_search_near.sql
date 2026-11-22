-- Near-me and map search (M4 Task 3b): one search_pros for the list and the map.
--
--   * New arguments, all default null so older callers keep working: p_origin_lat/p_origin_lng
--     (both or neither) and p_bbox = array[min_lng, min_lat, max_lng, max_lat]. The origin is a
--     search argument only; nothing stores it.
--   * One function for both views, so space, role, publish, filters and the blocked-viewer
--     shape cannot drift between them. pro_places is left-joined under its own RLS: a blocked
--     reader gets null place fields and no distance, sorts with the pros that have no point, and
--     is absent from a map view.
--   * List with an origin: match tier (only with a query), then distance to the origin (null
--     points last), then the old tiebreakers. Map (p_bbox given): only points inside, nearest the
--     view's centre first, 101 rows (a 101st means "zoom in"), p_limit and p_offset ignored.
--   * distance_m is display rounding (design G2): under 1 km, the nearest 100 m; from 1 km, the
--     nearest 500 m (1 260 -> 1 500, 2 260 -> 2 500); a none pro (its point is the commune
--     centre) in whole km. Never 0: the floor is one step (100 m, or 1 km for none), since "0 m"
--     would claim a precision no shown point has. Null without an origin.
--   * comes_to_you: a mobile pro whose service radius reaches the origin; false otherwise.
--
-- Why the body is a union of branches: a KNN scan of pro_places_search_point_idx needs
-- `order by search_point <-> <constant>` straight over pro_places, which the general order (tier
-- first, a left join, nulls last) cannot give. So the no-query origin list is its own branch (the
-- points, KNN-ordered, then the pros without a visible point), the map is another (KNN from the
-- view's centre), and every other call takes the general branch. The branches' gates are
-- parameter-only tests, so exactly one set runs; each is cut at limit + offset and the outer query
-- orders the union by one key.
-- The function is not inlined (its SET clause forbids it), so its statement is planned as a
-- generic plan over the parameters; 105-search-near N9 explains that statement.

-- The argument checks raise from plpgsql because search_pros must stay a stable SQL function
-- (its parameters must not be renamed or wrapped to stay plannable). Its parameters are not
-- named p_origin_*: 105 N8 asserts search_pros is the only function taking an origin.
-- Immutable: the result depends on the arguments only. Executable by authenticated because the
-- invoker search_pros calls it as the caller; anon cannot search at all.
create function public.search_args_check(
  p_lat double precision,
  p_lng double precision,
  p_bbox double precision[]
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  -- NaN fails every range test below (it sorts above all numbers in Postgres).
  if (p_lat is null) <> (p_lng is null)
     or (p_lat is not null
         and not (p_lat between -90 and 90 and p_lng between -180 and 180)) then
    raise exception 'origin_invalid';
  end if;
  if p_bbox is not null
     and (array_ndims(p_bbox) is distinct from 1
          or cardinality(p_bbox) <> 4
          or array_position(p_bbox, null) is not null
          or not (p_bbox[1] between -180 and 180 and p_bbox[3] between -180 and 180
                  and p_bbox[2] between -90 and 90 and p_bbox[4] between -90 and 90)
          or not (p_bbox[3] - p_bbox[1] > 0 and p_bbox[3] - p_bbox[1] <= 8)
          or not (p_bbox[4] - p_bbox[2] > 0 and p_bbox[4] - p_bbox[2] <= 8)) then
    raise exception 'bbox_invalid';
  end if;
  return true;
end;
$$;

drop function public.search_pros(text, text, integer, boolean, public.service_category, int, int);

create function public.search_pros(
  p_query text default null,
  p_region_code text default null,
  p_locality_id integer default null,
  p_kids boolean default null,
  p_category public.service_category default null,
  p_limit int default 30,
  p_offset int default 0,
  p_origin_lat double precision default null,
  p_origin_lng double precision default null,
  p_bbox double precision[] default null
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
  is_verified boolean,
  distance_m integer,
  place_mode public.place_mode,
  lat double precision,
  lng double precision,
  area_radius_m integer,
  landmark text,
  locality_id integer,
  comes_to_you boolean,
  live jsonb
)
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (
    select nullif(btrim(p_query), '') is not null as active,
           public.f_search_fold(nullif(btrim(p_query), '')) as fold,
           public.f_name_skeleton(nullif(btrim(p_query), '')) as skeleton
  ),
  qp as (
    select q.active, q.fold <> '' as folds, '%' || q.fold || '%' as pattern,
           case when char_length(q.skeleton) >= 3 then '%' || q.skeleton || '%' end as skel_pattern
    from q
  ),
  -- Unchanged from 20261122000200: fold matches are tier 0, skeleton-only matches tier 1.
  matched as (
    select u.id, min(u.tier) as tier
    from (
      select p.id, 0 as tier
      from qp, public.pro_profiles p
      where qp.active and qp.folds and p.search_key like qp.pattern
      union all
      select p.id, 1
      from qp, public.pro_profiles p
      where qp.active and qp.folds and p.search_skeleton like qp.skel_pattern
      union all
      select p.id, 0
      from qp, public.pro_profiles p
      cross join lateral public.pro_public_services(p.id) s
      left join public.service_presets sp on sp.key = s.preset_key
      where qp.active and qp.folds
        and p.published_at is not null
        and p.space = (select public.current_space())
        and public.f_search_fold(concat_ws(' ', s.name, sp.name_ar, sp.name_fr, sp.name_en,
                                           sp.name_kab)) like qp.pattern
    ) u
    group by u.id
  ),
  -- The listable pros under every filter but the text; inlined into each branch, so the KNN
  -- branches can drive the join from the index.
  base as not materialized (
    select p.id, p.kind, p.display_name, p.avatar_path, p.workplace_type, p.workplace_name,
           l.region_code, r.name_ar as region_name_ar, r.name_fr as region_name_fr,
           l.name_ar as locality_name_ar, l.name_fr as locality_name_fr, p.customer_mix,
           p.is_verified, p.published_at, p.locality_id, p.service_radius_km,
           pl.place_mode, pl.lat, pl.lng, pl.area_radius_m, pl.landmark, pl.search_point
    from public.pro_profiles p
    left join public.pro_places pl on pl.pro_id = p.id
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
  ),
  ranked as (
    -- No query, origin, list: the points, nearest first (KNN on pro_places_search_point_idx).
    (select b.*, 0 as tier,
            b.search_point operator(extensions.<->)
              extensions.st_point(p_origin_lng, p_origin_lat, 4326)::extensions.geography as sort_m
     from base b
     where nullif(btrim(p_query), '') is null and p_bbox is null
       and p_origin_lat is not null and p_origin_lng is not null
       and b.search_point is not null
     order by b.search_point operator(extensions.<->)
                extensions.st_point(p_origin_lng, p_origin_lat, 4326)::extensions.geography,
              b.is_verified desc, b.published_at desc, b.id
     limit least(greatest(coalesce(p_limit, 30), 0), 50)
           + least(greatest(coalesce(p_offset, 0), 0), 1000))
    union all
    -- ... then the pros with no visible point (no coordinates, or the reader is blocked).
    (select b.*, 0, null::double precision
     from base b
     where nullif(btrim(p_query), '') is null and p_bbox is null
       and p_origin_lat is not null and p_origin_lng is not null
       and b.search_point is null
     order by b.is_verified desc, b.published_at desc, b.id
     limit least(greatest(coalesce(p_limit, 30), 0), 50)
           + least(greatest(coalesce(p_offset, 0), 0), 1000))
    union all
    -- Map: the points inside the view, nearest its centre first. The && test is on the view
    -- padded by half a degree (a geography box follows great circles, which bow past the
    -- view's straight lat/lng edges) and serves the index; the lat/lng test is the exact one.
    (select b.*, 0,
            b.search_point operator(extensions.<->)
              extensions.st_point((p_bbox[1] + p_bbox[3]) / 2, (p_bbox[2] + p_bbox[4]) / 2,
                                  4326)::extensions.geography
     from base b
     cross join qp
     left join matched m on m.id = b.id
     where p_bbox is not null
       and (not qp.active or m.id is not null)
       and b.search_point operator(extensions.&&) extensions.st_makeenvelope(
             greatest(p_bbox[1] - 0.5, -180), greatest(p_bbox[2] - 0.5, -90),
             least(p_bbox[3] + 0.5, 180), least(p_bbox[4] + 0.5, 90), 4326)::extensions.geography
       and extensions.st_x(b.search_point::extensions.geometry) between p_bbox[1] and p_bbox[3]
       and extensions.st_y(b.search_point::extensions.geometry) between p_bbox[2] and p_bbox[4]
     order by b.search_point operator(extensions.<->)
                extensions.st_point((p_bbox[1] + p_bbox[3]) / 2, (p_bbox[2] + p_bbox[4]) / 2,
                                    4326)::extensions.geography,
              b.is_verified desc, b.published_at desc, b.id
     limit 101)
    union all
    -- Everything else: a list with a query, or without an origin.
    (select b.*, coalesce(m.tier, 0),
            b.search_point operator(extensions.<->)
              extensions.st_point(p_origin_lng, p_origin_lat, 4326)::extensions.geography
     from base b
     cross join qp
     left join matched m on m.id = b.id
     where p_bbox is null
       and (nullif(btrim(p_query), '') is not null
            or p_origin_lat is null or p_origin_lng is null)
       and (not qp.active or m.id is not null)
     order by coalesce(m.tier, 0),
              b.search_point operator(extensions.<->)
                extensions.st_point(p_origin_lng, p_origin_lat, 4326)::extensions.geography nulls last,
              b.is_verified desc, b.published_at desc, b.id
     limit least(greatest(coalesce(p_limit, 30), 0), 50)
           + least(greatest(coalesce(p_offset, 0), 0), 1000))
  ),
  page as (
    select g.*
    from ranked g
    order by g.tier, g.sort_m nulls last, g.is_verified desc, g.published_at desc, g.id
    -- The argument check sits in the limit: the executor evaluates it before fetching the first
    -- row, whichever branch runs and even for an empty page.
    limit case when public.search_args_check(p_origin_lat, p_origin_lng, p_bbox) then
            case when p_bbox is not null then 101
                 else least(greatest(coalesce(p_limit, 30), 0), 50) end
          end
    offset case when p_bbox is not null then 0
                else least(greatest(coalesce(p_offset, 0), 0), 1000) end
  )
  select g.id, g.kind, g.display_name, g.avatar_path, g.workplace_type, g.workplace_name,
         g.region_code, g.region_name_ar, g.region_name_fr, g.locality_name_ar,
         g.locality_name_fr, g.customer_mix,
         (select min(s.price_dzd) from public.pro_public_services(g.id) s),
         g.is_verified,
         case
           when d.m is null then null
           when g.place_mode = 'none' then greatest(1000, round(d.m / 1000) * 1000)
           when d.m < 1000 then greatest(100, round(d.m / 100) * 100)
           else round(d.m / 500) * 500
         end::integer,
         g.place_mode, g.lat, g.lng, g.area_radius_m::integer, g.landmark, g.locality_id,
         coalesce(g.workplace_type = 'mobile'
                  and extensions.st_dwithin(
                        extensions.st_point(p_origin_lng, p_origin_lat, 4326)::extensions.geography,
                        g.search_point, g.service_radius_km * 1000), false),
         (select s.live from public.pro_live_snapshots(array[g.id]) s)
  from page g
  cross join lateral (
    -- Measured on the spheroid (st_distance's default); the order uses the index's sphere
    -- distance, which differs by well under one display step.
    select extensions.st_distance(
             g.search_point,
             extensions.st_point(p_origin_lng, p_origin_lat, 4326)::extensions.geography) as m
  ) d
  order by g.tier, g.sort_m nulls last, g.is_verified desc, g.published_at desc, g.id;
$$;

revoke execute on function
  public.search_args_check(double precision, double precision, double precision[]),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int,
                     double precision, double precision, double precision[])
from public, anon;
grant execute on function
  public.search_args_check(double precision, double precision, double precision[]),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int,
                     double precision, double precision, double precision[])
to authenticated;
