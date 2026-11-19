-- Follow-up F1 (M2 security audit, 2026-11-19): a customer's space is self-chosen, so the
-- same-space condition does not limit who can call pro_contact_phone. It must therefore never hand
-- out the pro's login number: pros now give a separate contact number, and search paging is
-- bounded so listings cannot be walked without end.

alter table public.pro_profiles
  add column contact_phone text
    constraint pro_profiles_contact_phone_format
      check (contact_phone is null or contact_phone ~ '^\+213[567][0-9]{8}$');

-- Before this migration a public phone meant the login number; none of those rows has a contact
-- number yet, so they stop showing a phone until the pro enters one.
update public.pro_profiles
   set phone_visibility = 'hidden'
 where phone_visibility = 'public'
   and contact_phone is null;

alter table public.pro_profiles
  add constraint pro_profiles_public_phone_has_number
    check (phone_visibility <> 'public' or contact_phone is not null);

-- Writable by the owner (RLS pro_profiles_update_own). No SELECT grant: column grants are per
-- role, and owners and customers are both `authenticated`, so a grant would let any customer who
-- can list the profile read the number whatever its visibility. Owners read it through
-- own_pro_contact_phone, customers through pro_contact_phone.
grant update (contact_phone) on public.pro_profiles to authenticated;

-- 'followers' is reserved for a later milestone and returns null for now.
create or replace function public.pro_contact_phone(p_pro_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.contact_phone
  from public.pro_profiles p
  where p.id = p_pro_id
    and p.phone_visibility = 'public'
    and public.is_listable(p.id);
$$;

-- The caller's own contact number, whatever its visibility; null for anyone else's profile.
create function public.own_pro_contact_phone(p_pro_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.contact_phone
  from public.pro_profiles p
  where p.id = p_pro_id
    and p.owner_id = auth.uid();
$$;

-- Same body as 20261115000200_pro_profiles.sql but for the offset cap: with the limit capped at
-- 50, an unbounded offset still let a caller page through every listing.
create or replace function public.search_pros(
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
  offset least(greatest(coalesce(p_offset, 0), 0), 1000);
$$;

revoke execute on function
  public.pro_contact_phone(uuid),
  public.own_pro_contact_phone(uuid),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int)
from public, anon;

grant execute on function
  public.pro_contact_phone(uuid),
  public.own_pro_contact_phone(uuid),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int)
to authenticated;
