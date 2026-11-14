# LEMQES — Flutter + Supabase rebuild: design

Date: 2026-11-13 · Status: READY FOR APPROVAL · Product record: [PRODUCT.md](../../../PRODUCT.md)

## 1. Intent and why

LEMQES exists to remove the wait-and-guess of the neighbourhood barbershop. Before leaving home, a customer should know whether their barber is open and how many people are ahead. A barber should fill the chair without phone calls.

Today the product is a Jetpack Compose prototype (`app/`, ~18.6k lines) exported from Google AI Studio. Every screen and flow exists, but nothing is real: there is no backend, all data is in-memory (`MockRepository.kt`), and login, map, ads, wallet, QR, push and deep links are simulated.

This project rebuilds LEMQES as a real, shippable product: a **Flutter** app for iOS and Android on a **Supabase** backend. It covers the full prototype scope with a full visual redesign. The Kotlin code stays as the **reference spec** for screens, flows and business rules; it is not ported line by line.

**Success:** barbers keep their live status and queue current during the working day, customers stop walking to closed or full shops, and the app passes App Store and Play review with store-only payments.

## 2. Goals, non-goals, anti-goals

**Goals**
- Every prototype feature works for real, end to end, between real phones (scope list in §5).
- Live state (status + queue) propagates to every watching phone within ~2 s.
- 4 languages (Arabic RTL, French, English, Tamazight), with Arabic as a first-class layout.
- Strict Men / Women separation everywhere, enforced server-side, not only in the UI.
- A modern, premium, distinctive visual identity (§7), shared by iOS and Android.

**Non-goals (for this project)**
- No admin web panel: verification and moderation are done in the Supabase dashboard.
- No languages beyond the 4 current ones (the i18n structure is ready for the other 11).
- No local payment rails (Chargily, Edahabia, cash top-ups).
- No auto-renewing subscriptions.
- No porting of the Kotlin UI code.

**Anti-goals (a failure even if it technically works)**
- A queue or status that can be stale without saying so.
- A mixed Men/Women surface anywhere, including search, maps, follows, broadcasts and notifications.
- Arabic that is a mirrored afterthought: clipped, mis-ordered numerals, LTR icons.
- A zero-balance barber made invisible or humiliated: followers still see the profile, QR and status.
- A generic booking-app look that could belong to any country.

## 3. Constraints

- **Stores:** Apple In-App Purchase and Google Play Billing are the only payment paths. Apple and Google rules must be rechecked before launch.
- **Login:** phone + password. An SMS one-time code only at sign-up and password reset. Google sign-in is an optional extra.
- **Hosting:** Supabase in an EU region.
- **Launch market:** Algeria first (confirmed 2026-11-13), currency DA. Tunisia, Morocco and France/Europe come later, and pricing per country lives in the store consoles.
- **Flutter:** current stable. The installed fvm 3.24.4 is from 2024 and must be upgraded.
- **Repo layout:** new `flutter_app/` and `supabase/` folders; the Kotlin `app/` is kept read-only as the reference.

## 4. Approaches considered

| Approach | Trade-off | Verdict |
|---|---|---|
| **A. Feature by feature, each fully working end to end** (tables + RLS + server logic + Flutter screens + tests per feature) | Slower to "see everything", but every merged feature is real and tested; no big-bang integration | **Chosen by the user** |
| B. All screens first on mocks, backend after | Fast visible progress, but repeats the prototype's problem (looks done, isn't) and defers the hardest integration risks | Rejected |
| C. Backend schema first, then all UI | Clean data model up front, but nothing usable for a long time and a schema designed without feedback from real screens | Rejected |

**Build order (A):**
1. Foundation: auth/SMS, Men/Women space, i18n + RTL, theme.
2. Barber profile, photos, services.
3. Live status and queue.
4. Map and near-me.
5. Bookings, reminders, auto-cancel.
6. Follow, broadcast, discounts, reviews.
7. Salons and join requests.
8. Home visits.
9. Finance.
10. Wallet, store purchases, ads.
11. QR and share links.
12. Push polish.

**First store release after step 5** (decided by the user). It ships live status, queue, map and bookings, with the wallet switched off: nobody is limited or charged. Each barber's free month starts the day the wallet launches (step 10), not at sign-up. Steps 6–12 ship as updates.

## 5. Scope: what gets built (decided by the user)

- **Roles:** customer, barber/stylist, home artist, salon owner (who can also be a barber). 5-step sign-up wizard, profile photo.
  - **One account per phone number can hold several roles** (for example a barber who also books as a customer, or an owner who also cuts), with a role switch as in the prototype. Every access rule checks the active role.
