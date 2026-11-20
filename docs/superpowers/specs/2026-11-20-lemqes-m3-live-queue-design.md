# LEMQES M3 — Live status and live queue: design

Date: 2026-11-20 · Status: DRAFT (interview done 2026-11-19/20; approval with the M3 plan) · Parent spec: [2026-11-13-lemqes-flutter-supabase-design.md](2026-11-13-lemqes-flutter-supabase-design.md) §4 step 3, §5 "Live", §7, §7b

## 1. Intent

A customer opening LEMQES should know, before leaving home, whether their barber is open and how long the wait is, and should be able to take a place in line from the app. A barber should run the day's line from one thumb-reachable screen. The parent spec's anti-goal governs everything here: **a status or queue that can be stale without saying so is a failure**, even if it technically works.

## 2. Goals, non-goals, anti-goals

**Goals**
- Barber live status (open / on break / closed) and a live queue (walk-ins + remote joins), propagated to every watching phone within ~2 s.
- Status never stays "open" past closing time unattended; customers always see how old a status is.
- Queue privacy settings: hide the queue count, followers-only join (stored; behaves as paused until M6).
- Status, queue count and wait on the explore cards and the public profile.
- Abuse limits on remote joins enforced in SQL.

**Non-goals (M3)**
- Push notifications (M12): "your turn" and "on my way" are seen only while the app is open.
- Bookings taking a turn ahead of walk-ins (M5) — the order key is ready for it.
- Zero-balance limits (M10) — one `can_join` function is where M10 adds its check.
- Followers (M6), map/distance (M4), salons sharing a queue (M7).

**Anti-goals**
- A confident green "Ouvert" on a shop that closed hours ago.
- Any customer seeing another customer's name in a queue.
- A duplicated "call next" (double tap, retry on bad 4G) skipping someone.
- A men's barber surfacing in the women's space through the queue (ticket card, broadcasts).

## 3. Decisions made with the user (2026-11-19/20)

| Topic | Decision |
|---|---|
| Stale status | **Both:** auto-close at closing time (Africa/Algiers) + a grace the barber can extend; customers always see the status age. |
| Walk-in entry | **+1 is one tap**; an optional service and an optional name can be added to the entry afterwards. |
| Hide queue count | **Hides only the number**; the wait ("~40 min") stays visible. A joined customer always sees their own place. |
| Pro-gap G1 | Abuse limits in SQL: one active place per account, ≤ 5 joins per day, 24 h block after 2 "absent" marks, barber can block an account. |
| Pro-gap G2 | Served/absent/cancelled entries are kept as history (state column), never deleted. |
| Pro-gap G3 | Every queue action is one atomic server call with a request id; the Today screen shows "Hors ligne" and disables actions when offline. |
| Pro-gap G4 | Average service time learned from history (median of the last 20 served, default 20 min until 5 exist). |
| Pro-gap G5 | Screen-reader announcements when the customer's place changes. |
| Transport | **B — database broadcasts:** triggers send a small public snapshot on a private per-barber channel; names never travel on it. |

## 4. Approaches (transport)

| Approach | Trade-off | Verdict |
|---|---|---|
| A. Postgres Changes on the queue/status tables | Least code, but queue rows carry names (needs a mirrored public table) and every change is authorized per subscriber, the scaling path Supabase warns about | Rejected |
| **B. Broadcast from the database** (`realtime.send(..., private => true)` from triggers; RLS on `realtime.messages` authorizes topics) | Privacy by construction (payload is the public snapshot), the recommended scalable path; more SQL | **Chosen** |
| C. Client polling | Simple, but misses ~2 s and costs battery/data on a list | Rejected |

Sources: Supabase docs "Broadcast" (`realtime.send(payload, event, topic, private)`; database broadcasts are private by default) and "Realtime Authorization" (`for select` policy on `realtime.messages` = receive, `realtime.topic()`, client `RealtimeChannelConfig(private: true)`; enforcing private-only needs "Allow public access" off in hosted Realtime settings). Dart: realtime_client 2.13.2 (`RealtimeChannelConfig.private`, `setAuth`), supabase-dart 2.16.5 re-sends the session token to Realtime on auth changes. pg_cron 1.6.4 is available in the local stack.

## 5. Behaviour

