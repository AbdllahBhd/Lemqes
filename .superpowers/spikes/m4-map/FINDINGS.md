# M4 spike — OpenFreeMap in flutter_map: findings

Date: 2026-11-22 · Plan: `task_plan.md` → Spike · Throwaway code lived on a scratch worktree (`spike/m4-map`, deleted); nothing from it is committed except this file and `shots/`.

## Verdict: **GO** (OpenFreeMap + `vector_map_tiles`), with the six implementation rules below

Every item of the plan's GO bar passed. One required item could only be met partly: there was no physical Android phone, so the Android numbers come from an emulator (recorded in (e)).

## Setup

- Flutter 3.50.0 via `scripts/sdk`. Resolved: `flutter_map` 8.3.2, `vector_map_tiles` 9.0.0-beta.13, `vector_tile_renderer` 6.1.0, `vector_tile` 2.0.1, `latlong2` 0.10.1, `geolocator` 14.1.2, `geolocator_linux` 0.2.6, `http` 1.6.0.
- Style: `https://tiles.openfreemap.org/styles/liberty`. Tiles: TileJSON `https://tiles.openfreemap.org/planet` → `…/planet/20261115_080022_pt/{z}/{x}/{y}.pbf`, provider max zoom 14. `User-Agent: dz.lemqes.spike`.
- Labels are patched per locale. Every symbol layer whose `text-field` reads a name gets `["coalesce", ["get","name:ar"], ["get","name"]]` in Arabic, or `["coalesce", ["get","name:latin"], ["get","name"]]` otherwise. That covers 20 layers; the 3 shield layers keep `ref`.
- Devices: Linux desktop (Ubuntu 26.04, profile mode); Android 15 emulator `sdk gphone64 x86 64` (API 35, profile mode). **No physical Android phone was available.**

## Results against the GO bar

| Item | Result | Evidence |
|---|---|---|
| (a) resolves with the pinned SDK | ✅ only **without** `flutter_map_marker_cluster`. 8.2.2 needs `latlong2 ^0.9.1`, but `vector_map_tiles` 9.0.0-beta.10+ needs `^0.10.1`, so version solving fails. | `pub add` output |
| (b) Algiers and Tizi Ouzou at z8/z12/z15 render | ✅ on Linux and Android | `shots/linux_z12_ar.png`, `linux_tizi_z12_ar.png`, `android_tizi_z15_ar.png` |
| (c) Arabic labels | ✅ Glyphs join correctly, words are in the right right-to-left order, no tofu at any of the three zooms. Arabic + digits put the numbers in the right place (`محطة 2 مايو 1962`). Labels never mix Arabic and Latin, because each one is either `name:ar` or the `name` fallback. | `linux_bidi_digits_crop.png`, `linux_polygon_z15_ar.png` |
| (d) markers and metre circles stay aligned while panning | ✅ markers, and ✅ circles **drawn as polygons**. ❌ `CircleLayer` breaks at street zoom: a 1 km circle at z15 draws as a solid square. Its filled disk is a `drawPoints` call with a round cap and stroke width 2r, and large point sizes break on this renderer. | `linux_circlelayer_bug_z15.png` vs `linux_polygon_z15_ar.png` |
| (e) p90 frame time while panning 10 s | ✅ Linux: 601 frames; total p50 2.4 ms / **p90 2.95 ms**; build p90 0.42 ms; raster p90 0.61 ms (bar ≤ 16 ms). ✅ Android emulator: 601 frames; total p50 1.5 ms / **p90 17.8 ms**; raster p90 16.7 ms (bar ≤ 33 ms). Tiles render off the UI thread (layer mode `raster`), so tile loading does not show in frame times. | run logs |
| (f) offline second open shows cached tiles | ✅ Second run with the tile URL pointing at a dead host (`127.0.0.1:9`): z8 over the whole region came fully from the file cache. | `linux_offline_cache_z8.png` |
| (g) attribution in RTL | ✅ Visible: collapsed to an (i) button, expanded on demand. Two defects in RTL. `TextSourceAttribution` prepends "©" itself, so a hand-written "©" doubles it. The neutral "©" also lands on the wrong side unless the widget is wrapped in `Directionality(ltr)`. | `android_z15_ar_attribution.png` |
| (h) widget test + golden without network | ✅ when the vector layer is **replaced** by a plain background: map, polygon circle, marker and attribution render and the golden is stable. ❌ a `VectorTileLayer` with an empty in-memory provider fails in `flutter_test` (`CancellationException` at teardown). | `test_plain_override_golden.png` |
| (i) geolocator on this Linux box | Location unavailable here: `isLocationServiceEnabled=false`, `checkPermission=unableToDetermine`, `getCurrentPosition` → `org.freedesktop.DBus.Error.AccessDenied: Geolocation disabled for UID 1000`. On Android it works once the manifest declares location: without it, geolocator raises "No location permissions are defined in the manifest". | run logs |

