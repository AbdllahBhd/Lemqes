---
name: LEMQES
description: Live status and live queue for Maghreb barbering, Material 3 in the Lagoon finish.
colors:
  deep-sea: "#062A35"
  lagoon-teal: "#0F6E7A"
  lagoon-blue: "#1F6FD1"
  teal-deep: "#0B5560"
  pill-mist: "#D3E7EF"
  row-tint: "#E8F3F7"
  champagne-gold: "#D8B46A"
  ground: "#F5F5F8"
  card-white: "#FFFFFF"
  ink: "#111827"
  muted-ink: "#5E6573"
  outline: "#8A90A0"
  hairline: "#E4E4EC"
  error: "#B3261E"
  status-open: "#15803D"
  status-break: "#B45309"
  dark-ground: "#071A21"
  dark-card: "#0E242C"
  dark-ink: "#E3ECEF"
  dark-muted: "#A3B6BD"
  dark-teal: "#7DD3DD"
  status-open-on-dark: "#4ADE80"
  status-break-on-dark: "#FBBF24"
typography:
  display:
    fontFamily: "Alexandria, Noto Sans Arabic, Noto Sans Tifinagh"
    fontSize: "36px"
    fontWeight: 600
    lineHeight: 1.22
  headline:
    fontFamily: "Alexandria, Noto Sans Arabic, Noto Sans Tifinagh"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.33
  title:
    fontFamily: "Alexandria, Noto Sans Arabic, Noto Sans Tifinagh"
    fontSize: "16px"
    fontWeight: 500
    lineHeight: 1.5
    letterSpacing: "0.15px"
  body:
    fontFamily: "Inter, Noto Sans Arabic, Noto Sans Tifinagh"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0.15px"
  label:
    fontFamily: "Inter, Noto Sans Arabic, Noto Sans Tifinagh"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
    letterSpacing: "0.1px"
  wordmark:
    fontFamily: "Alexandria"
    fontSize: "18px"
    fontWeight: 600
    letterSpacing: "2.88px"
  numeric:
    fontFamily: "Alexandria"
    fontFeature: "tnum"
rounded:
  tag: "8px"
  code-box: "12px"
  field: "14px"
  card: "20px"
  sheet: "24px"
  pill: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.lagoon-teal}"
    textColor: "{colors.card-white}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0 24px"
    height: "48px"
  button-primary-disabled:
    backgroundColor: "{colors.hairline}"
    textColor: "{colors.muted-ink}"
    rounded: "{rounded.pill}"
    height: "48px"
  card:
    backgroundColor: "{colors.card-white}"
    rounded: "{rounded.card}"
    padding: "16px"
  choice-card-selected:
    backgroundColor: "{colors.card-white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "16px"
  text-field:
    backgroundColor: "{colors.card-white}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.field}"
    height: "56px"
  code-box:
    backgroundColor: "{colors.card-white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.code-box}"
    width: "44px"
    height: "56px"
  tag:
    backgroundColor: "{colors.pill-mist}"
    textColor: "{colors.teal-deep}"
    rounded: "{rounded.tag}"
    padding: "2px 8px"
  band-tag:
    textColor: "{colors.card-white}"
    rounded: "{rounded.tag}"
    padding: "4px 8px"
  space-switch-selected:
    backgroundColor: "{colors.card-white}"
    textColor: "{colors.deep-sea}"
    rounded: "{rounded.sheet}"
    height: "48px"
  header-band:
    backgroundColor: "{colors.deep-sea}"
    textColor: "{colors.card-white}"
    height: "150px"
---

# Design System: LEMQES

## Overview

**Creative North Star: "Deep Water, Clear Signal"**

LEMQES is category-standard Material 3, executed at full craft. The brand lives in one deep body of colour, the Lagoon gradient, laid across the top of the screen like water seen from above, and everything below it is clear, quiet ground where the live state of a barbershop can be read at a glance. Nothing is themed: no scissors ornament, no barber-pole stripes, no salon pastel. The premium feel comes from the depth of the band, the soft lift of white cards, and a confident display face, not from decoration.

