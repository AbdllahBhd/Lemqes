# LEMQES Milestone 4 — Map, Near-me, Workplace Place, Commune Coordinates, Arabic Search: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objective:** Milestone 4: customers find pros nearest first on a list or a map inside their own space, each pro shows exactly the location they chose (pin, area or commune only), commune coordinates are checked and corrected, and Arabic search folds letters and matches across scripts — all at zero running cost.

**Architecture:** Same shape as M1–M3. Business rules in Postgres: a `pro_places` table (one row per pro) written only by a definer RPC and readable only through block-aware RLS (owner, or a listable pro that has not blocked the reader); a trigger-maintained `search_point` (shown place, else commune centre) with a GiST index; `search_pros` (still `security invoker`, `stable`, language SQL) extended with origin, map bounds, match tiers and distance, so list and map share one function and every M3 invariant. The customer's origin is a call parameter, never written. Client: `flutter_map` + OpenFreeMap vector tiles through `vector_map_tiles`, isolated in `LemqesBaseMap`; location behind `DeviceLocation` (geolocator + a fake).

**Tech Stack:** Flutter 3.50.0 · flutter_map 8.3.2 · vector_map_tiles 9.0.0-beta.13 (+ vector_tile_renderer 6.1.0) · (no `flutter_map_marker_cluster`: incompatible `latlong2`, spike finding (a); clustering is a pure grid function) · geolocator 14.1.2 · url_launcher 6.3.3 · shared_preferences (existing `core/storage/`) · flutter_riverpod 3.5 · go_router 18 · Postgres 17 + PostGIS 3.3.7 + pg_trgm · pgTAP · Supabase CLI local stack.

**Spec:** [docs/superpowers/specs/2026-11-22-lemqes-m4-map-near-me-design.md](docs/superpowers/specs/2026-11-22-lemqes-m4-map-near-me-design.md) (decisions D1–D7, G1–G5, S1–S4, behaviour, external facts §7, council §7b) · parent [2026-11-13 design](docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md) §5 Map · M3 design §6b · [DESIGN.md](DESIGN.md) · `supabase/data/geo/dz/SOURCE.md`.

**Sources for external facts:** design §7 (pub.dev API pages, OpenFreeMap quick start, OSMF tile policy and attribution/substantial guidelines, Supabase PostGIS docs, PostGIS `ST_DWithin`/KNN docs, Google Maps URLs, Waze deep links), checked 2026-11-22.

**Plan reviewed:** 2026-11-22 by an LLM council (5 advisors, 5 anonymous peer reviews, synthesis) — changes at the bottom.

## Decisions made with the user (2026-11-21/22)

- **D1 Place:** every pro chooses `exact` / `area` (circle they place: 500 m / 1 km / 2 km) / `none`; optional; default `none`; only what is shown is stored.
- **D2/D6 Map:** `flutter_map` + OpenFreeMap via `vector_map_tiles`, proven by a spike; fallback CARTO raster (free ≤ 1M tiles/month, Latin labels) only after the user sees the spike report. No paid plan, no card on file.
- **D3 Order:** nearest first when an origin exists. **D4:** existing pros nudged, never blocked, never a publish gap. **D5:** fold + cross-script skeleton. **D7:** chip = origin only (last explicit choice wins); place filter stays a filter.
- **G1–G5:** directions; display rounding; renderer tile cache; "Se déplace jusqu'à vous"; tile hygiene on the hosted checklist.
- **S1–S4 (council, all recommended):** women's-space warning before a pin/area + one-tap "Masquer mon emplacement"; nudge salons only; pin gaming accepted and logged; Law 18-07/ANPDP + Play disclosure on the pre-release checklist.

## In scope / Out of scope

**In scope:** map spike · commune coordinate checks + fixes · Arabic fold + skeleton (SQL + Dart, shared vectors) · `pro_places`, `set_pro_place`, `viewer_blocked`, `search_point` · `search_pros` origin/bbox/tiers/distance · Dart location/origin/place data layer · near-me list (chip, explainer, distances, far notice, "Se déplace jusqu'à vous") · `LemqesBaseMap`, attribution, data-licence screen · pro place picker (setup step, edit, S1 warning, hide button, salon nudge) · customer map view, commune pins, "Itinéraire" · integration paths, real-tile check, gate.

**Out of scope (later):** geocoding · exact address after booking (non-goal; M5 must not reopen it silently — D1 rules out hidden points) · home-visit booking (M8) · typo tolerance · offline map regions · self-hosted tiles · hosted checklist items (R3, R13, G5, S4, R22) · M2/M3 deferred minors.

## Approach (decisions and why)

