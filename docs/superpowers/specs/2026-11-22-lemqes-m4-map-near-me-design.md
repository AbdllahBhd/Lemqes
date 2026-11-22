# LEMQES M4 — Map, near-me, workplace place, commune coordinates, Arabic search: design

Date: 2026-11-22 · Status: DRAFT (interview done 2026-11-21/22; council-reviewed 2026-11-22; approval with the M4 plan) · Parent spec: [2026-11-13-lemqes-flutter-supabase-design.md](2026-11-13-lemqes-flutter-supabase-design.md) §4 step 4, §5 "Map", "Location data", §7 · M3 design: [2026-11-20-lemqes-m3-live-queue-design.md](2026-11-20-lemqes-m3-live-queue-design.md) §6b

## 1. Intent

A customer should find the barbers around them — nearest first, on a list or a map — inside their own space, with the live status M3 already carries. A pro should decide, alone and at any time, how much of their location the space sees: their door, an area they place, or just their commune. Arabic search should match the way people type, in either script. And all of it costs nothing to run (user, 2026-11-22: "I don't want to pay anything").

Governing anti-goal: **nothing on a map reveals more about a pro's location than the pro chose to show.** The simplest guarantee, decided with the user: **the server never stores a location the pro did not choose to show.**

## 2. Goals, non-goals, anti-goals

**Goals**
- Each pro chooses a **place mode**: `exact` (a pin), `area` (a circle the pro places: 500 m / 1 km / 2 km), or `none` (commune only). Same rule for every workplace type. Switchable any time.
- Explore sorts **nearest first** whenever an origin is known; every row shows a rounded distance.
- A **list / map toggle** on Explore; the map shows status-dot pins, area circles, commune pins, clusters, "Rechercher dans cette zone".
- Location permission asked **in context**, approximate accepted, origin **never stored server-side**; a commune picker is the fallback and the manual override.
- **Commune coordinates** checked automatically; flagged points corrected or marked verified.
- **Arabic folding** plus **cross-script matching** ("Amine" ↔ "أمين").
- "Itinéraire" on exact pins; home artists whose radius reaches the customer marked "Se déplace jusqu'à vous".
- **Zero running cost** for maps.

**Non-goals (M4)**
- Address geocoding / address search.
- Revealing an exact address after a booking (revisit with M5).
- Home-visit booking and travel fee display (M8).
- Typo-tolerant fuzzy ranking.
- Offline map regions; only the renderer's on-device tile cache.
- Self-hosted tiles (option C, revisit if OpenFreeMap disappears).

**Anti-goals**
- A pro's location inferable beyond what they chose (nothing hidden is stored, so nothing can leak).
- A map or list mixing Men and Women, or showing a blocked customer a barber as anything but closed (M3 §6b) — this includes commune-pin counts — **or showing a blocked customer the pro's place at all** (a blocked customer gets the `none` shape everywhere, including a direct table select).
- Nudging a home-based women's-space pro toward showing her door.
- A permission prompt at app start, or a dead end when location is refused.
- Arabic as an afterthought: mirrored controls wrong, mis-ordered digits, clipped attribution, map labels in Latin only for an Arabic UI.
- An existing published pro vanishing from search because it has no place.
- A bill: any map component that needs a paid plan or a card on file.

## 3. Decisions made with the user (2026-11-21/22)