Density is calm and thumb-sized. Every touch target is at least 48 dp, every screen has one primary action, and that action is a gradient pill placed where a standing barber's thumb lands. Arabic is designed, not mirrored: every layout uses start/end, and phone numbers and codes stay left-to-right inside right-to-left screens.

Dark mode is its own scheme built from the deep-sea hue, not an inversion: surfaces are near-black sea tones, the teal lifts to a pale lagoon, and the band stays the same so the brand reads identically at night.

**Key Characteristics:**
- One gradient world (deep sea, teal, blue) on three surfaces only: the header band, the primary pill and the live ring.
- Cool grey ground with white 20 px cards lifted by a two-layer soft shadow; no card borders.
- Alexandria for headings, names and numbers; Inter for reading and controls; Noto Arabic and Tifinagh as fallbacks.
- Champagne gold is held back for "you" and money; it never decorates.
- Material Icons (outlined) only, in tinted discs on cards.

## Colors

A cool, maritime palette: one saturated teal-to-blue accent over neutral grey ground, with status colours that only ever mean status.

### Primary
- **Lagoon Teal** (lagoon-teal): the brand's working colour. Selected states, focus borders, links, the progress bar, the filled checkmark on a chosen card. The start of the button gradient.
- **Lagoon Blue** (lagoon-blue): the end of the button gradient and the bottom-trailing corner of the band. Never used alone as a fill.
- **Deep Sea** (deep-sea): the top of the header band and the ink on white controls sitting on the band (the selected space pill).
- **Deep Teal** (teal-deep): text on mist containers (tags, icon discs).

### Secondary
- **Pill Mist** (pill-mist): the container colour for icon discs, "Free" and "Active" tags, the selected sign-in tab.
- **Row Tint** (row-tint): a faint teal wash for a highlighted list row.

### Tertiary
- **Champagne Gold** (champagne-gold): reserved for "you" (your place in a queue) and money (wallet, prices). Unused in the foundation screens, on purpose.

### Neutral
- **Ground** (ground): the page background in light mode. Cards and sheets sit on it.
- **Card White** (card-white): cards, input fills, the auth card.
- **Ink** (ink): all primary text.
- **Muted Ink** (muted-ink): secondary text, helper text, unselected icons. Darker than the spec's #6B7280, which fails AA on ground.
- **Outline** (outline) and **Hairline** (hairline): field strokes and dividers respectively.
- **Dark Ground / Dark Card / Dark Ink / Dark Muted** (dark-ground, dark-card, dark-ink, dark-muted): the same roles in the dark scheme. Dark Teal (dark-teal) replaces Lagoon Teal as the primary there.

### Status
- **Open** (status-open / status-open-on-dark), **On break** (status-break / status-break-on-dark), **Closed** (muted-ink / dark-muted). The light inks fall below AA on dark surfaces, so each status has a dark-surface twin.

### Named Rules
**The Three Surfaces Rule.** The Lagoon gradient appears on the header band, the primary pill and the live ring around an open barber's photo. Nowhere else: not on cards, not on text, not on icons.

**The Gold Is Personal Rule.** Champagne gold marks only what belongs to the viewer (their queue place) or money. If it is decorative, remove it.

**The Status Means Status Rule.** Green, amber and grey are spent only on open, on break and closed. A success message does not borrow the open green.

## Typography

**Display Font:** Alexandria (variable, bundled), falling back to Noto Sans Arabic and Noto Sans Tifinagh
**Body Font:** Inter (variable, bundled), with the same fallbacks

**Character:** Alexandria is wide, geometric and warm; it carries names, headings and counts with a confident, slightly premium voice. Inter does the reading and the controls, neutral and very legible in bright shop light.

