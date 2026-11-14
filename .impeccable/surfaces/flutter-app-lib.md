---
version: 1
slug: "flutter-app-lib"
primary_target: "flutter_app/lib"
related_targets: []
---

# Surface brief: LEMQES Flutter app (flutter_app/lib)

## Scope and mode

The whole native app (Android + iPhone, one shared design). Visitor mode: Operate. Customers check who is open and how long the queue is; barbers run status and queue one-handed at the chair.

## Audience, job, constraints

Barbers, stylists, home artists, salon owners and their customers in Algeria first; Arabic RTL, French, English, Tamazight (Tifinagh). Bright shop light, one thumb, 48 dp targets, WCAG AA, system font scaling. No real users, photos or reviews yet: never present demo data as real.

## Unresolved decisions

- None open for M1. DESIGN.md and `.impeccable/design.json` were written from the built tokens and widgets (Task 11, 2026-11-14).

## Direction contract

THESIS: The live state is the product. Category-standard Material 3 executed at full craft, refusing themed ornament and the generic white salon-booking calendar.

OWN-WORLD: Lagoon. Deep sea #062A35 to teal #0F6E7A to blue #1F6FD1 at 160 degrees with a soft white bloom top-trailing, only on the header band, primary pills and the live ring. Ground #F5F5F8, white 20-24 radius cards with layered soft shadow and no border, champagne gold only for "you" and money. Alexandria display, Inter body, tabular figures.

STORY: A customer reads who is open and how many are ahead before leaving home, then joins or books. A barber sets status and calls next with one tap.

FIRST VIEWPORT: Gradient header band (about 150 dp) carrying the wordmark or salon name; the search field or queue card straddles its lower edge; content on the ground below; the primary pill under the thumb.

FORM: Material 3 app chrome, position 1 of the ordered list (category standard, chosen by the user over four themed worlds). seed:2c904c7b1ac433b2

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Finish record (M1 foundation, 2026-11-14)

FINISH discharged for the M1 foundation build:

- **Review:** finish review run in-thread (the build ran as a subagent with no subagent capability, so the degraded finish-reviewer path was used). Evidence: widget-test captures at 390x844 dp in fr-light, ar-dark and fr-light at 130 % text for auth, reset, wizard steps 1-4, both homes, settings and the role sheet (`.impeccable/review/`, not committed). Critique snapshot: `.impeccable/critique/` (30/40; local, not committed).
- **Verdict:** `ship` at M1 scope. Fixed in the batch: empty-state icon disc, loading pill and spinner semantics, role sheet on the ground colour, shared `LemqesWordmark`. Accepted adaptation: nothing straddles the home band yet, because the search field and queue card do not exist until M2-M4 (roadmap in task_plan.md); the FIRST VIEWPORT promise is re-audited when they land. Deferred minors: customer band's space tag duplicates the space switch; sign-in pill sits mid-screen rather than pinned under the thumb.
- **DESIGN.md:** written at the repo root with `.impeccable/design.json`.
- **Raster provenance:** the five brand masters in `flutter_app/assets/brand/` carry their origin (`impeccable embed-prompt --scan` reports 0 missing). The Android and iOS launcher/splash PNGs are generator output of those masters (`flutter_launcher_icons.yaml`, `flutter_native_splash.yaml`) and inherit that provenance.
