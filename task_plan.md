# LEMQES Milestone 1 — Foundation: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objective:** Milestone 1 Foundation: real phone + password + SMS sign-up and login, Men/Women spaces and roles enforced in Postgres, four languages with designed Arabic RTL, and the Lagoon theme in light and dark, all on a local Supabase stack.

**Architecture:** A Flutter app in `flutter_app/` (feature-first, `data/` + `presentation/` per feature, no domain layer: business rules live in Postgres) talks to Supabase through `supabase_flutter`. Account rules (spaces, roles, active role) are enforced by RLS and `security definer` RPCs in `supabase/migrations/`, so a modified client cannot bypass them. State is plain Riverpod 3 (no codegen); navigation is go_router with a session/profile redirect.

**Tech Stack:** Flutter 3.47.5 (Dart 3.13.4) · supabase_flutter 2.18.x · flutter_riverpod 3.5.x · go_router 18.x · shared_preferences 2.5.x · flutter_localizations + gen_l10n · intl 0.20.x · mocktail 1.0.x · integration_test · Supabase CLI 2.121 local stack (Docker) · pgTAP via `supabase test db` · flutter_launcher_icons 0.14.4 · flutter_native_splash 2.4.8.

**Spec:** [docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md](docs/superpowers/specs/2026-11-13-lemqes-flutter-supabase-design.md) (approved 2026-11-14) · product truth: [PRODUCT.md](PRODUCT.md) · visual reference: `.impeccable/mocks/decision/premium-lagoon.html`. Executors read spec §5 and §7 before any task.

**Plan reviewed:** 2026-11-14 by an LLM council (5 advisors, anonymous peer review, chairman). What changed is listed at the bottom.

## In scope / Out of scope

**In scope (milestone 1 of 12):** toolchain + repo layout · Lagoon theme (light + dark), bundled fonts, core branded widgets · i18n for `ar` (RTL), `fr`, `en`, `kab` · accounts schema: profiles, roles, spaces, active role, with RLS and RPCs · phone + password sign-up with SMS code, login, password reset · sign-up wizard steps 1–3 (space, role, credentials) + SMS code · role switch, add a role, customer space switch · role-aware home placeholders and a settings screen · redrawn Lagoon app icon and splash · one integration path (sign-up → login → reset) against the local stack · DESIGN.md.

**Out of scope here (later milestones, see Roadmap):** wizard steps 4–5 (pro profile: photo, experience, workplace, services, map point → M2/M4; customer interests + radar → M2/M4) · barber/salon entity tables with their own space (M2, M7) · wilaya/commune data (prototype has only 12 wilayas; M2) · accepted customer types incl. kids (barber setting, M2) · profile photos and Storage (M2) · free-month / wallet copy (M10) · Google sign-in · hosted Supabase project and real SMS provider (before M5) · Firebase/FCM · server-side user language (M6/M12) · deep-link return path (M11).

## Approach (decisions and why)

- **One plan per milestone.** The spec is 12 subsystems; this file details M1 only and keeps M2–M12 as a roadmap. Each later milestone gets its own detailed plan here when it starts (spec §4, approach A).
- **Rules in Postgres, not Dart.** Later RLS policies use three interfaces from Task 4: `current_space()` (the space the user is acting in, resolved through the active role), `acts_as(role)` (role held **and** active — spec §5 "every access rule checks the active role") and `has_role(role)` (held). Security itself comes from roles held, ownership and the data's space; `acts_as` enforces the mode separation the spec asks for. Policies wrap them as `(select current_space())` / `(select acts_as(...))` so Postgres evaluates them once per query.
- **Account created after the code is verified.** Wizard answers (space, role, name, business name, phone) are held in a local draft; `signUp(phone, password)` sends the SMS; after `verifyOTP` the client calls `complete_signup(...)`. A session without a profile always routes back into the wizard (which then skips `signUp`), so an interrupted sign-up resumes instead of breaking.
- **Password reset is a composed flow** (no official phone recipe; verified in gotrue 2.27.3 source): `signInWithOtp(phone, shouldCreateUser: false)` → `verifyOTP(type: sms)` → `updateUser(password)`. A session fresh from `verifyOTP` needs no reauthentication nonce.
- **Local auth behaviour is measured, not assumed.** Task 4 starts with a curl spike against the local stack and records the real responses (SMS provider needed or not, duplicate-number signal, wrong-code error code); Task 5 maps errors from those records.
- **Kabyle (`kab`, Latin script, LTR, Tifinagh font fallback)** is not supported by Material/Cupertino localizations in Flutter 3.47.5 (verified in `flutter_localizations` source): we ship fallback delegates that serve French Material/Cupertino strings and LTR widgets for `kab`; intl formatting maps `kab` → `fr`.
- **Digits:** intl 0.20.x `ar` and `ar_DZ` both use Latin digits (CLDR 48), which matches Algerian usage; Arabic formats with `ar_DZ`. User-typed Eastern Arabic digits are accepted in phone and code input.
- **SDK pinning without the fvm binary:** `flutter_app/.fvmrc` holds the version (fvm-compatible); `scripts/sdk` resolves `${FVM_HOME:-$HOME/fvm}/versions/<version>/bin` and runs `flutter`/`dart` from `flutter_app/`. The installed fvm stub runs under the old PATH Dart and is unreliable.
- **No Riverpod codegen** (riverpod.dev: codegen optional). Generated l10n code is git-ignored and regenerated by `gen-l10n` in the lint script.
- **Integration tests run on the Linux desktop target** against the local stack (`flutter test` blocks real HTTP; GTK, clang, cmake, ninja are installed).
- **Password minimum 8 characters** (prototype allowed 4; phone numbers get recycled — Supabase docs warning).
- **Local Supabase on ports 553xx** because another project's stack already holds 543xx on this machine.

## Global Constraints

