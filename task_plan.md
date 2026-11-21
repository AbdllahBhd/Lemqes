# LEMQES Milestone 3 — Live Status & Live Queue: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objective:** Milestone 3: barbers run a live status (open / on break / closed, auto-closing at closing time) and a live queue (walk-ins + remote joins, abuse-limited) from a Today screen, and customers see status, age, queue count and wait on explore cards and public profiles within ~2 s through Supabase Realtime broadcasts, and can hold a place in line.

**Architecture:** Same shape as M1/M2 (M2 plan: git `fdeb191:task_plan.md`). Business rules live in Postgres: one `pro_live` row per pro profile, a `queue_entries` history table, security-definer RPCs for every action (each with a request id), pg_cron for auto-close and end-of-day. **Each RPC and job ends with exactly one explicit call to `live_broadcast(pro_id)`** (security definer), which sends the **public snapshot** (no names, no ids of customers) with `realtime.send(..., private => true)` on topic `pro:<pro id>`; the only trigger that broadcasts is on `pro_profiles` publish/unpublish. RLS on `realtime.messages` lets only the owner and listable customers join a topic. Clients fetch a snapshot by RPC, apply broadcasts, re-fetch on every (re)subscribe, and **re-derive time-driven state locally** (auto-close, stale, break end, shrinking wait) from raw timestamps and the server-clock offset, because no message is sent when only time passes.

**Tech Stack:** Flutter 3.50.0 · supabase_flutter 2.18.3 / realtime_client 2.13.2 (private channels, `onBroadcast`) · flutter_riverpod 3.5 · go_router 18 · Postgres 17 + pg_cron 1.6.4 · pgTAP · Supabase CLI 2.121 local stack.

**Spec:** [docs/superpowers/specs/2026-11-20-lemqes-m3-live-queue-design.md](docs/superpowers/specs/2026-11-20-lemqes-m3-live-queue-design.md) (decisions with the user, behaviour) · parent [2026-11-13 design](docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md) §5 Live, §7, §7b · [DESIGN.md](DESIGN.md) · prototype reference `app/src/main/java/com/example/ui/screens/{BarberHomeScreen,CustomerExploreScreen}.kt`, `ui/components/{BarberDashboardCards,BarberDiscoveryCard,HeaderAndStatusComponents}.kt`, `model/LemqesModels.kt` (`BarberStatus`, `QueueJoinMode`, `QueueCustomer`), `viewmodel/LemqesViewModel.kt` (`setBarberStatus`, `addWalkIn`, `callNext`, `joinQueueRemotely`).

**Sources for external facts:** Supabase docs "Broadcast" (`realtime.send(payload, event, topic, private)`, database broadcasts private by default) and "Realtime Authorization" (`for select` on `realtime.messages` = receive, `realtime.topic()`, `RealtimeChannelConfig(private: true)`, hosted "Allow public access" must be off). Local DB (read 2026-11-20): `realtime.send` catches every error and only raises a WARNING, adds an `id` key to the payload, and inserts into daily partitions `realtime.messages_YYYY_MM_DD` created by the Realtime service. realtime_client 2.13.2 `RealtimeChannelConfig.private`, `setAuth`; supabase-dart 2.16.5 re-sends the session token to Realtime on auth changes. pg_cron 1.6.4 available locally.

**Plan reviewed:** 2026-11-20 by an LLM council (5 advisors, 3 anonymous peer reviews, synthesis) — changes listed at the bottom.

## Decisions made with the user (2026-11-19/20)