- **`pro_places`** (`pro_id` PK → `pro_profiles` on delete cascade; row created by the `pro_profiles` insert trigger, backfilled `none`): `place_mode public.place_mode not null default 'none'`, `place extensions.geography(Point,4326)`, `area_radius_m smallint`, `landmark text` (hygiene check of `workplace_name`, ≤ 80), generated `lat`/`lng double precision` (`st_y/st_x(place::extensions.geometry)`), `search_point extensions.geography(Point,4326)`, `updated_at`. Coherence checks: `none` ⇔ no place/radius/landmark; `area` ⇔ radius in (500,1000,2000), no landmark; `exact` ⇔ no radius. GiST on `search_point`.
- **Why a separate table:** `pro_profiles_select` lets every same-space customer read a published row and cannot see blocks, so a place column there would hand a blocked customer the pin. `pro_places` RLS: `select` to `authenticated` using `(select public.owns_pro(pro_id)) or ((select public.is_listable(pro_id)) and not (select public.viewer_blocked(pro_id)))`; no insert/update/delete grants. `viewer_blocked(p_pro_id)` (definer, stable): `exists (pro_blocks where pro_id = p and customer_id = auth.uid())`.
- **`set_pro_place(p_request_id uuid, p_mode, p_lat, p_lng, p_radius_m, p_landmark)`** (definer): caller owns the pro and acts as pro; codes `no_locality`, `place_invalid`, `place_out_of_country` (`geo_countries.bbox`, added in Task 1), `place_too_far` (> 30 km from the commune centre); idempotent via `pro_place_requests(actor, request_id)` (same contract as M3 `queue_requests`; pruned by `queue_end_of_day`, the M3 daily job); returns the place row. Never broadcasts (place is not live).
- **`search_point` maintenance:** a trigger on `pro_places` (`coalesce(place, commune centre)`), a trigger on `pro_profiles.locality_id` change (recompute; reset to `none` if the existing `place` is > 30 km from the new centre), and a trigger on `geo_localities` `lat/lng` update (recompute `none` rows of that commune). One SQL function `f_pro_search_point(pro_id)` holds the coalesce (M7 salons add their door there).
- **Fold:** `f_search_fold`, `f_name_skeleton` (immutable, `set search_path = ''`, rules in design §5, Arabizi digits). Stored generated `pro_profiles.search_key` / `search_skeleton` over `display_name` + `workplace_name`; `pg_trgm` GIN (`gin_trgm_ops`). Services keep per-row folding. Skeleton used only when the query skeleton has ≥ 3 letters.
- **`search_pros`** (`security invoker`, `stable`, SQL; new params default null so old callers work): `p_origin_lat`, `p_origin_lng` (both or neither → `origin_invalid`), `p_bbox float8[]` (4 values, each side ≤ 8° → else `bbox_invalid`). Left join `pro_places` (RLS applies). Order: match tier (`0` fold, `1` skeleton; only with a query), then `search_point <-> origin` nulls last (blocked readers see null), then `is_verified desc, published_at desc, id`. Map mode: `search_point && envelope`, ordered by distance to the envelope centre, limit 101, offset ignored. New columns: `distance_m` (rounded: < 1 km → 100 m steps, else 500 m; `none` → whole km), `place_mode`, `lat`, `lng`, `area_radius_m`, `landmark`, `locality_id`, `comes_to_you`.
- **Commune coordinates:** `scripts/geo/coord_fixes.py --check` / `--emit <migration>` reads the vendored dataset (same path the seed build uses) + `supabase/data/geo/dz/coord_fixes.json`; writes `20261122000100_geo_coords_fix.sql` (`geo_countries.bbox`, `geo_coord_verified(id, reason)`, `update geo_localities`). `build_geo_sql.py`, `patches.json` and the applied seed stay byte-identical.
- **Client:** `DeviceLocation` (`permission()`, `request({required bool precise})`, `current()`), `GeolocatorDeviceLocation` (only importer of geolocator) + `FakeDeviceLocation`; `originProvider` (last explicit chip choice, persisted under a new key via `core/storage/shared_preferences_provider.dart`; device rounded to 3 decimals; refresh on resume after 10 min via `core/time/clock_providers.dart`); `ExploreQuery` gains `origin`, `bbox`; map view state in the route (`/explore?view=map&lat=&lng=&z=`) for M11 links.
- **Map:** `features/map/presentation/lemqes_base_map.dart` is the only importer of `vector_map_tiles`; style URL `MAP_STYLE_URL` read through `core/config/env.dart` from `flutter_app/env/{example,local}.json`; label field per locale (`ar` → `name:ar`, else Latin; `kab` Latin); `RichAttributionWidget` always; `userAgentPackageName`. Tests override the base layer with a plain background and never build `VectorTileLayer` (spike (h)). **Spike rules (FINDINGS, GO 2026-11-22):** area circles are `PolygonLayer` polygons (≥ 72 points), never `CircleLayer`; each locale's patched style has its own `id` (`liberty-ar`, `liberty-latin`); attribution in `Directionality(ltr)`, no hand-written ©, `showFlutterMapAttribution: false`; clustering by a pure pixel-grid function.
- **Order and parallelism:** Task 0 → Spike → (**Task 1 ‖ Task 2**) → 3a → 3b → 4 → 5 → 6 → 7 → 8. Tasks 1 and 2 touch disjoint files (Task 1 in its own worktree), but share one local Supabase stack: **their `supabase db reset` / `npm test` runs are never concurrent** — Task 1 runs its DB gate first, Task 2 after merging Task 1. Task 5 (near-me list) needs no map, so a FALLBACK verdict blocks only Tasks 6–7.