| # | Question | Decision |
|---|---|---|
| D1 | How exact is a pro's location? | Each pro chooses `exact` / `area` / `none`, any workplace type; the pro places the circle themself. Only what is shown is stored. Location is optional for everyone. |
| D2 | Map SDK | `flutter_map` (runs on Android, iOS, Linux; the integration suite runs on Linux, Google Maps has no Linux plugin). |
| D3 | Default order with an origin | Nearest first; verified pros keep the badge, lose priority. Without an origin: today's order. |
| D4 | Existing published pros without a place | Nudge, don't block: listed by commune centre, no individual marker, dashboard card; skippable setup step; never a publish gap. |
| D5 | Arabic search | Fold within script **and** cross-script sound skeleton. |
| D6 | Tile source (no money) | **OpenFreeMap** vector tiles (free, keyless, commercial use allowed, no SLA) rendered with `vector_map_tiles`, **proven by a spike first**. Fallback if the spike fails: CARTO raster with a free key (free ≤ 1M tiles/month) — applied only after the user sees the spike report. |
| D7 | Location chip | **Two controls:** the top-bar chip sets only the origin (sort + distances, no filtering); the existing place filter stays a filter. In the chip, the customer's last explicit choice wins ("Ma position" or a commune). |
| G1 | Directions | "Itinéraire" on exact pins → Google Maps URL, Waze second. |
| G2 | Distance rounding | Display rounding: 100 m steps under 1 km, 0.5 km above; `none`-mode distances in whole km with "≈". Presentation only (every shown point is public). |
| G3 | Tile cache | The renderer's on-device cache (~30 days); no GPL caching plugin. |
| G4 | Home artists | `mobile` pro whose `service_radius_km` reaches the origin → "Se déplace jusqu'à vous". |
| S1 | Women's-space exposure (spaces are self-chosen, so anyone can open the women's space) | Before a women's-space pro saves a pin or an area: a plain warning "Tout le monde peut voir ce point"; a one-tap "Masquer mon emplacement" on the dashboard (→ `none`). |
| S2 | Location nudge | The dashboard card nudges **salons only**; studios and home artists are never nudged. |
| S3 | Pin gaming (centre-of-town pins to rank first) | Accepted and logged: a false pin sends customers to the wrong place; revisit with reviews (M6). |
| S4 | Law 18-07 (ANPDP declaration) + Play location disclosure | On the pre-release checklist before M5's store release. |
| G5 | Tile access hygiene | OpenFreeMap needs no key; a unique `User-Agent` and the attribution are required. On the hosted checklist with R3/R13 (plus key restriction if the CARTO fallback is used). |

## 4. Approaches

**Location privacy.** (a) exact pin for all — unsafe for home studios; (b) per workplace type with a server-side random offset — stores a secret point and needs an offset that never re-rolls; (c) **the pro places what is shown, the server stores only that** — chosen (user refined b into c): no secret, no offset, no averaging attack, full control.

**Tiles at zero cost.** (a) **OpenFreeMap vector + `vector_map_tiles`** — chosen: free, keyless, Arabic names in the data; risk: the renderer is a beta, "minimally maintained", with LTR-hard-coded label direction → spike; (b) CARTO raster — mature, free up to 1M tiles/month then watermark or pay, no label-language control → fallback; (c) Protomaps file on Cloudflare R2 — needs our own domain (~$10/yr) and possibly a card → rejected. Paid MapTiler/Stadia (free tiers forbid commercial use) → rejected by the user.

