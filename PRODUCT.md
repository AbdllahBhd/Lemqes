# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

One shared branded design on iPhone and Android (Flutter), Material 3 structure. On Apple hardware it still owes iOS its OS guarantees: safe-area insets, Reduce Motion, edge-swipe back.

## Stack

Flutter (current stable) + Supabase (EU-hosted Postgres, row-level security, Edge Functions, pg_cron). Riverpod, go_router, google_maps_flutter, google_mobile_ads, qr_flutter, app_links, FCM. The Jetpack Compose prototype in `app/` is the reference spec for screens, flows and business rules, not code to keep.

## Users

Two audiences, designed for equally, under one identity:

- **Barbers, stylists, home artists and salon owners** (a salon owner can also be a barber). They run their day from the phone at the chair: set live status, manage the live queue (+1 / −1 / call next), accept bookings, broadcast to followers, track income. They pay for the app through the wallet.
- **Customers.** They check who is open now, how long the queue is, join remotely or book a slot, follow their barber, and get reminders.

Men and Women are strictly separate spaces; nothing is mixed. Each barber or salon belongs to one space; a customer may switch spaces (e.g. booking for family), but no screen ever shows both. One phone number can hold several roles (e.g. a barber who also books as a customer).

## Product Purpose

Remove the wait-and-guess of the neighborhood barbershop: a customer knows before leaving home whether their barber is open and how many people are ahead; a barber fills the chair without phone calls. Success: barbers keep their status and queue live during the working day, and customers stop walking to closed or full shops.

## Positioning

Live status and a live queue run by the barber in real time, built for Maghreb barbering culture (Arabic RTL, French, Tamazight, Men/Women separation, home visits), not a generic salon booking calendar.

## Operating Context

- Launch market: Algeria first (confirmed 2026-11-13). Tunisia, Morocco, France/Europe later.
- Barbers use the app one-handed, standing, between clients, often in bright shop light; customers check it at home or on the street.
- Languages: Arabic (RTL), French, English, Tamazight; i18n ready for more.
- Prices in local currency (DA, DT, DH, €).

## Capabilities and Constraints

- 5 roles: customer, barber/stylist, home artist, salon owner (can also be a barber); 5-step signup wizard.
- Live status (online / on break / offline), live queue, "on my way", map pick + near-me.
- Bookings with −1 h / −30 min reminders, −15 min auto-cancel, check-in; home-visit bookings with artist confirmation and travel fee.
- Follow, broadcasts, discounts, reviews (anonymous for followers); salon join requests.
- Finance tracker (income, tips separate, expenses, shop % or flat rent).
- Wallet: 1 free month, store credit packs priced per country, 3 rewarded ads/day. At zero balance the barber stays visible but limited (no new bookings, no remote queue join, no broadcasts/discounts); existing bookings honored.
- Real scannable QR + share links, push notifications between phones.
- Login: phone + password; SMS code only at signup and password reset; Google sign-in optional.
- Payments: Apple In-App Purchase and Google Play Billing only.

## Brand Commitments

- Name: **LEMQES** (Darja for "scissors"). Existing launcher icon at `app/src/main/res/drawable/ic_lemqes_foreground_1794378455748.jpg`.
- The prototype's visual look (dark navy + gold for men, pink/fuchsia for women) is not binding: a full visual redesign was requested, modern, professional, premium.
- **Standing preference: the category standard, executed at full craft** (chosen 2026-11-13 over themed worlds). Clean Material 3, conventions embraced without irony or smuggled quirk. Quality bar: **Yassir** (the Algerian super-app users already know) — LEMQES must feel at least as polished and familiar.
- **Premium "Lagoon" finish** (user asked for gradients, then "premium and fancy"): a deep-sea → teal → blue gradient on large brand surfaces only, Alexandria display type, champagne gold reserved for "you" and the wallet, soft layered shadows. Full spec in `docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md` §7.

## Evidence on Hand

- No real users, barbers, testimonials, photos or reviews exist yet. Never present demo data as real.
- Prototype screens and flows in `app/src/main/java/com/example/ui/`.

## Product Principles

1. The live state is the product: status and queue are always the first thing read, always current, never stale without saying so.
2. Barber actions take one thumb and one tap at the chair.
3. Men and Women spaces are separate everywhere, by design, not by filter.
4. Arabic RTL is a first-class layout, never a mirrored afterthought.
5. A limited (zero-balance) barber is still dignified and visible to followers.

## Accessibility & Inclusion

- WCAG AA contrast; 48 dp touch targets; system font scaling respected.
- Full RTL mirroring for Arabic; Tifinagh script support for Tamazight.