- **Spaces:** strict Men / Women, never mixed.
  - **Each barber, home artist and salon belongs to exactly one space.**
  - **A customer can switch spaces** (for example a man booking for his wife or daughter), but no screen, search, map, list, broadcast or notification ever mixes the two. Every query is scoped to the current space, server-side.
  - Customer types include **kids** (men+kids, women+kids, kids only), as in the prototype.
- **Services:** preset + custom services with prices.
- **Live:**
  - status (online / on break / offline)
  - live queue with +1 / −1 / call next, in real time
  - remote queue join
  - "on my way"
- **Map:** real map pick for workplace, near-me discovery.
- **Bookings:** reminders at −1 h and −30 min, auto-cancel at −15 min without check-in, check-in.
  - **Slots come from the barber's opening hours and service durations.** Two bookings never overlap.
  - **When its time comes, a booking takes the next turn, ahead of walk-ins in the queue.**
- **Location data:** Algerian wilayas and communes (from the prototype's `AlgeriaLocations.kt`).
- **Privacy settings:** phone visibility (public / followers / hidden), hide queue count, followers-only queue join, approve followers, hide prices.
- **Deferred (not in this project):** weekly schedule across several shops, social media handles.
- **Home visits:** booking with artist confirmation and travel fee.
- **Social:** follow, broadcasts, discounts, reviews (anonymous for followers).
- **Salons:** join requests between barbers and salon owners.
- **Finance:** income, tips kept separate, expenses, shop arrangement (percentage or flat rent).
- **Wallet:**
  - 1 free month to start
  - store credit packs for 1, 2 and 6 months, priced per country, with the country taken from the store account
  - 3 rewarded ads per day, 30 s and non-skippable; 25 days of ads = 1 month
  - balance kept server-side; purchases verified with Apple/Google; ad rewards verified via the AdMob server-side callback
  - **Who pays:** each barber, home artist and salon owner who works the chair pays for their own profile. A salon owner who doesn't cut pays nothing. One barber at zero balance does not limit the others in the salon.
  - **Deduction:** one day every calendar day, like a subscription.
- **Zero balance = visible but limited, no grace period:**
  - profile, QR and status stay visible to followers
  - new bookings, remote queue join, broadcasts and discounts turn off
  - a banner says "top up or watch ads"
  - existing bookings are honoured
  - **the barber still appears in search and near-me for everyone, marked "limited"** (no booking, no remote queue join)
  - **walk-in queue controls (+1 / −1 / call next) and the live count keep working**
- **QR and links:** real scannable QR codes and share links / deep links.
- **Push:** notifications between phones (FCM; APNs via FCM).

## 6. Architecture (calls made by Claude, not objected to — confirm on approval)

**Client.** Flutter, Riverpod (state), go_router (navigation + deep links via app_links), google_maps_flutter, google_mobile_ads, qr_flutter, firebase_messaging, in_app_purchase.

**Backend.** Supabase:
- **Postgres + row-level security** is where business rules live: space separation, role permissions, zero-balance limits, queue invariants. Rules are enforced in SQL functions and policies, so a modified client cannot bypass them.
- **Realtime** on status and queue tables for live updates.
- **Edge Functions** for push fan-out, store purchase verification and AdMob reward callbacks.
- **pg_cron** for auto-cancel (−15 min) and the daily wallet deduction.
- **Storage** for profile and work photos.

**Testing.** Each feature ships with:
- database tests for its RLS and functions
- Dart unit tests for its logic
- widget tests for its screens
- one integration path per critical flow (sign-up, queue, booking, purchase)

## 7. Visual direction

**Decided by the user (2026-11-13): the category standard, executed at full craft.** This was chosen in the impeccable direction round over four themed worlds: Raï Cassette, Painted Shopfront, Gate Board and Warm Consumer App. The user chose it deliberately. Build conventional Material 3 at the highest polish, with no themed ornament, irony or quirk smuggled in.

- **Quality bar: Yassir.** LEMQES must feel at least as polished and as familiar as the Algerian super-app its users already know.
- **Finish: premium "Lagoon"** (chosen 2026-11-13 after the user asked for gradients, then for "premium and fancy").
- **Reference composition:** `.impeccable/mocks/decision/premium-lagoon.html` (layout from `canon.html`). It shows the customer Explore screen (Men, French) and the stylist Today screen (Women, Arabic RTL). The build matches its arrangement, density and hierarchy. It is a first-screen thumbnail, so the build still owes scrolling content, every other screen, and every state.
- **Customer Explore:**
  - top app bar: wordmark, space label, location
  - search field
  - "your queue" info card with "Je suis en route"
  - filter chips
  - barber list rows: photo tile, Arabic + Latin name, rating, area · distance, status word + dot, queue count and wait, starting price
- **Stylist Today:**
  - salon name with a wallet chip
  - status segmented button (open / break / closed)
  - queue card: large count, −1 / +1, and a full-width primary "call next"
  - "now serving" row
  - queue list: position, name, service, state (on the way / checked in / booking time)
- **Palette (from the reference; final tokens set in the foundation task):**
  - **Brand gradient "Lagoon":** deep sea #062A35 → teal #0F6E7A → blue #1F6FD1, at 160°, with a soft white radial bloom (~20%) in the top trailing corner. It is used **only** on:
    - the header band behind the app bar. The search field (customer) and the queue card (stylist) overlap its lower edge.
    - primary buttons: a teal → blue pill with a 1 px top highlight and a soft shadow below
    - the "live" ring around an open barber's photo
  - **Solid brand teal #0F6E7A** for the selected chip. Active nav pill tint #D3E7EF with teal-dark #0B5560 icon; selected-row tint #E8F3F7.
  - **Champagne gold #D8B46A**, reserved for "you" and money: your place in a queue (the "3e" badge) and the wallet chip. Never decorative.
  - Ground #F5F5F8. Cards are white, 20–24 px radius, with layered soft shadows and no borders. Ink #111827, muted #6B7280.
  - Status: open green, break amber, closed grey, always paired with a word. A barber on break gets a dashed grey ring instead of the live ring.
  - White text on every gradient stop meets WCAG AA (≥ 4.5:1).
- **Type:**
  - Display: **Alexandria** (Arabic + Latin) for headings, names, the wordmark (wide tracking) and the big queue number.
  - Body: **Inter** (Latin) + **Noto Sans Arabic**, with a Noto Sans Tifinagh fallback.
  - Sizes come from the Material type scale in sp, so system font scaling works.
- **Dark theme:** a first-class Material dark scheme, designed and tested, not an invert.
- **Process for the builder:** before the foundation task writes UI, record the direction contract in the surface brief (impeccable `new-work` §5). After the foundation UI exists, run the impeccable documenter to write DESIGN.md and its tokens. Every screen task then runs the `ui-quality` self-review.

Structure: Material 3 (navigation bar, top app bar, segmented buttons, chips, sheets, snackbars), one shared design on iOS and Android. The OS guarantees are kept on both: safe areas, edge-swipe back, Reduce Motion, and system font scaling.

Rules that hold across the app:
- Live state is the first thing read on every barber row and on the barber's Today screen.
- Every status has a word, never colour alone.
- The barber's single primary action ("call next") sits under the thumb.
- Arabic RTL is designed, not mirrored: numerals and ± controls keep LTR order, icons that imply direction flip.
- 48 dp touch targets, WCAG AA contrast, tabular figures for counts, times and prices.

## 7b. Smaller calls made by Claude (from the builder check — correct any on review)

- **Wallet unit:** the balance is counted in **days of service**, not money. A 1 / 2 / 6-month pack adds 30 / 60 / 180 days. Each verified ad adds 0.4 day, matching the prototype's per-ad reward (`Country.perAdRewardUsd` = monthly ÷ 25 ÷ 3). So 3 ads a day earn 1.2 days, and 25 full ad days = 30 days. Days stay comparable across countries; the store sets the price per country.
- **Free month:** granted once per verified phone number, not per account or device, so re-registering doesn't grant it again.
- **Reviews:** only a customer with a completed booking or a served queue visit with that barber can review, once per visit. An "anonymous" review hides the author from the barber and the public; the author is still stored server-side for moderation.
- **Finance:** private to each barber. The barber records their own shop arrangement (percentage or flat rent). A salon owner does not see the other barbers' income.
- **Queue wait estimate:** the sum of the service durations of the people ahead; when a service has no duration, the barber's average service time. Shown as "~N min" and never shown as exact.
- **Remote queue no-show:** the barber can mark a remote joiner "absent", which removes them. There is no timed auto-removal (only bookings have the −15 min rule).
- **Verification:** a barber appears in discovery once their phone number is verified. A separate "verified" badge is granted by hand in the Supabase dashboard.

## 8. What's left to the builder

- Exact table design, RLS policies and function signatures.
- Exact Flutter folder structure (feature-first, per the `project-structure` skill).
- Exact design tokens: they come from the chosen direction and are recorded in DESIGN.md after the foundation build.
- SMS provider choice for one-time codes (Supabase Auth phone provider).

## 9. Open questions

- None blocking. The app icon must be redrawn in the Lagoon world (the current one is the discarded navy + gold look). This happens during the foundation task.
