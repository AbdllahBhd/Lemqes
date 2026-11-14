# LEMQES → Flutter + Supabase: brainstorm handoff (2026-11-13)

> **Superseded 2026-11-13:** visual direction picked (category standard, premium "Lagoon") and the full design doc written: `docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md`. Next: user approval, then `superpowers:writing-plans`.

Status: brainstorming in progress. **No design doc approved yet. Nothing built.**
Resume with the `superpowers:brainstorming` skill, then `superpowers:writing-plans`.

## What exists today
- `app/` is a Jetpack Compose prototype exported from Google AI Studio (~18.6k lines Kotlin).
- **No backend.** All data comes from `app/src/main/java/com/example/data/MockRepository.kt` (in-memory).
  The Postgres/ASP.NET architecture Gemini wrote was chat text only, never code.
- Simulated / fake in the prototype: login (passwords in memory), map picker (Canvas, not a real map),
  rewarded ads (30 s timer, no AdMob), wallet top-ups (just adds to the number), QR code (decorative
  9×9 pattern), notifications to the barber (in-memory list), deep links, admin panel (absent).
- Real-ish: all screens and flows, 4 languages (AR with RTL, FR, EN, Tamazight), photo picker (no upload),
  local reminder notifications on the customer's own phone, device GPS read.
- The last AI Studio task (home-visit booking with artist confirm) was **canceled mid-run**; not verified to compile.
- The Kotlin code is the **reference spec** for screens, flows and business rules.

## Decisions made (by the user)
1. **Scope: everything in the prototype**, built for real (option C):
   5 roles (customer, barber/stylist, home artist, salon owner who can also be a barber),
   strict Men / Women spaces (no mixed), 5-step signup wizard, profile photo, preset + custom services,
   live status + live queue (+1 / −1 / call next) in real time, "on my way", real map pick + near-me,
   bookings with −1 h / −30 min reminders, −15 min auto-cancel, check-in, home-visit bookings with
   artist confirmation and travel fee, follow / broadcasts / discounts / reviews (anonymous for followers),
   salon join requests, finance tracker (income, tips separate, expenses, shop % or flat rent),
   wallet (1 free month, country pricing in local currency, 3 ads/day, top-ups), real scannable QR +
   share links, push notifications between phones, 4 languages with Arabic RTL.
2. **Login:** phone + password; one-time SMS code only at sign-up and password reset; Google sign-in optional extra.
3. **Payments: store payments only** (Apple In-App Purchase + Google Play Billing). No Chargily/Edahabia.
4. **Wallet at zero balance: visible but limited, no grace period.** Profile, QR and status stay visible to
   followers; new bookings, remote queue join, broadcasts and discounts turn off; banner "top up or watch ads";
   existing bookings honored.
5. **Build order: approach A — feature by feature, each fully working end-to-end** (tables + security rules +
   server logic + Flutter screens + tests), in this order:
   foundation (auth/SMS, Men/Women, i18n + RTL, theme) → barber profile/photos/services → live status & queue →
   map & near-me → bookings/reminders/auto-cancel → follow/broadcast/discounts/reviews → salons & join requests →
   home visits → finance → wallet/store purchases/ads → QR & share links → push polish.
6. **Full visual redesign**: modern, professional, premium. User asked to use the design skills
   (now available: `impeccable`, `ui-quality`, `motion`).

## Calls proposed by Claude (user has not objected; confirm in the design doc)
- No admin web panel at first; verification & moderation via the Supabase dashboard.
- Only the 4 current languages translated; i18n structure ready for the other 11.
- Repo layout: new `flutter_app/` and `supabase/` folders; Kotlin `app/` kept as reference.
- Use a current stable Flutter (installed fvm version 3.24.4 is from 2024).
- Wallet: store **consumable credit packs** (1, 2, 6 months) priced per country in the store consoles;
  user's country comes from the store account. Balance kept server-side in Supabase; purchases verified with
  Apple/Google; ad rewards verified via AdMob server-side callback. No auto-renewing subscriptions
  (they can't combine with ad-earned credit). Ads: 3/day, 30 s, non-skippable, 25 days of ads = 1 month.
- Stack: Riverpod, go_router, google_maps_flutter, google_mobile_ads, qr_flutter, app_links, FCM (APNs via FCM).
  Supabase hosted in the EU; business rules in Postgres functions + row-level security; Edge Functions for
  push, purchase verification and ad callbacks; pg_cron for auto-cancel and daily wallet deduction.
- Recheck Apple/Google payment rules before launch.

## Where we stopped
Picking a **visual direction**. Mockups (git-ignored):
`.superpowers/brainstorm/3765615-1794595672/content/visual-direction.html`
- A. Obsidian & Brass — dark luxury, serif, brass (Men) / rose gold (Women)
- B. Clean Studio — light warm off-white, heavy black type, deep green (Men) / rosewood (Women)
- C. Bold Contrast — black/white + lime (Men) / coral (Women), geometric type
Plan was to redo these with the `impeccable` + `ui-quality` skills before the user picks.
Restart the mockup server with the brainstorming skill's `scripts/start-server.sh --project-dir <repo root>`.

## Remaining steps
1. Pick the visual direction (redo mockups with impeccable / ui-quality first).
2. Write the full design doc in `docs/superpowers/specs/`, run the builder check, get approval.
3. Invoke `superpowers:writing-plans`.