Also observed, outside the bar:
- **Label cache:** the renderer caches rendered tiles under the theme `id` (`vector_tile_loading_cache.dart`: `'$tileKey/${_theme.id}/…'`). Switching from Arabic to Latin labels with the same style `id` kept the Arabic tiles (`linux_latin_same_id_bug.png`). A per-locale `id` fixes it (`linux_latin_patched_id.png`: "Baie d'Alger", "Hydra", "Casbah").
- **Cold cache:** on the first Linux run, z12 Algiers still showed blurred lower-zoom substitute tiles after 7 s. Warm runs were sharp. Customers will see a brief blur on first use in an area.
- **Coverage:** OSM data around Algiers and Tizi Ouzou is dense (streets, POIs, Arabic names). Sparser regions were not checked.

## Real-tile captures (Task 8, `real-tiles/`)

Observed on the built app against the live OpenFreeMap tiles, one line each:

- `explore-map-ar.png`: Arabic labels read `name:ar` (تيلملي، سيدي امحمد، القبة) with Latin only where OSM has no Arabic name; the exact pin and the RTL chrome sit correctly over the tiles, and the (i) attribution stays bottom-right.
- `explore-map-fr.png`: the same view in Latin labels (Telemly, Sidi M'Hamed, Hydra, Kouba): the per-locale style id keeps the two caches apart, as rule 3 requires.
- `picker-ar.png`: the Zone circle (polygon) is legible over dense streets; the centre dot marks the exact saved point, and the preview copy then said "وليس عنوانك" (not your address), which the final review found false (fixed: the copy now says the centre is shown).
- `picker-fr.png`: same in French; the preview then read "pas votre adresse" (since replaced by the honest wording), and the Save button sits under the controls with the S1 warning scrolled below the fold.

## Implementation rules for Tasks 6–7

1. **No `flutter_map_marker_cluster`.** It cannot be installed alongside `vector_map_tiles`. Cluster by hand: group markers into a pixel grid at the current zoom, a small pure function with unit tests.
2. **Area circles are `PolygonLayer` polygons** (≥ 72 points from `Distance().offset`), never `CircleLayer`.
3. **Each locale's patched style gets its own `id`** (`liberty-ar`, `liberty-latin`), or cached tiles keep the old labels.
4. **Attribution:** `RichAttributionWidget` inside `Directionality(textDirection: TextDirection.ltr)`, sources without a hand-written "©", `showFlutterMapAttribution: false`, texts "OpenMapTiles" and "OpenStreetMap contributors".
5. **Tests never build `VectorTileLayer`.** `LemqesBaseMap` takes its base layer from a provider, and tests override it with a plain background.
6. **Location:** the Linux tests use the fake `DeviceLocation` (GeoClue refuses this user). Android needs the manifest entries from Task 4 before any real call.

## Sources

- `vector_map_tiles` 9.0.0-beta.13 source (`lib/src/style/style.dart`, `vector_tile_layer.dart`, `cache/vector_tile_loading_cache.dart`) and README; `vector_tile_renderer` 6.1.0 `themes/theme_reader.dart`.
- `flutter_map` 8.3.2 `lib/src/layer/circle_layer/painter.dart`.
- OpenFreeMap style and TileJSON as fetched on 2026-11-22.
