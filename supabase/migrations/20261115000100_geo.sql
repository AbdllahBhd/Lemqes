-- Geo reference data: countries, their first-level regions and their localities.
--
-- Country-agnostic on purpose: Algeria fills it as country 'DZ' (regions = wilayas, localities =
-- communes) and a later country only adds rows. The data is public reference data, so everyone
-- (anon included) may read it; nobody writes it through the API, only migrations do.
--
-- geo_localities.id is the country's official locality code (the DZ commune code), not a
-- serial: barber addresses will reference it, and reseeding (e.g. better coordinates in M4) must
-- keep those references pointing at the same commune.

create table public.geo_countries (
  code text primary key check (code ~ '^[A-Z]{2}$'),
  name_ar text not null,
  name_fr text not null,
  name_en text not null,
  timezone text not null,
  currency text not null
);

create table public.geo_regions (
  country_code text not null references public.geo_countries,
  code text not null,
  -- Set when the region was split out of another one (DZ: the 2026 wilayas 59-69).
  parent_code text,
  name_ar text not null check (char_length(btrim(name_ar)) > 0),
  name_fr text not null check (char_length(btrim(name_fr)) > 0),
  primary key (country_code, code),
  foreign key (country_code, parent_code) references public.geo_regions (country_code, code)
);

create table public.geo_localities (
  id integer primary key,
  country_code text not null,
  region_code text not null,
  official_code text not null,
  name_ar text not null check (char_length(btrim(name_ar)) > 0),
  name_fr text not null check (char_length(btrim(name_fr)) > 0),
  lat double precision check (lat between -90 and 90),
  lng double precision check (lng between -180 and 180),
  unique (country_code, official_code),
  foreign key (country_code, region_code) references public.geo_regions (country_code, code)
);

create index geo_localities_region_idx on public.geo_localities (country_code, region_code);
create index geo_regions_parent_idx on public.geo_regions (country_code, parent_code)
  where parent_code is not null;

alter table public.geo_countries enable row level security;
alter table public.geo_regions enable row level security;
alter table public.geo_localities enable row level security;

revoke all on public.geo_countries, public.geo_regions, public.geo_localities
  from anon, authenticated;
grant select on public.geo_countries, public.geo_regions, public.geo_localities
  to anon, authenticated;

create policy geo_countries_select_all on public.geo_countries
  for select to anon, authenticated using (true);
create policy geo_regions_select_all on public.geo_regions
  for select to anon, authenticated using (true);
create policy geo_localities_select_all on public.geo_localities
  for select to anon, authenticated using (true);
