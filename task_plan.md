# LEMQES Milestone 2 — Barber Profile, Photos & Services: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objective:** Milestone 2: barbers and home artists build a real public profile (photo, work photos, services with prices and durations, weekly hours, workplace in a wilaya/commune, accepted customers incl. kids), and customers browse and open the profiles of their own space, on Flutter 3.50.0 and the local Supabase stack.

**Architecture:** Same shape as M1 (Milestone 1 plan: git `8696eda:task_plan.md`). New Postgres entities own their space (`pro_profiles.space not null`), so every later milestone (status, queue, bookings, salons) keys on a profile row, not on a person. Customers read through one security-invoker search RPC and RLS that checks the caller's current space and active role; writes go through RLS + column grants (simple fields) or security-definer RPCs (creation, hours, publishing). Location data is generic (country → region → locality) and seeded for Algeria. Photos live in Supabase Storage with owner-only write policies.

**Tech Stack:** Flutter **3.50.0** (upgraded in Task 1) · supabase_flutter 2.18.x (Storage) · flutter_riverpod 3.x · go_router · image_picker · url_launcher · intl · pgTAP · Supabase CLI local stack.

**Spec:** [docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md](docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md) §4 step 2, §5, §6, §7, §7b · product truth [PRODUCT.md](PRODUCT.md) · design system [DESIGN.md](DESIGN.md) + surface brief `.impeccable/surfaces/flutter-app-lib.md` · prototype reference `app/src/main/java/com/example/ui/screens/{BarberHomeScreen,BarberProfileDetailScreen,CustomerExploreScreen}.kt`, `ui/components/{ProfilePhotoAndServicesComponents,BarberDiscoveryCard}.kt`, `RoleRegistrationForms.kt`, `HomeArtistRegistrationForm.kt`, `model/LemqesModels.kt`, `data/MockRepository.kt` (`buildServiceItemFromLabel`).

**Plan reviewed:** 2026-11-14 by an LLM council (5 advisors, anonymous peer review, chairman) — changes listed at the bottom.

## Decisions made with the user (2026-11-14)

- Customers get a **basic barber list in M2** (browse own space, open a profile); live status/queue added in M3.
- **Flutter 3.47.5 → 3.50.0** as the first task.
- Women's space label stays **"Femmes"**.
- The role-switch list may show roles of **both spaces** (account settings, not content).
- Location data: **69 wilayas, 1,541 communes** for Algeria, in a **country-agnostic** schema (Tunisia, Morocco, France later need data only).

## In scope / Out of scope

**In scope:** Flutter upgrade · generic geo tables + Algerian seed (69/1,541, Arabic + French names) · pro profiles for **barber** and **home artist** (one per person per role, with its own space) · profile photo + up to 9 work photos (Storage) · service catalogue presets per space/home + custom services (price DA, duration) · weekly opening hours with an optional break and past-midnight closing · accepted customers (adults / adults + kids / kids only) · privacy: phone visibility (public / hidden; "followers" stored, treated as hidden until M6) and hide prices · pro setup steps after sign-up and the same flow when a pro role is added later · pro dashboard ("Mon profil": preview + edit sections) replacing the M1 placeholder · customer explore list (search, wilaya/commune, kids, service category) + public profile screen with a call button when the phone is public · M1 carry-overs (Env guard, `initializeDateFormatting`, brightness-aware status inks, `full_name` trimming, search field straddling the explore header).

**Out of scope (later):** live status / queue / wait time (M3) · map pick, GPS point, distance, near-me (M4) · bookings and slots from hours (M5) · follow, reviews, ratings, broadcasts, discounts (M6) · salons, salon-owner setup (chairs, amenities), join requests, workplace linked to a salon (M7) · home-visit booking, covered zones (M8) · the queue privacy settings (hide queue count, followers-only queue join — M3) and follower approval (M6) · verified-badge workflow beyond a column only the Supabase dashboard can set · other countries' data · image moderation · customer interests / radar.

## Approach (decisions and why)