**Geometry.** (a) plain lat/lng + Haversine; (b) **PostGIS `geography(Point, 4326)` + GiST** — chosen (Claude's call, not objected): correct distances, indexed KNN, `&&` for map views.

**Search.** (a) fold within script; (b) **(a) + cross-script skeleton** — chosen; (c) (a) + typo tolerance.

## 5. Behaviour

### Pro side — place
- A separate table `pro_places` (one row per pro, created with the profile, backfilled): `place_mode` (`none` default | `area` | `exact`), `place` (`extensions.geography(Point,4326)`, null iff `none`), `area_radius_m` (500 | 1000 | 2000, set iff `area`), `landmark` (≤ 80 chars, `exact` only, same hygiene check as `workplace_name`), generated `lat`/`lng`, and the ranking point `search_point`. Check constraints pin the coherence.
- **Read path (council finding):** `pro_profiles` stays readable by every same-space customer, so the place cannot live there. `pro_places` has its own RLS: the owner, or a listable pro **that has not blocked the reader** (`not public.viewer_blocked(pro_id)`, a definer helper because `pro_blocks` is not client-readable). The invoker `search_pros` left-joins it, so a blocked reader gets null place fields and no distance, exactly like a `none` pro, and a direct select returns no row.
- `set_pro_place(p_request_id, p_mode, p_lat, p_lng, p_radius_m, p_landmark)` — definer, owner only, the only writer (no column grants). Codes: `place_too_far` (> 30 km from the commune centre), `place_out_of_country`, `place_invalid` (incoherent fields), `no_locality` (pro has no commune yet). `none` clears the other fields.
- Commune change: a trigger on `locality_id` resets the place to `none` when the existing `place` is > 30 km from the new commune centre. The edit screen compares the returned profile and says "Votre emplacement a été retiré".
- Setup: `/pro/setup/location` after `profile`, "Plus tard" skips it, never a gap. Edit from the dashboard; a dashboard card while `place_mode = none`.
- Picker UI: map centred on the commune (or the device if granted), draggable pin, "Ma position actuelle" (precise permission asked here only), mode control (Pin · Zone · Commune seulement), radius chips for Zone, landmark field for Pin, preview line "Les clients verront : …".

### Customer side — origin
- Origin = the customer's last explicit choice in the chip: "Ma position" (device position rounded to ~100 m on the device) or a commune (its centre); with no choice yet, the device position if already granted, else none.
- The chosen commune is remembered on the device; the origin is a search parameter, never stored on the server.
- Permission: explainer sheet on the first tap of the chip's "Ma position" or of the map toggle, then the OS prompt; approximate accepted; refusal / GPS off → commune picker. Position refreshed on resume after 10 min.
- The chip only sets the origin; the existing place filter (`p_region_code`, `p_locality_id`) keeps filtering.

### Search and distance (server)
- `search_pros` gains `p_origin_lat`, `p_origin_lng` (both or neither, else `origin_invalid`) and `p_bbox` (`array[min_lng, min_lat, max_lng, max_lat]`). One function for list and map, so space, role, publish, filters and the blocked-viewer snapshot cannot drift between them.
- Each pro has a trigger-maintained `search_point` = `place`, else the commune centre, else null; GiST index. A commune coordinate update refreshes it.
- **Order:** with a text query, match tier first (fold match in the same script, then skeleton match), then distance, then the current tiebreakers; without a query, distance first. Pros with a null `search_point` come last. No distance cutoff.
- Returned extra columns: `distance_m` (rounded per G2, null without origin), `place_mode`, `lat`/`lng` (the shown point only; null for `none`), `area_radius_m`, `landmark`, `locality_id`, `comes_to_you` (`mobile` and `ST_DWithin(origin, search_point, service_radius_km·1000)`).
- **Map mode** (bbox given): only pros whose `search_point` is inside, ordered by distance to the view's centre, at most 100 (the call fetches 101; a 101st row means "Zoomez pour voir plus"), no offset. A new view is fetched only on "Rechercher dans cette zone", never on every pan. `none`-mode rows come back like any other (their `search_point` is the commune centre, `lat`/`lng` null); the client groups them by `locality_id` into commune pins, so counts follow the same filters and blocked-viewer rule as the list.
- **Far notice:** if the nearest result is > 10 km away, the list shows "Rien à moins de 10 km — voici les plus proches".
- The public profile read returns the same place fields.

### Map (client)
- `LemqesBaseMap` is the only widget that knows the tile source (OpenFreeMap style, label field rewritten to `name:ar` for Arabic UI and to the Latin name otherwise — `kab` uses Latin, since OSM has almost no `name:kab`; the CARTO fallback, if ever used, shows its own labels: a recorded gap), attribution "© OpenMapTiles © OpenStreetMap contributors" always reachable, unique `User-Agent`.
- Status-dot markers (DESIGN.md tokens), area circles in metres, commune pins with a count, clustering when zoomed out, "Rechercher dans cette zone" after a pan, tap → the same card as the list, RTL-aware controls.
- "Itinéraire" on exact pins → `https://www.google.com/maps/dir/?api=1&destination=LAT%2CLNG`, Waze `https://waze.com/ul?ll=LAT,LNG&navigate=yes`.
- A "Données cartographiques" entry in settings lists the ODbL / OpenMapTiles credits (OSM attribution guideline for apps).

### Commune coordinates
- `scripts/geo/build_geo_sql.py` checks, failing the build: inside Algeria's bounds; no whole-degree coordinate; no two communes sharing a point; distance to the wilaya median ≤ max(4 × the wilaya's median spread, 60 km). A dry run on 2026-11-22 flagged ~22 points (3 whole-degree, 2 shared pairs, ~17 far — some genuine, e.g. El Borma, Hassi Messaoud).
- "Wilaya spread" = the median distance of the wilaya's communes to the wilaya's median point.
- Each flagged point is either corrected or marked `verified` with its reason in a **separate** file `supabase/data/geo/dz/coord_fixes.json` (OSM, a handful of coordinates — insubstantial under the ODbL guidelines, credited in `SOURCE.md`). `patches.json` and the applied seed (hash-pinned) are never touched. A new update migration is generated from it; the verified ids are emitted into that migration (`geo_coord_verified` table) so pgTAP can exclude them. Ids never change.

