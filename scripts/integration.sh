#!/usr/bin/env sh
# Runs the app's integration paths on Linux desktop against the local stack.
# Resets the local database before each file so every file starts from the
# seed (both sign up with test_otp numbers that must still be free).
#
# LEMQES_ENV overrides the app env file (default flutter_app/env/local.json).
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

env_file="${LEMQES_ENV:-flutter_app/env/local.json}"
if [ ! -f "$env_file" ]; then
  echo "integration: $env_file not found" >&2
  exit 1
fi

# The run resets a database and signs up test accounts: never against a
# hosted project. Only the host is read and printed, never the keys.
url="$(jq -r '.SUPABASE_URL // empty' "$env_file")"
host="$(printf '%s' "$url" | sed -E 's#^[a-zA-Z]+://([^/:]+).*#\1#')"
case "$host" in
  127.0.0.1 | localhost) ;;
  *)
    echo "integration: SUPABASE_URL host '$host' is not the local stack" >&2
    exit 1
    ;;
esac
anon_key="$(jq -r '.SUPABASE_ANON_KEY // empty' "$env_file")"

# `supabase db reset` restarts the stack's containers; auth may answer a few
# seconds after it returns.
wait_for_auth() {
  tries=0
  until curl -fsS -o /dev/null -H "apikey: $anon_key" "$url/auth/v1/health"; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
      echo "integration: auth did not answer after the reset" >&2
      exit 1
    fi
    sleep 1
  done
}

env_arg="$(cd "$(dirname "$env_file")" && pwd)/$(basename "$env_file")"
for file in auth_flow_test.dart pro_profile_flow_test.dart; do
  supabase db reset
  wait_for_auth
  scripts/sdk flutter test "integration_test/$file" -d linux \
    --dart-define-from-file="$env_arg"
done
