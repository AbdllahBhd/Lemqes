begin;
select plan(62);

-- Calendar used below (Africa/Algiers, UTC+1, no DST): 2026-11-23 is a Monday, 11-24 a Tuesday,
-- 11-25 a Wednesday, 11-26 a Thursday. tests.create_pro gives Monday 09:00-18:00;
-- tests.set_hours overrides single weekdays.
do $$
begin
  perform set_config('t.a', tests.create_account('213550000700', 'men', 'barber', 'Amine')::text, true);
  perform set_config('t.b', tests.create_account('213550000701', 'men', 'barber', 'Bilal')::text, true);
  perform set_config('t.c', tests.create_account('213550000702', 'men', 'customer')::text, true);
  perform set_config('t.pa', tests.create_pro(current_setting('t.a')::uuid, 'barber', 'Salon Amine')::text, true);
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Salon Bilal')::text, true);
  perform tests.set_hours(current_setting('t.pa')::uuid, 1, '09:00', '19:00');
  perform tests.set_hours(current_setting('t.pa')::uuid, 2, '14:00', '01:00');
end;
$$;

-- Contract ----------------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('pro_live_create', 'pro_shift_end', 'set_live_status', 'extend_auto_close',
                      'live_touch', 'live_broadcast', 'live_auto_close', 'live_request_seen')
      and prosecdef
      and proconfig @> array['search_path=""']),
  8,
  'the 8 new definer functions are security definer with search_path = '''''
);
select is(
  (select count(*)::int from pg_class
    where oid in ('public.pro_live'::regclass, 'public.queue_requests'::regclass)
      and relrowsecurity),
  2,
  'RLS is enabled on pro_live and queue_requests'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('live_now', 'service_day', 'pro_live_create', 'pro_shift_end',
                      'set_live_status', 'extend_auto_close', 'live_touch', 'live_broadcast',
                      'live_auto_close', 'live_effective', 'live_request_seen')
      and (has_function_privilege('anon', oid, 'execute')
           or has_function_privilege('public', oid, 'execute'))),
  0,
  'no new function is executable by anon or public'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('pro_live_create', 'pro_shift_end', 'live_touch', 'live_broadcast',
                      'live_auto_close', 'live_request_seen')
      and has_function_privilege('authenticated', oid, 'execute')),
  0,
  'internal helpers and the trigger function are not executable by authenticated'
);

-- S1 ------------------------------------------------------------------------------------------
-- No pro exists when the migration runs on a fresh reset, so the backfill is pinned as the
-- invariant it establishes: every pro_profiles row has its pro_live row.
select ok(
  exists (select 1 from public.pro_live l
           where l.pro_id = current_setting('t.pa')::uuid and l.status = 'closed'
             and l.queue_mode = 'open' and not l.hide_queue_count and l.avg_service_min = 20
             and l.queue_version = 0 and l.auto_close_at is null and l.break_until is null),
  'S1 a new pro gets a closed pro_live row with the defaults'
);
select is(
  (select count(*)::int from public.pro_profiles p
    where not exists (select 1 from public.pro_live l where l.pro_id = p.id)),
  0,
  'S1 every pro (existing ones through the backfill) has a pro_live row'
);

-- S2 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is((select count(*)::int from public.pro_live), 0, 'S2 a customer selects no pro_live row');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(pro_id) from public.pro_live),
  array[current_setting('t.pa')::uuid],
  'S2 an owner selects only the own pro_live row'
);

-- S3 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  format($$ select public.set_live_status(%L, 'open', null, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'S3 another owner cannot set the status'
);
select throws_ok(
  format($$ select public.extend_auto_close(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'S3 another owner cannot extend the auto-close'
);

-- S4 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select tests.freeze_now('2026-11-23 09:00+01');
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                                    gen_random_uuid())),
  '2026-11-23 19:30+01'::timestamptz,
  'S4 open at 09:00 on a 09:00-19:00 day closes at 19:30'
);
select ok(
  (select status = 'open' and status_changed_at = '2026-11-23 09:00+01'
          and last_activity_at = '2026-11-23 09:00+01'
     from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  'S4 the row is open with status_changed_at and last_activity_at at now'
);
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'closed', null,
                                                    gen_random_uuid())),
  null,
  'S4 closing clears auto_close_at'
);

-- S5 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-24 15:00+01');
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                                    gen_random_uuid())),
  '2026-11-25 01:30+01'::timestamptz,
  'S5 open at 15:00 on a 14:00-01:00 day closes at 01:30 the next day'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());

-- S6 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-25 00:30+01');
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                                    gen_random_uuid())),
  '2026-11-25 01:30+01'::timestamptz,
  'S6 open at 00:30 inside yesterday''s 14:00-01:00 shift closes at 01:30 today'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());

-- S7 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 08:30+01');
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                                    gen_random_uuid())),
  '2026-11-23 19:30+01'::timestamptz,
  'S7 open at 08:30 before a 09:00 opening closes at 19:30'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());

-- S8 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-26 10:00+01');
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                                    gen_random_uuid())),
  '2026-11-26 13:30+01'::timestamptz,
  'S8 open on a closed weekday closes at now + 3 h 30'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());
select tests.freeze_now('2026-11-23 20:00+01');
select is(
  (select auto_close_at from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                                    gen_random_uuid())),
  '2026-11-23 23:30+01'::timestamptz,
  'S8 open after the day''s closing time also closes at now + 3 h 30'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());

-- S9 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 09:00+01');
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null, gen_random_uuid());
select is(
  public.extend_auto_close(current_setting('t.pa')::uuid, gen_random_uuid()),
  '2026-11-23 20:30+01'::timestamptz,
  'S9 extend adds 60 minutes'
);
select is(
  (select auto_close_at from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  '2026-11-23 20:30+01'::timestamptz,
  'S9 the extension is stored'
);
-- 20:30 + 60 min = 21:30, past now + 12 h = 21:00.
select is(
  public.extend_auto_close(current_setting('t.pa')::uuid, gen_random_uuid()),
  '2026-11-23 21:00+01'::timestamptz,
  'S9 extend never goes past now + 12 h'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());
-- A long shift can already close more than 12 h ahead: Wednesday 09:00-23:00 opened at 09:00
-- closes at 23:30 (14 h 30 away); extending must never bring that earlier.
select tests.set_hours(current_setting('t.pa')::uuid, 3, '09:00', '23:00');
select tests.freeze_now('2026-11-25 09:00+01');
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null, gen_random_uuid());
select is(
  public.extend_auto_close(current_setting('t.pa')::uuid, gen_random_uuid()),
  '2026-11-25 23:30+01'::timestamptz,
  'S9 extend past the 12 h cap keeps a later auto_close_at unchanged (never earlier)'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());
select tests.freeze_now('2026-11-23 09:00+01');

-- S10 -----------------------------------------------------------------------------------------
select throws_ok(
  format($$ select public.extend_auto_close(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_open', 'S10 extend on a closed row raises not_open'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null, gen_random_uuid());
select tests.freeze_now('2026-11-23 19:31+01');
select throws_ok(
  format($$ select public.extend_auto_close(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_open', 'S10 extend after auto_close_at passed (row still says open) raises not_open'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());

-- S11 -----------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 10:00+01');
select throws_ok(
  format($$ select public.set_live_status(%L, 'on_break', '2026-11-23 09:59+01', gen_random_uuid()) $$,
         current_setting('t.pa')),
  'P0001', 'invalid_break_until', 'S11 a past break_until is refused'
);
select throws_ok(
  format($$ select public.set_live_status(%L, 'on_break', '2026-11-23 14:01+01', gen_random_uuid()) $$,
         current_setting('t.pa')),
  'P0001', 'invalid_break_until', 'S11 a break_until more than 4 h away is refused'
);
select throws_ok(
  format($$ select public.set_live_status(%L, 'open', '2026-11-23 10:30+01', gen_random_uuid()) $$,
         current_setting('t.pa')),
  'P0001', 'invalid_break_until', 'S11 break_until with a status other than on_break is refused'
);
select ok(
  (select status = 'on_break' and break_until is null
     from public.set_live_status(current_setting('t.pa')::uuid, 'on_break', null, gen_random_uuid())),
  'S11 on_break without a return time is accepted'
);
select is(
  (select break_until from public.set_live_status(current_setting('t.pa')::uuid, 'on_break',
                                                  '2026-11-23 14:00+01', gen_random_uuid())),
  '2026-11-23 14:00+01'::timestamptz,
  'S11 a break_until exactly 4 h away is accepted'
);
select ok(
  (select status = 'open' and break_until is null
     from public.set_live_status(current_setting('t.pa')::uuid, 'open', null, gen_random_uuid())),
  'S11 back to open clears break_until'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'closed', null, gen_random_uuid());

-- S12 -----------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 09:00+01');
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null, gen_random_uuid());
select is(
  (select e.status from public.pro_live l, public.live_effective(l) e
    where l.pro_id = current_setting('t.pa')::uuid),
  'open'::public.live_status,
  'S12 effective status is open before auto_close_at'
);
select tests.freeze_now('2026-11-23 19:30+01');
select ok(
  (select e.status = 'closed' and not e.stale and l.status = 'open'
     from public.pro_live l, public.live_effective(l) e
    where l.pro_id = current_setting('t.pa')::uuid),
  'S12 effective status is closed once auto_close_at passed while the row still says open'
);

-- S13 -----------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 10:59+01');
select is(
  (select e.stale from public.pro_live l, public.live_effective(l) e
    where l.pro_id = current_setting('t.pa')::uuid),
  false,
  'S13 not stale 1 h 59 after the last activity'
);
select tests.freeze_now('2026-11-23 11:00+01');
select ok(
  (select e.stale and e.status = 'open' from public.pro_live l, public.live_effective(l) e
    where l.pro_id = current_setting('t.pa')::uuid),
  'S13 stale 2 h 00 after the last activity'
);
select public.set_live_status(current_setting('t.pa')::uuid, 'on_break', null, gen_random_uuid());
select is(
  (select e.stale from public.pro_live l, public.live_effective(l) e
    where l.pro_id = current_setting('t.pa')::uuid),
  false,
  'S13 a status change clears stale'
);

-- S14 -----------------------------------------------------------------------------------------
-- PA open until 19:30, PB open until 21:00; at 19:30 only PA is expired.
do $$
begin
  perform tests.clear_auth();
  perform tests.freeze_now('2026-11-23 09:00+01');
  update public.pro_live
     set status = 'open', break_until = null, auto_close_at = '2026-11-23 19:30+01'
   where pro_id = current_setting('t.pa')::uuid;
  update public.pro_live
     set status = 'on_break', auto_close_at = '2026-11-23 21:00+01'
   where pro_id = current_setting('t.pb')::uuid;
  perform tests.freeze_now('2026-11-23 19:30+01');
end;
$$;
select is(public.live_auto_close(), 1, 'S14 live_auto_close closes one expired row and returns 1');
select ok(
  (select status = 'closed' and auto_close_at is null and break_until is null
          and status_changed_at = '2026-11-23 19:30+01'
     from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  'S14 the expired row is closed'
);
select is(
  (select status from public.pro_live where pro_id = current_setting('t.pb')::uuid),
  'on_break'::public.live_status,
  'S14 the unexpired row is untouched'
);
select is(public.live_auto_close(), 0, 'S14 a second run closes nothing');

-- S15 -----------------------------------------------------------------------------------------
select is(
  (select schedule || '|' || command || '|' || active::text
     from cron.job where jobname = 'lemqes_live_auto_close'),
  '* * * * *|select public.live_auto_close()|true',
  'S15 the auto-close job runs every minute and is active'
);
select lives_ok(
  (select command from cron.job where jobname = 'lemqes_live_auto_close'),
  'S15 the job command runs'
);

-- S16 -----------------------------------------------------------------------------------------
select is(
  public.service_day('2026-11-24 01:00+01', 'Africa/Algiers'),
  '2026-11-23'::date,
  'S16 01:00 belongs to the previous service day'
);
select is(
  public.service_day('2026-11-24 06:31+01', 'Africa/Algiers'),
  '2026-11-24'::date,
  'S16 06:31 belongs to the same service day'
);

-- S17 -----------------------------------------------------------------------------------------
do $$
begin
  perform tests.freeze_now('2026-11-23 09:00+01');
  perform set_config('t.req', gen_random_uuid()::text, true);
  perform tests.authenticate_as(current_setting('t.a')::uuid);
end;
$$;
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null, current_setting('t.req')::uuid);
select tests.freeze_now('2026-11-23 09:05+01');
select ok(
  (select status = 'open' and status_changed_at = '2026-11-23 09:00+01'
          and last_activity_at = '2026-11-23 09:00+01'
     from public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                                 current_setting('t.req')::uuid)),
  'S17 the same set_live_status request twice changes nothing the second time'
);
select set_config('t.ext', gen_random_uuid()::text, true);
select public.extend_auto_close(current_setting('t.pa')::uuid, current_setting('t.ext')::uuid);
select is(
  public.extend_auto_close(current_setting('t.pa')::uuid, current_setting('t.ext')::uuid),
  '2026-11-23 20:30+01'::timestamptz,
  'S17 the same extend request twice extends once'
);
select throws_ok(
  format($$ select public.set_live_status(%L, 'closed', null, %L) $$,
         current_setting('t.pa'), current_setting('t.ext')),
  'P0001', 'request_reused', 'S17 a request id reused for another action raises request_reused'
);
select throws_ok(
  format($$ select public.set_live_status(%L, 'closed', null, null) $$, current_setting('t.pa')),
  'P0001', 'request_id_required', 'S17 a null request id is refused'
);
select is(
  (select status from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  'open'::public.live_status,
  'S17 the reused request left the row open'
);

-- S18 -----------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok(
  format($$ select public.set_live_status(%L, 'open', null, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'S18 anon cannot call set_live_status'
);
select throws_ok(
  format($$ select public.extend_auto_close(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'S18 anon cannot call extend_auto_close'
);
select throws_ok(
  $$ select public.live_effective(null::public.pro_live) $$,
  '42501', null, 'S18 anon cannot call live_effective'
);
select throws_ok(
  $$ select public.service_day(now(), 'Africa/Algiers') $$,
  '42501', null, 'S18 anon cannot call service_day'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  format($$ select public.live_touch(%L) $$, current_setting('t.pa')),
  '42501', null, 'S18 authenticated cannot call live_touch'
);
select throws_ok(
  format($$ select public.pro_shift_end(%L, now()) $$, current_setting('t.pa')),
  '42501', null, 'S18 authenticated cannot call pro_shift_end'
);
select throws_ok(
  format($$ select public.live_broadcast(%L) $$, current_setting('t.pa')),
  '42501', null, 'S18 authenticated cannot call live_broadcast'
);
select throws_ok(
  $$ select public.live_auto_close() $$,
  '42501', null, 'S18 authenticated cannot call live_auto_close'
);
select throws_ok(
  format($$ select public.live_request_seen(%L, gen_random_uuid(), 'x', %L) $$,
         current_setting('t.a'), current_setting('t.pa')),
  '42501', null, 'S18 authenticated cannot call live_request_seen'
);
select throws_ok(
  $$ select count(*) from public.queue_requests $$,
  '42501', null, 'S18 authenticated cannot read queue_requests'
);

-- S19 -----------------------------------------------------------------------------------------
select throws_ok(
  format($$ update public.pro_live set status = 'open' where pro_id = %L $$, current_setting('t.pa')),
  '42501', null, 'S19 the owner cannot update pro_live directly'
);
select throws_ok(
  format($$ insert into public.pro_live (pro_id) values (%L) $$, current_setting('t.pa')),
  '42501', null, 'S19 a client cannot insert into pro_live'
);
select throws_ok(
  format($$ delete from public.pro_live where pro_id = %L $$, current_setting('t.pa')),
  '42501', null, 'S19 a client cannot delete from pro_live'
);

-- live_broadcast stub: bumps queue_version only when asked (Task 3 adds realtime.send).
do $$ begin perform tests.clear_auth(); end; $$;
select public.live_broadcast(current_setting('t.pa')::uuid);
select public.live_broadcast(current_setting('t.pa')::uuid, true);
select is(
  (select queue_version from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  1::bigint,
  'live_broadcast bumps queue_version only when the queue changed'
);

select * from finish();
rollback;