## Global Constraints

- All M1–M3 Global Constraints still bind (git `5dcf477:task_plan.md`, `fdeb191:task_plan.md`): definer functions `set search_path = ''`, fully qualified names (PostGIS via `extensions.` and `operator(extensions.<->)`), `revoke execute … from public, anon`, client RPCs `to authenticated`, `(select …)` in policies; bare `raise exception '<snake_code>'`; DESIGN.md tokens, 48 dp, WCAG AA, designed RTL; every string in all 4 ARBs + REVIEW.md; Conventional Commits ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; **Flutter and Dart only via `scripts/sdk`** (e.g. `scripts/sdk flutter test test/...`); local ports 553xx; never touch Docker containers named `*_DoWee`.
- **Space separation, and blocked customers get the `none` shape** (no point, no distance, closed `live`) on every row, list or map, and on a direct `pro_places` select — pgTAP (3a, 3b) and integration (Task 8).
- **Origin never written:** `search_pros` stays `stable` language SQL (cannot write); no RPC takes an origin except `search_pros` — pinned structurally in pgTAP (3b).
- **Zero cost:** no package, service or key that needs payment or a card.
- Test phones: add `213550000007` (women studio pro, `area`) and `213550000008` (women customer, blocked by 07 in the seed); existing `213550000006` is the unblocked women customer. `config.toml` changes need `supabase stop && supabase start`.
- Branch `feat/map-near-me` (from `develop` at `5dcf477`). Never push; merge to `develop` only when the user says so.

## Review Focus

1. **Location truth** — no response carries a point the pro did not choose; `none` erases it; a blocked customer never gets it, not even by a direct select (3a, 3b, Task 8).
2. **Space on the map** — a women's pro never appears in a men's bbox (3b, Task 8 with a positive control).
3. **Order** — tier, then distance, nulls last; verified no longer first; map mode deterministic with the 101st-row signal (3b).
4. **Fold parity** — Dart and SQL agree on every vector, fold and skeleton (Task 2, re-checked in lint).
5. **Permission flow** — no prompt before the user's tap; refusal → commune picker; no origin → old order (Task 5).
6. **Arabic map** — Arabic map labels per the spike's bar; attribution visible in RTL; real tiles seen once before merge (Spike, Task 8).
7. **Women's-space friction** — S1 warning before a pin/area, hide button, no nudge for non-salons (Task 6).

---

## File structure (locked here)

```
supabase/migrations/20261122000100_geo_coords_fix.sql   # generated: geo_countries.bbox, geo_coord_verified, lat/lng updates
supabase/migrations/20261122000200_search_fold.sql      # pg_trgm, f_search_fold, f_name_skeleton, search keys, tiered matching
supabase/migrations/20261122000300_pro_places.sql       # postgis, place_mode, pro_places + RLS, viewer_blocked, set_pro_place, search_point triggers
supabase/migrations/20261122000400_search_near.sql      # search_pros origin/bbox/order/distance/columns
supabase/tests/database/030-geo.sql (ext)  040-pro-profiles.sql (ext)  060-search-pros.sql (ext)  090-live-realtime.sql (refs)
supabase/tests/database/095-search-fold.sql  096-fold-vectors.sql (generated)  100-pro-places.sql  105-search-near.sql
supabase/tests/fold_vectors.json  supabase/fixtures/map_seed.sql
supabase/data/geo/dz/{coord_fixes.json,SOURCE.md}  scripts/geo/coord_fixes.py  scripts/fold_vectors.py
flutter_app/lib/
  core/config/env.dart (MAP_STYLE_URL)  core/router/{redirect,app_router}.dart  core/l10n/arb/*.arb  core/l10n/REVIEW.md
  features/geo/data/{device_location,origin,geo_models}.dart
  features/geo/presentation/{search_fold,locality_picker,location_chip,location_explainer_sheet}.dart
  features/explore/data/{explore_models,explore_api,explore_providers}.dart
  features/explore/presentation/{explore_screen,pro_card_tile,pro_labels,pro_public_profile_screen,explore_map_view,directions_button}.dart
  features/map/presentation/{lemqes_base_map,pro_markers,commune_pin}.dart
  features/pro/data/{pro_models,pro_api,pro_repository,pro_failure}.dart
  features/pro/presentation/place/{place_picker_screen,place_mode_control}.dart  features/pro/presentation/setup/location_step.dart
  features/pro/presentation/dashboard/pro_dashboard_screen.dart  features/settings/presentation/{settings_screen,map_licences_screen}.dart
  features/live/data/live_channels.dart (only if the search_pros row shape breaks it)
flutter_app/env/example.json  flutter_app/pubspec.{yaml,lock}  flutter_app/android/app/src/main/AndroidManifest.xml  flutter_app/ios/Runner/Info.plist
flutter_app/test/ (mirrors lib/, goldens under each test folder's goldens/)  flutter_app/integration_test/{map_customer_test,place_pro_test,pro_profile_flow_test}.dart
.superpowers/spikes/m4-map/FINDINGS.md (+ screenshots)  # force-added like M3's FINDINGS (`.superpowers/` is git-ignored)
```

---

