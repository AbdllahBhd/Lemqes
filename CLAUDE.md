# Project Memory (CLAUDE.md)

> This file is automatically loaded by Claude Code at the start of every session.
> Keep it short and high-signal: Claude reads it every time, so every line costs context.

## Project Overview

- **Name:** LEMQES
- **What it does:** Live status and live queue for Maghreb barbering (men's and women's spaces); Milestone 1 is phone sign-up, login, reset, roles and spaces.
- **Tech stack:** Flutter 3.50.0 (Dart, Riverpod 3, go_router) + Supabase (Postgres, GoTrue phone auth, RLS).
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
- Live status + queue (M3): `pro_live` (one row per pro) and `queue_entries` (history, never deleted) are written only by definer RPCs that lock `pro_live` `for update`, take a `p_request_id`, and end with exactly one `live_broadcast` (bumps `pro_live.live_version`, the client's snapshot ordering key; `realtime.send` of `live_snapshot` to the private topic `pro:<id>`; `live_topic_allowed` authorizes at join only). `can_join` is internal (only `join_queue` runs it). Client: `features/live/`; `LiveChannels` ref-counts channels, re-fetches on (re)subscribe, socket reopen and resume, and closes all on space/role/account change. Owners use `ownProLiveProvider`/`ownerQueueProvider`, customers `proLiveProvider`/`myTicketProvider`. A blocked customer reads the pro as closed (`live_snapshot(pro, viewer)` closed shape, refused channel → `LiveChannels` serves fetches only, `pro_not_open`); a hidden count leaves the recount inputs out of the snapshot (refetch on `queueChangeKey`). Integration seeds: `supabase/fixtures/live_seed.sql`.
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