- **Stale status:** auto-close at closing time (Africa/Algiers) + 30 min grace the barber can extend by 1 h; customers always see the status age; 2 h without a barber action → "Statut incertain".
- **Walk-in +1** is one tap; optional service and optional name afterwards.
- **Hide queue count** hides only the number; the wait stays visible; a joined customer always sees their own place.
- **Pro-gap G1–G5 all accepted:** SQL abuse limits on remote join; history kept; idempotent atomic actions + offline banner that disables actions; learned average service time; screen-reader announcements.
- **Transport B:** database broadcasts of a public snapshot on private per-pro channels; explore cards on screen update live (~2 s goal kept — the review's "refresh every 60 s" suggestion was rejected for that reason).
- "Offline/paused" = the **queue mode** (Ouvert à tous / Abonnés seulement / En pause), not a fourth status; "Abonnés seulement" behaves as paused until M6.

## In scope / Out of scope

**In scope:** a throwaway Realtime spike · `pro_live` + status RPCs + auto-close (pg_cron) · `queue_entries` with walk-in/remote entries, call next / finish / absent / undo / clear, ticket numbers per service day, history, learned average · remote join with G1 limits, "on my way", leave · queue settings (mode, hide count, blocked customers) · snapshot RPC, `live` column in `search_pros`, explicit broadcasts, `realtime.messages` policy, end-of-day job · Dart live data layer (channels, providers, reconnect re-fetch, local re-derivation, server-clock offset) · country clock and the M2 `HoursTable` "today" fix · pro bottom navigation + Today screen · explore card live line + rings, public profile live block + join sheet + ticket, "Votre file" card on Explore · integration path with a seeded barber and raw clients · CLAUDE.md Flutter version fix.

**Out of scope (later):** push for "your turn"/"on my way" (M12) · bookings in the queue (M5; `sort_at` and the remote-only active index are ready) · zero-balance limits (M10; `can_join` and `join_block` are the hooks) · followers and "Abonnés seulement" enforcement (M6) · distance, map (M4) · salon-shared queues (M7; `served_by` is ready) · finance from served visits (M9; `price_dzd` snapshot is ready) · hosted rate limiting and the hosted Realtime "Allow public access = off" (R3/R13, before any hosted release) · offline action queueing on the barber side (G3 decision: actions are disabled offline) · other M2 deferred minors (Risks).

## Approach (decisions and why)

- **`pro_live`**, one row per pro (created by a trigger on `pro_profiles` insert, backfilled): `status live_status ('open','on_break','closed') default 'closed'`, `break_until timestamptz`, `auto_close_at timestamptz`, `status_changed_at`, `last_activity_at`, `queue_mode queue_mode ('open','followers','paused') default 'open'`, `hide_queue_count boolean default false`, `avg_service_min smallint default 20`, `queue_version bigint default 0`. Written only by definer RPCs and jobs; owner select only; customers never select it.
- **Time seam:** every live function and every `default` on the new tables uses `public.live_now()` (wraps `now()`). pgTAP freezes time with `tests.freeze_now(ts)`, which **redefines `public.live_now()` inside the test transaction** (rolled back with the test). Never a client-settable GUC.
- **Service day:** the Africa/Algiers date of `(at − 6 h 30 min)`, defined once in `service_day(p_at, p_tz)`. (M2 allows past-midnight closings until 06:00, so 06:30 is after every shift.) Ticket numbers, the 5-joins limit and end-of-day use it.
- **Effective status, derived on every read and on the client:** `auto_close_at <= now` → closed; `on_break` with `break_until` passed → shown "Pause prolongée" (still not joinable); open/break with `last_activity_at < now − 2 h` → stale. The per-minute job makes the stored row and the broadcast catch up; clients don't wait for it.
- **Shift end:** `pro_shift_end(p_pro_id, p_at)` in the country timezone: the shift containing `p_at` (including yesterday's past-midnight shift), else the next shift starting later today, else null. Open/break sets `auto_close_at = coalesce(shift_end, now + 3 h) + 30 min`; `extend_auto_close` +60 min, cap `now + 12 h`.
- **`queue_entries`** (history, never deleted): `id, pro_id, served_by uuid (= pro_id until M7), ticket_no, service_day date, kind ('walk_in','remote'), customer_id uuid references profiles on delete set null (remote only), name (walk-in only, name hygiene, ≤ 40), service_id → pro_services, duration_min, price_dzd (both snapshotted when the service is set; null = average / unknown), state ('waiting','serving','served','absent','cancelled','removed'), end_reason ('cleared','end_of_day','left','blocked','undo'), sort_at (default `live_now()`; M5 bookings set earlier), on_my_way_at, called_at, ended_at, created_at default live_now()`. Indexes: unique `(customer_id) where state in ('waiting','serving') and kind = 'remote'`; unique `(served_by) where state = 'serving'`; unique `(pro_id, service_day, ticket_no)`. No delete grant; a `before delete` trigger raises `history_is_kept` unless the delete cascades from `pro_profiles`.
- **Serialization:** every status and queue RPC starts with `select … from pro_live where pro_id = $1 for update`; this serializes ticket numbers, call-next and settings per pro. pgTAP cannot run two sessions, so a two-session shell script proves the race (Task 2a).
- **Idempotency (G3):** **every mutating RPC (owner and customer) takes `p_request_id uuid not null`.** `queue_requests(actor uuid, request_id uuid, action text, pro_id uuid, created_at, primary key (actor, request_id))`: a repeat with the same action returns the current result and changes nothing; a repeat with a different action → `request_reused`. Pruned after 2 days by the daily job.
- **Owner reads never carry customer ids:** owner RPCs return `owner_queue_row (entry_id, ticket_no, kind, label, service_id, duration_min, state, on_my_way_at, called_at, sort_at, position)`. `label` = walk-in name, else the remote customer's `full_name`, else `Client <ticket_no>`.
- **Average (G4):** on each served entry, `avg_service_min` = median of `ended_at − called_at` over the last 20 served, clamped 5..120; stays 20 until 5 exist.
- **Wait:** `queue_wait_min(pro_id, before_sort_at)` = max(serving duration − minutes since called, 5) + sum of waiting durations ahead (duration or average), rounded up to 5. Snapshots also carry the raw inputs (`serving_called_at`, `serving_duration_min`, `ahead_minutes`) so the client can shrink the wait between messages, except when the count is hidden or the pro is closed (security wave: then no inputs, the client shows `wait_min` as is).
- **Join rules (G1):** `can_join(p_pro_id)` (definer, the one place M10 extends) raises the first failing code: `not_listable` (other space, unpublished, not acting as customer), `own_queue`, `pro_not_open` (closed, effective-closed, stale, or on break — with or without return time), `queue_paused` (mode `paused` or `followers`), `already_in_queue`, `join_limit_reached` (5 per service day), `absent_block` (2 absents marked after a call, within 7 days; lifted 24 h after the 2nd). A customer blocked by this pro is refused `pro_not_open` at the status check, exactly as at a closed pro (security wave: `join_unavailable` removed).
- **Snapshot** (`live_snapshot(p_pro_id) returns jsonb`, internal): `pro_id, status, break_until, auto_close_at, status_age_from` (= `last_activity_at` rounded down to 5 min — coarse presence, R14), `queue_mode, listed, count_hidden, join_block` (null when joinable by pro-side conditions, else `closed|on_break|paused|followers`; M10 adds `limited`), `wait_min, live_version, server_now`, and only while the count is shown `waiting_count, serving_called_at, serving_duration_min, ahead_minutes, queue_version`. Closed (effective-closed, or blocked for the reading customer: `live_snapshot(p_pro_id, p_viewer)`) nulls the times, age, queue and wait. The `live` object is the same shape in `search_pros` (one `live jsonb` column), in `pro_live_snapshots`, and in broadcasts (where `realtime.send` adds `id`).
- **Broadcast:** `live_broadcast(p_pro_id)` (definer, execute revoked from clients) bumps `queue_version` when asked (`p_queue_changed boolean`) and calls `realtime.send(live_snapshot(p_pro_id), 'live', 'pro:' || p_pro_id, true)`. Called **once at the end** of every RPC and per affected pro by each job; no triggers on `pro_live`/`queue_entries`. One definer trigger on `pro_profiles` (`published_at`, `display_name`, `avatar_path` change) calls it, since clients update `pro_profiles` directly. Because `realtime.send` swallows errors, tests assert the inserted row, and run as `authenticated` (the `postgres` role bypasses RLS and would hide a missing definer).
- **Channel authorization:** `create policy live_topics on realtime.messages for select to authenticated using (realtime.messages.extension = 'broadcast' and public.live_topic_allowed((select realtime.topic())))`; `live_topic_allowed(text)` (definer) checks `^pro:[0-9a-f-]{36}$` before casting, then `owns_pro(id) or is_listable(id)`. No insert policy. Do not `enable row level security` on `realtime.messages` in migrations (Supabase docs). Authorization is checked **at join only**, so the client tears down every channel on space, role or account change and on unpublish broadcasts.
- **Internal helpers are not callable:** `live_snapshot`, `live_broadcast`, `live_touch`, `pro_shift_end`, `live_auto_close`, `queue_end_of_day`, `queue_wait_min` → `revoke execute … from public, anon, authenticated`; pinned in pgTAP.
- **Client data flow:** `LiveChannels` (one per app, independent of widget visibility) ref-counts `pro:<id>` private channels with a 10 s linger, re-fetches snapshots (batched in a 250 ms window, ≤ 60 ids) on every subscribe/resubscribe and on app resume, drops snapshots older than the one held (`live_version`), closes all channels on space/role/auth change, and exposes `connected`. A **30 s ticker** re-derives effective status, stale, break end and wait. Live providers set `retry: null` (Riverpod 3 auto-retry would replay actions and hide failures).
- **"Hors ligne"** = `LiveChannels.connected` false for > 5 s, or the last RPC failed with a network error. Barber: banner + actions disabled (G3). Customer: the live line shows "Mis à jour il y a X min" instead of a confident status until the channel is back (same anti-goal, customer side).
- **Navigation:** pros get a Material `NavigationBar` (theme exists, unused) with **Aujourd'hui** (default) and **Mon profil** (M2 dashboard). Customers keep Explore; the "Votre file" card sits at the top of Explore **only in the ticket's space**.
- **Country clock:** `core/time/country_clock.dart` — `countryNow(timezone, utcNow)` with a fixed-offset table (`Africa/Algiers` = +1 h, no DST since 1981); unknown zone throws. The only file allowed to call `DateTime.now()` in new or touched code is `core/time/clock_providers.dart`.
- **Order and parallelism:** Task 0 → Spike → Task 1 → 2a → 2b → 3 → 4b → 5 → 6 → 7, strictly sequential (shared migrations, ARBs, router). **Task 4a (country clock, models, failures, repository skeleton) runs in parallel with Tasks 1–3** in its own worktree: it touches only `flutter_app/`, never runs `supabase` commands, and is merged before Task 4b.

## Global Constraints

- All M1/M2 Global Constraints still bind (git `fdeb191:task_plan.md` §Global Constraints): definer functions `set search_path = ''`, fully qualified names, `revoke execute … from public, anon`, grant client RPCs `to authenticated`, policies wrap helpers in `(select …)`; errors are bare `raise exception '<snake_code>'` (+ `detail`); colours/type/48 dp/WCAG AA/RTL designed (Latin tabular digits for counts, times and prices; `Ltr` for times like "19:30" inside Arabic text); every new string in all 4 ARBs + REVIEW.md; Conventional Commits ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; Flutter only via `scripts/sdk`; local Supabase ports 553xx; never touch other projects' Docker stacks.
- **Space separation:** no snapshot, broadcast topic, ticket card or join reaches a customer outside the pro's space — pinned in pgTAP (Tasks 2b–3) and integration (Task 7, including the switch-space-with-open-channels path).
- **No customer ever receives another customer's name or id; no pro ever receives a customer id** — not through snapshots, broadcasts, `search_pros`, owner RPCs, or a direct select on `queue_entries`.
- Time: `public.live_now()` + `geo_countries.timezone` in SQL; in Dart, server time from snapshots and the country clock.
- Test phones (local `[auth.sms.test_otp]` only): add `213550000004` (seeded men barber), `213550000005` (men customer), `213550000006` (women customer). In the app they are typed `0550000004/05/06`.
- Branch `feat/live-queue` (from `develop` at `fdeb191`).

## Review Focus

1. **Stale "open"** — barber opens at 09:00 on a 09:00–19:00 day and walks away: from 19:30 every read **and a mounted card with no new message** say "Fermé"; at 11:00 with no action, "Statut incertain". 14:00–01:00 closes at 01:30 next day. Pinned in Task 1 pgTAP (frozen `live_now`), Task 4b (ticker re-derivation) and Task 6 widget tests (advance the fake clock, no broadcast).
2. **Names, ids and space leaks** — a customer never receives a name or another customer's id; a pro never receives a customer id; a channel joined in the men's space receives nothing after a switch to women. Pinned in Task 2b/3 pgTAP and Task 7 integration (with a positive control).
3. **Double "call next"** — same request id twice → one person served; two sessions racing → exactly one serving row, no error to the barber. Pinned in Task 2a (pgTAP + race script) and Task 5 (button ignores taps in flight).
4. **Join abuse** — every `can_join` code, each in isolation, with a clear message; a blocked customer sees the pro as closed (snapshot, refused channel, `pro_not_open`), never a block. Pinned in Task 2b pgTAP and Task 6 widget tests.
5. **Reconnect truth** — after the socket drops and comes back, or the JWT refreshes, the Today screen and cards show the server's current state, never an older broadcast. Pinned in Task 4b (fake channel) and Task 7 (`realtime.disconnect()`/`connect()`).

---

## File structure (locked here)

```
supabase/migrations/20261120000100_live_status.sql      # enums, live_now, service_day, pro_live, shift end, status RPCs, live_broadcast stub, auto-close job
supabase/migrations/20261120000200_queue_owner.sql      # queue_entries, queue_requests, owner RPCs, average, wait
supabase/migrations/20261120000210_queue_join.sql       # pro_blocks, can_join, join/leave/on-my-way, my_ticket, settings, blocks
supabase/migrations/20261120000300_live_realtime.sql    # snapshot, search_pros live column, real live_broadcast, pro_profiles trigger, realtime policy, end-of-day job
supabase/tests/database/070-live-status.sql  080-queue-owner.sql  085-queue-join.sql  090-live-realtime.sql
supabase/tests/race/call_next_race.sh                   # two psql sessions
supabase/tests/fixtures/live_seed.sql                   # published men barber for integration
supabase/config.toml                                    # + test_otp 213550000004/05/06
flutter_app/lib/
  core/time/{country_clock,clock_providers}.dart
  features/live/data/{live_models,live_derive,live_api,live_repository,live_failure,live_channels,live_providers}.dart
  features/live/presentation/today/{today_screen,status_control,queue_card,queue_list,queue_settings_sheet,offline_banner}.dart
  features/live/presentation/customer/{live_status_line,live_ring,live_block,join_queue_sheet,my_ticket_card}.dart
  features/home/presentation/pro_shell.dart
  shared/widgets/hours_table.dart
flutter_app/test/ (mirrors lib/)  flutter_app/integration_test/{live_queue_customer_test,live_queue_barber_test}.dart
.superpowers/spikes/m3-realtime/                         # spike notes (throwaway code not committed)
```

---

### Task 0: Commit the design and plan

- [x] **Step 1:** `git add docs/superpowers/specs/2026-11-20-lemqes-m3-live-queue-design.md task_plan.md && git commit` with subject `docs: add milestone 3 live queue design and plan`.

**Done when:** (1) `git log -1 --format=%s` = `docs: add milestone 3 live queue design and plan`; (2) nothing to run; (3) only those two files changed.

---

### Spike: Realtime private-channel delivery (throwaway, ≤ 2 h)

**Why first:** everything after Task 1 assumes that a DB-side `realtime.send(..., private => true)` reaches a Dart private channel, that the `realtime.messages` policy refuses another space, and that a client can hold ~35 channels. If any of that is false, Tasks 3–6 change shape.

- [x] **Step 1:** On a scratch branch off `feat/live-queue`, with a scratch migration and a Dart script (`scripts/sdk dart run`) using `supabase` 2.16.5: (a) a policy using `realtime.topic()` like the Approach's; (b) `select realtime.send(...)` as postgres → a subscribed same-space client receives it within 2 s, and the payload carries an `id` key; (c) a client whose policy check is false gets `RealtimeSubscribeStatus.channelError` (or the exact status it gets — record it); (d) one client subscribes 40 private channels — record the per-client/per-tenant limits that apply (the local Realtime `max_channels_per_client` / tenant settings and the matching hosted limits from the Supabase docs); (e) after `supabase.auth.refreshSession()` the channels keep receiving; (f) whether today's `realtime.messages_*` partition exists right after `supabase db reset`, and how long until it does.
- [x] **Step 2:** Write `.superpowers/spikes/m3-realtime/FINDINGS.md` with the observed results, the sources consulted and any plan amendment needed (proposed in the report, not applied silently). Delete the scratch branch.

**Done when:** (1) `FINDINGS.md` answers (a)–(f) with observed output (or a doc URL for hosted limits); (2) `git status` on `feat/live-queue` shows only `FINDINGS.md` added; (3) no other files changed. If (b) or (c) fails, stop and report BLOCKED (the transport decision returns to the user).

---

### Task 1: Live status — schema, shift end, status RPCs, auto-close

**Files:** Create `supabase/migrations/20261120000100_live_status.sql`, `supabase/tests/database/070-live-status.sql`; modify `supabase/tests/database/000-setup.sql` (`tests.freeze_now(timestamptz)`, `tests.set_hours(pro uuid, weekday int, opens time, closes time)`); modify `supabase/config.toml` (three test_otp numbers).

**Interfaces — Produces (SQL, `public`):** types `live_status`, `queue_mode`; `live_now()`; `service_day(p_at timestamptz, p_tz text) returns date` (immutable); `pro_live` + creation trigger + backfill (RLS: owner select; no client writes); `pro_shift_end(p_pro_id uuid, p_at timestamptz) returns timestamptz` (internal); `set_live_status(p_pro_id uuid, p_status live_status, p_break_until timestamptz, p_request_id uuid) returns pro_live` (owner → else `not_owner`; `p_break_until` only with `on_break`, null allowed, future and ≤ 4 h → else `invalid_break_until`); `extend_auto_close(p_pro_id uuid, p_request_id uuid) returns timestamptz` (`not_open` when effective-closed); `live_touch(p_pro_id)` (internal); `live_broadcast(p_pro_id uuid, p_queue_changed boolean default false)` — **stub that only bumps `queue_version`** here, completed in Task 3; `live_auto_close() returns integer` (closes expired rows, calls `live_broadcast` per closed pro); `live_effective(pro_live) returns table(status live_status, stale boolean)`; pg_cron job `lemqes_live_auto_close` `* * * * *` running `select public.live_auto_close()`. `queue_requests` table + `live_request_seen(p_actor, p_request_id, p_action, p_pro_id) returns boolean` (internal; raises `request_reused`) — used by every RPC from here on.

- [x] **Step 1:** Confirm `create extension if not exists pg_cron` works in a migration on the local stack and the `cron.schedule(job_name, schedule, command)` signature for 1.6 (pg_cron README); record the source in the migration header.
- [x] **Step 2: Failing pgTAP `070`** — cases: **S1** row created for a new pro, backfilled for existing; **S2** customer select on `pro_live` → 0 rows; **S3** another owner → `not_owner`; **S4** open at 09:00 on 09:00–19:00 → `auto_close_at` 19:30 local; **S5** open at 15:00 on 14:00–01:00 → 01:30 next day; **S6** open at 00:30 inside yesterday's 14:00–01:00 → 01:30 today; **S7** open at 08:30 before a 09:00 opening → 19:30; **S8** open on a closed weekday → now + 3 h 30; **S9** extend +60 and the 12 h cap; **S10** extend when effective-closed → `not_open`; **S11** `break_until` past or > 4 h → `invalid_break_until`, null accepted; **S12** `live_effective` closed when `auto_close_at` passed but row says open; **S13** stale at 2 h 00, not at 1 h 59; **S14** `live_auto_close()` closes exactly the expired rows and returns the count; **S15** executing the text of `cron.job.command` for `lemqes_live_auto_close` runs and the job is `active`; **S16** `service_day` 01:00 → previous date, 06:31 → same date; **S17** same request id twice → one change; same id with another action → `request_reused`; **S18** anon → 42501 on every client RPC; authenticated → 42501 on `live_touch`, `pro_shift_end`, `live_broadcast`, `live_auto_close`; **S19** client `update pro_live` → 42501.
- [x] **Step 3:** Implement; `supabase db reset`; `supabase test db` PASS; `supabase db lint` clean.
- [x] **Step 4:** Commit `feat: add live status with auto-close`.

**Done when:** (1) `070-live-status.sql .. ok` with S1–S19 each present as a named assertion (`-- S<n>` comment) and `plan(N)` matching; (2) `supabase test db` all files pass, `supabase db lint` no errors; (3) no files changed outside `supabase/`.

---

### Task 2a: Queue — entries and owner actions

**Files:** Create `supabase/migrations/20261120000200_queue_owner.sql`, `supabase/tests/database/080-queue-owner.sql`, `supabase/tests/race/call_next_race.sh`.

**Interfaces — Produces:** `queue_entries` (per Approach, delete guard trigger); type `owner_queue_row`; owner RPCs, all `(…, p_request_id uuid)`, owner-only (`not_owner`), lock `pro_live`, record the request, call `live_touch`, end with `live_broadcast(pro_id, true)`, return `setof owner_queue_row`: `queue_add_walk_in(p_pro_id, p_request_id)`, `queue_set_details(p_entry_id, p_name, p_service_id, p_request_id)` (`invalid_service`, `invalid_name`), `queue_undo_walk_in(p_pro_id, p_request_id)` (`nothing_to_undo`), `queue_call_next(p_pro_id, p_request_id)` (`queue_empty`; recomputes the average), `queue_finish(p_pro_id, p_request_id)` (`nothing_serving`), `queue_mark_absent(p_entry_id, p_request_id)` (`not_remote`), `queue_clear(p_pro_id, p_request_id)`; `owner_queue(p_pro_id)` (read); `queue_wait_min` (internal).

- [x] **Step 1: Failing pgTAP `080`** — **Q1** +1 gives tickets 1,2,3 and restarts on the next service day; **Q2** same request id twice → one entry; **Q3** undo removes only the latest waiting walk-in, `nothing_to_undo` when none; **Q4** call next on empty → `queue_empty`; **Q5** call next serves by `sort_at`, finishes the previous serving entry, exactly one serving row; **Q6** finish; finish with none serving → `nothing_serving`; **Q7** the partial unique indexes exist and every owner RPC body contains `for update` (assert via `pg_get_functiondef`); **Q8** `set_details` with another pro's or an inactive service → `invalid_service`; bad name → `invalid_name`; duration and price snapshotted; **Q9** absent on a walk-in → `not_remote`; **Q10** clear cancels waiting only; **Q11** wait: one 30-min walk-in ahead + serving 20-min entry called 10 min ago → 40; rounding up to 5; **Q12** average after 5 served = median, clamped 5..120, 20 before; **Q13** `owner_queue_row` has no `customer_id` column; labels (name / full_name / `Client N`); **Q14** customer calling any owner RPC → `not_owner`; anon → 42501; **Q15** `delete from queue_entries` as postgres → `history_is_kept`; deleting the pro cascades; no delete grant to authenticated; **Q16** each owner RPC inserts its `queue_requests` row.
- [x] **Step 2:** `call_next_race.sh`: seeds a pro with 3 waiting entries, runs `queue_call_next` from two `psql` sessions at once (different request ids, `pg_sleep` inside a `begin` block to force overlap) 20 times, asserts exactly one serving row and no error each time; exits non-zero otherwise.
- [x] **Step 3:** Implement; reset; `supabase test db` PASS; `sh supabase/tests/race/call_next_race.sh` exit 0; lint clean. Commit `feat: add live queue owner actions`.

**Done when:** (1) `080 .. ok` with Q1–Q16 as named assertions, `plan(N)` matching; the race script exits 0; (2) `supabase test db` all pass, `supabase db lint` no errors; (3) no files changed outside `supabase/`.

---

### Task 2b: Remote join, abuse limits, settings, blocks

**Files:** Create `supabase/migrations/20261120000210_queue_join.sql`, `supabase/tests/database/085-queue-join.sql`.

**Interfaces — Produces:** `pro_blocks(id, pro_id, customer_id references profiles on delete cascade, ticket_label text, created_at)` (owner select only, via RPC); `can_join(p_pro_id uuid)` (raises per Approach); `join_queue(p_pro_id uuid, p_service_id uuid, p_request_id uuid) returns my_ticket_row`; `queue_on_my_way(p_entry_id uuid, p_request_id uuid)`; `leave_queue(p_entry_id uuid, p_request_id uuid)`; `my_ticket() returns setof my_ticket_row (entry_id, pro_id, pro_space, ticket_no, state, end_reason, position, wait_min, on_my_way_at, called_at, ended_at, display_name, avatar_path)` — the active entry, or the latest ended one within 30 min; `set_queue_settings(p_pro_id, p_mode queue_mode, p_hide_count boolean, p_request_id uuid)`; `queue_block(p_entry_id, p_request_id)` (remote only → `not_remote`; stores the entry's label as `ticket_label`, cancels the entry `blocked`); `queue_blocked(p_pro_id) returns table(block_id, ticket_label, created_at)`; `queue_unblock(p_block_id, p_request_id)`. All customer/owner writes end with `live_broadcast`.

- [x] **Step 1: Failing pgTAP `085`** — **J1** each `can_join` code in isolation: `not_listable` (other space; unpublished; acting as barber), `own_queue`, `pro_not_open` (closed; effective-closed; stale; on break with and without `break_until`), `queue_paused` (paused; followers), `already_in_queue` (active entry at another pro), `join_limit_reached` (6th remote join of the service day), `absent_block` (2 absents within 7 days; lifted 24 h after the 2nd), blocked → `pro_not_open` (security wave; was `join_unavailable`); **J2** join succeeds: position, wait, `sort_at` order with walk-ins; inactive or other-pro service → `invalid_service`; **J3** same request id twice → one entry; **J4** on-my-way stamps, does not reorder; **J5** leave → cancelled `left`; **J6** `my_ticket` shows ended `absent` / `end_of_day` within 30 min, nothing after; **J7** a customer `select * from queue_entries` → only own rows; **J8** settings change mode/hide count, owner only; **J9** block stores the label, refuses walk-ins (`not_remote`), unblock restores joining; `queue_blocked` exposes no customer id; **J10** deleting a customer account keeps their history rows with `customer_id` null; **J11** a walk-in entry plus a remote entry for the same person never collide (index is remote-only); **J12** anon → 42501 on every new function.
- [x] **Step 2:** Implement; reset; `supabase test db` PASS; lint clean. Commit `feat: add remote queue join with abuse limits`.

**Done when:** (1) `085 .. ok` with J1–J12 as named assertions (J1 one assertion per code and sub-case), `plan(N)` matching; (2) `supabase test db` all pass, `supabase db lint` no errors; (3) no files changed outside `supabase/`.

---

### Task 3: Snapshots, search column, broadcasts, channel policy, end-of-day

**Files:** Create `supabase/migrations/20261120000300_live_realtime.sql`, `supabase/tests/database/090-live-realtime.sql`; modify `supabase/tests/database/060-search-pros.sql`; modify `flutter_app/lib/features/explore/data/explore_models.dart` (+ test) only if the new column breaks parsing.

**Interfaces — Produces:** `live_snapshot` (keys per Approach); `pro_live_snapshots(p_pro_ids uuid[]) returns table(pro_id uuid, live jsonb)` (customer: listable only, others dropped; owner: own; > 60 → `too_many_ids`); `search_pros` (same params, M2 columns + `live jsonb`); real `live_broadcast`; definer trigger on `pro_profiles`; `live_topic_allowed(text)` + `live_topics` policy; `queue_end_of_day() returns integer` (cancels `waiting|serving` of earlier service days `end_of_day`, broadcasts per pro, prunes `queue_requests` > 2 days) as job `lemqes_queue_end_of_day` `30 5 * * *` (UTC = 06:30 Africa/Algiers).

- [x] **Step 1: Failing pgTAP `090`** — **R0** today's `realtime.messages` partition exists (fail with a clear message if not — the Spike's finding (f) says how `integration.sh`/tests wait for it); **R1** snapshot keys equal the Approach list exactly; no key contains `name`, `customer`, `phone`; **R2** when hidden, no `waiting_count`, `ahead_minutes`, serving fields or `queue_version`, and `wait_min` present (security wave; was `waiting_count` null); **R3** `join_block` per status/mode (closed, on_break, paused, followers, null); **R4** `status_age_from` rounded down to 5 min; **R5** `pro_live_snapshots` drops other-space and unpublished ids, `too_many_ids` at 61; **R6** `search_pros` `live` equals `live_snapshot` for the same pro, spaces still isolated (060 updated); **R7** each client RPC from Tasks 1–2b, **run as `authenticated`**, inserts exactly one `realtime.messages` row (topic `pro:<id>`, event `live`, `private` true, payload minus `id` equals `live_snapshot`); a refused RPC inserts none; **R8** a direct client `update pro_profiles set display_name …` as `authenticated` inserts one row; unpublish inserts one with `join_block = 'closed'`; **R9** `live_topic_allowed`: owner true, same-space listable customer true, other-space false, unpublished false, acting as barber for another pro false, `pro:abc` and `pro:<uuid>x` false without error, anon false; **R10** `queue_end_of_day` cancels yesterday's waiting and serving, keeps today's, returns the count, prunes old requests; its `cron.job.command` text runs; **R11** authenticated → 42501 on `live_snapshot`, `live_broadcast`, `queue_end_of_day`, `queue_wait_min`.
- [x] **Step 2:** Implement; reset; `supabase test db` PASS; lint clean; `npm run lint && npm run typecheck && scripts/sdk flutter test` (the M2 explore parser must accept the new column).
- [x] **Step 3:** Commit `feat: broadcast live snapshots on private channels`.

**Done when:** (1) `090 .. ok` with R0–R11 named, `060 .. ok`, `plan(N)` matching; (2) full gate `npm run lint`, `npm run typecheck`, `npm test` pass; (3) no files changed outside `supabase/` and `flutter_app/lib/features/explore/data/explore_models.dart` + its test.

---

### Task 4a: Country clock, live models, failures, repository  ‖ parallel with Tasks 1–3 (worktree)

**Files:** Create `lib/core/time/{country_clock,clock_providers}.dart`, `lib/features/live/data/{live_models,live_derive,live_failure,live_api,live_repository}.dart`, tests. Modify `lib/shared/widgets/hours_table.dart`, `lib/features/explore/presentation/pro_public_profile_screen.dart` and `lib/features/pro/presentation/dashboard/pro_dashboard_screen.dart` (replace `profileClockProvider` device time with `countryClockProvider`), their tests.

**Interfaces — Produces:** `DateTime countryNow(String timezone, DateTime utcNow)`; `clock_providers.dart`: `utcClockProvider` (the only `DateTime.now()` call), `countryClockProvider`, `serverOffsetProvider`. Models: `LiveStatus`, `QueueMode`, `JoinBlock {closed, onBreak, paused, followers, unknown}`, `LiveSnapshot` (all snapshot keys; `fromJson` ignores `id` and unknown keys; `isNewerThan`), `OwnerQueueRow`, `MyTicket`, `BlockedCustomer`. `live_derive.dart`: `LiveView derive(LiveSnapshot s, DateTime serverNow)` → effective status, stale, break-overdue, current wait, age (pure). `LiveFailure` (sealed) for every SQL code of Tasks 1–3 (`NotOwner, NotOpen, InvalidBreakUntil, RequestReused, QueueEmpty, NothingToUndo, NothingServing, NotRemote, InvalidService, InvalidName, NotListable, OwnQueue, ProNotOpen, QueuePaused, AlreadyInQueue, JoinLimitReached, AbsentBlock, JoinUnavailable, TooManyIds, LiveNetworkFailure, UnknownLiveFailure`) with a `guardLive` like `guardPro`. `LiveApi` (thin RPC adapter) + `LiveRepository` (one method per client RPC; each user action gets a request id that is **reused on retry of that action**).

- [x] **Step 1: Failing tests:** `country_clock_test.dart` (UTC 23:30 → Algiers 00:30 next day; unknown zone throws); `hours_table_test.dart` addition (device in UTC−5 at 23:30 still highlights the Algiers weekday); `live_models_test.dart` (RPC `live` object and broadcast payload with `id` parse equal; `isNewerThan`); `live_derive_test.dart` (open → closed at `auto_close_at` without a new snapshot; stale at 2 h; break overdue; wait shrinks with time since `serving_called_at`, never below the rounded floor; age uses server time); `live_repository_test.dart` (every code → its failure — grep each code string in the migrations; retry reuses the request id; network → `LiveNetworkFailure`).
- [x] **Step 2:** Implement; PASS; commit `feat: add country clock and live data models`.

**Done when:** (1) the five test files pass; `grep -rn "DateTime.now()" flutter_app/lib` lists only `core/time/clock_providers.dart` and files not touched by M3 (list them in the report); (2) `npm run lint`, `npm run typecheck`, `scripts/sdk flutter test` pass; (3) no files changed outside `flutter_app/lib/core/time/`, `flutter_app/lib/features/live/data/`, the three files named above, matching `test/` dirs. Merged into `feat/live-queue` after Task 3 (code strings re-grepped against the final migrations).

---

### Task 4b: Live channels and providers

**Files:** Create `lib/features/live/data/{live_channels,live_providers}.dart`, tests. Modify `lib/features/explore/data/{explore_models,explore_providers}.dart` (`ProCard.live`, seed `proLiveProvider`) + tests.

**Interfaces — Produces:** `LiveChannels` (per Approach; constructor takes a channel factory and a snapshot fetcher for tests; `watch(proId) → Stream<LiveSnapshot>`, `connected`, `closeAll()`); listens to account space/role and auth changes and calls `closeAll()` then re-subscribes the current listeners. Providers (all `retry: null`): `proLiveProvider(proId)` (`LiveView`, re-derived by a 30 s ticker), `ownerQueueProvider(proId)` (refetch when `queueVersion` changes; actions expose in-flight state), `myTicketProvider` (refetch on its pro's snapshots and on resume; empty when `pro_space` ≠ current space), `liveConnectedProvider`.

- [x] **Step 1: Failing tests:** `live_channels_test.dart` with a fake factory (two listeners share one channel; 10 s linger then unsubscribe; resubscribe triggers a batched re-fetch; an older broadcast is ignored; space change closes every channel and re-joins with the new space's listeners; a channel error marks disconnected after 5 s); `live_providers_test.dart` (ticker flips open → closed with no message; owner queue refetches only on a new `queueVersion`; ticket refetch on snapshot; ticket hidden in the other space; failing fetch is not retried automatically).
- [x] **Step 2:** Implement; PASS; commit `feat: add live channels and providers`.

**Done when:** (1) the two new test files and the updated explore tests pass; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/live/data/`, `flutter_app/lib/features/explore/data/`, matching `test/` dirs.

---

### Task 5: Pro shell and the Today screen

**Files:** Create `lib/features/home/presentation/pro_shell.dart`, `lib/features/live/presentation/today/*`, tests + goldens. Modify `home_screen.dart` (pro branch → `ProShell`), `app_router.dart` if needed, ARBs + REVIEW.md.

**Behaviour:** per design §5 Barber surfaces. Status segmented button (Ouvert / En pause / Fermé; break opens return-time chips 15/30/45/60 min + "Sans heure"; Fermé with entries waiting asks to confirm). Auto-close row ("Fermeture auto à 19:30" in `Ltr`, "Prolonger d'1 h"). Queue card: large tabular count, −1 / +1, full-width gradient "Appeler le suivant" in the thumb zone; "En cours" row with "Terminé". Queue list: position, label, service, walk-in/remote icon + word, "en route" badge; tap → sheet with service chips + optional name (walk-ins), "Absent" and "Bloquer" (remote, with confirm). Settings sheet: mode (3 choices; "Abonnés seulement" explains it works like "En pause" until followers arrive), hide-count switch, blocked list with unblock. "Vider la file" with confirm. "Hors ligne" banner disables every action; action buttons ignore taps while their call is in flight. Unpublished banner ("Les clients ne voient pas votre statut"). Failures through a `LiveFailureListener` (like `ProFailureListener`).

- [x] **Step 1: Failing tests:** `pro_shell_test.dart` (pros land on Aujourd'hui; Mon profil = M2 dashboard; customers unaffected); `today_screen_test.dart` (status change calls the repo; auto-close row from the snapshot in Algiers time; +1/−1/call next/finish; a second tap on call next while in flight sends nothing; offline banner disables actions; Fermé with waiting confirms; unpublished banner; failure snackbar keeps content); `queue_list_test.dart` (labels; remote-only actions); `queue_settings_sheet_test.dart` (mode, hide count, unblock); 200 % `ar` no overflow on all four. Goldens: Today (open with 4 entries incl. one remote "en route", on break, closed empty) × light/dark × fr/ar.
- [x] **Step 2:** Implement; ui-quality self-review; PASS; **look at every golden PNG** and list each path with a one-line observation in the report; commit `feat: add pro today screen with live queue controls`.

**Done when:** (1) the four test files pass; every golden listed by path with its observation; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/{live,home}/presentation/`, `flutter_app/lib/core/router/`, `flutter_app/lib/core/l10n/`, matching `test/` dirs (data-layer fixes the UI exposes are allowed in `flutter_app/lib/features/live/data/` and listed).

---

### Task 6: Customer live surfaces

**Files:** Create `lib/features/live/presentation/customer/*`, tests + goldens. Modify `lib/features/explore/presentation/{pro_card_tile,explore_screen,pro_public_profile_screen}.dart` + tests, ARBs + REVIEW.md.

**Behaviour:** per design §5 Customer surfaces. `LiveStatusLine` (dot + word + age; "Statut incertain" muted; "retour 14:30" / "Pause prolongée"; "Mis à jour il y a X min" while disconnected); `LiveRing` (gradient open, dashed grey break, none closed/stale) on card avatars and the profile hero; queue line ("3 en attente · ~40 min" / "File ouverte · ~40 min" / "File complète" / none when closed). Cards subscribe while mounted. Profile: `LiveBlock` + "Rejoindre la file" (enabled when `join_block` is null) → `JoinQueueSheet` (services with duration, price per `show_prices`) → ticket; each `can_join` code has its own sentence (a blocked customer hears the closed pro's `pro_not_open` sentence; security wave, `join_unavailable` removed). `MyTicketCard` at the top of Explore (ticket's space only): "Vous êtes 3e · ~25 min" with the gold badge, "C'est votre tour", "Je suis en route", "Quitter la file" (confirm), ended states for 30 min ("Marqué absent", "File fermée par le barbier"). Position changes announced with `SemanticsService.announce` (G5). Owner preview `/pro/me/preview` shows the live block read-only.

- [x] **Step 1: Failing tests:** `live_status_line_test.dart` (each status; stale; age from server offset; break return time and overdue; disconnected label; open → closed when the fake clock passes `auto_close_at` with no broadcast); `pro_card_tile_test.dart` additions (hidden count; paused; closed shows no queue line; a broadcast updates the card without refetch); `join_queue_sheet_test.dart` (each refusal sentence; success shows the ticket); `my_ticket_card_test.dart` (position; serving; ended states; hidden in the other space; leave confirm; announcement on position change); `pro_public_profile_screen_test.dart` additions (join disabled per `join_block`; owner preview read-only); 200 % `ar` no overflow. Goldens: explore with ticket card + 3 live cards (open, break, closed), profile live block, join sheet × light/dark × fr/ar.
- [x] **Step 2:** Implement; ui-quality self-review; PASS; look at every golden and list it with an observation; commit `feat: show live status and queue to customers`.

**Done when:** (1) the five test files pass; every golden listed by path with its observation; (2) lint, typecheck, flutter test pass; (3) no files changed outside `flutter_app/lib/features/{live,explore}/presentation/`, `flutter_app/lib/core/l10n/`, matching `test/` dirs (data-layer fixes allowed in `flutter_app/lib/features/live/data/`, listed).

---

### Task 7: Integration paths, finish review, milestone gate

**Files:** Create `supabase/tests/fixtures/live_seed.sql`, `flutter_app/integration_test/{live_queue_customer_test,live_queue_barber_test}.dart`; modify `scripts/integration.sh` (apply the seed after reset for the live files, wait for today's `realtime.messages` partition, run all four files), `DESIGN.md`, `CLAUDE.md` (Flutter 3.50.0; architecture notes for live/queue), `task_plan.md` (ticks + Gate log).

- [x] **Step 1: `live_seed.sql`** creates (as postgres) the men barber account 0550000004 with password `lemqes-test-1`, a published profile with two services and hours 00:00–23:59 on all seven days (so the test never depends on the wall clock), and a women barber for the leak control.
- [x] **Step 2: `live_queue_customer_test.dart`** (app = customer 0550000005 signing up; a raw `SupabaseClient` signed in as the barber; a raw client signed up as the women customer 0550000006): card shows "Fermé"; raw barber opens and adds 2 walk-ins → the app's card shows "Ouvert" and "2 en attente" within 3 s with no user action; open profile, join → "Vous êtes 3e"; raw barber calls next twice → "C'est votre tour" within 3 s; raw barber hides the count → "File ouverte"; **leak check with positive control:** the women raw client joins `pro:<men barber>` → `channelError`, while a second men-space raw client on the same topic receives the next broadcast; **switch path:** the app switches to Femmes → no ticket card, no men card, and a broadcast sent after the switch is not received by the app (its channel was closed); **reconnect:** `realtime.disconnect()`, raw barber adds a walk-in, `realtime.connect()` → the card shows the new count within 3 s.
- [x] **Step 3: `live_queue_barber_test.dart`** (app = barber 0550000004 signing in; raw customer 0550000005): Today screen opens; +1, raw customer joins → the remote entry appears with its name within 3 s; call next → the raw customer's `my_ticket` shows serving; mark absent on a remote entry; "Hors ligne" banner after `realtime.disconnect()` disables "Appeler le suivant".
- [x] **Step 4:** `sh scripts/integration.sh` twice in a row. Run the app; capture Today, explore, profile, ticket card in fr-light and ar-dark; impeccable finish review against DESIGN.md; fix; add the new components to DESIGN.md; fix CLAUDE.md.
- [x] **Step 5:** Full gate (lint, typecheck, `npm test`, race script, integration ×2) → Gate log row at the branch tip; `security-auditor` (realtime policy, internal helper grants, snapshot payloads, join abuse and oracles, request-id replay, cron jobs, presence tracking R14) and whole-branch `code-reviewer` in parallel; one fix wave; re-gate; re-review; ask the user before merging `feat/live-queue` → `develop` (`--no-ff`); propose M4.

**Done when:** (1) two consecutive integration runs pass all four files; DESIGN.md lists the new components; CLAUDE.md says Flutter 3.50.0; the Gate log row at the final pre-merge commit is all green; a findings table has one disposition per finding (fixed + commit, or ruled + reason); (2) same full gate; (3) no files changed outside `flutter_app/`, `scripts/integration.sh`, `supabase/` (seed + review fixes), `DESIGN.md`, `CLAUDE.md`, `task_plan.md`, `.impeccable/`.

---

## Risks & open questions

| # | What | Why it matters | Decision (recommended first) | Relation | Cost |
|---|---|---|---|---|---|
| R9 | Realtime channel limits per client/tenant (≈ 30 cards + profile + ticket) | Joins over the limit are refused; cards would silently stop updating | A: measured in the Spike; `LiveChannels.watch` stays the only UI interface so the topic strategy can change (recommended) | [NEEDED for the plan — Spike] | in spike |
| R10 | Device clock skew | Ages and auto-close would lie on a phone with a wrong clock | Server time in every snapshot; derivation uses the offset | [NEEDED — Task 4a] | in task |
| R11 | Fixed UTC+1 for Algeria in Dart | Fine for DZ; Morocco/France need a tz database | `timezone` package with the next country | [FUTURE idea] | 1 h |
| R12 | No push until M12 | A customer with the app closed misses "C'est votre tour" | Accept; M12 push | [FUTURE idea — M12] | — |
| R13 | Hosted: Realtime "Allow public access" off, pg_cron enabled, partitions created | Otherwise public channels exist and jobs don't run | Add to the hosted checklist with R3 | [NEEDED — before hosting] | 15 min |
| R14 | Presence tracking: anyone in a space can watch when a pro (esp. women's space) opens, pauses, closes | Physical-safety concern in a small town | Ages rounded to 5 min now; per-account snapshot rate limit with R3 before hosting; revisit "status visible to followers only" with M6 | [NEEDED — before hosting] | 1 h |
| R7/R3 | Scraping/abuse; hosted rate limiting | Carried from M2; remote join adds a write path | SQL limits now (G1); rate limit with the hosted setup | [NEEDED — before hosting] | — |
| R15 | Barber on weak 4G can't act while "Hors ligne" | User decided G3 = disable; queued offline actions would be safer for flow but riskier for truth | Keep the decision; revisit after field use | [FUTURE idea] | 3 h |
| M2 minors | Deferred minors in `.superpowers/sdd/task_plan/progress.md` | — | Only "today uses device clock" is fixed here (Task 4a); the rest stay deferred | [SIDE FIX — safe to defer] | — |
| D7, R4–R6, R8, D1–D6, R1–R3 | Carried from M2 | See git `fdeb191:task_plan.md` | Unchanged | as before | — |

## Roadmap

M1 foundation ✅ (`f7263e0`) · M2 barber profile, photos, services, explore ✅ (`4b0a4f3`, F1 `70f9c17`, `fdeb191`) · **M3 live status + queue (this plan)** · M4 map + near-me, workplace pick, commune coordinates, Arabic search folding · M5 bookings (slots from M2 hours, bookings in the queue via `sort_at`), reminders, −15 min auto-cancel, in-app account deletion → **first store release** (wallet off) · M6 follow, broadcasts, discounts, reviews (from served visits), followers-only queue · M7 salons + join requests (`served_by`) · M8 home visits · M9 finance (`price_dzd` snapshots) · M10 wallet (`join_block = limited`) · M11 QR + deep links · M12 push polish.

## Gate log

| Commit | lint | typecheck | flutter test | supabase test db | integration | Notes |
|---|---|---|---|---|---|---|
| 5c821cd (M1 merge gate) | ✅ | ✅ | ✅ 256 | ✅ 65 | ✅ ×2 | Milestone 1 baseline. |
| 7514d8c (M2 pre-merge gate) | ✅ | ✅ | ✅ 572 | ✅ 231 | ✅ ×3 | After security audit + whole-branch review fix wave. |
| fcd04d9 (F1 gate) | ✅ | ✅ | ✅ 582 | ✅ 247 | ✅ ×2 | Contact phone; 248 pgTAP after review pin. |
| adca74d (M3 pre-merge gate) | ✅ | ✅ | ✅ 839 | ✅ 618 | ✅ ×2 (4 files) | After security audit + whole-branch review fix wave; race 20/20; pgTAP also green on a DB with leftover integration seed. |
| 3bb7ea0 (M3 security fix wave) | ✅ | ✅ | ✅ 854 | ✅ 651 | ✅ ×2 (4 files) | User chose "Fix all, then merge": blocked customer sees a permanently closed barber, join-check order, replay filter, hidden-count payload, absent after call; security re-review approved; race 20/20; pgTAP green after integration. |

## Plan review (2026-11-20, LLM council) — what changed

- **Broadcasts:** row triggers on `pro_live`/`queue_entries` would send 3+ messages per action and recurse through the `queue_version` bump → one explicit, security-definer `live_broadcast` at the end of each RPC/job; only `pro_profiles` keeps a (definer) trigger. Tests run as `authenticated` (postgres bypasses RLS) and compare payload minus the `id` that `realtime.send` adds; R0 checks the daily partition exists because `realtime.send` swallows errors.
- **Time-driven staleness:** nothing is sent when only time passes → snapshots carry raw timestamps and wait inputs; the client re-derives on a 30 s ticker (`live_derive.dart`), with widget tests advancing the clock and no broadcast. Customer surfaces show "Mis à jour il y a X min" while disconnected.
- **Channel auth at join only:** channels close on space/role/auth change; integration tests the switch path and the leak check now has a positive control (`channelError` vs a same-space receiver).
- **Spike first** (private delivery, refusal status, channel limits, JWT refresh, partitions) before any task builds on Realtime.
- **Concurrency:** `for update` on `pro_live` in every RPC; pgTAP pins the lock and indexes; a two-session race script proves it.
- **Idempotency:** every mutating RPC takes a non-null request id; `queue_requests` keyed `(actor, request_id)` with the action (`request_reused`).
- **Security:** internal helpers revoked from clients (pgTAP); owner reads return labels, never customer ids; a blocked customer reads the pro as closed (`pro_not_open`, closed snapshot, refused channel; security wave, replacing `join_unavailable`); ages rounded to 5 min (R14).
- **Cheap now, costly later:** `served_by` (M7), `price_dzd` snapshot (M9), `customer_id on delete set null` (store-required account deletion), remote-only active index (M5), `join_block` code instead of a boolean (M6/M10), one `live jsonb` in `search_pros` (M4).
- **Definitions:** service day (06:30) defined once; break without a return time is not joinable; followers mode → `queue_paused`; `nothing_serving`; "Hors ligne" signal; time frozen by redefining `live_now()` in the test transaction (never a GUC).
- **Sizing and order:** Task 2 split into 2a/2b and Task 4 into 4a/4b; Task 4a runs in parallel with Tasks 1–3; Riverpod providers `retry: null`.
- **Done-whens:** numbered pgTAP cases, cron command executed (not only registered), Task 3 fence widened to the explore parser, `DateTime.now()` confined to one named file, goldens listed with an observation each, integration seeds by SQL and reconnects by `realtime.disconnect()/connect()`, third test phone, Gate log before the merge question, CLAUDE.md Flutter version.
- **Declined:** "explore cards refresh every 60 s instead of live" (contradicts the settled ~2 s goal); offline queueing of barber actions (contradicts the G3 decision — R15); price `currency` column (money is integer DZD by global constraint).

---

`/goal every task in task_plan.md is checked off per its own "Done when", and npm run lint, npm run typecheck, npm test and sh scripts/integration.sh all pass`