### Task 0: Commit the design and plan

- [x] **Step 1:** `git add docs/superpowers/specs/2026-11-22-lemqes-m4-map-near-me-design.md task_plan.md && git commit` with subject `docs: add milestone 4 map and near-me design and plan`.

**Done when:** (1) `git log -1 --format=%s` = `docs: add milestone 4 map and near-me design and plan`; (2) nothing to run (docs only); (3) `git show --stat HEAD` lists only those two files.

---

### Spike: OpenFreeMap in flutter_map (throwaway, ≤ 3 h)

**Why first:** D6 rests on a beta renderer whose label direction is hard-coded LTR.

- [x] **Step 1:** On a scratch branch, a throwaway screen with flutter_map 8.3.2 + vector_map_tiles 9.0.0-beta.13 + OpenFreeMap `liberty`, label field patched to `name:ar`. Measure on **Linux and an Android device (physical preferred; emulator only if none, recorded)**, profile mode: (a) `scripts/sdk flutter pub get` resolves with the pinned SDK; (b) Algiers and Tizi Ouzou at z8/z12/z15 render; (c) Arabic labels; (d) markers + metre circles stay aligned while panning; (e) frame times while panning 10 s; (f) a second open of the same area offline shows cached tiles; (g) `RichAttributionWidget` in RTL; (h) a widget test and a golden render the map with a no-network tile override; (i) `geolocator` on this Linux box (GeoClue or not).
- [x] **Step 2:** `.superpowers/spikes/m4-map/FINDINGS.md` with observations, screenshot paths, sources, verdict. **GO requires all of:** (a) resolves; (c) pure-Arabic labels joined and in the right order, no tofu boxes, in all three zooms; mixed Arabic + Latin labels readable (or a documented label rule that avoids them, e.g. `name:ar` only); (e) p90 frame time ≤ 16 ms on Linux and ≤ 33 ms on the Android device; (d) drift ≤ 1 px; (f) cached tiles shown; (g) attribution fully visible; (h) passes. Otherwise **FALLBACK proposed**: stop and ask the user. `git add -f` the findings; delete the scratch branch.

**Done when:** (1) `FINDINGS.md` answers (a)–(i) with numbers or screenshots and states GO or FALLBACK against the bar above; (2) `git show --stat HEAD` lists only `.superpowers/spikes/m4-map/` files; (3) no other files changed. FALLBACK stops the plan before Task 6.

---

### Task 1: Commune coordinates — checks and fixes  ‖ parallel with Task 2 (worktree; DB gate first)

**Files:** create `scripts/geo/coord_fixes.py`, `supabase/data/geo/dz/coord_fixes.json`, generated `supabase/migrations/20261122000100_geo_coords_fix.sql`; modify `supabase/data/geo/dz/SOURCE.md`, `supabase/tests/database/030-geo.sql`.

- [x] **Step 1: Failing checks** — `coord_fixes.py --check` (four rules, design §5; "wilaya spread" defined there) lists the flagged ids (≈ 22 on 2026-11-22) and exits 1. pgTAP `030` cases **C1** every point inside `geo_countries.bbox`; **C2** no shared point; **C3** no whole-degree coordinate; **C4** no wilaya-spread outlier outside `geo_coord_verified` — fail first (no bbox/table yet).
- [x] **Step 2:** One `coord_fixes.json` entry per flagged id: `{lat, lng, source: "osm:node/<id>"}` or `{verified: "<reason>"}`. `SOURCE.md` records the OSM credit and the count (< 100).
- [x] **Step 3:** `coord_fixes.py --emit supabase/migrations/20261122000100_geo_coords_fix.sql`.

**Done when:** (1) `python3 -I scripts/geo/coord_fixes.py --check` exits 0; `supabase db reset && supabase test db` shows `030 .. ok` with C1–C4 and `plan(N)` matching; `git diff --quiet 5dcf477 -- scripts/geo/build_geo_sql.py supabase/data/geo/dz/patches.json supabase/migrations/20261115000110_geo_dz_seed.sql` exits 0; (2) `npm test` green (run when Task 2 is not using the stack); (3) no files changed outside the Files list above.

---

### Task 2: Arabic folding and cross-script search  ‖ parallel with Task 1 (DB gate after Task 1 merges)

**Files:** create `supabase/migrations/20261122000200_search_fold.sql`, `supabase/tests/database/095-search-fold.sql`, `supabase/tests/fold_vectors.json`, `scripts/fold_vectors.py`, generated `supabase/tests/database/096-fold-vectors.sql`; modify `supabase/tests/database/{040-pro-profiles,060-search-pros}.sql`, `flutter_app/lib/features/geo/presentation/{search_fold,locality_picker}.dart`, `flutter_app/lib/features/explore/presentation/pro_labels.dart`, their tests, `package.json` (`lint` adds `python3 -I scripts/fold_vectors.py --check`).