### Hierarchy
- **Display** (600, 36 to 57 sp): big live numbers (queue length, wait time) when they arrive. Always tabular figures.
- **Headline** (600, 24 sp, 32 sp line): screen titles in the wizard and reset flows; the pro's name on the band.
- **Title** (500, 16 to 22 sp): card titles, section headings in settings, the empty-state title (22 sp).
- **Body** (400, 16 sp / 14 sp): explanations under titles and on cards, in muted ink.
- **Label** (600, 14 sp): buttons, tabs and pills. Medium and small labels (500, 12 and 11 sp) for tags and step counters.
- **Wordmark** (Alexandria 600, 18 sp, 16 % tracking, white): "LEMQES" on the band, from the shared `LemqesWordmark` widget only.

### Named Rules
**The Variable Weight Rule.** The bundled faces are variable fonts; a weight only renders through `lemqesWeight()`, which moves the `wght` axis. A bare `fontWeight` silently stays at 400.

**The Tabular Count Rule.** Every count, time and price uses `lemqesNumeric` (tabular figures) so live numbers never jitter as they change.

**The sp Rule.** Sizes are sp and follow the system font scale. Layouts that hold text (the band, the code boxes) grow with the scale rather than clipping.

## Layout

Single-column phone layout, designed at 390 x 844 and verified at 130 % text. Page gutters are 24 dp in the wizard and reset flows and 16 dp on the auth screen, homes and settings. Content scrolls; the one primary action is pinned below the scroll area with 24 dp sides and 16 dp below, under the thumb.

The first viewport of a home is the header band (about 150 dp, taller when text scale or the status bar demands it). The band holds the wordmark or the pro's name, the role-switch and settings actions, and one row of controls (the space switch, or the space tag). From M3 on, the search field or queue card straddles the band's lower edge, rising 32 dp into it.

Spacing follows a 4 dp base: 4 between progress segments and inside tags, 8 between related rows, 16 inside cards and between cards, 24 between groups and around the page, 32 before a destructive action.

### Named Rules
**The One Pill Rule.** A screen has at most one gradient primary pill. Secondary actions are text buttons or outlined buttons.

**The Start/End Rule.** Every padding, alignment and icon position uses directional (start/end) values; phone numbers, codes and other digits are wrapped LTR inside RTL.

## Elevation & Depth

Depth is a hybrid: tonal layers set the planes (ground, then white cards, then sheets), and a soft two-layer shadow lifts cards off the ground. There is no Material surface tint. In dark mode the card colour is one tone lighter than the ground; the shadow remains but does most of its work in light mode.

