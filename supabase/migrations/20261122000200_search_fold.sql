-- Arabic folding and cross-script name search (M4 Task 2).
--
--   * f_search_fold(text): the one fold both sides of a search apply. Lower case, Latin accents
--     and apostrophes gone, hamza forms -> alef, ya/alef maqsura -> ya, ta marbuta -> ha, ؤ -> و,
--     ئ -> ي, harakat and tatweel removed, Arabic-Indic and Persian digits -> 0-9, punctuation
--     -> space, spaces collapsed.
--   * f_name_skeleton(text): a sound skeleton so "Amine" finds "أمين". The raw text has ة read as
--     "a" (before the fold would merge it into ه), then per word, on the fold: initial و/ي are w/y;
--     in a word after the first, the article ال (or a lone el/al) is "l"; Latin ou before a vowel
--     is w (Ouassim) but a vowel before a consonant (Oussama, Ouled); ch/sh, kh, gh, ph, dj, dh
--     and an initial th become one letter each; c before e/i/y is s and any other c or q is k;
--     Arabizi digits 3 7 9 5 2 read as ع ح ق خ ء; Arabic letters are read the Algerian-French way
--     (ش ch, ج dj, خ kh, غ gh, ق k, ع a); vowels (and w, y inside a word) are dropped but a word's
--     first vowel is kept as "a"; doubled letters collapse and spaces go.
--     supabase/tests/fold_vectors.json is the single table both this and the Dart port
--     (search_fold.dart) are tested against.
--   * pro_profiles.search_key / search_skeleton: stored from display_name + workplace_name, with
--     pg_trgm GIN indexes so a substring search does not scan the table.
--   * search_pros: same signature and columns; the match goes through the fold, skeleton-only
--     matches (query skeleton of 3+ letters) rank after fold matches.
--
-- Both functions are immutable so the stored columns and indexes can use them; they are not
-- security definer (f_unaccent already is), so a role that updates display_name needs execute.

create extension if not exists pg_trgm with schema extensions;

