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

- DESIGN.md and its tokens are written by the documenter after the foundation UI exists (Task 11).

## Direction contract

THESIS: The live state is the product. Category-standard Material 3 executed at full craft, refusing themed ornament and the generic white salon-booking calendar.

OWN-WORLD: Lagoon. Deep sea #062A35 to teal #0F6E7A to blue #1F6FD1 at 160 degrees with a soft white bloom top-trailing, only on the header band, primary pills and the live ring. Ground #F5F5F8, white 20-24 radius cards with layered soft shadow and no border, champagne gold only for "you" and money. Alexandria display, Inter body, tabular figures.

STORY: A customer reads who is open and how many are ahead before leaving home, then joins or books. A barber sets status and calls next with one tap.

FIRST VIEWPORT: Gradient header band (about 150 dp) carrying the wordmark or salon name; the search field or queue card straddles its lower edge; content on the ground below; the primary pill under the thumb.

FORM: Material 3 app chrome, position 1 of the ordered list (category standard, chosen by the user over four themed worlds). seed:2c904c7b1ac433b2

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