### Arabic search
- `f_search_fold(text)` (immutable SQL): lower, Latin unaccent, `أ إ آ ٱ → ا`, `ى → ي`, `ة → ه`, `ؤ → و`, `ئ → ي`, harakat and tatweel removed, Arabic-Indic and Persian digits → 0-9, apostrophes/punctuation dropped, whitespace collapsed.
- `f_name_skeleton(text)`: folded Arabic transliterated the Algerian-French way, then both scripts reduced to a consonant skeleton (vowels dropped; `ou/u/o`, `ch/sh`, `dj/j`, `k/q/c`, `kh`, `gh` classes merged; doubles collapsed; Arabizi digits `3 7 9 5 2` read as ع ح ق خ ء).
- Stored keys on `pro_profiles` (`search_key`, `search_skeleton`) for `display_name` + `workplace_name`; services and presets use the fold only; `pg_trgm` GIN indexes.
- Skeleton matching only when the query's skeleton has ≥ 3 letters.
- Dart `searchFold` and `nameSkeleton` (replacing `foldLatin` in `features/geo/presentation/search_fold.dart`) apply the same rules for the locality picker, so "Tizi" finds "تيزي". One vector table `supabase/tests/fold_vectors.json` drives a Dart test and a generated pgTAP file (`scripts/fold_vectors.py --check` in lint), so the two folds cannot drift.

## 6. Constraints
- Space scoping and the blocked-viewer closed shape on every row, list or map.
- Flutter only through `scripts/sdk`; location behind a `DeviceLocation` interface with a fake for widget and integration tests (GeoClue is not assumed on the test machine).
- l10n in ar, fr, en, kab + `REVIEW.md`; Arabic RTL goldens for the map card, the chip and the picker.
- No secrets needed for OpenFreeMap; the style URL lives in `env/*.json` so the fallback is config.
- Android declares `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`; customer flows request coarse only, the pro picker may request fine. iOS usage strings (localised later, M2 minor). Play data safety: location processed, not stored — release checklist.

## 7. External facts (primary sources, checked 2026-11-22)
Full notes with URLs: side-session notes `m4-external-facts.md`, `m4-free-tiles.md`.
- `flutter_map` 8.3.2 (2026-08-27, BSD-3): Android/iOS/Linux; `RichAttributionWidget`; `CircleMarker(useRadiusInMeter: true)`; built-in tile caching since 8.2 (not for offline use). `flutter_map_marker_cluster` 8.2.2 (BSD-3). Avoid `flutter_map_tile_caching` (GPL-3.0).
- `vector_map_tiles` 9.0.0-beta.13 (needs flutter_map ^8.1.1; 8.0.0 stable targets flutter_map 7; 10.x needs Flutter main + Impeller); README: "minimally maintained". `vector_tile_renderer` 6.1.0 hard-codes LTR label direction (source read) → spike.
- OpenFreeMap: commercial use allowed, no key, no limits, no SLA; attribution OpenMapTiles + OpenStreetMap; vector only; planet tiles carry `name:ar`.
- MapTiler and Stadia free tiers forbid commercial use; OSM's own tile servers may withdraw access from commercial services.
- ODbL: "© OpenStreetMap contributors" + licence link, findable in apps; under 100 features is insubstantial (no share-alike).
- `geolocator` 14.1.2: Linux via GeoClue; Android 12+ and iOS 14+ allow approximate-only (`reduced`). `permission_handler` has no Linux → not used.
- PostGIS 3.3.7 available in the local stack; `create extension postgis with schema extensions`; `st_point(lng, lat)::geography`; `ST_DWithin` in metres; KNN `<->` uses the index only in `ORDER BY` with a constant.
- `url_launcher` 6.3.3; https direction links need no `LSApplicationQueriesSchemes`.

## 7b. Council review (2026-11-22) — what changed
- Place moved out of `pro_profiles` into `pro_places` with block-aware RLS (a blocked customer could otherwise select the pin directly).
- Chip: last explicit choice wins. Map mode: deterministic order, 101-row "zoom in" signal, fetch only on demand.
- Coordinate fixes in their own file and migration; the hashed seed is untouched.
- Arabizi digits in the skeleton; Dart skeleton for the locality picker; `kab` map labels in Latin.
- New decisions S1–S4 (women's-space warning and hide button, salon-only nudge, pin gaming accepted, compliance checklist).
- "Never stored": nothing in our tables (`search_pros` stays `stable` SQL, which cannot write); hosted API request logs are on the hosted checklist (R22).

## 8. Left to the builder
- Exact transliteration table and skeleton classes, as long as the shared vectors pass.
- Marker visuals within DESIGN.md; cluster thresholds.
- How the OpenFreeMap style is localised (fetched and patched at runtime vs a bundled patched copy), as long as the spike's finding holds.