- [x] **Step 1: Vectors and failing tests** — `fold_vectors.json`: ≥ 40 `{input, fold, skeleton}` cases covering every rule (each hamza form, ى, ة, ؤ, ئ, harakat, tatweel, Arabic-Indic and Persian digits, Latin accents, apostrophes, the Kabyle letters already in `_latin`, Arabizi `3mine`/`7amid`) and cross-script pairs (Amine/أمين, Mohamed/محمد/Mohammed, Yacine/ياسين, Khaled/خالد, Djamel/جمال, Chérif/شريف, Lamine/لمين, Tizi/تيزي). The Dart test reads the JSON and asserts **both** `searchFold` and `nameSkeleton`; the generator writes `096` asserting both SQL functions. `095`: **F1** functions immutable, callable by `authenticated`; **F2** `search_pros('احمد')` finds `أحمد`; **F3** `'Amine'` ↔ `أمين` both ways; **F4** fold match ranks before skeleton match; **F5** query skeleton < 3 letters never skeleton-matches; **F6** GIN trigram indexes on `search_key`, `search_skeleton`; **F7** with 2,000 seeded pros (`analyze`d), `explain (format json)` of a name query uses the trigram index on `search_key`. See them fail.
- [x] **Step 2:** Implement; `searchFold`/`nameSkeleton` replace `foldLatin` (callers `pro_labels.dart`, `locality_picker.dart`); the stale doc comment about Arabic goes.
- [x] **Step 3:** `040`/`060`: update only cases whose function list or order changes because of tiers, each named in the report.

**Done when:** (1) `095 .. ok` (F1–F7) and `096 .. ok`; `scripts/sdk flutter test test/features/geo/presentation/search_fold_test.dart` passes every vector (fold and skeleton); `python3 -I scripts/fold_vectors.py --check` exits 0; (2) `npm run lint`, `npm run typecheck`, `npm test` green; (3) no files changed outside the Files list above.

---

### Task 3a: `pro_places`, block-aware reads, `set_pro_place`, search point

**Files:** create `supabase/migrations/20261122000300_pro_places.sql`, `supabase/tests/database/100-pro-places.sql`; modify `supabase/tests/database/000-setup.sql` (`tests.set_place(...)`), `040-pro-profiles.sql` (function/trigger lists), `supabase/config.toml` (test_otp 07/08).

- [x] **Step 1: Failing pgTAP `100`** — **P1** postgis in schema `extensions`; `pro_places` exists, a row per pro (backfill + insert trigger); no insert/update/delete grant (`update pro_places` as `authenticated` → 42501); **P2** RLS: owner reads own row; same-space customer reads a listable pro's row; other-space → no row; unpublished → no row; **blocked customer → no row** (direct select of `lat` returns nothing); **P3** `set_pro_place` codes `no_locality`, `place_invalid` (each incoherent combination), `place_out_of_country`, `place_too_far` at 30.1 km, ok at 29.9 km; non-owner refused; replayed request id → same result, no change; **P4** `none` nulls place, radius, landmark, `lat/lng`; **P5** `search_point` = place, else commune centre, else null; follows a `geo_localities` coordinate update for `none` rows; **P6** commune change > 30 km resets to `none`, ≤ 30 km keeps; **P7** `set_pro_place` inserts no `realtime.messages` row; **P8** `viewer_blocked`, `f_pro_search_point` not executable by `anon`; `viewer_blocked` returns only about `auth.uid()`.
- [x] **Step 2:** Implement.

**Done when:** (1) `100 .. ok` with P1–P8 named and `plan(N)` matching, `040 .. ok`; (2) `npm run lint`, `npm run typecheck`, `npm test` green; (3) no files changed outside the Files list above.

---

### Task 3b: Near-me and map search (`search_pros`)

**Files:** create `supabase/migrations/20261122000400_search_near.sql`, `supabase/tests/database/105-search-near.sql`; modify `supabase/tests/database/{040-pro-profiles,060-search-pros,090-live-realtime}.sql` (signature references), `flutter_app/lib/features/explore/data/{explore_models,explore_api}.dart`, create `flutter_app/test/features/explore/data/explore_models_test.dart`; `flutter_app/lib/features/live/data/live_channels.dart` and `flutter_app/integration_test/pro_profile_flow_test.dart` only if the new row shape breaks them.

- [x] **Step 1: Failing pgTAP `105`** — **N1** with origin, no query: distance order, null points last, verified no longer first; **N2** query + origin: tier then distance; **N3** `distance_m` rounding: 740 m → 700, 1.26 km → 1500, `none` → whole km; null without origin; **N4** bbox: only points inside, never another space, ordered by distance to the centre, 101 rows max, `bbox_invalid` (3 values, > 8° side), `origin_invalid` (one coordinate); **N5** `none` rows in a bbox: null `lat/lng`, their `locality_id`; **N6** blocked customer: row present with null `lat/lng`/`distance_m` and closed `live` (= `live_snapshot(pro, viewer)`), and absent from a bbox (null point); **N7** `comes_to_you` only for `mobile` within `service_radius_km`; **N8** structural origin check: `search_pros` is `stable`, language `sql`, `security invoker`; no other function in `public` has a parameter named `p_origin_%`; **N9** with 2,000 seeded pros, `explain (format json)` of an origin query without text uses the GiST index on `search_point`.
- [x] **Step 2:** Drop and recreate `search_pros` (new params default null); update test references.
- [x] **Step 3:** `explore_models.dart` parses the new columns (absent → null) with a unit test per column; `explore_api.dart` sends the new params only when set.

