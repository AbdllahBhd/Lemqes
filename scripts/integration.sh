#!/usr/bin/env sh
# Runs the app's integration paths on Linux desktop against the local stack.
# Resets the local database before each file so every file starts from the
# seed (they sign up with test_otp numbers that must still be free); the live
# files also get supabase/fixtures/live_seed.sql, the map file
# supabase/fixtures/map_seed.sql.
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

# realtime.send inserts into today's realtime.messages partition and drops the
# message silently when it is missing (spike f: the reset creates it). Dates
# are the partition's own (UTC).
wait_for_partition() {
  part="messages_$(date -u +%Y_%m_%d)"
  tries=0
  until [ "$(docker exec supabase_db_lemqes psql -U postgres -Atc \
    "select to_regclass('realtime.$part') is not null")" = "t" ]; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
      echo "integration: realtime.$part missing 60 s after the reset" >&2
      exit 1
    fi
    sleep 1
  done
}

env_arg="$(cd "$(dirname "$env_file")" && pwd)/$(basename "$env_file")"
for file in auth_flow_test.dart pro_profile_flow_test.dart \
  live_queue_customer_test.dart live_queue_barber_test.dart \
  place_pro_test.dart map_customer_test.dart; do
  supabase db reset
  wait_for_auth
  case "$file" in
    live_*) seed=supabase/fixtures/live_seed.sql ;;
    map_*) seed=supabase/fixtures/map_seed.sql ;;
    *) seed= ;;
  esac
  if [ -n "$seed" ]; then
    docker exec -i supabase_db_lemqes psql -U postgres -v ON_ERROR_STOP=1 -q \
      < "$seed"
    wait_for_partition
  fi
  scripts/sdk flutter test "integration_test/$file" -d linux \
    --dart-define-from-file="$env_arg"
done