- Flutter **3.47.5**, always via `scripts/sdk flutter …` / `scripts/sdk dart …` (runs inside `flutter_app/`); never the PATH default 3.24.4.
- Dart package `lemqes`; placeholder app id **`com.lemqes.lemqes`** (from `flutter create --org com.lemqes`; final id is decision D1, before M5).
- Supabase local stack only, API on `http://127.0.0.1:55321`. Secrets via `--dart-define-from-file=env/local.json` (git-ignored); `env/example.json` committed. Never commit `.env`, `env/local.json`, keys.
- Phone numbers stored and sent as E.164 `+213XXXXXXXXX`; Algeria mobile only (`5|6|7` + 8 digits after the trunk 0).
- Spaces `men`, `women` — never mixed on one screen. Roles `customer`, `barber`, `home_artist`, `salon_owner`.
- Colours (spec §7): gradient `#062A35 → #0F6E7A → #1F6FD1` at 160° with ~20 % white radial bloom top-trailing, only on header band, primary buttons, live ring · solid teal `#0F6E7A` (selected chip) · nav pill `#D3E7EF` with icon `#0B5560` · selected row `#E8F3F7` · gold `#D8B46A` only for "you" and money · ground `#F5F5F8` · cards white, radius 20–24, layered soft shadow, no border · ink `#111827` · **muted `#5E6573`** (spec's `#6B7280` is 4.44:1 on ground and fails AA; AA wins) · status words: open `#15803D`, break `#B45309`, closed = muted.
- Type: Alexandria (display: headings, names, wordmark with wide tracking, big numbers) · Inter body with fallbacks Noto Sans Arabic, Noto Sans Tifinagh · Material type scale in sp · tabular figures for counts, times, prices. Fonts bundled as assets (OFL, github.com/google/fonts `ofl/…`), never fetched at runtime.
- 48 dp minimum touch targets · WCAG AA (≥ 4.5:1 text, ≥ 3:1 large text/UI) · every status has a word · RTL designed: numerals, phone numbers, codes and ± controls stay LTR; direction-implying icons flip.
- Every screen has designed loading, empty and error states; no raw exception strings in UI.
- Icons: Flutter's Material `Icons` only. Craft-floor bans (impeccable): no eyebrows/kickers, no gradient text, no glass, no coloured side borders > 1 px, no Unicode/emoji icons.
- New user-facing copy goes into all four ARB files plus `lib/core/l10n/REVIEW.md` in the task that introduces it (the parity test enforces it).
- Every task's fence implicitly allows `flutter_app/pubspec.lock`.
- Conventional Commits, ≤ 72 chars, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Work on `feat/foundation`, never on `master`.

## Review Focus

1. **Phone typed any Algerian way** — `0550 12 34 56`, `+213 550123456`, `00213550123456`, `550123456`, dashes, dots, Eastern Arabic digits `٠٥٥٠ ١٢ ٣٤ ٥٦` → all `+213550123456`; landline, foreign or short numbers get an inline message, not a server error. Pinned in Task 5 (`phone_number_test.dart`).
2. **Sign-up interrupted** — killed after the SMS was sent (no session yet), or after the code was verified but before the profile exists, or launched offline → reopening lands on the right step with the answers kept, or on a retry view; never a blank home, a second `signUp`, or `profile_exists`. Pinned in Task 6 (`redirect_test.dart`) and Task 7 (`credentials_step_test.dart`).
3. **Number already registered** — `signUp` for a confirmed number (signal recorded in the Task 4 spike) → the UI says the number has an account and offers login and reset; it never says "account created". Pinned in Tasks 5 and 7.
4. **Kabyle selected** — Material widgets (text-field menus, back tooltips, date picker) must not throw "No MaterialLocalizations found"; numbers still format. Pinned in Task 3 (`kab_fallback_test.dart`).
5. **Arabic at 200 % font scale** — wizard and auth screens do not overflow; phone and code fields stay LTR with Latin digits. Pinned in Task 7 (`auth_rtl_scale_test.dart`).

---

## File structure (locked here)

```
package.json                      # gate scripts for the done-gate hook (lint / typecheck / test)
.gitignore                        # + flutter build outputs, .fvm/, env/local.json, l10n gen/, supabase/.temp
scripts/sdk                       # runs flutter/dart of the .fvmrc version inside flutter_app/
scripts/integration.sh
supabase/
  config.toml                     # ports 553xx, phone signup, confirmations, test OTPs, min password 8
  migrations/20261114000100_accounts.sql
  tests/database/000-setup.sql    # pgtap extension + tests.* helpers, no rollback
  tests/database/001-smoke.sql
  tests/database/010-accounts.sql
flutter_app/
  .fvmrc  l10n.yaml  pubspec.yaml  analysis_options.yaml  flutter_launcher_icons.yaml  flutter_native_splash.yaml
  env/example.json
  assets/fonts/                   # Alexandria[wght].ttf, Inter[opsz,wght].ttf, NotoSansArabic[wdth,wght].ttf, NotoSansTifinagh-Regular.ttf, OFL.txt
  assets/brand/                   # icon_master.svg, icon_foreground.png, icon_background.png, icon_monochrome.png, splash_mark.png
  lib/
    main.dart  app.dart
    core/config/env.dart
    core/supabase/supabase_providers.dart
    core/router/app_router.dart  redirect.dart  placeholder_screen.dart
    core/theme/lemqes_tokens.dart  lemqes_gradients.dart  lemqes_typography.dart  lemqes_theme.dart  theme_mode_controller.dart
    core/l10n/arb/app_{fr,en,ar,kab}.arb  REVIEW.md  gen/ (generated, git-ignored)
    core/l10n/locale_controller.dart  kab_fallback_delegates.dart  intl_locale.dart
    features/auth/data/phone_number.dart  auth_repository.dart
    features/auth/presentation/auth_screen.dart  login_form.dart  reset_password_screen.dart
    features/signup/data/signup_draft.dart  signup_draft_store.dart
    features/signup/presentation/signup_wizard.dart  steps/{space_step,role_step,credentials_step,code_step}.dart
    features/account/data/account.dart  account_api.dart  account_repository.dart  account_providers.dart
    features/account/presentation/role_switch_sheet.dart  space_switch.dart
    features/home/presentation/customer_home_screen.dart  pro_home_screen.dart  home_screen.dart
    features/settings/presentation/settings_screen.dart
    shared/widgets/lagoon_header_band.dart  lemqes_primary_button.dart  choice_card.dart  step_progress.dart  code_field.dart  ltr.dart  state_views.dart
  test/  (mirrors lib/)  test/flutter_test_config.dart  test/goldens/
  integration_test/auth_flow_test.dart
```

Why feature-first without `domain/`: `project-structure` skill — this milestone's domain logic lives in SQL; a Dart domain layer would duplicate it.

---

### Task 0: Branches

- [ ] **Step 1:** `git checkout -b develop master && git merge --no-ff docs/lemqes-design` (the design doc's review gate was the builder check plus the user's approval).
- [ ] **Step 2:** `git checkout -b feat/foundation develop`.

**Done when:** (1) `git branch --show-current` prints `feat/foundation`; `git log develop --oneline` contains `docs: add LEMQES Flutter + Supabase design doc`; (2) no gates exist yet — nothing to run; (3) `git status --short` shows no tracked-file changes beyond the merge.

---

### Task 1: Toolchain, scaffold and gates

**Files:** Create `scripts/sdk`, `flutter_app/` (via `flutter create`), `flutter_app/.fvmrc`, `flutter_app/analysis_options.yaml`, `flutter_app/env/example.json`, `flutter_app/lib/core/config/env.dart`, `flutter_app/lib/core/supabase/supabase_providers.dart`, `flutter_app/test/app_smoke_test.dart`, `supabase/` (via `supabase init`), `supabase/tests/database/{000-setup,001-smoke}.sql`, `package.json`. Modify `.gitignore`.

**Interfaces — Produces:**
- `scripts/sdk <flutter|dart> [args…]`: reads `flutter_app/.fvmrc` (`{"flutter": "3.47.5"}`), execs `${FVM_HOME:-$HOME/fvm}/versions/<v>/bin/<tool> "$@"` with cwd `flutter_app/`; exits 1 with a clear message if that SDK is missing.
- `abstract final class Env { static const supabaseUrl = String.fromEnvironment('SUPABASE_URL'); static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY'); }`
- `final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);`
- `000-setup.sql` (no `begin`/`rollback`, so it persists in the local DB; `supabase db reset` wipes it and it reruns first): `create extension if not exists pgtap with schema extensions; create schema if not exists tests;` functions `tests.create_user(phone text, confirmed boolean default true) returns uuid` (inserts into `auth.users` with `aud`/`role` `authenticated`, `phone_confirmed_at = case when confirmed then now() end`), `tests.authenticate_as(uid uuid)` (`set local role authenticated` + `set local request.jwt.claims` with `sub`, `role`), `tests.clear_auth()` (`reset role`); then `select plan(1); select has_schema('tests'); select * from finish();`.
- npm scripts (root `package.json`, no dependencies): `lint` = `scripts/sdk flutter gen-l10n && scripts/sdk dart format --output=none --set-exit-if-changed lib test && scripts/sdk flutter analyze`; `typecheck` = `scripts/sdk flutter analyze --no-pub`; `test` = `scripts/sdk flutter test && supabase test db`. (Task 10 adds `integration_test` to the format list. `gen-l10n` is a no-op until Task 3 adds `l10n.yaml`; until then `lint` starts at `format`.)

- [ ] **Step 1:** Write `scripts/sdk` (bash, `set -euo pipefail`, `chmod +x`); write `flutter_app/.fvmrc` first so the SDK resolves; then from repo root `~/fvm/versions/3.47.5/bin/flutter create --org com.lemqes --project-name lemqes --platforms android,ios,linux flutter_app` (direct path because `scripts/sdk` needs the folder to exist). Confirm `scripts/sdk flutter --version` prints `3.47.5`. Check https://docs.flutter.dev/release/archive: if a newer 3.47.x/3.48 stable exists, report it before continuing.
- [ ] **Step 2:** Add deps: `supabase_flutter`, `flutter_riverpod`, `go_router`, `shared_preferences`, `intl`, `flutter_localizations (sdk)`; dev: `mocktail`, `integration_test (sdk)`, `flutter_lints`. `analysis_options.yaml`: include `package:flutter_lints/flutter.yaml`, `strict-casts`, `strict-inference`, `strict-raw-types`, plus `prefer_single_quotes`, `always_declare_return_types`, `avoid_dynamic_calls`.
- [ ] **Step 3:** `supabase init` at repo root (decline the VS Code/IntelliJ settings prompts). In `config.toml` set `project_id = "lemqes"` and ports: `api 55321`, `db 55322`, `shadow_port 55320`, `studio 55323`, `inbucket 55324`, `analytics 55327`, `pooler 55329`. `supabase start`; copy URL + anon key into `flutter_app/env/local.json`.
- [ ] **Step 4:** `main.dart`: `Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey)` then `runApp(const ProviderScope(child: LemqesApp()))`; `app.dart`: `LemqesApp` (ConsumerWidget) returning a placeholder `MaterialApp`. Replace the counter test with `app_smoke_test.dart`: pumps `LemqesApp` in `ProviderScope` with `supabaseClientProvider` overridden by a mocktail `SupabaseClient`, expects one `MaterialApp`.
- [ ] **Step 5:** Write `000-setup.sql` and `001-smoke.sql` (`begin; select plan(1); select ok(tests.create_user('+213550000099') is not null); select * from finish(); rollback;`).
- [ ] **Step 6:** `.gitignore` additions: `flutter_app/build/`, `flutter_app/.dart_tool/`, `flutter_app/.fvm/`, `flutter_app/env/local.json`, `flutter_app/lib/core/l10n/gen/`, `supabase/.temp/`, `supabase/.branches/`, `node_modules/` (and commit the pending `.superpowers/` lines already in the working tree).
- [ ] **Step 7:** Run `npm run lint`, `npm run typecheck`, `npm test`.
- [ ] **Step 8:** Commit `chore: scaffold flutter app, supabase stack and gates`.

**Done when:** (1) `scripts/sdk flutter --version` prints `Flutter 3.47.5`; `npm test` prints `All tests passed!` (1 test: `app_smoke_test.dart`) and pg_prove lists `000-setup.sql .. ok`, `001-smoke.sql .. ok`, `Result: PASS`; `curl -s http://127.0.0.1:55321/rest/v1/ -H "apikey: <anon>" -o /dev/null -w '%{http_code}'` prints `200`; (2) `npm run lint` and `npm run typecheck` exit 0; (3) no files changed outside `flutter_app/`, `supabase/`, `scripts/sdk`, `package.json`, `.gitignore`.

---

### Task 2: Lagoon theme, fonts, direction contract, core widgets

**Files:** Create `lib/core/theme/{lemqes_tokens,lemqes_gradients,lemqes_typography,lemqes_theme,theme_mode_controller}.dart`, `lib/shared/widgets/{lagoon_header_band,lemqes_primary_button,state_views}.dart`, `assets/fonts/*`, `test/flutter_test_config.dart`, `test/core/theme/{contrast_test,theme_test,theme_mode_controller_test}.dart`, `test/shared/widgets/{lagoon_header_band_golden_test,lemqes_primary_button_golden_test,state_views_test}.dart`, goldens. Modify `pubspec.yaml`, `lib/app.dart`. Plus the impeccable surface brief.

**Interfaces — Produces:**
- `abstract final class LemqesColors` — `static const Color` for every Global Constraints colour: `deepSea, teal, blue, tealDark, pill, rowTint, gold, ground, ink, muted, open, onBreak, closed`.
- `class LemqesGradients extends ThemeExtension<LemqesGradients> { final Gradient brand; final Gradient button; final Gradient bloom; }` — read with `Theme.of(context).extension<LemqesGradients>()!`.
- `ThemeData lemqesTheme(Brightness b)`; `TextTheme lemqesTextTheme(Brightness b)`; `const TextStyle lemqesNumeric` with `[FontFeature.tabularFigures()]`.
- `final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);` persisted under shared_preferences key `theme_mode` (default `ThemeMode.system`); `setMode(ThemeMode)`.
- `LagoonHeaderBand({required Widget child, double height = 150, Widget? overlap})` — gradient + bloom; `overlap` straddles the lower edge.
- `LemqesPrimaryButton({required String label, required VoidCallback? onPressed, bool loading = false, IconData? icon, Key? key})` — gradient pill, 1 px top highlight, soft shadow, min height 48, disabled when `onPressed == null`, spinner replaces the icon and the label stays when `loading`; visible focus ring.
- `LoadingView()`, `EmptyView({required String title, String? body, Widget? action})`, `ErrorView({required String message, required String retryLabel, required VoidCallback onRetry})`.
- `app.dart` wires `theme: lemqesTheme(Brightness.light)`, `darkTheme: lemqesTheme(Brightness.dark)`, `themeMode: ref.watch(themeModeProvider)`.

- [ ] **Step 1:** Run `sh .claude/skills/impeccable/scripts/impeccable context --target flutter_app/lib`; write `## Direction contract` (six blocks + FINISH line, `seed:2c904c7b1ac433b2`) into the surface brief it names, per `.claude/skills/impeccable/reference/new-work.md` "Before code". Record the brief's path in this plan's Gate log notes. Read `.claude/skills/impeccable/reference/craft-floor.md` before UI code.
- [ ] **Step 2: Failing tests.**
  - `contrast_test.dart` with helper `double contrast(Color a, Color b)` (WCAG relative luminance): `white` on `deepSea`, `teal`, `blue` ≥ 4.5; `ink` on `ground` ≥ 4.5; `muted` on `white`, `ground`, `rowTint` ≥ 4.5; `tealDark` on `pill` ≥ 4.5; `open`, `onBreak`, `closed` on `white` ≥ 4.5; `ink` on `gold` ≥ 4.5; dark scheme `onSurface`/`surface`, `onSurfaceVariant`/`surface`, `onPrimary`/`primary` ≥ 4.5.
  - `theme_test.dart`: light and dark both have `LemqesGradients`; `displayLarge.fontFamily == 'Alexandria'`; `bodyMedium.fontFamily == 'Inter'` with `fontFamilyFallback` containing `'NotoSansArabic'` and `'NotoSansTifinagh'`; `useMaterial3`; light `scaffoldBackgroundColor == LemqesColors.ground`; dark `scaffoldBackgroundColor != Colors.black` and ≠ light ground.
  - `theme_mode_controller_test.dart`: default `system`; `setMode(dark)` persists; a fresh container reads `dark`.
  - `state_views_test.dart`: `ErrorView` retry tap calls `onRetry`; `EmptyView` renders its action.
  Run → FAIL.
- [ ] **Step 3:** Download the four fonts + `OFL.txt` from github.com/google/fonts (`ofl/alexandria`, `ofl/inter`, `ofl/notosansarabic`, `ofl/notosanstifinagh`); declare families `Alexandria`, `Inter`, `NotoSansArabic`, `NotoSansTifinagh`. Implement tokens, gradients (brand 160°, stops 0 / 0.55 / 1.0; bloom radial white 20 % at `AlignmentDirectional.topEnd`), typography, both `ColorScheme`s (dark designed from deep-sea surfaces, not an invert — values chosen by the implementer, held by the contrast test), the controller and the `app.dart` wiring. Run → PASS.
- [ ] **Step 4: Goldens.** `flutter_test_config.dart` loads the bundled fonts and `MaterialIcons` via `FontLoader`. Goldens: `LagoonHeaderBand` (with a search-field overlap) and `LemqesPrimaryButton` (enabled / pressed / disabled / loading / focused) × light/dark × `ar` RTL/`fr` LTR (locale set via `Localizations.override` + `Directionality`). Generate with `--update-goldens`, then **look at every PNG** next to a render of `premium-lagoon.html` (`google-chrome --headless=new --window-size=800,960 --screenshot=…`); fix, regenerate, commit.
- [ ] **Step 5:** ui-quality self-review of the widgets; commit `feat: add Lagoon theme, bundled fonts and core widgets`.

**Done when:** (1) `scripts/sdk flutter test test/core/theme test/shared` → `All tests passed!` covering the 6 files above, goldens committed under `test/shared/widgets/goldens/` and listed by name in the hand-back with what was checked; the surface brief contains `## Direction contract` and `seed:2c904c7b1ac433b2`; (2) `npm run lint` exits 0 and `scripts/sdk flutter test` (whole suite) passes; (3) no files changed outside `flutter_app/lib/core/theme/`, `flutter_app/lib/shared/widgets/`, `flutter_app/lib/app.dart`, `flutter_app/assets/fonts/`, `flutter_app/test/`, `flutter_app/pubspec.yaml`, the surface brief, `task_plan.md`.

---

### Task 3: Four languages, RTL, Kabyle fallback

**Files:** Create `flutter_app/l10n.yaml`, `lib/core/l10n/arb/app_{fr,en,ar,kab}.arb`, `lib/core/l10n/{locale_controller,kab_fallback_delegates,intl_locale}.dart`, `lib/core/l10n/REVIEW.md`, `lib/shared/widgets/ltr.dart`, `test/core/l10n/{arb_parity_test,kab_fallback_test,rtl_test,intl_locale_test,locale_controller_test}.dart`. Modify `app.dart`, `pubspec.yaml` (`flutter: generate: true`).

**Interfaces — Produces:**
- `l10n.yaml`: `arb-dir: lib/core/l10n/arb`, `template-arb-file: app_fr.arb`, `output-dir: lib/core/l10n/gen`, `output-localization-file: app_localizations.dart`, `nullable-getter: false`. Accessor `extension L10nX on BuildContext { AppLocalizations get l10n => AppLocalizations.of(this); }` in `locale_controller.dart`.
- `const supportedLocales = [Locale('ar'), Locale('fr'), Locale('en'), Locale('kab')];`
- `Locale resolveInitialLocale(List<Locale> deviceLocales)` — first device language in the set, else `Locale('ar')`.
- `final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);` persisted under key `locale`; `setLocale(Locale)`; sets `Intl.defaultLocale = intlLocaleFor(locale)`.
- `const kabMaterialDelegate`, `kabCupertinoDelegate`, `kabWidgetsDelegate` — `isSupported(l) => l.languageCode == 'kab'`; Material/Cupertino `load` return the French global localizations; Widgets returns LTR `DefaultWidgetsLocalizations`.
- `String intlLocaleFor(Locale l)` → `ar`→`ar_DZ`, `kab`→`fr`, others → languageCode.
- `Ltr({required Widget child})` — `Directionality(textDirection: TextDirection.ltr, child: child)` for phone numbers, codes, counts and ± controls.
- Initial ARB keys (French template from the prototype's French copy, others translated): `appName`, `spaceMen`, `spaceWomen`, `languageName_ar`, `languageName_fr`, `languageName_en`, `languageName_kab`, `themeSystem`, `themeLight`, `themeDark`, `actionRetry`, `errorGeneric`, `errorNetwork`, `loading`. Later tasks add their own keys (Global Constraints).

- [ ] **Step 1: Failing tests.**
  - `arb_parity_test.dart`: the four ARB files have identical non-`@` key sets, and every placeholder in `fr` appears in each translation.
  - `kab_fallback_test.dart`: `MaterialApp(locale: Locale('kab'), localizationsDelegates: appDelegates, supportedLocales: supportedLocales)` with a button opening `showDatePicker`; after tapping, `tester.takeException()` is null, `MaterialLocalizations.of(ctx)` is non-null and `Directionality.of(ctx) == TextDirection.ltr`; `NumberFormat.decimalPattern(intlLocaleFor(Locale('kab'))).format(1234)` does not throw.
  - `rtl_test.dart`: under `Locale('ar')`, `Directionality.of(ctx) == TextDirection.rtl`; inside `Ltr` it is `ltr`.
  - `intl_locale_test.dart`: `NumberFormat.decimalPattern(intlLocaleFor(Locale('ar'))).format(1234)` matches `RegExp(r'^[0-9.,  ]+$')`; `resolveInitialLocale([Locale('de'), Locale('fr','DZ')]) == Locale('fr')`; `resolveInitialLocale([Locale('de')]) == Locale('ar')`.
  - `locale_controller_test.dart`: `setLocale(Locale('kab'))` persists; a fresh container reads `kab`.
  Run → FAIL.
- [ ] **Step 2:** Implement. `app.dart`: `locale: ref.watch(localeProvider)`, `localizationsDelegates: [AppLocalizations.delegate, kabMaterialDelegate, kabCupertinoDelegate, kabWidgetsDelegate, ...GlobalMaterialLocalizations.delegates]` (export this list as `appDelegates` for tests), `supportedLocales`. Run → PASS.
- [ ] **Step 3:** `REVIEW.md`: one row per key with `ar` and `kab` status `draft` (decision D2).
- [ ] **Step 4:** Commit `feat: add four-language localization with Kabyle fallback`.

**Done when:** (1) `scripts/sdk flutter test test/core/l10n` → `All tests passed!` covering the 5 files above; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/lib/core/l10n/`, `flutter_app/lib/shared/widgets/ltr.dart`, `flutter_app/lib/app.dart`, `flutter_app/l10n.yaml`, `flutter_app/pubspec.yaml`, `flutter_app/test/core/l10n/`.

---

### Task 4: Local auth spike, accounts schema, RLS and RPCs

**Files:** Create `supabase/migrations/20261114000100_accounts.sql`, `supabase/tests/database/010-accounts.sql`. Modify `supabase/config.toml`, `task_plan.md` (Spike results).

**Interfaces — Produces (SQL, all in `public`; functions `security definer set search_path = ''`; for each function `revoke execute … from public, anon; grant execute … to authenticated;`):**
- `create type space as enum ('men','women'); create type app_role as enum ('customer','barber','home_artist','salon_owner');`
- `profiles(id uuid primary key references auth.users on delete cascade, full_name text not null check (char_length(btrim(full_name)) between 2 and 80), pro_space space, customer_space space not null, active_role app_role not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now())`.
- `profile_roles(profile_id uuid not null references profiles on delete cascade, role app_role not null, business_name text, created_at timestamptz not null default now(), primary key (profile_id, role), check (role <> 'salon_owner' or (business_name is not null and char_length(btrim(business_name)) between 2 and 80)))`. `business_name` is interim: M7 moves it into a `salons` table (decision D5).
- `complete_signup(p_full_name text, p_space space, p_role app_role, p_business_name text default null) returns profiles` — `raise exception 'phone_not_verified'` unless the caller's `auth.users.phone_confirmed_at is not null`; `'profile_exists'` if a profile exists; sets `customer_space = p_space`, `pro_space = case when p_role <> 'customer' then p_space end`, `active_role = p_role`; inserts the role row and, for pro roles, a `customer` row too (every account can book).
- `add_role(p_role app_role, p_space space default null, p_business_name text default null) returns void` — `customer`: insert if missing. Pro role: if `pro_space is null`, require `p_space` (`raise exception 'space_required'`) and set it; if `p_space` is given and ≠ `pro_space` → `'space_locked'`. Held role → no-op.
- `set_active_role(p_role app_role) returns void` — `'role_not_held'` unless held.
- `set_customer_space(p_space space) returns void`.
- `current_space() returns space language sql stable` — `customer_space` when active role is `customer`, else `pro_space`; null without a profile.
- `acts_as(p_role app_role) returns boolean stable` — held and `active_role = p_role`. `has_role(p_role app_role) returns boolean stable` — held.
- RLS enabled on both tables. Policies: `profiles` select + update where `id = (select auth.uid())`; `profile_roles` select where `profile_id = (select auth.uid())`. Grants: `revoke all on profiles, profile_roles from anon, authenticated; grant select on profiles, profile_roles to authenticated; grant update (full_name) on profiles to authenticated;` (writes only through RPCs). `updated_at` set by a `before update` trigger.
- A header comment in the migration states the policy pattern later milestones copy: wrap helpers as `(select current_space())`, `(select acts_as('barber'))`; security = roles held + ownership + the data's space.
- `config.toml`: `[auth] minimum_password_length = 8`; `[auth.sms] enable_signup = true`, `enable_confirmations = true`; `[auth.sms.test_otp]` `213550000001`, `213550000002`, `213550000003`, `213550000009` = `"123456"`.

- [ ] **Step 1: Spike.** Apply the config, `supabase stop && supabase start` (auth settings reload only on restart). With the anon key against `http://127.0.0.1:55321/auth/v1`: (a) `POST /signup {"phone":"+213550000009","password":"lemqes-spike-1"}`; (b) `POST /verify {"type":"sms","phone":"+213550000009","token":"000000"}` (wrong code); (c) `POST /verify` with `123456`; (d) repeat (a) for the now-confirmed number; (e) `POST /otp {"phone":"+213550000009","create_user":false}`. Write each HTTP status + `error_code`/`msg` (or `identities` length for (d)) into **Spike results** below. If (a) fails with an SMS-provider error, add `[auth.sms.twilio] enabled = true` with dummy `account_sid`/`message_service_sid`/`auth_token = "env(TWILIO_DUMMY)"`, restart, rerun, and record that too.
- [ ] **Step 2: Failing pgTAP tests** (`010-accounts.sql`, `begin; select plan(n); … select * from finish(); rollback;`):
  - unconfirmed user (`tests.create_user(…, false)`) → `complete_signup` throws `phone_not_verified`.
  - confirmed → `complete_signup('Amine','men','barber')` returns `pro_space='men'`, `active_role='barber'`; `has_role('customer')` and `has_role('barber')` true; `acts_as('barber')` true, `acts_as('customer')` false; second call throws `profile_exists`.
  - no profile → `current_space()` is null.
  - `add_role('salon_owner','women','Salon X')` for that men barber throws `space_locked`; `add_role('salon_owner',null,'Salon X')` succeeds; `add_role('salon_owner',null,null)` (fresh user) raises `23514`; customer-only user `add_role('barber')` with no space throws `space_required`.
  - `set_active_role('home_artist')` without it throws `role_not_held`; `set_active_role('customer')` → `current_space() = customer_space` and `acts_as('customer')`; `set_customer_space('women')` → `current_space() = 'women'` while `pro_space` stays `men`.
  - user B selects 0 rows of A's `profiles`/`profile_roles`; `insert into profile_roles` → `42501`; `update profiles set pro_space='women'` → `42501`; `update profiles set active_role='customer'` → `42501`; `update profiles set full_name='Amine B'` succeeds for own row, affects 0 rows for another's.
  - as `anon`: each of the 7 functions → `42501`.
  Run `supabase test db` → FAIL.
- [ ] **Step 3:** Write the migration; `supabase db reset`; `supabase test db` → PASS; `supabase db lint` → no errors.
- [ ] **Step 4:** Commit `feat: add accounts schema with spaces, roles and RLS`.

**Done when:** (1) Spike results below are filled with real statuses for (a)–(e); `supabase test db` → `010-accounts.sql .. ok`, `Result: PASS`; `supabase db lint` reports no errors; (2) `npm test` passes; (3) no files changed outside `supabase/`, `task_plan.md`.

---

### Task 5: Auth and account data layer

**Files:** Create `lib/features/auth/data/{phone_number,auth_repository}.dart`, `lib/features/account/data/{account,account_api,account_repository,account_providers}.dart`, tests `test/features/auth/data/{phone_number_test,auth_repository_test}.dart`, `test/features/account/data/{account_repository_test,account_controller_test}.dart`.

**Interfaces — Consumes:** `supabaseClientProvider` (Task 1); SQL RPCs (Task 4); Spike results (Task 4).
**Produces:**
- `String? normalizeAlgerianMobile(String input)` → `'+213XXXXXXXXX'` or null. Maps Eastern Arabic (U+0660–0669) and Persian (U+06F0–06F9) digits to ASCII; strips spaces, dots, dashes, parentheses; accepts prefixes `+213`, `00213`, `213` (+ 9 digits), `0`, or bare 9 digits; first significant digit `5|6|7`.
- `sealed class AuthFailure implements Exception` — `InvalidCredentials`, `PhoneAlreadyRegistered`, `InvalidOrExpiredCode`, `RateLimited(Duration? retryAfter)`, `WeakPassword`, `NetworkFailure`, `UnknownAuthFailure(String debug)`; mapping lives only in the repository and uses the `error_code`s recorded in Spike results.
- `class AuthRepository { AuthRepository(GoTrueClient auth); Future<void> signUp({required String phone, required String password}); Future<void> verifySignUpCode({required String phone, required String code}); Future<void> resendSignUpCode(String phone); Future<void> signIn({required String phone, required String password}); Future<void> sendResetCode(String phone); Future<void> verifyResetCode({required String phone, required String code}); Future<void> setNewPassword(String password); Future<void> signOut(); Stream<AuthState> authStateChanges(); Session? get currentSession; }` — inputs already E.164. `signUp` throws `PhoneAlreadyRegistered` on the signal recorded in spike (d) (and also on an empty `identities` list). `sendResetCode` = `signInWithOtp(phone:, shouldCreateUser: false)`; `resendSignUpCode` = `resend(type: OtpType.sms, phone:)`.
- `enum Space { men, women }`, `enum AppRole { customer, barber, homeArtist, salonOwner }` with `String toDb()` / `static fromDb(String)` (`home_artist`, `salon_owner`); `bool get isPro`.
- `class Account { final String id; final String fullName; final Space customerSpace; final Space? proSpace; final AppRole activeRole; final Set<AppRole> roles; final String? businessName; Space get currentSpace; String get displayName; }` — `displayName` = `businessName` when active role is `salonOwner`, else `fullName`.
- `abstract interface class AccountApi { Future<Object?> rpc(String fn, Map<String, Object?> params); Future<Map<String, Object?>?> myProfile(); Future<List<Map<String, Object?>>> myRoles(); }` + `SupabaseAccountApi(SupabaseClient)` (thin; not unit-tested — covered by Task 10).
- `class AccountRepository { AccountRepository(AccountApi api); Future<Account?> fetchMine(); Future<Account> completeSignup({required String fullName, required Space space, required AppRole role, String? businessName}); Future<void> addRole(AppRole role, {Space? space, String? businessName}); Future<void> setActiveRole(AppRole role); Future<void> setCustomerSpace(Space space); }` — maps exception messages to `sealed class AccountFailure implements Exception`: `SpaceLocked`, `SpaceRequired`, `RoleNotHeld`, `ProfileExists`, `PhoneNotVerified`, `UnknownAccountFailure(String debug)`.
- Providers: `authRepositoryProvider`, `accountRepositoryProvider`, `sessionProvider` (`StreamProvider<Session?>`), `accountProvider` (`AsyncNotifierProvider<AccountController, Account?>`, refetches on session change; `switchRole(AppRole)`, `addRole(AppRole, {Space? space, String? businessName})`, `switchSpace(Space)`, `refresh()` — each calls the repo then refetches).

- [ ] **Step 1: Failing tests.**
  - `phone_number_test.dart` table → `'+213550123456'`: `'0550 12 34 56'`, `'+213 550 12 34 56'`, `'00213550123456'`, `'213550123456'`, `'550123456'`, `'0550-12-34-56'`, `'0550.12.34.56'`, `'(0550) 12 34 56'`, `'٠٥٥٠ ١٢ ٣٤ ٥٦'`, `'۰۵۵۰۱۲۳۴۵۶'`; → null: `'021 12 34 56'`, `'0450123456'`, `'+33612345678'`, `'05501234'`, `'055012345678'`, `''`, `'abc'`.
  - `auth_repository_test.dart` (mocktail `GoTrueClient`): duplicate-number signal from spike (d) → `PhoneAlreadyRegistered`; spike (b) code → `InvalidOrExpiredCode`; `invalid_credentials` → `InvalidCredentials`; status 429 / `over_sms_send_rate_limit` → `RateLimited`; `weak_password` → `WeakPassword`; `SocketException`/`AuthRetryableFetchException` → `NetworkFailure`; `sendResetCode` calls `signInWithOtp(phone: '+213550123456', shouldCreateUser: false)`.
  - `account_repository_test.dart` (mock `AccountApi`): `completeSignup` calls `rpc('complete_signup', {'p_full_name':'Salon Lina owner','p_space':'women','p_role':'salon_owner','p_business_name':'Salon Lina'})`; `PostgrestException(message: 'space_locked')` → `SpaceLocked`; `fetchMine` with no profile → null; with profile + roles rows → `roles`, `currentSpace`, `displayName` correct.
  - `account_controller_test.dart`: `switchSpace(Space.women)` calls `setCustomerSpace` then state has `currentSpace == women`; a repo failure leaves `AsyncError` and keeps the previous value.
  Run → FAIL.
- [ ] **Step 2:** Implement; run → PASS. Commit `feat: add auth and account repositories`.

**Done when:** (1) `scripts/sdk flutter test test/features/auth/data test/features/account/data` → `All tests passed!` covering the 4 files above; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/lib/features/{auth,account}/data/`, `flutter_app/test/features/{auth,account}/data/`.

---

### Task 6: Router, redirect and sign-up draft

**Files:** Create `lib/core/router/{app_router,redirect,placeholder_screen}.dart`, `lib/features/signup/data/{signup_draft,signup_draft_store}.dart`, `test/core/router/redirect_test.dart`, `test/features/signup/data/signup_draft_store_test.dart`. Modify `app.dart` (`MaterialApp.router`).

**Interfaces — Consumes:** `sessionProvider`, `accountProvider` (Task 5).
**Produces:**
- Routes (builders point at `PlaceholderScreen(name)` until Tasks 7–8 replace them): `/` (redirect only), `/auth`, `/auth/reset`, `/signup/:step` (`space`, `role`, `credentials`, `code`), `/home`, `/settings`.
- `String? authRedirect({required bool hasSession, required AsyncValue<Account?> account, required SignupDraft? draft, required String location})` — pure, rules in order:
  1. no session: if `draft?.phone != null` and location is `/` or `/auth` → `/signup/code`; else if location starts with `/auth` or `/signup` → null; else → `/auth`.
  2. session, `account` loading → null when on `/home`, else `/home` (home shows `LoadingView`).
  3. session, `account` error → `/home` unless already there (home shows `ErrorView` with retry → `accountProvider.refresh()`); never the wizard.
  4. session, account null: location starts with `/signup` → null (free back/forward inside the wizard); else → `/signup/${draft?.resumeStep ?? 'space'}`.
  5. session, account present: location `/auth/reset` → null (reset finishes before leaving); other `/auth*`, `/signup*` or `/` → `/home`; else null.
- `class SignupDraft { final Space? space; final AppRole? role; final String? fullName; final String? businessName; final String? phone; String get resumeStep; Map<String, Object?> toJson(); factory SignupDraft.fromJson(Map<String, Object?>); SignupDraft copyWith(...); }` — `resumeStep`: no space → `space`; no role → `role`; no phone → `credentials`; else `code`. **Never stores the password.**
- `class SignupDraftStore { Future<SignupDraft?> read(); Future<void> write(SignupDraft draft); Future<void> clear(); }` (key `signup_draft`); `final signupDraftProvider = AsyncNotifierProvider<SignupDraftController, SignupDraft?>(…)` with `update(SignupDraft Function(SignupDraft) f)` and `clear()`. The router reads `ref.read(signupDraftProvider).value`.
- `GoRouter(refreshListenable: …)` driven by session, account and draft changes; exposed as `final routerProvider = Provider<GoRouter>(…)`.

- [ ] **Step 1: Failing tests.** `redirect_test.dart`: one test per rule branch above, including: no session + draft with phone at `/` → `/signup/code`; no session + no draft at `/home` → `/auth`; session + loading at `/signup/role` → `/home`; session + error at `/signup/space` → `/home`; session + no account + no draft at `/home` → `/signup/space`; session + no account at `/signup/role` → null (back navigation); session + account at `/auth/reset` → null; session + account at `/auth` → `/home`. `signup_draft_store_test.dart`: write → read equal; stored JSON has no `password` key; `clear` → null; `resumeStep` for each stage. Run → FAIL.
- [ ] **Step 2:** Implement; run → PASS. Commit `feat: add router with session-aware redirect and signup draft`.

**Done when:** (1) `scripts/sdk flutter test test/core/router test/features/signup/data` → `All tests passed!` covering the 2 files above with ≥ 12 tests in `redirect_test.dart`; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/lib/core/router/`, `flutter_app/lib/features/signup/data/`, `flutter_app/lib/app.dart`, `flutter_app/test/core/router/`, `flutter_app/test/features/signup/data/`.

---

### Task 7: Auth and sign-up screens

**Files:** Create `lib/features/auth/presentation/{auth_screen,login_form,reset_password_screen}.dart`, `lib/features/signup/presentation/{signup_wizard.dart,steps/space_step.dart,steps/role_step.dart,steps/credentials_step.dart,steps/code_step.dart}`, `lib/shared/widgets/{choice_card,step_progress,code_field}.dart`, tests (listed in Step 1), goldens. Modify `lib/core/router/app_router.dart` (real builders for `/auth`, `/auth/reset`, `/signup/:step`), ARB files + `REVIEW.md`.

**Interfaces — Consumes:** Tasks 2, 3, 5, 6. **Produces:** `ChoiceCard({required String title, String? subtitle, String? badge, required bool selected, required VoidCallback onTap, IconData? icon, Key? key})`; `StepProgress({required int step, required int total})`; `CodeField({required ValueChanged<String> onCompleted, int length = 6, Key? key})` (inside `Ltr`, numeric keyboard, `AutofillHints.oneTimeCode`, maps Eastern Arabic digits, pasting 6 digits fills all). Widget keys for Task 10: `Key('phoneField')`, `Key('passwordField')`, `Key('confirmField')`, `Key('nameField')`, `Key('businessNameField')`, `Key('codeField')`, `Key('primaryAction')`, `Key('space_men')`, `Key('space_women')`, `Key('role_<dbName>')`, `Key('forgotPassword')`, `Key('tab_signup')`, `Key('tab_login')`.

Behaviour (layout per the direction contract; header band with wordmark on the auth screen):
- **AuthScreen:** language chips (AR / FR / EN / TZ → `kab`) and a theme toggle in the top bar; tabs "Se connecter" / "Créer un compte" (the latter starts the wizard at `/signup/space`). Login: phone (in `Ltr`, `TextInputType.phone`, hint `0550 12 34 56`), password with show/hide, primary "Se connecter", link "Mot de passe oublié ?" → `/auth/reset`. Field errors inline; failure banner for `InvalidCredentials`, `NetworkFailure`, `RateLimited` (shows retry time).
- **Wizard:** `StepProgress` total 4 for customer, 5 for pro roles (steps 4–5 come in M2; until then, after the code step pros land on `/home`). Step 1 space (two `ChoiceCard`s). Step 2 role (four cards, wording by space via ARB `select`; customer badge "Gratuit"; **no free-month badge on pro roles** — the free month starts at wallet launch, M10). Step 3 credentials: business name (salon owner only), full name, then — **only when there is no session** — phone, password (≥ 8) and confirm with a live match hint → `signUp` → draft saved with phone → `/signup/code`. **With a session (verified, profile missing), step 3 shows only the names and calls `completeSignup` directly.** `PhoneAlreadyRegistered` → message + "Se connecter" / "Réinitialiser le mot de passe" buttons. Code step: `CodeField`, resend with a 60 s countdown, `InvalidOrExpiredCode` message, "Retour à la connexion" (clears the draft); on success `completeSignup` from the draft, then `clear()`; the router moves to `/home`.
- **Reset:** phone → `sendResetCode` → `CodeField` → `verifyResetCode` → new password + confirm → `setNewPassword` → snackbar → `/home`.

- [ ] **Step 1: Failing widget tests** (repositories mocked, `ProviderScope` overrides):
  - `test/features/auth/presentation/login_form_test.dart`: invalid phone → phone error, no `signIn`; valid → `signIn(phone: '+213550123456', password: …)`; `InvalidCredentials` → banner; loading state while pending.
  - `test/features/signup/presentation/credentials_step_test.dart`: business-name field only for `salonOwner`; `'1234567'` → length error; mismatch → hint; `PhoneAlreadyRegistered` → message + both buttons and no "account created" text; **with a session and no account, no phone/password fields are shown and `completeSignup` is called, `signUp` never** (Review Focus 2).
  - `test/features/signup/presentation/role_step_test.dart`: women space shows the women wording; pro cards have no free-month badge.
  - `test/features/signup/presentation/code_step_test.dart`: pasting `123456` calls `verifySignUpCode` once; `InvalidOrExpiredCode` → message and cleared field; resend enabled only after `pump(60 s)`; success → `completeSignup` with the draft values, then draft cleared.
  - `test/features/auth/presentation/reset_password_screen_test.dart`: the three stages advance in order; `sendResetCode` gets E.164.
  - `test/features/auth/presentation/auth_rtl_scale_test.dart`: `ar` + `TextScaler.linear(2.0)` at 360×740 for AuthScreen and each wizard step: `tester.takeException()` is null; phone and code fields resolve `Directionality.of == ltr` (Review Focus 5).
  - Goldens: AuthScreen and role step × light/dark × `fr`/`ar`.
  Run → FAIL.
- [ ] **Step 2:** Implement and wire the routes. Run → PASS. Look at every golden; ui-quality self-review (one primary action per view, designed loading/error states, 48 dp, focus order).
- [ ] **Step 3:** Commit `feat: add auth screens and sign-up wizard steps 1-3`.

**Done when:** (1) `scripts/sdk flutter test test/features/auth/presentation test/features/signup/presentation test/shared` → `All tests passed!` covering the 6 files above, goldens listed by name in the hand-back; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/lib/features/{auth,signup}/presentation/`, `flutter_app/lib/shared/widgets/`, `flutter_app/lib/core/router/app_router.dart`, `flutter_app/lib/core/l10n/arb/`, `flutter_app/lib/core/l10n/REVIEW.md`, matching `flutter_app/test/` dirs.

---

### Task 8: Home placeholders, settings, role and space switch

**Files:** Create `lib/features/home/presentation/{home_screen,customer_home_screen,pro_home_screen}.dart`, `lib/features/account/presentation/{role_switch_sheet,space_switch}.dart`, `lib/features/settings/presentation/settings_screen.dart`, tests (listed in Step 1), goldens. Modify `lib/core/router/app_router.dart` (`/home`, `/settings`), ARB files + `REVIEW.md`; delete `lib/core/router/placeholder_screen.dart` once unused.

**Interfaces — Consumes:** `accountProvider` (`switchRole`, `addRole`, `switchSpace`, `refresh`), `authRepositoryProvider.signOut`, `localeProvider`, `themeModeProvider`. Keys: `Key('roleSwitch')`, `Key('settings')`, `Key('signOut')`, `Key('spaceSwitch_men')`, `Key('spaceSwitch_women')`, `Key('addRole')`.

- **HomeScreen:** watches `accountProvider`: loading → `LoadingView`; error → `ErrorView` (retry → `refresh()`); data → customer or pro home by `activeRole`.
- **CustomerHome:** Lagoon header band with wordmark, current space label, `SpaceSwitch` (Hommes / Dames segmented control), role-switch and settings actions; body `EmptyView` "Les barbiers arrivent bientôt" (M2 replaces it).
- **ProHome:** header band with `account.displayName` and the space label (space not switchable; info tooltip says why), role-switch and settings actions; body `EmptyView` "Complétez votre profil" with a disabled action (M2).
- **RoleSwitchSheet:** held roles with the active one selected; tap → `switchRole`; "Ajouter un rôle" → cards for roles not held; a pro role asks for a space only if `proSpace == null` (otherwise shows the locked space); salon owner asks for a business name.
- **Settings:** language (4 options, native names), theme (system / light / dark), role switch entry, sign out (confirm dialog).

- [ ] **Step 1: Failing widget tests:** `test/features/home/presentation/home_screen_test.dart` — loading, error (retry calls `refresh`), customer vs pro by role. `customer_home_screen_test.dart` — tapping Dames calls `switchSpace(Space.women)` and the label updates. `pro_home_screen_test.dart` — no `SpaceSwitch`; salon owner shows the business name, barber the full name. `test/features/account/presentation/role_switch_sheet_test.dart` — only held roles listed; adding `barber` with `proSpace == men` shows no space choice and calls `addRole(AppRole.barber)`; with `proSpace == null` asks for a space; `salonOwner` requires a business name. `test/features/settings/presentation/settings_screen_test.dart` — choosing Taqbaylit sets `Locale('kab')`; sign-out confirm calls `signOut`. Run → FAIL.
- [ ] **Step 2:** Implement and wire the routes. Run → PASS. Goldens for both homes × light/dark × `fr`/`ar`; inspect; ui-quality self-review.
- [ ] **Step 3:** Commit `feat: add role-aware home, settings and role/space switching`.

**Done when:** (1) `scripts/sdk flutter test test/features/home test/features/account/presentation test/features/settings` → `All tests passed!` covering the 5 files above, goldens listed by name in the hand-back; `grep -r PlaceholderScreen flutter_app/lib` finds nothing; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/lib/features/{home,account/presentation,settings}/`, `flutter_app/lib/core/router/`, `flutter_app/lib/core/l10n/arb/`, `flutter_app/lib/core/l10n/REVIEW.md`, matching `flutter_app/test/` dirs.

---

### Task 9: Lagoon app icon and splash

**Files:** Create `assets/brand/{icon_master.svg,icon_foreground.png,icon_background.png,icon_monochrome.png,splash_mark.png}`, `flutter_launcher_icons.yaml`, `flutter_native_splash.yaml`. Generated by the tools under `android/app/src/main/res/`, `ios/Runner/`.

- [ ] **Step 1:** Design the mark in `icon_master.svg` (1024²): a white scissors-derived "L" monogram on the Lagoon gradient with bloom; foreground inside the 66 % adaptive safe zone; a monochrome variant for Android 13 themed icons. Follow craft-floor. Render PNGs with `google-chrome --headless=new --default-background-color=00000000 --window-size=1024,1024 --screenshot=…` (`rsvg-convert` is not installed).
- [ ] **Step 2:** Configure flutter_launcher_icons 0.14.4 (`adaptive_icon_background`, `adaptive_icon_foreground`, `adaptive_icon_monochrome`, `remove_alpha_ios: true`) and flutter_native_splash 2.4.8 (`color: "#062A35"`, `image`, plus `android_12:` with `image` and `icon_background_color: "#062A35"`). Run `scripts/sdk dart run flutter_launcher_icons` and `scripts/sdk dart run flutter_native_splash:create`.
- [ ] **Step 3: Verify:** look at `mipmap-xxxhdpi/ic_launcher.png`, the adaptive foreground over its background, and the iOS 1024 icon, at 48 px and full size; `scripts/sdk flutter build apk --debug --dart-define-from-file=env/local.json` succeeds.
- [ ] **Step 4:** Commit `feat: redraw app icon and splash in Lagoon`.

**Done when:** (1) the apk build exits 0; the hand-back names each inspected PNG and what was checked; `file flutter_app/assets/brand/icon_foreground.png` reports `RGBA`; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/assets/brand/`, the two yaml configs, `flutter_app/pubspec.yaml`, `flutter_app/android/app/src/main/res/`, `flutter_app/android/app/src/main/AndroidManifest.xml`, `flutter_app/ios/Runner/` (assets, `Info.plist`, `Base.lproj/`), `flutter_app/ios/Runner.xcodeproj/project.pbxproj`, `flutter_app/web/` if the splash tool creates it (delete it instead if not needed).

---

### Task 10: Integration path against the local stack

**Files:** Create `flutter_app/integration_test/auth_flow_test.dart`, `scripts/integration.sh`. Modify `package.json` (`integration_test` in the format list).

- [ ] **Step 1:** `scripts/integration.sh`: `supabase db reset` then `scripts/sdk flutter test integration_test/auth_flow_test.dart -d linux --dart-define-from-file=env/local.json`. If the Linux build fails on a missing system library (e.g. `liblzma-dev`), stop and ask the user before any `sudo apt install`.
- [ ] **Step 2: Write the test** (real local Supabase, test OTP `123456`, phone `0550000001`, finders by the Keys from Tasks 7–8). Start by clearing persisted state (`SharedPreferences.getInstance().then((p) => p.clear())` and `Supabase.instance.client.auth.signOut()` before `pumpWidget`), because `db reset` leaves a stale session on disk. Flow: sign up as a men barber "Amine", password `lemqes-test-1` → code → ProHome shows "Amine" and the men label → role sheet → customer → CustomerHome → Dames → label updates → **RLS check from the real client:** `client.from('profiles').select()` returns exactly 1 row, and `client.rpc('set_active_role', params: {'p_role': 'home_artist'})` throws `PostgrestException` containing `role_not_held` → sign out → log in with phone + password → home → sign out → reset password for `0550000001` → code → new password `lemqes-test-2` → home → sign out → log in with the old password shows the credentials error.
- [ ] **Step 3:** Run `sh scripts/integration.sh` twice in a row.
- [ ] **Step 4:** Commit `test: add sign-up, login and reset integration path`.

**Done when:** (1) two consecutive `sh scripts/integration.sh` runs each print `All tests passed!`; (2) `npm run lint` exits 0 and the whole suite passes; (3) no files changed outside `flutter_app/integration_test/`, `scripts/integration.sh`, `package.json`, `flutter_app/linux/`.

---

### Task 11: Finish review, DESIGN.md, milestone gate

- [ ] **Step 1:** Run the app (`scripts/sdk flutter run -d linux --dart-define-from-file=env/local.json`, or an Android emulator) and screenshot auth, each wizard step, both homes and settings in `fr` light and `ar` dark. Impeccable finish review against the direction contract and `premium-lagoon.html` (header band, primary button, type voices, density); fix findings.
- [ ] **Step 2:** Run impeccable `document` → `DESIGN.md` (+ sidecar) from the built tokens and widgets; discharge the FINISH line in the surface brief.
- [ ] **Step 3:** Full gate: `npm run lint && npm run typecheck && npm test && sh scripts/integration.sh`; record the commit and results in the Gate log.
- [ ] **Step 4:** Delivery loop (`.claude/rules/delivery.md`): `code-reviewer` agent on `git diff develop...feat/foundation`; `security-auditor` agent (auth + RLS); fix or rebut every finding; update `CLAUDE.md` Project Overview + Architecture Notes (stack, `scripts/sdk`, commands, layout); merge `feat/foundation` → `develop` with `--no-ff`; propose M2.

**Done when:** (1) `DESIGN.md` exists; the Gate log row at the merge commit shows lint, typecheck, `flutter test`, `supabase test db` and integration green; both reviewers' findings are listed as fixed or rebutted in the hand-back; (2) the same full gate; (3) no files changed outside `DESIGN.md`, its sidecar, the surface brief, `CLAUDE.md`, `task_plan.md`, and fixes inside paths already fenced by Tasks 1–10.

---

## Spike results (filled by Task 4 Step 1)

| Call | HTTP status | error_code / msg / identities |
|---|---|---|
| (a) signup new number | 200 (400 without provider) | user returned, `identities` length 1, no session; phone stored without `+` (`213550000009`). Without a provider: 400 `phone_provider_disabled` "Phone signups are disabled" |
| (b) verify wrong code | 403 | `otp_expired` "Token has expired or is invalid" |
| (c) verify right code | 200 | session (access + refresh token), `phone_confirmed_at` set |
| (d) signup confirmed number | 422 | `user_already_exists` "User already registered" (error, not an empty `identities` list) |
| (e) otp, create_user false | 200 (429 within 5 s) | `{"message_id":"test-otp"}`; within `max_frequency` of (a): 429 `over_sms_send_rate_limit` "...only request this after 4 seconds". Unknown number: 422 `otp_disabled` "Signups not allowed for otp" |
| SMS provider block needed? | yes | CLI warns "no SMS provider is enabled. Disabling phone login"; dummy `[auth.sms.twilio] enabled = true` (`auth_token = "env(TWILIO_DUMMY)"`) fixes it; only `test_otp` numbers work locally |

## Risks & open questions

| # | What | Why it matters | Decision (recommended first) | Relation | Cost |
|---|---|---|---|---|---|
| D1 | Final app id (placeholder `com.lemqes.lemqes`) | Store listings and Firebase bind to it; it can't change after release | A: you pick a domain-based id before M5 (recommended) · B: keep the placeholder | [NEEDED for the plan — before M5] | 10 min |
| D2 | Arabic and Kabyle copy reviewed by a native speaker | Claude's drafts, Kabyle especially, will read wrong to users | A: you name a reviewer before M5; strings tracked in `REVIEW.md` (recommended) · B: ship fr/ar only at first release | [NEEDED for the plan — before M5] | hours (reviewer) |
| D3 | Production SMS provider + EU Supabase project | Real sign-ups need SMS that reaches Mobilis/Djezzy/Ooredoo; needs your accounts | A: Twilio Verify, tested on all three carriers before M5 (recommended) · B: decide at M5. Before any `supabase config push`: remove `[auth.sms.test_otp]` and the dummy `[auth.sms.twilio]` block | [NEEDED for the plan — before M5] | 1–2 h + per-SMS cost |
| D4 | Password min 8 (prototype: 4) | 4 digits are guessable; recycled numbers make it worse | A: 8, no composition rule (recommended) · B: 6 (Supabase default) | [SIDE FIX — safe to defer] | none |
| D5 | One pro space per person | M1 assumes all of a person's pro roles share one space (`space_locked`); a man owning a women's salon would be blocked | A: keep for M1, revisit when M7 creates `salons` with their own `space` (recommended) · B: allow per-role space now | [FUTURE idea — M7] | M7: ~1 h |
| D6 | Muted text `#5E6573` instead of the spec's `#6B7280` | `#6B7280` fails AA on the ground colour | A: accept the darker grey (recommended) · B: keep `#6B7280` only on white cards | [SIDE FIX — safe to defer] | none |
| R1 | Kabyle on Material uses French fallback strings (menus, date picker) | Acceptable for Kabyle readers in Algeria; the full documented path is a custom localization | Revisit if users complain | — | — |
| R2 | Algerian data-protection law (18-07) for stored phone numbers | Applies before real users exist | Review before M5 with the hosted project | [NEEDED for the plan — before M5] | hours |

## Roadmap (each gets its own detailed plan here when it starts)

M2 barber profile, photos (Storage), services, wizard steps 4–5, accepted customer types incl. kids, wilaya/commune data (full list; prototype has 12) · M3 live status + queue (Realtime) · M4 map + near-me, workplace pick · M5 bookings, reminders, −15 min auto-cancel (pg_cron) → **first store release** (wallet off) · M6 follow, broadcasts, discounts, reviews · M7 salons + join requests · M8 home visits · M9 finance · M10 wallet, store purchases, rewarded ads (free month starts here) · M11 QR + deep links · M12 push polish.

## Gate log

| Commit | lint | typecheck | flutter test | supabase test db | integration | Notes |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | T2 surface brief: `.impeccable/surfaces/flutter-app-lib.md` |

## Plan review (2026-11-14, LLM council) — what changed

- **SQL contract:** NULL-safe business-name check; `revoke execute … from public, anon` on every function with an `anon` test for each; `acts_as()` added (spec §5); `space_required`; unconfirmed-user test helper; tests for `current_space()` null and column grants; the redundant `pro_space` trigger removed.
- **Spike first:** a curl spike settles SMS-provider need, the duplicate-number signal and wrong-code errors before Task 5 maps them.
- **Redirect:** `/auth/reset` exempt; an offline account error goes to a retry view, never the wizard; free back navigation inside the wizard; a resumed verified sign-up skips `signUp`.
- **Toolchain:** `scripts/sdk` instead of the broken fvm stub; `.fvmrc` before `flutter create`; ports 553xx (another stack holds 543xx); pgTAP setup file with its own plan; lint covers only existing dirs; generated l10n git-ignored.
- **Fences:** theme wiring in `app.dart` (Task 2); router edits in Tasks 7–8; `pubspec.lock` everywhere; iOS plist/pbxproj in Task 9; widget keys defined in Tasks 7–8 for Task 10.
- **Spec conflicts found:** muted grey fails AA (D6); the "Gratuit 1 mois" badge would promise the free month at sign-up (removed; M10).
- **Inputs:** Eastern Arabic digits in phone and code fields; stale session cleared in the integration test; RLS denial checked from the real client.
- **Declined as scope creep:** a `pro_profiles` table now (M2/M7 own those entities), country-parameterized phone parser, golden-matrix helper, `seed.sql`, deep-link `from`, server-side `profiles.locale`, migration rollback tooling.

---

`/goal every task in task_plan.md is checked off per its own "Done when", and npm run lint, npm run typecheck, npm test and scripts/integration.sh all pass`