**Done when:** (1) `105 .. ok` with N1–N9, `060`, `040`, `090` ok; `scripts/sdk flutter test test/features/explore/data` green; (2) `npm run lint`, `npm run typecheck`, `npm test` green; (3) no files changed outside the Files list above.

---

### Task 4: Location, origin and place data layer (Dart)

**Files:** create `flutter_app/lib/features/geo/data/{device_location,origin}.dart`; modify `features/geo/data/geo_models.dart` (commune centre), `features/explore/data/explore_providers.dart`, `features/pro/data/{pro_models,pro_api,pro_repository,pro_failure}.dart`, `core/storage/shared_preferences_provider.dart` (only if a key helper is needed), `flutter_app/pubspec.{yaml,lock}` (geolocator, url_launcher), `flutter_app/android/app/src/main/AndroidManifest.xml` (coarse + fine location, `<queries>` for https view intents), `flutter_app/ios/Runner/Info.plist` (location usage strings); tests mirroring each.

- [x] **Step 1: Failing tests** — fake `DeviceLocation`: denied / approximate / precise / service off; `originProvider`: last explicit choice wins (commune beats device and vice versa), persisted across restarts, device rounded to 3 decimals, refresh on resume only after 10 min (fake clock); a new origin re-runs the explore search; `ProRepository.setPlace` sends a request id and maps every server code to a `ProFailure`; `ProProfile` (owner) reads its `pro_places` row.
- [x] **Step 2:** Implement; customer flows request approximate only.

