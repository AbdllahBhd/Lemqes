# Project Memory (CLAUDE.md)

> This file is automatically loaded by Claude Code at the start of every session.
> Keep it short and high-signal: Claude reads it every time, so every line costs context.

## Project Overview

- **Name:** LEMQES
- **What it does:** Live status and live queue for Maghreb barbering (men's and women's spaces); Milestone 1 is phone sign-up, login, reset, roles and spaces.
- **Tech stack:** Flutter 3.47.5 (Dart, Riverpod 3, go_router) + Supabase (Postgres, GoTrue phone auth, RLS).
- **Package manager:** npm only as a task runner; Flutter/Dart only through `scripts/sdk` (pinned SDK, cds into `flutter_app/`).

## Essential Commands

```bash
npm run lint                  # gen-l10n + dart format check + flutter analyze
npm run typecheck             # gen-l10n + flutter analyze
npm test                      # flutter test + supabase test db (pgTAP)
sh scripts/integration.sh     # per integration_test file: reset the local DB, run on Linux
scripts/sdk flutter <args>    # any other Flutter/Dart command
supabase start | db reset     # local stack on ports 553xx (repo root only)
```

## Architecture Notes

- App: `flutter_app/lib/` is feature-first (`features/<name>/data` + `presentation`), shared widgets in `shared/widgets/`, cross-cutting code in `core/`.
- Business rules live in Postgres: `supabase/migrations/` (security definer RPCs, RLS); pgTAP in `supabase/tests/database/`.
- Routing is a pure function: `core/router/redirect.dart` (unit-tested), wired in `core/router/app_router.dart`.
- l10n: ARBs in `core/l10n/arb/` (ar, fr, en, kab); translation status in `core/l10n/REVIEW.md`; generated code is git-ignored.
- Visual language: `DESIGN.md` at the repo root.
- Pro profiles (M2): a `pro_profiles` row per (owner, kind) owns its `space` (never client-writable); listed only once published. Setup is `/pro/setup/{profile,services,hours}` (redirect resumes at the first gap), the pro home is the dashboard in `features/pro/presentation/dashboard/`; customers browse through `search_pros` (security invoker, caller's space) in `features/explore/`, open `/pro/:id`, read services via `pro_public_services`. Photos: Storage buckets `avatars`/`work-photos`, paths `<pro id>/<uuid>.<ext>`.
- `supabase/config.toml` carries local-only `test_otp` numbers and a dummy Twilio provider: never push them to a hosted project.
- Local secrets in `flutter_app/env/local.json` (git-ignored); never commit it.

## Rules

Detailed conventions live in `.claude/rules/` and are loaded automatically:

- @.claude/rules/code-style.md
- @.claude/rules/pr.md
- @.claude/rules/workflow.md
- @.claude/rules/delivery.md
- @.claude/rules/reporting.md

API conventions load on demand as a skill (`.claude/skills/api-conventions/`) —
only sessions that touch an API pay for them.

## Session & Context Hygiene

- When compacting this conversation, always preserve the full list of modified
  files, the current task plan status, and any test commands used.
- Unrelated new task → suggest starting a fresh session instead of continuing here.

## Hard Constraints (always follow)

- Never commit secrets, API keys, or `.env` files.
- Never push directly to `main` — always work on a feature branch.
- Run the test suite before claiming a task is complete.
- Prefer editing existing files over creating new ones.
