#!/usr/bin/env sh
# Runs the app's integration path on Linux desktop against the local stack.
# Resets the local database first so every run starts from the seed.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

supabase db reset
scripts/sdk flutter test integration_test/auth_flow_test.dart -d linux \
  --dart-define-from-file=env/local.json