**Done when:** (1) `scripts/sdk flutter test test/features/geo test/features/explore/data test/features/pro/data` green; (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` (whole app) green; (3) no files changed outside the Files list above.

---

### Task 5: Near-me list (no map)

**Files:** create `features/geo/presentation/{location_chip,location_explainer_sheet}.dart`; modify `features/explore/presentation/{explore_screen,pro_card_tile,pro_labels}.dart`, ARBs + REVIEW.md; tests and goldens under `flutter_app/test/features/{geo,explore}/presentation/goldens/`.

- [x] **Step 1: Failing widget tests** — no permission prompt on Explore open; the chip's "Ma position" shows the explainer, then requests approximate; denied or service off → commune picker (the existing `locality_picker.dart`); picking a commune sets the origin; rows show distance (G2, `≈ 3 km` for `none`) and "Se déplace jusqu'à vous"; no origin → no distances, old order; far notice when the first row > 10 km, including a `none`-only result set; blocked-viewer row shows closed and no distance; chip and place filter independent. Goldens (fr light, ar RTL): `explore_list_near_{fr,ar}.png`, `location_chip_{fr,ar}.png`, `location_explainer_{fr,ar}.png`.
- [x] **Step 2:** Implement.

**Done when:** (1) the new tests and the six named goldens pass; (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` green; (3) no files changed outside the Files list above.

---

### Task 6: Base map and the pro place picker  (blocked by a FALLBACK verdict until the user answers)

**Files:** create `features/map/presentation/{lemqes_base_map,pro_markers,commune_pin}.dart`, `features/pro/presentation/place/{place_picker_screen,place_mode_control}.dart`, `features/pro/presentation/setup/location_step.dart`, `features/settings/presentation/map_licences_screen.dart`; modify `core/router/{redirect,app_router}.dart`, `core/config/env.dart`, `flutter_app/env/example.json`, `features/pro/presentation/dashboard/pro_dashboard_screen.dart`, `features/settings/presentation/settings_screen.dart`, `flutter_app/pubspec.{yaml,lock}` (map packages), `flutter_app/test/flutter_test_config.dart` (only if goldens need fonts), ARBs + REVIEW.md; tests and goldens under `flutter_app/test/features/{map,pro}/presentation/goldens/`. `flutter_app/env/local.json` gains `MAP_STYLE_URL` locally (ignored, not committed).

- [ ] **Step 1: Failing tests** — router: the setup flow goes profile → location → services; "Plus tard" goes to services; resume after an interruption goes to the first real gap, never to `location`; picker: radius chips only for Zone, landmark only for Pin, preview line per mode, save sends the fields, `place_too_far` message, Commune seulement clears the pin, commune-change reset message; **S1**: in the women's space, choosing Pin or Zone shows the warning before saving; "Masquer mon emplacement" on the dashboard sets `none` in one tap; **S2**: the nudge card shows for a salon with `none`, never for `own_studio`/`mobile`; `LemqesBaseMap` with the background override, attribution present and LTR; label field and style `id` per locale (`ar`, `fr`, `en`, `kab`); the area circle is a polygon. Goldens: `place_picker_{pin,zone,commune}_{fr,ar}.png`, `pro_dashboard_place_card_{fr,ar}.png`.
- [ ] **Step 2:** Implement per the spike's GO settings.

**Done when:** (1) the new tests and the eight named goldens pass; (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` green; (3) no files changed outside the Files list above.

---

### Task 7: Customer map view and directions

**Files:** create `features/explore/presentation/{explore_map_view,directions_button}.dart`; modify `explore_screen.dart`, `pro_public_profile_screen.dart`, `core/router/app_router.dart` (`/explore?view=map&lat=&lng=&z=`), ARBs + REVIEW.md; tests and goldens under `flutter_app/test/features/explore/presentation/goldens/`.

- [ ] **Step 1: Failing widget tests** — the toggle keeps query, filters and origin; the map state round-trips through the route; markers for `exact`, polygon circles for `area`, commune pins with counts for `none` grouped by `locality_id`; the grid-clustering function unit-tested (merge within the cell size, split when zoomed in, counts preserved); "Rechercher dans cette zone" appears after a pan and sends one bbox (no request while panning); a 101st row shows "Zoomez pour voir plus"; a tapped pin shows the card; a blocked viewer's pro is not on the map; "Itinéraire" only for `exact`, Google Maps URL, Waze in the overflow (fake launcher). Goldens: `explore_map_{fr,ar}.png` with each marker kind.
- [ ] **Step 2:** Implement.

**Done when:** (1) the new tests and the two named goldens pass; (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` green; (3) no files changed outside the Files list above.

---

### Task 8: Integration paths, real-tile check, finish review, milestone gate

**Files:** create `supabase/fixtures/map_seed.sql`, `flutter_app/integration_test/{map_customer_test,place_pro_test}.dart`; modify `scripts/integration.sh` (seed per file), `task_plan.md` (Gate log), `CLAUDE.md` (one M4 Architecture line).

- [ ] **Step 1:** Integration with `FakeDeviceLocation` and the test tile override: (a) pro `213550000007` sets a 1 km Zone in setup (warning shown), then "Masquer mon emplacement"; the public profile has no point; (b) customer `213550000006` (women) grants approximate location, sees the studio's circle nearest first, no men's pros; switches to men via `spaceSwitch_men` and sees the seeded men's pro (positive control) and no women's pros; (c) customer `213550000008`, blocked by 07, sees 07 closed, with no distance, absent from the map; (d) search "Amine" finds the seeded `أمين`.
- [ ] **Step 2:** Manual real-tile pass: `scripts/sdk flutter run -d linux` with `env/local.json`, Explore map and picker in fr and ar; screenshots in `.superpowers/spikes/m4-map/real-tiles/` (force-added), each with one observation.
- [ ] **Step 3:** Full gate: `npm run lint`, `npm run typecheck`, `npm test`, `sh scripts/integration.sh` ×2 → Gate log row at the branch tip.
- [ ] **Step 4:** `security-auditor` (pro_places RLS and blocks, set_pro_place, origin non-persistence, bbox scraping, space on the map, S1 friction) and whole-branch `code-reviewer` in parallel; one fix wave (its own commit, files listed in its report); re-gate; re-review; CLAUDE.md line; ask the user before merging `feat/map-near-me` → `develop` (`--no-ff`); propose M5.

**Done when:** (1) both integration files pass twice in a row, the real-tile screenshots exist with observations, the Gate log row at the tip is all ✅, both reviews approve after the fix wave; (2) the full gate is green at that commit; (3) Step 1–3 commits touch only `supabase/fixtures/`, `flutter_app/integration_test/`, `scripts/integration.sh`, `.superpowers/spikes/m4-map/`, `task_plan.md`, `CLAUDE.md`; the fix-wave commit touches only files named in a review finding.

---

## Risks & open questions

| # | What | Why it matters | Decision (recommended first) | Relation | Cost |
|---|---|---|---|---|---|
| R16 | `vector_map_tiles` beta, "minimally maintained" | No upstream fixes | Spike GO (2026-11-22): Arabic, speed, cache passed; six rules recorded; `LemqesBaseMap` isolation keeps a provider switch local. No physical Android phone measured (emulator only) — re-check frame times on a real mid-range phone before the store release | [NEEDED — before release] | 30 min |
| R17 | OpenFreeMap has no SLA | Map could go blank | Map is optional UI (list keeps working); style URL in env; self-host revisited if needed | [FUTURE idea] | — |
| R18 | Skeleton matching is loose | Noisy short-name results | ≥ 3-letter rule, fold tier first; revisit after field use | [FUTURE idea] | — |
| R19 | GeoClue absent on the test machine | Real location untested on Linux | Fake in tests; real check in the spike (i) and on Android | [NEEDED — Task 4] | in task |
| R20 | Any origin/bbox lists a space's pros country-wide; spaces are self-chosen | Scraping, including of the women's space | Data shown is public by the pro's choice (D1) + S1 warning; bbox ≤ 8°, 101 rows; rate limit with R3 | [NEEDED — before hosting] | — |
| R21 | CARTO fallback: 1M tiles/month, Latin labels | Watermark or cost over the cap; Arabic anti-goal | Only after a FALLBACK verdict and the user's yes | [FUTURE idea] | — |
| R22 | Hosted API request logs may record `search_pros` parameters | "Never stored" holds only for our tables | Device rounds to ~100 m; check hosted log retention on the hosted checklist | [NEEDED — before hosting] | 15 min |
| S3 | Pins placed in a town centre to rank first | Ranking gaming | Accepted and logged; revisit with reviews (M6) | [FUTURE idea — M6] | — |
| S4 | Law 18-07 (ANPDP) + Play prominent disclosure / Data Safety for location | Location is personal data | Pre-release checklist before M5's store release | [NEEDED — before hosting] | 1–2 h |
| R14 | Presence tracking (M3): live status + a home pin shows when a pro is open | Safety | Unchanged (ages rounded); S1 warning mentions it; revisit followers-only status with M6 | [NEEDED — before hosting] | 1 h |
| R3/R13/G5 | Hosted rate limiting, Realtime public access off, test_otp guard, tile User-Agent/attribution | Hosted prerequisites | One hosted checklist before M5 | [NEEDED — before hosting] | 1 h |
| M2/M3 minors | Deferred minors in `.superpowers/sdd/m2-archive/`, `m3-archive/` | — | Unchanged; "Info.plist strings English-only" now covers location strings | [SIDE FIX — safe to defer] | — |

---

## Roadmap

M1 foundation ✅ (`f7263e0`) · M2 barber profile, photos, services, explore ✅ (`4b0a4f3`, F1 `70f9c17`, `fdeb191`) · M3 live status + queue ✅ (`5dcf477`) · **M4 map + near-me, workplace pick, commune coordinates, Arabic search folding (this plan)** · M5 bookings (slots from M2 hours, bookings in the queue via `sort_at`), reminders, −15 min auto-cancel, in-app account deletion → **first store release** (wallet off) · M6 follow, broadcasts, discounts, reviews (from served visits), followers-only queue · M7 salons + join requests (`served_by`) · M8 home visits · M9 finance (`price_dzd` snapshots) · M10 wallet (`join_block = limited`) · M11 QR + deep links · M12 push polish.

## Gate log

| Commit | lint | typecheck | flutter test | supabase test db | integration | Notes |
|---|---|---|---|---|---|---|
| 5c821cd (M1 merge gate) | ✅ | ✅ | ✅ 256 | ✅ 65 | ✅ ×2 | Milestone 1 baseline. |
| 7514d8c (M2 pre-merge gate) | ✅ | ✅ | ✅ 572 | ✅ 231 | ✅ ×3 | After security audit + whole-branch review fix wave. |
| fcd04d9 (F1 gate) | ✅ | ✅ | ✅ 582 | ✅ 247 | ✅ ×2 | Contact phone; 248 pgTAP after review pin. |
| adca74d (M3 pre-merge gate) | ✅ | ✅ | ✅ 839 | ✅ 618 | ✅ ×2 (4 files) | After security audit + whole-branch review fix wave; race 20/20; pgTAP also green on a DB with leftover integration seed. |
| 3bb7ea0 (M3 security fix wave) | ✅ | ✅ | ✅ 854 | ✅ 651 | ✅ ×2 (4 files) | User chose "Fix all, then merge": blocked customer sees a permanently closed barber, join-check order, replay filter, hidden-count payload, absent after call; security re-review approved; race 20/20; pgTAP green after integration. |


## Plan review (2026-11-22, LLM council) — what changed

- **Blocked-customer leak (fatal):** place moved from `pro_profiles` (readable by every same-space customer) to `pro_places` with block-aware RLS (`viewer_blocked`); pgTAP P2/N6 and integration (c) assert no point for a blocked customer, not only the closed `live`.
- **`search_point` readable by the invoker `search_pros`** through `pro_places` RLS; one `f_pro_search_point` (M7 salons hook).
- **Migration order:** coordinate fixes (000100) only touch `geo_localities`; `search_point` is created later (000300) with a `geo_localities` trigger for future fixes.
- **Chip:** last explicit choice wins (commune can override GPS).
- **Commune fixes** in their own file, script and migration; `build_geo_sql.py`, `patches.json` and the hashed seed stay byte-identical (checked by `git diff --quiet`).
- **Spike:** a numeric GO bar, an Android device, the no-network tile override proven, findings force-added (`.superpowers/` is ignored).
- **Escape hatches removed** (F7, N9 must pass); P13 replaced by a structural check (N8: `stable` SQL invoker, no other `p_origin_*` parameter).
- **Fences** now list every file the task touches (`pro_labels.dart`, `locality_picker.dart`, `040`, `core/storage`, `env/example.json`, manifest `<queries>`, named goldens); all Flutter commands via `scripts/sdk`.
- **Parallelism:** Tasks 1 ‖ 2 share one local stack → DB gates serialized.
- **Splits:** Task 3 → 3a/3b; the near-me list (Task 5) ships before the map (Tasks 6–7), so a FALLBACK blocks only the map.
- **Map mode:** deterministic order, 101st-row "Zoomez pour voir plus", fetch on demand only; map state in the route (M11).
- **Added:** Arabizi digits, Dart skeleton for the locality picker, `kab` map labels in Latin, real-tile manual pass before merge, `config.toml` restart note, test phones and blocked pair defined, S1–S4 decisions (user: all recommended).
- **Declined:** a random offset for area centres (contradicts the user's D1 "she places it"; S1 warning instead); ranking unverified pros by commune centre (S3: accepted and logged).