create function public.f_search_fold(p_text text)
returns text
language sql
immutable
parallel safe
strict
set search_path = ''
as $$
  select btrim(regexp_replace(
    regexp_replace(
      translate(
        regexp_replace(
          translate(lower(public.f_unaccent(p_text)), 'ɣ''’‘ʿʾʼ`', 'g'),
          '[\u064B-\u065F\u0670\u0640\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]', '', 'g'),
        'أإآٱةىؤئکی٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        'ااااهيويكي01234567890123456789'),
      '[!-/:-@[-`{-~\u00A1-\u00BF\u060C\u061B\u061F\u066A-\u066D\u06D4\u2010-\u2027\u2030-\u205E]',
      ' ', 'g'),
    '[\s\u00A0]+', ' ', 'g'));
$$;

create function public.f_name_skeleton(p_text text)
returns text
language plpgsql
immutable
parallel safe
strict
set search_path = ''
as $$
declare
  v_token text;
  v_n int := 0;
  v_out text := '';
begin
  -- ة is a final "a" (the fold would merge it into ه, which is a real h in Allah or Salah).
  for v_token in
    select t from regexp_split_to_table(public.f_search_fold(replace(p_text, 'ة', 'a')), ' ') as t
  loop
    v_n := v_n + 1;
    -- A word with no letter (a number) is kept as it is.
    if v_token !~ '[a-zء-ي]' then
      v_out := v_out || v_token;
      continue;
    end if;
    if v_n > 1 then
      -- Abdelkader / عبد القادر: the article is a bare l, not a kept first vowel.
      v_token := regexp_replace(v_token, '^ال(.)', 'l\1');
      v_token := regexp_replace(v_token, '^[ae]l$', 'l');
    end if;
    v_token := regexp_replace(v_token, '^و', 'w');
    v_token := regexp_replace(v_token, '^ي', 'y');
    v_token := regexp_replace(v_token, '^ou([aeiouy])', 'w\1');
    v_token := regexp_replace(v_token, '^th', 't');
    v_token := replace(v_token, 'ch', '#');
    v_token := replace(v_token, 'sh', '#');
    v_token := replace(v_token, 'kh', 'x');
    v_token := replace(v_token, 'gh', 'g');
    v_token := replace(v_token, 'ph', 'f');
    v_token := replace(v_token, 'dj', 'j');
    v_token := replace(v_token, 'dh', 'd');
    v_token := regexp_replace(v_token, 'c([eiy])', 's\1', 'g');
    v_token := translate(v_token, 'cq#37952', 'kkcahkxa');
    v_token := translate(v_token, 'اءبتثجحخدذرزسشصضطظعغفقكلمنهويپ', 'aabttjhxddrzscsdtzagfkklmnhuib');
    v_token := left(v_token, 1) || regexp_replace(substr(v_token, 2), '[aeiouyw]', '', 'g');
    v_token := regexp_replace(v_token, '^[aeiou]', 'a');
    v_token := regexp_replace(v_token, '([a-z])\1+', '\1', 'g');
    v_out := v_out || v_token;
  end loop;
  return v_out;
end;
$$;

alter table public.pro_profiles
  add column search_key text generated always as (
    public.f_search_fold(display_name || ' ' || coalesce(workplace_name, ''))
  ) stored,
  add column search_skeleton text generated always as (
    public.f_name_skeleton(display_name) || ' ' || public.f_name_skeleton(coalesce(workplace_name, ''))
  ) stored;

create index pro_profiles_search_key_trgm_idx
  on public.pro_profiles using gin (search_key extensions.gin_trgm_ops);
create index pro_profiles_search_skeleton_trgm_idx
  on public.pro_profiles using gin (search_skeleton extensions.gin_trgm_ops);

-- search_pros is security invoker, so the caller reads the two keys. They are a fold of
-- display_name and workplace_name, which the same rows already expose.
grant select (search_key, search_skeleton) on public.pro_profiles to authenticated;

revoke execute on function public.f_search_fold(text), public.f_name_skeleton(text)
  from public, anon;
grant execute on function public.f_search_fold(text), public.f_name_skeleton(text)
  to authenticated;

-- search_pros ------------------------------------------------------------------------------------

-- Body of 20261120000300 with the fold match: tier 0 = fold match (name, workplace or a service),
-- tier 1 = skeleton-only match on the name or workplace. The tier orders first; with no query
-- every row is tier 0 and the order is the one it was. A non-blank query that folds to nothing
-- ("%", "...") matches nothing.
-- The match is a union of id sets (one branch per index), not an OR over the row, so the two
-- trigram indexes can answer the name branches; the service branch scans, as service names are
-- not stored.
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
  is_verified boolean,
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
  page as (
    select p.id, p.kind, p.display_name, p.avatar_path, p.workplace_type, p.workplace_name,
           l.region_code, r.name_ar as region_name_ar, r.name_fr as region_name_fr,
           l.name_ar as locality_name_ar, l.name_fr as locality_name_fr, p.customer_mix,
           (select min(s.price_dzd) from public.pro_public_services(p.id) s) as min_price_dzd,
           p.is_verified, p.published_at, coalesce(m.tier, 0) as tier
    from public.pro_profiles p
    cross join qp
    left join matched m on m.id = p.id
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
      and (not qp.active or m.id is not null)
    order by coalesce(m.tier, 0), p.is_verified desc, p.published_at desc, p.id
    limit least(greatest(coalesce(p_limit, 30), 0), 50)
    offset least(greatest(coalesce(p_offset, 0), 0), 1000)
  )
  select g.id, g.kind, g.display_name, g.avatar_path, g.workplace_type, g.workplace_name,
         g.region_code, g.region_name_ar, g.region_name_fr, g.locality_name_ar,
         g.locality_name_fr, g.customer_mix, g.min_price_dzd, g.is_verified,
         (select s.live from public.pro_live_snapshots(array[g.id]) s)
  from page g
  order by g.tier, g.is_verified desc, g.published_at desc, g.id;
$$;