- **A pro profile is an entity, not a role flag.** `pro_profiles(id, owner_id, kind, space, …)` with `unique (owner_id, kind)`; `space` copied from `profiles.pro_space` at creation and never client-writable. Every later feature references `pro_profiles.id` (M1 council finding: tie space to the data, not the person).
- **Listed only when complete.** A profile appears to customers only when `published_at is not null`; `publish_pro_profile()` checks completeness (locality, customer mix, ≥ 1 active service, ≥ 1 open day). Removing the last active service or closing every day un-publishes automatically (trigger) and the dashboard says why.
- **Customers read through one RPC.** `search_pros(...)` (security invoker, so RLS still applies) returns card rows for the caller's current space; RLS on `pro_profiles` lets a non-owner read only published rows of `(select current_space())` while `(select acts_as('customer'))`. Owners always read their own rows.
- **Simple edits via RLS + column grants; structured edits via definer RPCs.** Profile text fields, services and photo rows: owner-only RLS, column grants, CHECK constraints. Creation (`create_pro_profile`), hours (`set_pro_hours`, atomic week replace with validation) and publishing are RPCs.
- **Opening hours** stored per weekday as **ISO 1 (Monday) … 7 (Sunday)** (matches Dart `DateTime.weekday` and Postgres `isodow`; the Saturday-first order is a display concern only), `opens`/`closes` as local `time`, one optional break (a break covers the split-shift case). A generated `crosses_midnight` column (`closes < opens`) marks past-midnight days, allowed up to `06:00` (Ramadan evenings); `opens = closes` is rejected. Wall-clock in the country's timezone (`geo_countries.timezone`, `Africa/Algiers`). Missing weekday = closed. Holidays/time-off and slot generation are M5.
- **Prices** integer DZD (`0..200000`), durations `5..300` min (prototype clamp). Display: Latin tabular digits, `intl` locale grouping, "DA".
- **Services are archived, never deleted** (`archived_at`), because M5 bookings will reference service rows; search, the 30-service cap and completeness count only non-archived active rows.
- **Service presets live in the DB** (`service_presets` with `name_ar/fr/en/kab`), seeded from the prototype catalogue, so presets are localized without ARB churn and later countries can add their own. Custom services carry one name typed by the pro (M1 name-hygiene rules apply).
- **Photos:** two public-read buckets, `avatars` and `work-photos`; object path **`<pro id>/<uuid>.jpg`** (never the account uid — `avatar_path` is returned to customers); `storage.objects` select/insert/update/delete for the owner only, checked by `exists (select 1 from public.pro_profiles where id = (storage.foldername(name))[1]::uuid and owner_id = (select auth.uid()))` (owner SELECT is required for `remove()`/upsert); `pro_photos.path` and `pro_profiles.avatar_path` must start with `<that pro id>/` (CHECK/trigger); client downsizes with `image_picker` (`maxWidth` 1600, `imageQuality` 82; avatar 800) and uploads JPEG; max 9 work-photo rows enforced in SQL (objects without a row are cleaned by the uploader's compensating delete; a periodic orphan sweep is out of scope). Bucket MIME/size limits are enforced by the Storage API and tested in the integration test, not pgTAP. Public read is acceptable: these photos are meant to be public, and paths carry no account id.
- **Search:** `create extension unaccent with schema extensions` plus an immutable wrapper `public.f_unaccent(text)`, used by `search_pros`, so Arabic letter folding later (M4, R6) is a one-function change. No trigram index yet (fine at M2 scale).
- **Geo seed source:** `ihahachi/algeria-cities` (MIT, 69 wilayas / 1,541 communes, Arabic + French), vendored at a pinned commit with its LICENSE under `supabase/data/geo/dz/`, converted by `scripts/geo/build_geo_sql.py` into a migration; the 11 new wilayas (59 Aflou … 69 El Abiodh Sidi Cheikh) are checked against the official decree (JO 2026 n° 40) and corrected through a documented patch file. `geo_regions.parent_code` keeps the pre-2026 wilaya for each new one.
- **Parallelism and order:** Task 1 (Flutter) ‖ Task 2 (geo, SQL only, in a worktree) run at the same time; the controller merges Task 2's branch before Task 3. Then strictly sequential: 3 schema → 4 data → 5 widgets → 6 setup → 7 explore + public profile (creates `/pro/:id`) → 8 dashboard (links to it) → 9 gate. During the parallel window only Task 2 runs `supabase` commands. Shared files have one owner at a time: `app_router.dart` (Tasks 6, 7, 8 in order), ARBs + REVIEW.md + generated l10n (every UI task), `pubspec.yaml/lock` (Tasks 1, 4).

## Global Constraints

- All M1 Global Constraints still bind (git `8696eda:task_plan.md` §Global Constraints): colours/type/48 dp/WCAG AA/RTL/no raw exceptions/craft-floor bans/ARB + REVIEW.md for every new string/`pubspec.lock` allowed in every fence/Conventional Commits ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. DESIGN.md is the design source of truth; read it before any UI work.
- Flutter **3.50.0** after Task 1, always via `scripts/sdk`; local Supabase on ports 553xx; never touch other projects' Docker stacks.
- **Space separation:** no customer-facing query, list, search result or profile ever returns a pro of another space — enforced in RLS and tested in pgTAP, not only in Dart.
- Every new SQL function `security definer set search_path = ''` (only `search_pros` is `security invoker`), fully qualified names, `revoke execute … from public, anon`, `grant … to authenticated`; policies wrap helpers as `(select …)`.
- Money: integer DZD only, never floats. Time: `time` + country timezone; never device-local assumptions in SQL.
- New free-text name columns get the M1 name-hygiene check (`display_name`, `workplace_name`, custom service `name`).
- Branch `feat/barber-profile` (from `develop`).

## Review Focus

1. **Space leak** — a customer in Femmes (or a pro browsing as customer in another space) never sees a Men pro: not through `search_pros`, a direct `select` on `pro_profiles`/`pro_services`/`pro_photos`/`pro_hours`, `pro_contact_phone`, or a guessed profile id. Pinned in Task 3 pgTAP and Task 9 integration.
2. **Someone else's photos/profile** — writing into another pro's Storage folder (real client, Task 9) or registering another pro's object path in `pro_photos`/`avatar_path`, editing another pro's services or hours, or setting `space`/`owner_id`/`published_at`/`is_verified` directly → denied. Pinned in Task 3 (pgTAP + storage policy tests).
3. **Typed numbers** — prices/durations typed with Eastern Arabic digits, spaces, `0`, empty, `999999`, `4` minutes → normalized or a clear inline error; shown back with Latin digits and "DA". Pinned in Task 4 (`price_parse_test.dart`) and Task 6 (`service_editor_test.dart`).
4. **Hours edge cases** — a day 14:00 → 01:00 (past midnight), a break outside opening hours, break end before start, every day closed → each accepted with the right display or rejected with a specific message, never silently saved wrong. Pinned in Task 3 (`set_pro_hours` pgTAP) and Task 6 (`hours_editor_test.dart`).
5. **Pro role without a profile** — a pro who killed setup midway, or added the barber role later from Settings, lands on a working "Complétez votre profil" path; never appears in customer lists until published. Pinned in Task 6 (`pro_setup_flow_test.dart`) and Task 3 (unpublished invisible).

---

## File structure (locked here)

```
scripts/geo/build_geo_sql.py                         # dataset → migration SQL (stdlib only)
supabase/data/geo/dz/{algeria_cities.json,LICENSE,SOURCE.md,patches.json}
supabase/migrations/20261115000100_geo.sql           # generic geo tables + RLS (hand-written)
supabase/migrations/20261115000110_geo_dz_seed.sql   # generated by the script
supabase/migrations/20261115000200_pro_profiles.sql  # types, pro_profiles, presets, services, hours, photos, RPCs, RLS, search
supabase/migrations/20261115000210_pro_storage.sql   # buckets + storage.objects policies
supabase/migrations/20261115000220_profile_name_trim.sql
supabase/migrations/20261115000230_service_presets_seed.sql
supabase/tests/database/030-geo.sql  040-pro-profiles.sql  050-pro-storage.sql  060-search-pros.sql
flutter_app/lib/
  core/config/env.dart                         # + guard
  core/l10n/intl_locale.dart                   # + date formatting init
  core/theme/status_colors.dart                # brightness-aware status inks
  features/geo/data/{geo_models,geo_repository,geo_providers}.dart
  features/geo/presentation/locality_picker.dart
  features/pro/data/{pro_models,pro_api,pro_repository,pro_providers,photo_uploader,price_parse}.dart
  features/pro/presentation/setup/{pro_setup_flow,profile_step,services_step,hours_step}.dart
  features/pro/presentation/edit/{service_editor,hours_editor,photo_gallery_editor,privacy_section}.dart
  features/pro/presentation/dashboard/pro_dashboard_screen.dart   # replaces home/pro_home_screen.dart
  features/explore/data/{explore_query,explore_providers}.dart
  features/explore/presentation/{explore_screen,pro_card,explore_filters}.dart
  features/explore/presentation/profile/pro_public_profile_screen.dart
  shared/widgets/{price_text,hours_table,photo_tile}.dart
flutter_app/test/ (mirrors lib/)  flutter_app/integration_test/pro_profile_flow_test.dart
```

---

### Task 0: Commit the plan

- [x] **Step 1:** `git add task_plan.md && git commit` with subject `docs: add milestone 2 barber profile plan` on `feat/barber-profile`.

**Done when:** (1) `git log -1 --format=%s` = `docs: add milestone 2 barber profile plan`; (2) nothing to run; (3) only `task_plan.md` changed.

---

### Task 1: Flutter 3.50.0 + M1 carry-overs  ‖ parallel with Task 2

**Files:** Modify `flutter_app/.fvmrc`, `pubspec.yaml`/`pubspec.lock`, `lib/core/config/env.dart`, `lib/bootstrap.dart`, `lib/core/l10n/{intl_locale,locale_controller}.dart`, `lib/core/theme/lemqes_theme.dart`, analyzer-driven fixes under `flutter_app/lib|test|integration_test`, regenerated goldens. Create `lib/core/theme/status_colors.dart`, tests.

**Interfaces — Produces:**
- `Env.assertConfigured()` — throws `StateError('Missing SUPABASE_URL / SUPABASE_ANON_KEY: run with --dart-define-from-file=env/local.json')` when either define is empty; `bootstrap()` calls it first.
- `Future<void> ensureDateFormatting(Locale l)` in `intl_locale.dart` — `initializeDateFormatting(intlLocaleFor(l))`; awaited in `bootstrap()` and on every `setLocale`.
- `class StatusColors extends ThemeExtension<StatusColors> { final Color open, onBreak, closed; }` in both themes (light = M1 tokens, dark = `openOnDark`…); `extension StatusColorsX on BuildContext { StatusColors get statusColors; }`.

- [x] **Step 1:** Install Flutter 3.50.0 into `~/fvm/versions/3.50.0` (`git clone --depth 1 --branch 3.50.0 https://github.com/flutter/flutter.git ~/fvm/versions/3.50.0`, then `~/fvm/versions/3.50.0/bin/flutter --version` and `flutter precache --android --linux`); confirm 3.50.0 is the current stable on https://docs.flutter.dev/release/archive and read its breaking-changes notes; set `.fvmrc` to `3.50.0`; raise the Dart SDK floor in pubspec to the bundled version; upgrade only packages the analyzer or resolver forces.
- [x] **Step 2: Failing tests:** `test/core/config/env_test.dart` (empty defines → `StateError` with the message above); `test/core/l10n/date_formatting_test.dart` (after `ensureDateFormatting(Locale('ar'))`, `DateFormat.EEEE(intlLocaleFor(Locale('ar'))).format(DateTime(2026,11,14))` returns the Arabic Saturday name; `kab` returns `samedi`); `test/core/theme/status_colors_test.dart` (dark `open`/`onBreak`/`closed` ≥ 4.5:1 on the dark surface; light `open == LemqesColors.open`).
- [x] **Step 3:** Implement; fix every analyzer finding; regenerate goldens with `--update-goldens` and **look at every changed PNG**; list them in the report.
- [x] **Step 4:** Commit `chore: upgrade to flutter 3.50.0 and close m1 carry-overs`.

**Done when:** (1) `scripts/sdk flutter --version` prints `Flutter 3.50.0`; `scripts/sdk flutter build apk --debug --dart-define-from-file=env/local.json` and `scripts/sdk flutter build linux --debug --dart-define-from-file=env/local.json` exit 0; the three new test files pass; every changed golden listed by path in the report; (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` pass (pgTAP and integration run in Task 3's gate, after the parallel window); (3) no repo files changed outside `flutter_app/` (the SDK itself installs into `~/fvm/versions/3.50.0`). If the `3.50.0` tag does not exist or is not the current stable, stop and report BLOCKED.

---

### Task 2: Generic geo tables + Algerian seed (69 / 1,541)  ‖ parallel with Task 1, in a worktree

**Files:** Create `scripts/geo/build_geo_sql.py`, `supabase/data/geo/dz/*`, `supabase/migrations/20261115000100_geo.sql`, `…000110_geo_dz_seed.sql` (generated), `supabase/tests/database/030-geo.sql`.

**Interfaces — Produces (SQL):**
- `geo_countries(code text primary key check (code ~ '^[A-Z]{2}$'), name_ar text not null, name_fr text not null, name_en text not null, timezone text not null, currency text not null)` — seeded `('DZ','الجزائر','Algérie','Algeria','Africa/Algiers','DZD')`.
- `geo_regions(country_code text references geo_countries, code text, parent_code text, name_ar text not null, name_fr text not null, primary key (country_code, code))` — DZ codes `'01'..'69'`; `parent_code` set for 59–69.
- `geo_localities(id integer primary key, country_code text not null, region_code text not null, official_code text not null, name_ar text not null, name_fr text not null, lat double precision, lng double precision, unique (country_code, official_code), foreign key (country_code, region_code) references geo_regions)`; index on `(country_code, region_code)`.
- RLS on all three: `select` for `anon, authenticated` `using (true)`; no write grants.
- `python3 -I scripts/geo/build_geo_sql.py --country DZ --source supabase/data/geo/dz/algeria_cities.json --patches supabase/data/geo/dz/patches.json --out supabase/migrations/20261115000110_geo_dz_seed.sql` — stdlib only, deterministic (sorted, no timestamps), exits non-zero if counts ≠ 69 / 1,541, a name is empty, or a code duplicates.

- [x] **Step 1:** Download the `ihahachi/algeria-cities` JSON at a pinned commit into a fresh empty temp dir; inspect it (fields, counts, sample Arabic/French names, whether lat/lng are per commune or per wilaya); copy the needed file + LICENSE into `supabase/data/geo/dz/`; write `SOURCE.md` (URL, commit SHA, date, license, field mapping, known gaps). Cross-check the commune list against `geoalgeria` (MIT) and note differences.
- [x] **Step 2:** Verify the 11 new wilayas (codes 59–69, Arabic + French names, parent wilaya) against the official decree (Journal Officiel 2026 n° 40 on joradp.dz); put corrections in `patches.json`; record what was verified and from which document in `SOURCE.md`. If the JO cannot be retrieved: keep the dataset's names exactly, write `verified: no` for 59–69 in `SOURCE.md`, flag it in the report (risk D7) — never invent or "fix" spellings from press articles. If any of 59–69 has **no** communes assigned in the dataset, stop and report NEEDS_CONTEXT (the user decides).
- [x] **Step 3: Failing pgTAP `030-geo.sql`:** DZ regions = 69; DZ localities = 1541; every region (incl. each of 59–69) has ≥ 1 locality; locality ids are stable (`id` = the dataset's official commune code, so M4 coordinate updates keep foreign keys); region `'16'` `name_fr = 'Alger'`; region `'68'` `name_fr = 'Bou Saâda'` with `parent_code = '28'`; anon can select; authenticated `insert into geo_regions` → 42501; no duplicate `official_code`.
- [x] **Step 4:** Write the hand migration + script, generate the seed, `supabase db reset`, `supabase test db` → PASS; `supabase db lint` clean.
- [x] **Step 5:** Commit `feat: add country-agnostic geo tables with algerian seed`.

**Done when:** (1) `030-geo.sql .. ok` with the assertions above; regenerating the seed and `git diff --exit-code supabase/migrations/20261115000110_geo_dz_seed.sql` shows no change; `SOURCE.md` names the pinned commit SHA and the JO verification outcome (`verified: yes|no`); (2) `supabase test db` all files pass; (3) no files changed outside `scripts/geo/`, `supabase/`.

---

### Task 3: Pro profiles, services, hours, photos — schema, RLS, RPCs, search

**Files:** Create migrations `…000200_pro_profiles.sql`, `…000210_pro_storage.sql`, `…000220_profile_name_trim.sql`, `…000230_service_presets_seed.sql`; tests `040-pro-profiles.sql`, `050-pro-storage.sql`, `060-search-pros.sql`; extend `supabase/tests/database/000-setup.sql` helpers if needed.

**Interfaces — Produces (SQL, `public`):**
- Types: `pro_kind ('barber','home_artist')`, `workplace_type ('salon','own_studio','mobile')`, `customer_mix ('adults','adults_and_kids','kids_only')`, `phone_visibility ('public','followers','hidden')`, `service_category ('hair','beard','coloring','nails','skincare','makeup','spa')`.
- `pro_profiles(id uuid primary key default gen_random_uuid(), owner_id uuid not null references profiles on delete cascade, kind pro_kind not null, space space not null, display_name text not null, bio text check (char_length(bio) <= 500), experience_years smallint check (experience_years between 0 and 60), workplace_type workplace_type not null, workplace_name text, country_code text not null default 'DZ' references geo_countries, locality_id integer references geo_localities, customer_mix customer_mix, service_radius_km smallint check (between 1 and 100), travel_fee_dzd integer check (between 0 and 200000), avatar_path text, phone_visibility phone_visibility not null default 'hidden', show_prices boolean not null default true, is_verified boolean not null default false, published_at timestamptz, created_at, updated_at, unique (owner_id, kind))`; name-hygiene checks on `display_name` (2–60 chars) and `workplace_name` (≤ 80).
- `service_presets(key text primary key, space space not null, home boolean not null, category service_category not null, name_ar, name_fr, name_en, name_kab text not null, default_price_dzd integer not null, default_duration_min smallint not null, sort smallint not null)` — select for authenticated; seeded (`…000230`) from the prototype catalogue (men/women × salon/home; prices/durations from `MockRepository.buildServiceItemFromLabel`).
- `pro_services(id uuid primary key default gen_random_uuid(), pro_id uuid not null references pro_profiles on delete cascade, preset_key text references service_presets, name text, category service_category not null, price_dzd integer not null check (between 0 and 200000), duration_min smallint not null check (between 5 and 300), active boolean not null default true, archived_at timestamptz, sort smallint not null default 0, check (preset_key is not null or name is not null))`; trigger: max 30 non-archived per pro → `too_many_services`; **no DELETE grant** (archive instead).
- `pro_hours(pro_id uuid references pro_profiles on delete cascade, weekday smallint check (weekday between 1 and 7), opens time not null, closes time not null, crosses_midnight boolean generated always as (closes < opens) stored, break_start time, break_end time, primary key (pro_id, weekday), check (opens <> closes), check (not (closes < opens) or closes <= '06:00'))` — ISO weekdays.
- `pro_photos(id uuid primary key default gen_random_uuid(), pro_id uuid not null references pro_profiles on delete cascade, path text not null unique, sort smallint not null default 0, created_at timestamptz not null default now(), check (path like pro_id::text || '/%'))`; trigger: max 9 per pro → `too_many_photos`. `pro_profiles.avatar_path` must be null or start with `id::text || '/'` (CHECK).
- Definer RPCs: `create_pro_profile(p_kind pro_kind, p_display_name text, p_workplace_type workplace_type) returns pro_profiles` (needs `has_role(kind)` → `role_not_held`; space = caller's `pro_space`; repeat → `pro_profile_exists`); `set_pro_hours(p_pro_id uuid, p_week jsonb) returns void` (owner only → `not_owner`; atomic replace with ISO weekdays; `opens = closes`, or past-midnight `closes > '06:00'` → `invalid_hours`; break inside the open span with `break_end > break_start` else `invalid_break`; runs the completeness/un-publish check **once, after** the replace — the row-level trigger must not un-publish mid-call); `publish_pro_profile(p_pro_id uuid) returns timestamptz` (owner only; needs locality, customer_mix, ≥ 1 active service, ≥ 1 hours row, else `profile_incomplete` with `detail` = comma list of `locality,customer_mix,services,hours`); `pro_contact_phone(p_pro_id uuid) returns text` (the owner's phone only when `phone_visibility = 'public'`, published, and in the caller's current space while acting as customer; else null).
- `search_pros(p_query text default null, p_region_code text default null, p_locality_id integer default null, p_kids boolean default null, p_category service_category default null, p_limit int default 30, p_offset int default 0) returns table (pro_id uuid, kind pro_kind, display_name text, avatar_path text, workplace_type workplace_type, workplace_name text, region_code text, region_name_ar text, region_name_fr text, locality_name_ar text, locality_name_fr text, customer_mix customer_mix, min_price_dzd integer, is_verified boolean)` — `security invoker`, `stable`, `p_limit` capped at 50; space = `(select current_space())`; published only; `min_price_dzd` null when `show_prices` is false; `p_kids = true` → mix in (`adults_and_kids`,`kids_only`); `p_query` matches display_name, workplace_name and non-archived active service names (preset names in all 4 languages, or custom name), case- and accent-insensitive through `public.f_unaccent()` (immutable wrapper over `extensions.unaccent`, created in this migration together with `create extension if not exists unaccent with schema extensions`); no phone numbers in the result; ordered `is_verified desc, published_at desc, id`.
- RLS: `pro_profiles` select = owner, or (`published_at is not null and space = (select current_space()) and (select acts_as('customer'))`); update = owner, column grants only on `display_name, bio, experience_years, workplace_type, workplace_name, locality_id, customer_mix, service_radius_km, travel_fee_dzd, avatar_path, phone_visibility, show_prices`; no insert/delete grants. `pro_services`: parent owner may select/insert/update (update grants exclude `pro_id`; archive via `archived_at`), no delete; `pro_photos`: parent owner may select/insert/delete (no update); customers select rows of listable pros (same predicate via `exists`). `pro_hours`: owner select; customers select rows of listable pros; writes only via `set_pro_hours`.
- Triggers (all `security definer`, since clients cannot write `published_at`): un-publish when the last active non-archived service is deactivated/archived; `set_pro_hours` performs its own post-replace check (no hours trigger); `updated_at`. A shared definer helper `is_listable(p_pro_id uuid) returns boolean` backs the child-table customer policies.
- Storage (`…000210`): buckets `avatars`, `work-photos` (`public = true`, `file_size_limit = 5242880`, `allowed_mime_types = {image/jpeg,image/png,image/webp}`); `storage.objects` **select**/insert/update/delete for `authenticated` only when the bucket is one of the two and `exists (select 1 from public.pro_profiles p where p.id::text = (storage.foldername(name))[1] and p.owner_id = (select auth.uid()))`.
- `…000220`: `before insert or update` trigger on `profiles` trimming `full_name`.
- Migration header: the M1 policy pattern plus "listable = published + same current space + acting as customer".

- [x] **Step 1: Failing pgTAP.** `040`: create with/without the role; repeat → `pro_profile_exists`; `space` copied from `pro_space`; updating `space`, `owner_id`, `published_at`, `is_verified` → 42501; `set_pro_hours`: normal day ok, 14:00→01:00 ok, 14:00→07:00 `invalid_hours`, break outside span `invalid_break`, break_end ≤ break_start `invalid_break`, non-owner `not_owner`; `publish_pro_profile` incomplete → `profile_incomplete` with the right detail, complete → timestamp; deleting the last service un-publishes; 31st service → `too_many_services`; customer in women space selects 0 men pros and 0 of their services/photos/hours; a user acting as barber selects 0 other pros; unpublished invisible to customers; owner sees own unpublished; another owner cannot insert services for my pro; deleting a service → 42501, archiving it works and hides it from search; `pro_photos` row with another pro's path → check violation; `avatar_path` with another pro's prefix → check violation; ISO weekday 0 or 8 → rejected; `opens = closes` → `invalid_hours`; `set_pro_hours` replacing a full week on a published profile keeps it published; anon → 42501 on every new function; `full_name` trimmed on update. `050` (SQL-level, as `authenticated` with the storage RLS): owner of pro P inserts `P/x.jpg` ok and can select/delete it; another user inserting or deleting under `P/` denied (and after the owner's select confirms the object exists, so the denial is real); 10th photo row → `too_many_photos`. (MIME and size limits are API-level → Task 9.) `060`: `search_pros` space isolation, kids filter, category filter, region/locality filters, query matches a preset name in Arabic and in French and a custom name, `Degrade` finds `Dégradé`, `show_prices = false` → `min_price_dzd` null, unpublished excluded, limit capped; `pro_contact_phone` rules (public/hidden/other space/unpublished).
- [x] **Step 2:** Write the migrations; `supabase db reset`; `supabase test db` → PASS; `supabase db lint` clean.
- [x] **Step 3:** Commit `feat: add pro profiles, services, hours and photo storage`.

**Done when:** (1) `040`, `050`, `060` ok, each file's `select plan(N)` matching its assertion count, with every case above; `supabase db lint` no errors; (2) full gate: `npm run lint`, `npm run typecheck`, `npm test`, `sh scripts/integration.sh` pass (first full run on Flutter 3.50.0 with Task 2 merged); (3) no files changed outside `supabase/`, except minimal fixes in `flutter_app/integration_test/` or `scripts/integration.sh` that the first 3.50 integration run requires (listed in the report).

---

### Task 4: Dart data layer — geo, pro, explore

**Files:** Create `lib/features/geo/data/*`, `lib/features/pro/data/*`, `lib/features/explore/data/*`, tests mirroring them. Modify `pubspec.yaml` (`image_picker`, `url_launcher`), `android/app/src/main/AndroidManifest.xml` (`<queries>` for `tel:`), `ios/Runner/Info.plist` (`NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`, `LSApplicationQueriesSchemes` `tel`).

**Interfaces — Produces:**
- Geo: `Region {String countryCode, code; String? parentCode; String nameAr, nameFr; String name(Locale l)}`, `Locality {int id; String regionCode, nameAr, nameFr; String name(Locale l)}` (`ar` → Arabic, others → French); `GeoRepository { Future<List<Region>> regions(String country); Future<List<Locality>> localities(String country, String regionCode); Future<Locality?> locality(int id); }` cached per session; `regionsProvider` (family by country), `localitiesProvider` (family by `(country, regionCode)`).
- Pro models: enums `ProKind`, `WorkplaceType`, `CustomerMix`, `PhoneVisibility`, `ServiceCategory` with `toDb/fromDb`; `ServicePreset`; `ProService {String id; String? presetKey; String? customName; ServiceCategory category; int priceDzd; int durationMin; bool active; String displayName(Locale l, Map<String, ServicePreset> presets)}`; `DayHours {int weekday; TimeOfDay opens, closes; TimeOfDay? breakStart, breakEnd; bool get pastMidnight}`; `ProPhoto {String id, path; int sort}`; `ProProfile {String id, ownerId; ProKind kind; Space space; String displayName; String? bio; int? experienceYears; WorkplaceType workplaceType; String? workplaceName; int? localityId; CustomerMix? customerMix; int? serviceRadiusKm, travelFeeDzd; String? avatarPath; PhoneVisibility phoneVisibility; bool showPrices, isVerified; DateTime? publishedAt; List<ProService> services; List<DayHours> hours; List<ProPhoto> photos; Set<ProfileGap> get gaps}` with `enum ProfileGap { locality, customerMix, services, hours }`.
- `ProProfilePatch` — immutable, all fields optional (`displayName, bio, experienceYears, workplaceType, workplaceName, localityId, customerMix, serviceRadiusKm, travelFeeDzd, avatarPath, phoneVisibility, showPrices`), `Map<String, Object?> toDb()` only with set fields; `ProServiceDraft {String? id; String? presetKey; String? customName; ServiceCategory category; int priceDzd; int durationMin; bool active}`.
- `abstract interface class ProApi` (thin Supabase adapter like `AccountApi`: `rpc(fn, params)`, `selectMine(kind)`, `selectPublic(proId)`, `update(table, id, values)`, `insert(table, values)`, `selectPresets(space, home)`) and `ProRepository { Future<ProProfile?> mine(ProKind kind); Future<ProProfile> create(ProKind kind, {required String displayName, required WorkplaceType workplaceType}); Future<void> updateProfile(String proId, ProProfilePatch patch); Future<ProService> upsertService(String proId, ProServiceDraft draft); Future<void> archiveService(String serviceId); Future<void> setHours(String proId, List<DayHours> week); Future<DateTime> publish(String proId); Future<String?> contactPhone(String proId); Future<ProProfile?> publicProfile(String proId); Future<List<ServicePreset>> presets(Space space, {required bool home}); }` mapping errors to `sealed class ProFailure` — `ProProfileExists`, `NotOwner`, `InvalidHours`, `InvalidBreak`, `ProfileIncomplete(Set<ProfileGap> gaps)`, `TooManyServices`, `TooManyPhotos`, `ProNetworkFailure`, `UnknownProFailure(String debug)` — same `_guard` pattern as `AccountRepository`.
- `PhotoUploader { Future<String> uploadAvatar(String proId, XFile file); Future<ProPhoto> addWorkPhoto(String proId, XFile file); Future<void> removeWorkPhoto(ProPhoto photo); String publicUrl(String bucket, String path); }` — path `<proId>/<uuid>.jpg`; removes the storage object if the row insert fails; the avatar is uploaded only after the profile exists (it needs `proId`).
- `myProProvider` (AsyncNotifier<ProProfile?> for the active pro role; refetch after each mutation; error keeps the previous value like `accountProvider`), `presetsProvider`.
- Explore: `ExploreQuery {String? text; String? regionCode; int? localityId; bool kidsOnly; ServiceCategory? category}`, `ProCard` (the `search_pros` columns), `exploreQueryProvider` (Notifier), `exploreResultsProvider` (AsyncNotifier, 30 per page, `loadMore()`, text debounced 300 ms, reset on query or space change).
- `price_parse.dart`: `int? parsePriceDzd(String input)` (Eastern Arabic/Persian digits, spaces, NBSP stripped; null when empty, non-integer or > 200000), `int? parseDurationMin(String input)` (5..300), `String formatDzd(int v, Locale l)` (Latin digits, locale grouping, " DA").

- [x] **Step 1: Failing tests:** `price_parse_test.dart` (`'1 500'`→1500, `'١٥٠٠'`→1500, `''`→null, `'0'`→0, `'999999'`→null, `'12.5'`→null; duration `'4'`→null, `'5'`→5, `'300'`→300, `'301'`→null; `formatDzd(1500, Locale('ar'))` has Latin digits); `pro_repository_test.dart` (mock `ProApi`: every SQL error string → its `ProFailure`; `profile_incomplete` detail → gap set; network → `ProNetworkFailure`); `geo_repository_test.dart` (cache avoids a second call; `name(Locale('ar'))` Arabic, `kab` French); `photo_uploader_test.dart` (path shape; cleanup when the row insert fails); `explore_providers_test.dart` (query change resets the page, `loadMore` appends, debounce, space change reloads); `pro_providers_test.dart` (mutation refetches; failure keeps value).
- [x] **Step 2:** Implement; PASS; commit `feat: add geo, pro and explore data layers`.

**Done when:** (1) the six test files named in Step 1 pass (`price_parse`, `pro_repository`, `geo_repository`, `photo_uploader`, `explore_providers`, `pro_providers`); every `ProFailure` mapping uses the exact error strings raised in Task 3's migration (grep them); (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` pass; (3) no files changed outside `flutter_app/lib/features/{geo,pro,explore}/data/`, matching `test/` dirs, `flutter_app/pubspec.yaml`, the AndroidManifest and Info.plist named above.

---

### Task 5: Shared pickers and display widgets

**Files:** Create `lib/features/geo/presentation/locality_picker.dart`, `lib/shared/widgets/{price_text,hours_table,photo_tile}.dart`, tests + goldens; ARB keys + REVIEW.md.

**Interfaces — Produces:**
- `LocalityPicker({required String country, String? regionCode, int? localityId, required void Function(String regionCode, int localityId) onChanged})` — two searchable sheets (wilaya, then commune), searching Arabic and French names with accents ignored, `"16 · Alger"` codes in `Ltr`, 48 dp rows, loading/empty/error states.
- `PriceText(int dzd)` (tabular Latin digits, "DA", `Ltr`), `HoursTable(List<DayHours> week)` (Saturday first, "Fermé" for closed days, "14:00 – 01:00" past midnight, break on a second line, today highlighted with the pill tint), `PhotoTile({required String url, VoidCallback? onRemove})` (network image with placeholder + error state, 1:1, radius 16).

- [x] **Step 1: Failing widget tests:** picker search "bou saada" (accents ignored) and an exact Arabic substring of region 68's dataset name both find region 68 (Arabic letter folding is M4, R6); region then commune calls `onChanged('68', id)`; `HoursTable` shows "Fermé" for a missing day and the past-midnight range; `PriceText` Latin digits under `ar`; 200 % text in `ar` → no overflow for all four. Goldens: `HoursTable` and picker sheet × light/dark × fr/ar — inspect.
- [x] **Step 2:** Implement; PASS; commit `feat: add locality picker and profile display widgets`.

**Done when:** (1) the widget tests pass; every golden listed by path in the report; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/geo/presentation/`, `flutter_app/lib/shared/widgets/`, `flutter_app/lib/core/l10n/` (ARBs, REVIEW.md, generated output), matching `test/` dirs.

---

### Task 6: Pro setup flow and editors

**Files:** Create `lib/features/pro/presentation/setup/*`, `lib/features/pro/presentation/edit/{service_editor,hours_editor}.dart`, tests + goldens. Modify `lib/core/router/{app_router,redirect}.dart` (+ tests), `lib/features/signup/presentation/signup_wizard.dart` (step total), ARBs + REVIEW.md.

**Behaviour:**
- Route `/pro/setup/:step` (`profile`, `services`, `hours`) for the active pro role. Entered (a) right after sign-up completion for pro roles — the wizard's `StepProgress` total becomes 7 for pros (space, role, credentials, code, profile, services, hours) and stays 4 for customers — (b) right after a pro role is added from the role-switch sheet, and (c) from the dashboard's "Complétez votre profil" (wired in Task 8). Pure redirect rule (tested in `redirect_test.dart`): after sign-up completion a pro goes to `/pro/setup/profile`; later, a pro without a published profile opening `/home` is **not** forced into setup (setup is offered on the dashboard, not imposed).
- **Profile step:** avatar (optional), display name (prefilled from the account name), experience chips (`<2`, `2–5`, `5–10`, `10+` stored 1/3/7/12 like the prototype), workplace type (salon / own studio / mobile; home artists fixed to mobile), workplace name (optional), `LocalityPicker`, customer mix (3 choice cards worded by space: "Hommes", "Hommes et enfants", "Enfants seulement" / Femmes variants), home artists also: radius chips 5/10/20/30 km and travel fee chips 0 ("Offert")/300/500/800 DA. First save → `create`, later saves → `updateProfile`.
- **Services step:** preset chips for the pro's space and kind (home artists see home presets); tapping one opens `ServiceEditor` prefilled with the preset's price/duration; "Ajouter un service personnalisé" opens it empty (name required). At least one active service to continue.
- **Hours step:** `HoursEditor` — per weekday open switch, opens/closes 24 h pickers (`Ltr`), optional break, "Copier sur tous les jours"; client validation mirrors the SQL rules with specific messages; save → `setHours` → `publish`; `ProfileIncomplete` jumps to the first missing step with a message; success → `/home`.
- Each step saves to the server on "Continuer"; killing the app mid-setup resumes at the first step with a gap.

- [x] **Step 1: Failing tests:** `pro_setup_flow_test.dart` (pro after code → `/pro/setup/profile`; customer → `/home`; resume at first gap; pro role added later from the role sheet → `/pro/setup/profile`; publish success → `/home`; `ProfileIncomplete({hours})` → hours step with message); `service_editor_test.dart` (Review Focus 3 through the UI); `hours_editor_test.dart` (Review Focus 4: past midnight accepted and displayed, break outside span error, all-closed blocks publishing with a message, copy-to-all); `redirect_test.dart` additions; 200 % `ar` no-overflow for the three steps. Goldens: profile step and hours step × light/dark × fr/ar — inspect.
- [x] **Step 2:** Implement; PASS; ui-quality self-review; commit `feat: add pro profile setup flow and editors`.

**Done when:** (1) the listed test files pass; every golden listed by path in the report; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/pro/` (presentation, plus data-layer fixes the UI exposes), `flutter_app/lib/core/router/`, `flutter_app/lib/features/signup/presentation/`, `flutter_app/lib/features/account/presentation/role_switch_sheet.dart`, `flutter_app/lib/core/l10n/`, matching `test/` dirs.

---

### Task 7: Customer explore list + public profile

**Files:** Create `lib/features/explore/presentation/*`, tests + goldens. Modify `customer_home_screen.dart` (body → `ExploreScreen`), `app_router.dart` (`/pro/:id`), ARBs + REVIEW.md.

**Behaviour:**
- **Explore** (replaces the M1 empty state): header band keeps wordmark, space switch and actions; a search field **straddles the band's lower edge** (DESIGN.md first viewport); filter row: wilaya/commune chip (opens `LocalityPicker`), "Enfants" chip, category chips (only categories present in this space's presets); results as `ProCard`s: avatar (or initials tile), name + verified tick, workplace type word + name, "Commune · Wilaya", kids tag when accepted, "À partir de 600 DA" (`PriceText`) or "Prix au salon" when hidden; infinite scroll; states: no-match ("Aucun barbier ne correspond" + clear filters), empty space ("Les barbiers arrivent bientôt"), loading skeleton, error with retry. No status, queue, distance or rating yet — and no placeholders for them.
- **Public profile `/pro/:id`:** hero (avatar, name, verified, kind + experience, workplace, commune · wilaya), bio, customer mix, "Appeler" only when `contactPhone` returns a number (`url_launcher` `tel:`, number in `Ltr`), services with `PriceText` (or "Prix au salon"), `HoursTable`, photo grid → full-screen viewer with swipe. Unknown or not-listed id → designed "Profil indisponible" state.

- [x] **Step 1: Failing tests:** `explore_screen_test.dart` (results render; filters update the query; empty vs no-match states; error retry; switching space reloads); `pro_card_test.dart` (hidden prices; kids tag; Arabic names under `ar`); `pro_public_profile_screen_test.dart` (call button only with a phone; unavailable state; photo viewer opens); 200 % `ar` no-overflow. Goldens: explore with 3 cards and the public profile × light/dark × fr/ar — inspect.
- [x] **Step 2:** Implement; PASS; commit `feat: add customer explore list and public pro profile`.

**Done when:** (1) the three test files pass; every golden listed by path in the report; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/{explore,home}/presentation/`, `flutter_app/lib/core/router/app_router.dart`, `flutter_app/lib/core/l10n/`, matching `test/` dirs.

---

### Task 8: Pro dashboard ("Mon profil")

**Files:** Create `lib/features/pro/presentation/dashboard/pro_dashboard_screen.dart`, `lib/features/pro/presentation/edit/{photo_gallery_editor,privacy_section}.dart`, tests + goldens. Modify `lib/features/home/presentation/home_screen.dart` (pro branch → dashboard); delete `pro_home_screen.dart` and its tests/goldens; ARBs + REVIEW.md.

**Behaviour:** Lagoon header band with avatar (tap → change), display name, space label, verified tick if set, role-switch + settings actions (M1 keys kept). Body: a visibility card ("Publié" / "Masqué" + reasons from `gaps`, "Compléter" action), then sections: Profil (edit → the profile step in edit mode), a "Compléter" action → `/pro/setup/<first gap>`, Services (list with `PriceText`; add/edit/deactivate via `ServiceEditor`), Horaires (`HoursTable` + edit via `HoursEditor`), Photos (`PhotoGalleryEditor`: grid of up to 9 `PhotoTile`s, add via picker, remove with confirm, upload progress, per-photo retry), Confidentialité (`PrivacySection`: phone public/hidden, "abonnés" shown disabled with "bientôt"; show-prices switch), and "Voir mon profil public" → the public profile screen (Task 7) in owner preview. Failures surface through a `ProFailureListener` built like `AccountFailureListener`.

- [x] **Step 1: Failing tests:** `pro_dashboard_screen_test.dart` (unpublished shows reasons + action; published shows "Publié"; deactivating the last service shows "Masqué" after refetch; failures show a snackbar and keep content); `photo_gallery_editor_test.dart` (10th add disabled with a message; remove asks to confirm; upload failure shows retry); `privacy_section_test.dart` (toggles call `updateProfile` with the right patch). Goldens: dashboard published/unpublished × light/dark × fr/ar — inspect.
- [x] **Step 2:** Implement; PASS; commit `feat: add pro dashboard with photos and privacy`.

**Done when:** (1) the three test files pass; every golden listed by path in the report; `grep -rn "ProHomeScreen\|pro_home_screen" flutter_app/lib flutter_app/test` finds nothing; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/{pro,home}/presentation/`, `flutter_app/lib/core/router/app_router.dart`, `flutter_app/lib/core/l10n/`, matching `test/` dirs.

---

### Task 9: Integration path, finish review, milestone gate

**Files:** Create `flutter_app/integration_test/pro_profile_flow_test.dart`; modify `scripts/integration.sh` (run both files), `DESIGN.md`, `CLAUDE.md` (architecture notes), `task_plan.md` (ticks + Gate log).

- [x] **Step 1:** Integration test against the local stack: sign up a **women** barber (0550000002) → setup: commune in Bou Saâda (68), adults + kids, two presets + one custom service (price typed with Arabic digits), hours Sat–Thu 09:00–19:00 with a 13:00–14:00 break and Friday closed, one work photo uploaded from bytes through `PhotoUploader` (picker bypassed), publish → dashboard "Publié". Sign out; sign up a **men** customer (0550000003) → explore: the women barber is **not** listed; switch to Femmes → listed; kids filter keeps it; region 68 keeps it; open the profile → services, hours, photo visible; phone hidden → no call button. Real-client RLS: back in Hommes, a direct `select` on `pro_profiles` by the barber's id returns 0 rows; as the barber, `update pro_profiles set space = 'men'` fails. Also, with the real client: uploading into another pro's folder fails, and an upload with a disallowed MIME type or over 5 MB is rejected by the Storage API. `scripts/integration.sh` resets the DB before **each** integration file. Run `sh scripts/integration.sh` twice in a row.
- [x] **Step 2:** Run the app, capture explore, public profile, setup steps and dashboard in fr-light and ar-dark; impeccable finish review against DESIGN.md + the direction contract; fix; add the new components (ProCard, HoursTable, LocalityPicker, PhotoTile, editors) to DESIGN.md.
- [ ] **Step 3:** Full gate (lint, typecheck, `npm test`, integration ×2) → Gate log; `security-auditor` (Storage policies and paths, RLS, `search_pros`, `pro_contact_phone` scraping risk) and whole-branch `code-reviewer` in parallel; one fix wave; re-review; ask the user before merging `feat/barber-profile` → `develop` (`--no-ff`); propose M3.

**Done when:** (1) two consecutive integration runs pass both files; DESIGN.md lists the new components; the Gate log row at the merge commit is all green; a findings table in the report has one disposition per finding (fixed + commit, or ruled + reason); (2) same full gate; (3) no files changed outside `flutter_app/`, `scripts/integration.sh`, `DESIGN.md`, `CLAUDE.md`, `task_plan.md`, `.impeccable/`, `supabase/` (review fixes), and fixes inside paths fenced by Tasks 1–8.

---

### Follow-up F1: separate pro contact phone, capped search paging (decided 2026-11-19)

**Why:** the M2 security audit showed a customer's space is self-chosen, so "only same-space customers" does not limit `pro_contact_phone`; and it returned the pro's **login** number. Space stays a preference (decision); the fix stops exposing login identities and bounds bulk paging. Rate limiting stays with the hosted setup (R3).

**Files:** new migration `supabase/migrations/20261119000100_pro_contact_phone.sql`; `supabase/tests/database/040-pro-profiles.sql`, `060-search-pros.sql`; `flutter_app/lib/features/pro/data/{pro_models,pro_api,pro_repository}.dart` (+ tests); `flutter_app/lib/features/pro/presentation/edit/privacy_section.dart`, dashboard wiring, ARBs + REVIEW.md (+ tests); `flutter_app/integration_test/pro_profile_flow_test.dart`; `DESIGN.md` (PrivacySection).

**Behaviour:**
- `pro_profiles.contact_phone text`: null or an Algerian mobile in E.164 (`^\+213[567][0-9]{8}$`); owner-writable through the column grant; never selectable by customers directly.
- CHECK `phone_visibility <> 'public' or contact_phone is not null`; existing `public` rows without a number become `hidden` in the migration.
- `pro_contact_phone(p_pro_id)` returns `contact_phone` (never `auth.users.phone`) under the same conditions as before (published, caller's current space, acting as customer, visibility public).
- `search_pros`: `p_offset` clamped to `0..1000` (`p_limit` still capped at 50).
- Privacy section: choosing "Visible" asks for the contact number (empty field, not prefilled with the login number; Algerian mobile in local or +213 form, same parser as sign-up). An invalid or empty number shows an inline error and saves nothing; switching to "Masqué" keeps the stored number; the number is shown in `Ltr`.

**Done when:** (1) pgTAP: contact_phone format CHECK, public-without-number refused, `pro_contact_phone` returns the contact number and never the login number (fixture makes them differ), customers cannot select `contact_phone`, offset clamp; widget tests for the privacy flow (valid, invalid, empty, Eastern Arabic digits, hiding keeps the number); integration: the barber sets a public contact number different from her login, and the Femmes customer sees the call button with that number; (2) `npm run lint`, `npm run typecheck`, `npm test`, `sh scripts/integration.sh` x2 pass; (3) no files changed outside the list above (+ matching test dirs, `pubspec.lock` if needed).

---

## Risks & open questions

| # | What | Why it matters | Decision (recommended first) | Relation | Cost |
|---|---|---|---|---|---|
| D7 | Official names of the 11 new wilayas | Press sources disagree on spellings; wrong names in a public picker look careless | A: verify against JO 2026 n° 40 in Task 2; if unreachable, keep the dataset's names unchanged with `verified: no` in `SOURCE.md` and recheck against the JO before M5 — never invent spellings (recommended) · B: hide wilayas 59–69 until verified | [NEEDED for the plan — Task 2] | 30–60 min |
| R7 | `pro_contact_phone` could be called in a loop to collect public phone numbers | Space is self-chosen (audit 2026-11-19), so any account can reach the women's space; scraping/harassment | F1: return a separate contact number (never the login), cap search paging; space stays a preference (decision 2026-11-19); rate-limit with the hosted setup (R3) before any hosted release | [NEEDED for the plan — F1 now, rate limit before hosting] | F1: 1–2 h |
| R8 | Orphan Storage objects (upload succeeded, row insert failed and compensating delete also failed) | Wasted storage, not a leak (paths carry no account id) | A: accept; periodic sweep later (recommended) | [FUTURE idea] | 1 h |
| R4 | Commune coordinates may be wilaya centroids in the dataset | Distance/near-me (M4) needs real commune points | A: accept for M2 (no distance shown); geocode from OSM/Wikidata in M4 (recommended) | [FUTURE idea — M4] | M4: 2 h |
| R5 | Public-read photo buckets | Anyone with a URL can fetch a pro's photos | A: accept — these photos are meant to be public; owner-only writes (recommended) · B: signed URLs (more requests, harder caching) | [SIDE FIX — safe to defer] | — |
| R6 | Arabic search quality (diacritics, alef/hamza, ta marbuta) | Arabic queries may miss results | A: `unaccent` + lower now; Arabic letter folding with M4 search work (recommended) | [FUTURE idea — M4] | 1 h |
| D1–D6, R1–R3 | Carried from M1: app id, native text review, SMS provider, password length, one pro space per person, muted grey, Kabyle Material fallback, data-protection law, hosted-auth hardening | See git `8696eda:task_plan.md` | Unchanged — all due before M5 | [NEEDED for the plan — before M5] | — |

## Roadmap (each gets its own detailed plan here when it starts)

M1 foundation ✅ (merged `f7263e0`) · **M2 barber profile, photos, services, explore (this plan)** · M3 live status + queue (Realtime) · M4 map + near-me, workplace pick, commune coordinates, Arabic search folding · M5 bookings (slots from M2 hours), reminders, −15 min auto-cancel → **first store release** (wallet off) · M6 follow, broadcasts, discounts, reviews, phone visibility "abonnés" · M7 salons + join requests, salon-owner setup · M8 home visits, covered zones · M9 finance · M10 wallet, store purchases, rewarded ads (free month starts here) · M11 QR + deep links · M12 push polish.

## Gate log

| Commit | lint | typecheck | flutter test | supabase test db | integration | Notes |
|---|---|---|---|---|---|---|
| 5c821cd (M1 merge gate) | ✅ | ✅ | ✅ 256 | ✅ 65 | ✅ ×2 | Milestone 1 baseline. |
| 7514d8c (M2 pre-merge gate) | ✅ | ✅ | ✅ 572 | ✅ 231 | ✅ ×3 | After security audit + whole-branch review fix wave; integration flakes root-caused (0916534, 7514d8c). |

## Plan review (2026-11-14, LLM council) — what changed

- **Storage:** paths `<pro id>/<uuid>.jpg` (no account uid exposed), owner check by join to `pro_profiles`, owner SELECT policy (needed for delete/upsert), path-prefix checks on `pro_photos.path` and `avatar_path`, MIME/size limits tested in the integration test.
- **Hours:** ISO weekdays 1–7, generated `crosses_midnight`, `opens = closes` rejected, publish check once after the atomic replace; time-off/holidays left to M5.
- **Services:** archived (`archived_at`), never deleted — M5 bookings will reference them.
- **Search:** `unaccent` created with an immutable `f_unaccent()` wrapper; Arabic folding stays M4 (picker test no longer expects it).
- **Triggers** that un-publish are security definer; child-table policies share `is_listable()`.
- **Order:** explore + public profile (Task 7) now come before the dashboard (Task 8) that links to it; setup tests stop at `/home`.
- **Fences/Done-whens:** Flutter build proof in Task 1; seed equals regenerated output; each of wilayas 59–69 must have communes (else ask); `plan(N)` counts; goldens listed by path; Android/iOS config in Task 4's fence; DB reset before each integration file; findings table at the gate.
- **Declined as scope creep:** a separate "listed" intent flag (pausing is M3's offline status), time-off table, per-date intervals function, `salon_id` reserve, currency-generic price columns, thumbnails, trigram index.

---

`/goal every task in task_plan.md is checked off per its own "Done when", and npm run lint, npm run typecheck, npm test and scripts/integration.sh all pass`