### Status
- Barber sets **Ouvert**, **En pause** (optional return time), **Fermé**. Every action stamps `last_activity_at`.
- Opening (or pausing) computes `auto_close_at` = end of the current shift from M2 hours in the country timezone + **30 min grace**. Past-midnight shifts close the next calendar day. Opening outside any shift gives `now + 3 h` (Claude's call). "Prolonger d'1 h" adds 60 min, any number of times, never past `now + 12 h`.
- A once-a-minute job closes every pro whose `auto_close_at` has passed and broadcasts. Every read also derives the effective status from `auto_close_at`, so a missed job run never shows a stale "open".
- **Age:** every customer-facing status shows its age ("il y a 12 min"). An open/break status with no barber action for **2 h** reads **"Statut incertain"** (muted, no live ring).
- Snapshots carry the server time, so ages are computed against the server clock, not the device's.

### Queue
- One line per pro, first come first served by `sort_at` (= join time; M5 bookings will set an earlier `sort_at`).
- **Walk-in +1:** one tap → entry "Client N" (ticket number per pro per service day). Optional service and name can be set afterwards. **−1** removes the most recent waiting walk-in (corrects a mis-tap).
- **Remote join:** a customer picks a service and gets the next place. Allowed only when the pro is listable to them, effective status is open (or on break before the return time), the queue mode is open, and the G1 limits pass. The owner can never join their own queue.
- **"Je suis en route"** is information for the barber; it never reorders.
- **"Appeler le suivant"** finishes the current "en cours" entry (served) and moves the first waiting entry to "en cours". **"Terminé"** finishes the current one without calling. **"Absent"** (remote entries) removes them and counts toward the G1 block.
- **Wait** for a position = remaining time of the "en cours" entry (its duration minus time since it was called, at least 5 min) + durations of the waiting entries ahead. Duration = the service's duration, or the learned average (G4). Shown as "~N min", rounded up to 5.
- **End of day:** auto-close stops new joins only. Waiting entries stay until the barber serves or clears them ("Vider la file", with confirmation). A daily job at 06:30 Africa/Algiers cancels whatever is left from the previous service day; the customer sees "File fermée par le barbier".
- **Hide count:** customers see "File ouverte · ~40 min" instead of "3 en attente · ~40 min".
- **Queue mode:** Ouvert à tous / Abonnés seulement (= paused until M6) / En pause ("File complète"). Walk-in controls always work.

### Abuse limits (G1)
- One active entry (waiting or serving) per customer account, across all pros.
- At most 5 remote joins per customer per service day.
- 2 "absent" marks within 7 days block remote joins for 24 h (Claude's call on the 7-day window).
- A barber can block the account behind a remote entry; a "Clients bloqués" list lets them unblock. A blocked customer's join is refused with a neutral message.
- Hosted rate limiting (R3) still applies before any hosted release.

### Customer surfaces
- **Explore card:** live ring (open), dashed ring (break), status word + dot + age, then "3 en attente · ~40 min" (or "File ouverte · ~40 min", "File complète", nothing when closed). Cards on screen update live.
- **Public profile:** a live block under the hero (same facts, larger), "Rejoindre la file" (service picker sheet), then once joined "Vous êtes 3e · ~25 min" with the gold badge, "Je suis en route", "Quitter la file".
- **"Votre file" card** at the top of Explore while the customer holds a place, **only in the ticket's space** (never a cross-space surface).
- Screen readers hear "Vous êtes 2e" when the position changes (G5).

### Barber surfaces
- Pros get a bottom navigation: **Aujourd'hui** (default) and **Mon profil** (the M2 dashboard).
- **Today:** status segmented button; auto-close row ("Fermeture auto à 19:30 · Prolonger d'1 h"); queue card with the large count, −1 / +1 and a full-width "Appeler le suivant" under the thumb; "En cours" row with "Terminé"; queue list (position, name or "Client N", service, walk-in/remote, "en route" badge, actions); queue settings sheet (mode, hide count, blocked clients); "Vider la file"; "Hors ligne" banner that disables actions; an unpublished profile shows that customers cannot see the status.

## 6. Constraints
- All M2 global constraints (definer RPCs with `search_path = ''`, `(select …)` in policies, space separation tested in pgTAP, ARB + REVIEW.md for every string, DESIGN.md tokens, 48 dp, WCAG AA, RTL designed).
- Time in SQL: `timestamptz` + `geo_countries.timezone`; never device time. In Dart: server time from snapshots; for "today" in `HoursTable`, the country's offset (Algeria is UTC+1 with no DST).

## 6b. Calls made after the plan review (2026-11-20, Claude's — correct any)

- A break **without** a return time is not joinable; a break whose return time has passed shows "Pause prolongée" and is not joinable.
- A customer refused because the barber blocked them sees a neutral "Impossible de rejoindre cette file pour le moment" (no block oracle).
- Status ages are rounded to 5 min (coarse presence; women's-space safety, R14).
- While a customer's live connection is down, the status line says "Mis à jour il y a X min" instead of a confident status.
- Cards re-derive closed / stale / break-over / wait locally on a 30 s ticker, because no message is sent when only time passes.
- History rows keep `served_by` (M7), the price at the time (M9), and survive account deletion with the customer id cleared.

## 7. Left to the builder
Exact column names, function signatures and channel event names beyond those fixed in the plan; widget decomposition; animation details (per the `motion` skill).
