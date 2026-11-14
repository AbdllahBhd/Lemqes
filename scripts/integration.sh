#!/usr/bin/env sh
# Runs the app's integration paths on Linux desktop against the local stack.
# Resets the local database before each file so every file starts from the
# seed (both sign up with test_otp numbers that must still be free).
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

for file in auth_flow_test.dart pro_profile_flow_test.dart; do
  supabase db reset
  scripts/sdk flutter test "integration_test/$file" -d linux \
    --dart-define-from-file=env/local.json
done