### Shadow Vocabulary
- **Card lift** (two layers: 0 1 2 at 5 % and 0 10 28 at 9 % of #141228): every card, the auth card, the settings groups, choice cards.
- **Pill glow** (0 10 20, spread -8, Lagoon Blue at 60 %): under the primary pill in light mode. In dark mode a plain black drop (0 8 16, spread -6, 60 %) replaces it, since a coloured glow on deep sea reads as a halo.
- **Inset highlight** (1 px white at 25 % along the pill's top edge): the only "shine" in the system.

### Named Rules
**The No Border Card Rule.** Cards are separated from the ground by the shadow and the tone step, never by a stroke. The only card stroke is the 2 dp teal outline that marks a selected choice.

## Shapes

Soft, generous rounding that grows with the size of the object: 8 px tags, 12 px code boxes and language chips, 14 px text fields, 20 px cards, 24 px sheets and the auth card, full stadium pills for buttons and the space switch. Icons sit in 48 px circular mist discs on cards and a 64 px disc in empty states. Step progress is a row of 4 px rounded bars.

## Components

### Buttons
- **Shape:** stadium pill, 48 dp tall, 24 dp side padding.
- **Primary (`LemqesPrimaryButton`):** teal-to-blue gradient at 120 degrees, white label 14 sp semibold, optional 18 dp leading icon, pill glow underneath, 1 px top highlight.
- **States:** pressed darkens with a 16 % black layer, focus 10 %, hover 8 % (darkening only, since white on the blue end clears AA by a small margin, 4.94:1). Keyboard focus adds a 2 dp primary ring 3 dp outside the pill. Loading swaps the icon for a spinner, keeps the label, swallows taps and tells screen readers the button is disabled. Disabled is a flat 12 % ink fill with 38 % ink label and no shadow.
- **Secondary:** text buttons in Lagoon Teal (forgot password, back to sign-in, add a role); the sign-out action is an outlined pill in the error colour.

### Chips and tags
- **Tag:** Pill Mist fill, Deep Teal label, 8 px radius ("Free", "Active").
- **Band tag:** white 8 % fill with a 35 % white stroke on the band ("Men's space").
- **Language chips:** 12 px rounded squares on the band, white fill when selected.

### Cards / Containers
- **Corner Style:** 20 px (cards), 24 px (auth card, sheets).
- **Background:** Card White on Ground; Dark Card on Dark Ground.
- **Shadow Strategy:** card lift.
- **Border:** none, except the selected choice card's 2 dp teal outline.
- **Internal Padding:** 16 dp.

### Inputs / Fields
- **Style:** filled white, 1 dp outline stroke, 14 px radius, outlined Material icon at the start, floating label.
- **Focus:** 2 dp Lagoon Teal stroke.
- **Error / Disabled:** 1 dp (2 dp focused) error stroke with the message below; disabled uses the hairline stroke.
- **Code field:** six 44 x 56 dp boxes (scaled with text) in two groups of three, 12 px radius, always LTR, accepts Eastern Arabic digits and paste.

### Navigation
- Back is a Material icon button at the top start; wizard screens pair it with the step progress bar and a "Step 1 of 4" label. Settings and role switching open from icon buttons on the band. Role switching is a modal bottom sheet with a drag handle on the ground colour, so its choice cards lift off it as on a page.

### Header band (`LagoonHeaderBand` / `HomeHeader`)
The signature surface: the Lagoon gradient at 160 degrees with a soft white bloom (20 % white radial, top-trailing), about 150 dp tall, white content, light status-bar icons. It grows with the text scale so nothing clips.

### Choice card (`ChoiceCard`)
A white card with a 48 dp mist icon disc, title, muted description, optional tag, and a radio at the end; selected adds the 2 dp teal outline and a filled teal check. Announced as a selectable button.

### State views
- **Empty (`EmptyView`):** a 64 dp mist icon disc, a 22 sp title, a muted body, an optional action, centred and scrollable.
- **Error (`ErrorView`):** a muted cloud-off icon, the message, and a primary retry pill.
- **Loading (`LoadingView`):** a teal spinner with a spoken label.

### Pro card (`ProCardTile`)
One explore result as a single 20 px card that opens the public profile: a 56 dp avatar disc (`ProAvatar`: photo, else up to two initials on Pill Mist, one for Arabic-script names), the name in title weight, the workplace and "Commune · Wilaya" lines in Muted Ink (a commune that names its wilaya appears once), "From 450 DA" with the amount in `PriceText`, the "Kids welcome" tag when it applies, and a trailing chevron. Announced as one button.

### Price text (`PriceText`)
Dinar amounts in semibold `lemqesNumeric`: Latin tabular digits, the locale's grouping ("1 500 DA" in French, "1.500 DA" in Arabic) and always LTR inside Arabic. Hidden prices read "Prix au salon" / "Prix sur demande" in Muted Ink instead.

### Hours table (`HoursTable`)
The week from Saturday, one 48 dp row per day: the day name at the start, "09:00 – 19:00" in `lemqesNumeric` at the end with the break ("Pause 13:00 – 14:00") muted under it, "Closed" in the closed status colour. Today sits on a Pill Mist row with a "Today" line, so it never relies on colour alone. Times are LTR islands in Arabic.

### Locality picker (`LocalityPicker`)
Two stacked white field cards, wilaya then commune (the commune disabled until a wilaya is chosen), each with a floating label and a chevron; the wilaya shows its code. Each opens a tall modal sheet with a search field (folds Latin accents, matches the code) and a list of 48 dp rows, the selected one on Pill Mist; picking a wilaya opens the commune sheet straight away.

### Photo tile (`PhotoTile`)
A square photo with a 16 px radius on a container-high placeholder, a small spinner while it loads and a muted broken-image icon when it cannot. An optional remove control is a 32 dp Deep Sea scrim disc with a white close glyph inside a 48 dp target at the top end.

### Service editor (`ServiceEditor`)
A bottom sheet for one service: preset name fixed (custom: name field and category chips), price (DA) and duration (min) fields side by side that accept Eastern Arabic digits and spaces and write back Latin digits, an active switch, the primary save pill, and "Remove" as an error-colour text button for an existing service. Errors are inline under the field.

### Hours editor (`HoursEditor`)
One block per day from Saturday, hairline dividers between them: day name and an open switch ("Closed" muted when off); opening and closing times as 48 dp outlined pills in `lemqesNumeric` (LTR), a "copy to every day" icon button, an optional break row with its own pills and a remove icon, a moon note for a past-midnight close, and the day's error in the error colour as a live region.

### Photo gallery editor (`PhotoGalleryEditor`)
A three-across grid of `PhotoTile`s (up to 9) ending in a Pill Mist add tile (camera-plus icon and label, faded when the gallery is full); each upload shows in its own tile under a scrim with a spinner, a failed one offers retry and discard. Removal asks first.

### Privacy section (`PrivacySection`)
Two groups inside a dashboard card: who sees the phone (single-choice rows: public, hidden, and "followers" tagged "soon" and not selectable) and a "show prices" switch row. Each change saves only its own field. Choosing "Visible" opens an inline contact-number field under that row (never prefilled with the login number; the sign-up parser and errors; Cancel text button and an outlined Save pill), and the number and the visibility save together. Once public, the number shows in `Ltr` under the row with a "change number" text button; hiding keeps the number for next time.

### Visibility card (dashboard)
The first dashboard card says whether customers can see the profile: a 48 dp Pill Mist disc with an eye (published) or crossed eye (hidden) icon, "Publié" / "Masqué" as the title, a muted line naming the space, and, when something is missing, a list of gaps with error-colour icons and the "Compléter mon profil" or "Publier mon profil" pill.

## Do's and Don'ts

### Do:
- **Do** keep the gradient on the band, the primary pill and the live ring only (The Three Surfaces Rule).
- **Do** put one primary pill per screen, pinned under the thumb, 48 dp tall.
- **Do** set weights through `lemqesWeight()` and numbers through `lemqesNumeric`.
- **Do** use start/end everywhere and keep phone numbers and codes LTR inside Arabic.
- **Do** reuse `LemqesWordmark`, `LemqesPrimaryButton`, `ChoiceCard`, `LagoonHeaderBand` and the state views rather than restyling locally.
- **Do** check every new screen in French light and Arabic dark, and at 130 % text.

### Don't:
- **Don't** use gradient text, glass or blur, eyebrows or kickers above headings, or coloured side borders thicker than 1 px.
- **Don't** use emoji or Unicode glyphs as icons; Material Icons only.
- **Don't** put a border on a card, or tint a surface with Material's surface tint.
- **Don't** use champagne gold for decoration, or status green and amber for anything but status.
- **Don't** use #6B7280 for muted text on the ground; it fails AA. Use Muted Ink.
- **Don't** mix the men's and women's spaces on one screen.
- **Don't** keep what `flutter_launcher_icons` / `flutter_native_splash` do to iOS: re-running them corrupts `flutter_app/ios/Runner.xcodeproj/project.pbxproj` (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`) and re-indents `flutter_app/ios/Runner/Info.plist`; revert those two files after regenerating.
