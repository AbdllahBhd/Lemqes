---
target: LEMQES Flutter app (M1 foundation)
total_score: 30
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
target_identity: "file:/mnt/disque-d/Develope/Lemqes/flutter_app/lib"
timestamp: 2026-11-14T07-04-56Z
slug: flutter-app-lib
---
# Critique: flutter_app/lib (M1 foundation, finish review)

Method: native platform (android), Assessment A only, in-thread (no detector on native source). Evidence: widget-test captures at 390x844 dp (DPR 2) in fr-light, ar-dark and fr-light at 130 % text, for auth, reset, wizard steps 1-4, customer home, pro home, settings and the role-switch sheet. The Linux desktop session is GNOME Wayland (grim unsupported, no xdotool/import), so the running app could not be screenshotted.

**Deterministic scan**: not applicable (native platform)

## Design specificity verdict
Grounded. The Lagoon band, gradient pill, Alexandria headings and Men/Women space switch are specific to LEMQES and its Maghreb barbering context; RTL is designed (start/end, LTR digits, mirrored progress and chevrons). No eyebrows, gradient text, glass, side stripes or glyph icons found.

## Heuristics (0-4)
| # | Heuristic | Score |
|---|---|---|
| 1 | Visibility of system status | 3 |
| 2 | Match with the real world | 4 |
| 3 | User control and freedom | 3 |
| 4 | Consistency and standards | 3 |
| 5 | Error prevention | 3 |
| 6 | Recognition over recall | 3 |
| 7 | Flexibility and efficiency | 3 |
| 8 | Aesthetic and minimalist design | 3 |
| 9 | Error recovery | 3 |
| 10 | Help and documentation | 2 |
| | Total | 30/40 |

## What's working
- The band, pill and white-card-on-ground system holds across every screen and both schemes; dark is a designed deep-sea scheme, not an inversion.
- Arabic is first-class: mirrored progress, chevrons and icon positions; phone and code stay LTR.
- 130 % text never clips: the band grows, fields ellipsize labels only, cards reflow.

## Priority issues
- [P2] Homes do not yet meet the FIRST VIEWPORT contract: nothing straddles the band and the ground below is empty. Fix: the search field (M2/M4) and queue card (M3) straddle the band edge 32 dp. Deferred to M2-M4 (content does not exist yet).
- [P2] Empty states were text-only and floated in a blank field. Fix: EmptyView gained a 64 dp mist icon disc (storefront for customers, badge for pros). FIXED.
- [P2] A loading LemqesPrimaryButton told screen readers it was an enabled button while swallowing taps; LoadingView's spinner had no spoken label. Fix: loading pill announces disabled with its label; LoadingView requires a label (l10n.loading). FIXED.
- [P3] Dark role-switch sheet: unselected choice cards were invisible (sheet colour = card colour). Fix: bottom sheets sit on the ground colour in both schemes. FIXED.
- [P3] Customer home band: the "Men's space" tag repeats the Men/Women switch directly below it, and wraps to two lines at 130 %. Fix: drop the tag when the switch is shown, at the M2 header rework (tests assert it today). Deferred.

## Persona red flags
- Casey (distracted, one hand): the sign-in pill sits mid-screen (y ~ 475 of 844) rather than under the thumb; acceptable while the keyboard is up, revisit with a pinned action.
- Sam (screen reader): loading pill state and unlabeled spinner (fixed).
- Jordan (first-timer): the pro home's only action is disabled ("arrives soon"); honest, but a dead end until M2.

## Minor observations
- Wordmark style was duplicated in the auth bar and home header (extracted to LemqesWordmark, FIXED).
- Primary pills mix icon and no-icon (login/credentials have icons; reset/space/role "Continue" do not).
- At 130 % the salon-name and confirm-password labels ellipsize until focused (Material behaviour).
- Champagne gold is unused in M1, correctly (no "you" or money yet).

## Questions to consider
- Should the auth card's sign-in pill be pinned to the bottom like the wizard's, so every primary action lives in one place?
- When the search field lands, does the space tag still earn a place on the customer band?
