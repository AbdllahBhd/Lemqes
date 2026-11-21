#!/bin/sh
# Two devices tap "call next" at the same moment: proves the pro_live row lock serializes them.
# pgTAP runs in one session and cannot show this, so two psql sessions race here, ROUNDS times:
# each opens a transaction, calls queue_call_next as the owner (distinct request ids), then holds
# the transaction for HOLD seconds, so the other session's call must wait on the lock.
#
# Each round passes only when both sessions succeed, the queue ends with exactly one serving
# row, exactly one more served row and one waiting row (two distinct people were called), and
# one session demonstrably waited (the calls overlapped). Exits non-zero on any failure.
#
# Needs the local stack (supabase start) with migrations applied. psql runs inside the
# supabase_db_lemqes container (no host psql). Seeds its own owner and pro, removes them on exit.
#
#   sh supabase/tests/race/call_next_race.sh

set -u

DB_CONTAINER=supabase_db_lemqes
ROUNDS=20
HOLD=1
OWNER=00000000-0000-4000-8000-00000000ace1
PRO=00000000-0000-4000-8000-00000000ace2
TMP=$(mktemp -d)

db() {
  docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -At "$@"
}

cleanup() {
  printf "delete from auth.users where id = '%s';\n" "$OWNER" | db >/dev/null 2>&1
  rm -rf "$TMP"
}
trap cleanup EXIT

# Deleting the auth user cascades to the profile, the pro and its queue (the history trigger
# allows a delete only through that cascade).
db >/dev/null <<SQL || { echo "call_next_race: FAIL (seeding)"; exit 1; }
delete from auth.users where id = '$OWNER';
insert into auth.users (id, aud, role, phone, phone_confirmed_at)
values ('$OWNER', 'authenticated', 'authenticated', '213550009990', now());
insert into public.profiles (id, full_name, pro_space, customer_space, active_role)
values ('$OWNER', 'Race Owner', 'men', 'men', 'barber');
insert into public.profile_roles (profile_id, role) values ('$OWNER', 'customer'), ('$OWNER', 'barber');
insert into public.pro_profiles (id, owner_id, kind, space, display_name, workplace_type,
                                 locality_id, customer_mix)
values ('$PRO', '$OWNER', 'barber', 'men', 'Race Salon', 'salon', 1601, 'adults');
SQL

as_owner="set local role authenticated;
select set_config('request.jwt.claims', '{\"sub\":\"$OWNER\",\"role\":\"authenticated\"}', true);"

counts() {
  db <<SQL
select count(*) filter (where state = 'serving') || ' '
    || count(*) filter (where state = 'served') || ' '
    || count(*) filter (where state = 'waiting')
from public.queue_entries where pro_id = '$PRO';
SQL
}

# Prints "waited=<seconds>" for the queue_call_next call only.
call_next() {
  db <<SQL
begin;
\o /dev/null
$as_owner
select clock_timestamp() as t0 \gset
select count(*) from public.queue_call_next('$PRO', gen_random_uuid());
\o
select 'waited=' || round(extract(epoch from clock_timestamp() - :'t0'::timestamptz)::numeric, 2);
select pg_sleep($HOLD) \g /dev/null
commit;
SQL
}

failures=0
overlaps=0
round=1
while [ "$round" -le "$ROUNDS" ]; do
  # Fresh queue: end whatever is active, then the owner adds 3 walk-ins.
  db >/dev/null <<SQL || { echo "call_next_race: FAIL (reseed, round $round)"; exit 1; }
update public.queue_entries
   set state = 'cancelled', end_reason = 'cleared', ended_at = now()
 where pro_id = '$PRO' and state in ('waiting', 'serving');
begin;
$as_owner
select count(*) from public.queue_add_walk_in('$PRO', gen_random_uuid());
select count(*) from public.queue_add_walk_in('$PRO', gen_random_uuid());
select count(*) from public.queue_add_walk_in('$PRO', gen_random_uuid());
commit;
SQL
  before=$(counts)
  served_before=$(echo "$before" | cut -d' ' -f2)

  call_next >"$TMP/a.out" 2>&1 &
  pid_a=$!
  call_next >"$TMP/b.out" 2>&1 &
  pid_b=$!
  wait "$pid_a"; status_a=$?
  wait "$pid_b"; status_b=$?

  after=$(counts)
  serving=$(echo "$after" | cut -d' ' -f1)
  served=$(echo "$after" | cut -d' ' -f2)
  waiting=$(echo "$after" | cut -d' ' -f3)
  wait_a=$(sed -n 's/^waited=//p' "$TMP/a.out")
  wait_b=$(sed -n 's/^waited=//p' "$TMP/b.out")
  # The second session waited for the first one's HOLD: at least half of it.
  overlapped=$(awk -v a="${wait_a:-0}" -v b="${wait_b:-0}" -v h="$HOLD" \
    'BEGIN { print ((a >= h / 2 || b >= h / 2) ? 1 : 0) }')

  problem=""
  [ "$status_a" -eq 0 ] || problem="$problem session A exited $status_a: $(tr '\n' ' ' <"$TMP/a.out");"
  [ "$status_b" -eq 0 ] || problem="$problem session B exited $status_b: $(tr '\n' ' ' <"$TMP/b.out");"
  [ "$serving" = 1 ] || problem="$problem $serving serving rows;"
  [ "$served" = $((served_before + 1)) ] || problem="$problem served went $served_before -> $served;"
  [ "$waiting" = 1 ] || problem="$problem $waiting waiting rows;"
  [ "$overlapped" = 1 ] || problem="$problem calls did not overlap (waited ${wait_a:-?}s / ${wait_b:-?}s);"

  if [ -n "$problem" ]; then
    failures=$((failures + 1))
    echo "round $round: FAIL$problem"
  else
    overlaps=$((overlaps + 1))
    echo "round $round: ok (waited ${wait_a}s / ${wait_b}s)"
  fi
  round=$((round + 1))
done

if [ "$failures" -eq 0 ]; then
  echo "call_next_race: PASS $ROUNDS/$ROUNDS rounds, one serving row and no error each time ($overlaps overlapped)"
  exit 0
fi
echo "call_next_race: FAIL $failures/$ROUNDS rounds failed"
exit 1
