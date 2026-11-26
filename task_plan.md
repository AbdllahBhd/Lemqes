# LEMQES Milestone 5 — Bookings, Reminders, Auto-cancel, Account Deletion: Implementation Plan

> Plan pending: interview → design doc → plan → adversarial review. The M4 plan is archived in [docs/plan-archive.md](docs/plan-archive.md).

## Risks & open questions

| # | What | Why it matters | Decision (recommended first) | Relation | Cost |
|---|---|---|---|---|---|
| R16 | `vector_map_tiles` beta, "minimally maintained" | No upstream fixes | Spike GO (2026-11-22): Arabic, speed, cache passed; six rules recorded; `LemqesBaseMap` isolation keeps a provider switch local. No physical Android phone measured (emulator only) — re-check frame times on a real mid-range phone before the store release | [NEEDED — before release] | 30 min |
| R17 | OpenFreeMap has no SLA | Map could go blank | Map is optional UI (list keeps working); style URL in env; self-host revisited if needed | [FUTURE idea] | — |
| R18 | Skeleton matching is loose | Noisy short-name results | ≥ 3-letter rule, fold tier first; revisit after field use | [FUTURE idea] | — |
| R19 | GeoClue absent on the test machine | Real location untested on Linux | Fake in tests; real check in the spike (i) and on Android | [NEEDED — Task 4] | in task |
| R20 | Any origin/bbox lists a space's pros country-wide; spaces are self-chosen | Scraping, including of the women's space | Data shown is public by the pro's choice (D1) + S1 warning; bbox ≤ 8°, 101 rows; rate limit with R3 | [NEEDED — before hosting] | — |
| R21 | CARTO fallback: 1M tiles/month, Latin labels | Watermark or cost over the cap; Arabic anti-goal | Only after a FALLBACK verdict and the user's yes | [FUTURE idea] | — |
| R22 | Hosted API request logs may record `search_pros` parameters | "Never stored" holds only for our tables | Device rounds to ~100 m; check hosted log retention on the hosted checklist; on the hosted Postgres keep `log_min_duration_statement` off (or high) and `log_parameter_max_length = 0` so origins and boxes never reach the Postgres logs through bind parameters | [NEEDED — before hosting] | 15 min |
| R23 | OpenFreeMap sees every tile request (the area a customer views, IP, User-Agent) | Third-party view of browsing areas | No account or origin is sent; tile templates are `https` only (enforced in `lemqes_base_map.dart`); disclose the tile provider in S4's privacy notice | [NEEDED — before hosting] | 15 min |
| S3 | Pins placed in a town centre to rank first | Ranking gaming | Accepted and logged; revisit with reviews (M6) | [FUTURE idea — M6] | — |
| S4 | Law 18-07 (ANPDP) + Play prominent disclosure / Data Safety for location | Location is personal data | Pre-release checklist before M5's store release | [NEEDED — before hosting] | 1–2 h |
| R14 | Presence tracking (M3): live status + a home pin shows when a pro is open | Safety | Unchanged (ages rounded); S1 warning mentions it; revisit followers-only status with M6 | [NEEDED — before hosting] | 1 h |
| R3/R13/G5 | Hosted rate limiting, Realtime public access off, test_otp guard, tile User-Agent/attribution | Hosted prerequisites | One hosted checklist before M5 | [NEEDED — before hosting] | 1 h |
| M2/M3 minors | Deferred minors in `.superpowers/sdd/m2-archive/`, `m3-archive/` | — | Unchanged; "Info.plist strings English-only" now covers location strings | [SIDE FIX — safe to defer] | — |

---

## Roadmap

M1 foundation ✅ (`f7263e0`) · M2 barber profile, photos, services, explore ✅ (`4b0a4f3`, F1 `70f9c17`, `fdeb191`) · M3 live status + queue ✅ (`5dcf477`) · M4 map + near-me, workplace pick, commune coordinates, Arabic search folding ✅ (`dcb47bf`) · M5 bookings (slots from M2 hours, bookings in the queue via `sort_at`), reminders, −15 min auto-cancel, in-app account deletion → **first store release** (wallet off) · M6 follow, broadcasts, discounts, reviews (from served visits), followers-only queue · M7 salons + join requests (`served_by`) · M8 home visits · M9 finance (`price_dzd` snapshots) · M10 wallet (`join_block = limited`) · M11 QR + deep links · M12 push polish.

## Gate log

| Commit | lint | typecheck | flutter test | supabase test db | integration | Notes |
|---|---|---|---|---|---|---|
| 5c821cd (M1 merge gate) | ✅ | ✅ | ✅ 256 | ✅ 65 | ✅ ×2 | Milestone 1 baseline. |
| 7514d8c (M2 pre-merge gate) | ✅ | ✅ | ✅ 572 | ✅ 231 | ✅ ×3 | After security audit + whole-branch review fix wave. |
| fcd04d9 (F1 gate) | ✅ | ✅ | ✅ 582 | ✅ 247 | ✅ ×2 | Contact phone; 248 pgTAP after review pin. |
| adca74d (M3 pre-merge gate) | ✅ | ✅ | ✅ 839 | ✅ 618 | ✅ ×2 (4 files) | After security audit + whole-branch review fix wave; race 20/20; pgTAP also green on a DB with leftover integration seed. |
| 3bb7ea0 (M3 security fix wave) | ✅ | ✅ | ✅ 854 | ✅ 651 | ✅ ×2 (4 files) | User chose "Fix all, then merge": blocked customer sees a permanently closed barber, join-check order, replay filter, hidden-count payload, absent after call; security re-review approved; race 20/20; pgTAP green after integration. |
| f69f74d (M4 Task 8 gate) | ✅ | ✅ | ✅ 1232 | ✅ 982 | ✅ ×2 (6 files) | Adds place_pro + map_customer paths (map_seed.sql); fixes the explore crash on a search after an empty answer (5a7e0ef) and the auth path's off-screen sign-out (f69f74d); real-tile captures fr/ar in `.superpowers/spikes/m4-map/real-tiles/`. Pre-review: security audit + whole-branch review still to run. |
| 90137b5 (M4 final-review fix wave) | ✅ | ✅ | ✅ 1248 | ✅ 993 | ✅ ×2 (6 files) | Security audit + whole-branch review fix wave: block/fold/argument helpers moved to `private` (no RPC), query cap 100, picker never defaults to the device fix + honest area copy, area tap target off-centre, style fetch recovers, first map search after the keyboard closes, chip re-asks after one refusal / offers settings, origin forgotten on account change. User decisions F1 (picker fix only) and F2 (block hints accepted) in the design doc. |

