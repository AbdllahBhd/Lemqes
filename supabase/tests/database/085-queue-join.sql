begin;
select plan(114);

-- Calendar (Africa/Algiers, UTC+1, no DST): 2026-11-23 is a Monday; time starts frozen at 10:00.
-- pa (Salon Amine) is where customers join; pb (Salon Bilal) carries the J1 status fixtures and
-- the history rows the abuse limits count. Fixtures are written as postgres.
do $$
begin
  perform set_config('t.a', tests.create_account('213550000850', 'men', 'barber', 'Amine')::text, true);
  perform set_config('t.b', tests.create_account('213550000851', 'men', 'barber', 'Bilal')::text, true);
  perform set_config('t.u', tests.create_account('213550000852', 'men', 'barber', 'Unpub')::text, true);
  perform set_config('t.c', tests.create_account('213550000853', 'men', 'customer', 'Chafik')::text, true);
  perform set_config('t.d', tests.create_account('213550000854', 'men', 'customer', 'Djamel')::text, true);
  perform set_config('t.e', tests.create_account('213550000855', 'men', 'customer', 'Elias')::text, true);
  perform set_config('t.f', tests.create_account('213550000856', 'men', 'customer', 'Farid')::text, true);
  perform set_config('t.g', tests.create_account('213550000857', 'men', 'customer', 'Ghani')::text, true);
  perform set_config('t.h', tests.create_account('213550000858', 'men', 'customer', 'Hamid')::text, true);
  perform set_config('t.k', tests.create_account('213550000859', 'men', 'customer', 'Kamel')::text, true);
  perform set_config('t.m', tests.create_account('213550000860', 'men', 'customer', 'Mourad')::text, true);
  perform set_config('t.n', tests.create_account('213550000861', 'men', 'customer', 'Nabil')::text, true);
  perform set_config('t.w', tests.create_account('213550000862', 'women', 'customer', 'Wafa')::text, true);
  perform set_config('t.x', tests.create_account('213550000863', 'men', 'customer', 'Xavier')::text, true);
  perform set_config('t.y', tests.create_account('213550000864', 'men', 'customer', 'Yacine')::text, true);
  perform set_config('t.q', tests.create_account('213550000865', 'men', 'customer', 'Qasim')::text, true);
  perform set_config('t.pa', tests.create_pro(current_setting('t.a')::uuid, 'barber', 'Salon Amine')::text, true);
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Salon Bilal')::text, true);
  perform set_config('t.pu', tests.create_pro(current_setting('t.u')::uuid, 'barber', 'Hidden', published => false)::text, true);
  perform set_config('t.s30', (select id from public.pro_services
                                where pro_id = current_setting('t.pa')::uuid)::text, true);
  perform set_config('t.sb', (select id from public.pro_services
                               where pro_id = current_setting('t.pb')::uuid)::text, true);
end;
$$;
insert into public.pro_services (pro_id, name, category, price_dzd, duration_min, active)
values (current_setting('t.pa')::uuid, 'Inactive', 'hair', 100, 15, false);
do $$
begin
  perform set_config('t.sin', (select id from public.pro_services
                                where pro_id = current_setting('t.pa')::uuid and name = 'Inactive')::text, true);
end;
$$;
-- can_join is internal (only join_queue runs it): the J1 codes are read through this wrapper,
-- which runs it as postgres with the caller's jwt claims (auth.uid()) still set.
create function tests.can_join(p_pro_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.can_join(p_pro_id);
end;
$$;
select tests.freeze_now('2026-11-23 10:00+01');
update public.pro_live
   set status = 'open', auto_close_at = '2026-11-23 19:30+01',
       last_activity_at = '2026-11-23 10:00+01', status_changed_at = '2026-11-23 10:00+01'
 where pro_id in (current_setting('t.pa')::uuid, current_setting('t.pb')::uuid,
                  current_setting('t.pu')::uuid);

-- Contract ------------------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('can_join', 'join_queue', 'queue_on_my_way', 'leave_queue', 'my_ticket',
                      'set_queue_settings', 'queue_block', 'queue_blocked', 'queue_unblock',
                      'queue_ticket')
      and prosecdef
      and proconfig @> array['search_path=""']),
  10,
  'the 10 new functions are security definer with search_path = '''''
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('can_join', 'join_queue', 'queue_on_my_way', 'leave_queue', 'my_ticket',
                      'set_queue_settings', 'queue_block', 'queue_blocked', 'queue_unblock',
                      'queue_ticket')
      and (has_function_privilege('anon', oid, 'execute')
           or has_function_privilege('public', oid, 'execute'))),
  0,
  'no new function is executable by anon or public'
);
select ok(
  not has_function_privilege('authenticated', 'public.queue_ticket(uuid)', 'execute'),
  'the internal queue_ticket is not executable by authenticated'
);
select ok(
  not has_function_privilege('authenticated', 'public.can_join(uuid)', 'execute'),
  'can_join is internal: authenticated cannot probe the join rules (join_queue runs them)'
);
select ok(
  coalesce((select prosecdef and proconfig @> array['search_path=""']
                   and not has_function_privilege('authenticated', oid, 'execute')
                   and not has_function_privilege('anon', oid, 'execute')
                   and not has_function_privilege('public', oid, 'execute')
              from pg_proc where oid = to_regprocedure('public.join_customer_check(uuid)')), false),
  'join_customer_check is an internal security definer with search_path = '''''
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.pro_blocks'::regclass)
  and not has_table_privilege('authenticated', 'public.pro_blocks', 'select')
  and not has_table_privilege('authenticated', 'public.pro_blocks', 'insert')
  and not has_table_privilege('anon', 'public.pro_blocks', 'select'),
  'pro_blocks has RLS and no client privilege (owners read it through queue_blocked)'
);

-- J1 ------------------------------------------------------------------------------------------
-- Each can_join code in isolation: every earlier check passes, only the named one fails.
do $$ begin perform tests.authenticate_as(current_setting('t.w')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'not_listable', 'J1 not_listable: a customer of the other space');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pu')),
  'P0001', 'not_listable', 'J1 not_listable: an unpublished pro');
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'not_listable', 'J1 not_listable: a caller acting as barber');

do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'customer' where id = current_setting('t.a')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'own_queue', 'J1 own_queue: the owner acting as customer in their own space');
do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'barber' where id = current_setting('t.a')::uuid;

update public.pro_live set status = 'closed', auto_close_at = null
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: closed');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'open', auto_close_at = '2026-11-23 09:59+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: effective-closed (auto_close_at passed, row says open)');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set auto_close_at = '2026-11-23 19:30+01', last_activity_at = '2026-11-23 08:00+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: stale (no owner activity for 2 h)');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'on_break', last_activity_at = '2026-11-23 10:00+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: on break without a return time');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set break_until = '2026-11-23 10:30+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'J1 on break before its return time: joining is allowed');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set queue_mode = 'paused' where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'queue_paused', 'J1 queue_paused: on break before its return time, mode paused');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set break_until = '2026-11-23 10:00+01', queue_mode = 'open'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: on break past its return time (Pause prolongée)');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'open', break_until = null, queue_mode = 'paused'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'queue_paused', 'J1 queue_paused: mode paused');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set queue_mode = 'followers' where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'queue_paused', 'J1 queue_paused: mode followers');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set queue_mode = 'open' where pro_id = current_setting('t.pb')::uuid;

-- c waits at pb: joining pa is refused.
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, customer_id)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 950, '2026-11-23', 'remote',
        current_setting('t.c')::uuid);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'already_in_queue', 'J1 already_in_queue: an active entry at another pro');
do $$ begin perform tests.clear_auth(); end; $$;
update public.queue_entries set state = 'cancelled', end_reason = 'left', ended_at = '2026-11-23 10:00+01'
 where pro_id = current_setting('t.pb')::uuid and ticket_no = 950;

-- e joined 4 times today (all ended) and once yesterday: a 5th today is allowed, a 6th is not.
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, customer_id, state, end_reason, ended_at)
select current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, t, d::date, 'remote',
       current_setting('t.e')::uuid, 'cancelled', 'left', '2026-11-23 09:00+01'
from (values (901, '2026-11-23'), (902, '2026-11-23'), (903, '2026-11-23'), (904, '2026-11-23'),
             (901, '2026-11-22')) v(t, d);
do $$ begin perform tests.authenticate_as(current_setting('t.e')::uuid); end; $$;
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'J1 join_limit_reached: 4 joins today (+ 1 yesterday) still allow a 5th');
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, customer_id, state, end_reason, ended_at)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 905, '2026-11-23', 'remote',
        current_setting('t.e')::uuid, 'cancelled', 'left', '2026-11-23 09:00+01');
do $$ begin perform tests.authenticate_as(current_setting('t.e')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'join_limit_reached', 'J1 join_limit_reached: the 6th remote join of the service day');

-- Absents (ended_at, called 10 min before): d 20th 12:00 + 22nd 10:30 (blocked until 23rd
-- 10:30); f 20th 12:00 + 22nd 09:59 (lifted at 23rd 09:59); g 14th 10:00 + 22nd 12:00 (8 days
-- apart, never blocked); q like d but never called (stored before marking required a call).
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, customer_id, state, called_at, ended_at)
select current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, t, d::date, 'remote',
       current_setting(c)::uuid, 'absent',
       case when called then at::timestamptz - interval '10 minutes' end, at::timestamptz
from (values (910, '2026-11-20', 't.d', '2026-11-20 12:00+01', true),
             (911, '2026-11-22', 't.d', '2026-11-22 10:30+01', true),
             (912, '2026-11-20', 't.f', '2026-11-20 12:00+01', true),
             (913, '2026-11-22', 't.f', '2026-11-22 09:59+01', true),
             (914, '2026-11-14', 't.g', '2026-11-14 10:00+01', true),
             (915, '2026-11-22', 't.g', '2026-11-22 12:00+01', true),
             (916, '2026-11-20', 't.q', '2026-11-20 12:00+01', false),
             (917, '2026-11-22', 't.q', '2026-11-22 10:30+01', false)) v(t, d, c, at, called);
do $$ begin perform tests.authenticate_as(current_setting('t.d')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'absent_block', 'J1 absent_block: 2 absents within 7 days, less than 24 h after the 2nd');
do $$ begin perform tests.authenticate_as(current_setting('t.f')::uuid); end; $$;
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'J1 absent_block: lifted 24 h after the 2nd absent');
do $$ begin perform tests.authenticate_as(current_setting('t.g')::uuid); end; $$;
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'J1 absent_block: 2 absents more than 7 days apart do not block');
do $$ begin perform tests.authenticate_as(current_setting('t.q')::uuid); end; $$;
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'J1 absent_block: only absents marked after a call count');

do $$ begin perform tests.clear_auth(); end; $$;
insert into public.pro_blocks (pro_id, customer_id, ticket_label)
values (current_setting('t.pa')::uuid, current_setting('t.h')::uuid, 'Hamid');
do $$ begin perform tests.authenticate_as(current_setting('t.h')::uuid); end; $$;
select is(tests.error_detail(format($$ select tests.can_join(%L) $$, current_setting('t.pa'))),
  'pro_not_open|', 'J1 blocked by this pro: pro_not_open, exactly a closed pro''s refusal (no detail)');
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pb')),
  'J1 a block at pa does not refuse pb');

-- J2 ------------------------------------------------------------------------------------------
-- W1, W2 walk-ins at 10:00; c joins at 10:05 with the 30-min service; W3 at 10:06.
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid());
select count(*) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid());
select tests.freeze_now('2026-11-23 10:05+01');
do $$ begin perform tests.clear_auth(); end; $$;
do $$
begin
  perform set_config('t.v0', (select queue_version from public.pro_live
                               where pro_id = current_setting('t.pa')::uuid)::text, true);
end;
$$;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
create temp table j2 on commit drop as
select * from public.join_queue(current_setting('t.pa')::uuid, current_setting('t.s30')::uuid,
                                gen_random_uuid());
select ok(
  (select ticket_no = 3 and state = 'waiting' and position = 3 and wait_min = 40
          and pro_space = 'men' and display_name = 'Salon Amine' and end_reason is null
     from j2),
  'J2 join returns ticket 3, position 3 behind two walk-ins, wait 40 (2 x average 20), the pro'
);
select is((select to_jsonb(j) -> 'ahead_minutes' from j2 j), '40'::jsonb,
  'J2 the ticket carries ahead_minutes (W1 + W2) for the app to recount the wait');
do $$ begin perform set_config('t.ec', (select entry_id from j2)::text, true); end; $$;
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select queue_version > current_setting('t.v0')::bigint
          and last_activity_at = '2026-11-23 10:00+01'
     from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  'J2 a join bumps queue_version and does not count as owner activity'
);
select ok(
  (select position('public.can_join' in d) > 0
          and position('public.can_join' in d) < position('for update' in d)
     from pg_get_functiondef('public.join_queue(uuid, uuid, uuid)'::regprocedure) d),
  'J2 join_queue runs the full can_join before taking the pro_live lock (and again under it)'
);
select tests.freeze_now('2026-11-23 10:06+01');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid());
select is(
  (select array_agg(ticket_no::text || ':' || kind::text || ':' || coalesce(label, '-')
                    order by position)
     from public.owner_queue(current_setting('t.pa')::uuid)),
  array['1:walk_in:-', '2:walk_in:-', '3:remote:Chafik', '4:walk_in:-'],
  'J2 the remote entry sorts by sort_at among walk-ins and is labelled with the full name'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select duration_min = 30 and price_dzd = 800 and customer_id = current_setting('t.c')::uuid
          and sort_at = '2026-11-23 10:05+01'
     from public.queue_entries where id = current_setting('t.ec')::uuid),
  'J2 the service duration and price are snapshotted, sort_at is the join time'
);
select tests.freeze_now('2026-11-23 10:10+01');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_call_next(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select ok(
  (select position = 2 and wait_min = 40 from public.my_ticket()),
  'J2 after W1 is called: position 2, wait 40 (20 left of W1 + W2)'
);
select is(
  (select to_jsonb(t) -> 'ahead_minutes' from public.my_ticket() t), '20'::jsonb,
  'J2 ahead_minutes: the waiting minutes before the ticket (W2), without the chair'
);
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.join_queue(%L, %L, gen_random_uuid()) $$,
         current_setting('t.pa'), current_setting('t.sin')),
  'P0001', 'invalid_service', 'J2 an inactive service is refused');
select throws_ok(
  format($$ select * from public.join_queue(%L, %L, gen_random_uuid()) $$,
         current_setting('t.pa'), current_setting('t.sb')),
  'P0001', 'invalid_service', 'J2 another pro''s service is refused');
do $$ begin perform tests.authenticate_as(current_setting('t.w')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.join_queue(%L, null, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_listable', 'J2 join_queue runs can_join (other space refused)');
do $$ begin perform tests.authenticate_as(current_setting('t.w')::uuid); end; $$;
select is(
  (select count(*)::int from public.my_ticket()),
  0, 'J2 my_ticket is empty for a customer without a ticket'
);

-- J3 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
do $$ begin perform set_config('t.rk', gen_random_uuid()::text, true); end; $$;
do $$
begin
  perform set_config('t.ek', (select entry_id from public.join_queue(
    current_setting('t.pa')::uuid, null, current_setting('t.rk')::uuid))::text, true);
end;
$$;
select is(
  (select entry_id from public.join_queue(current_setting('t.pa')::uuid, null,
                                          current_setting('t.rk')::uuid)),
  current_setting('t.ek')::uuid,
  'J3 replaying the join request returns the same ticket'
);
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select count(*)::int from public.queue_entries where customer_id = current_setting('t.k')::uuid),
  1, 'J3 the replayed join created one entry'
);
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.leave_queue(%L, %L) $$, current_setting('t.ek'), current_setting('t.rk')),
  'P0001', 'request_reused', 'J3 the same request id for another action is request_reused');
select throws_ok(
  format($$ select * from public.join_queue(%L, null, %L) $$, current_setting('t.pb'), current_setting('t.rk')),
  'P0001', 'request_reused', 'J3 the same join request id at another pro is request_reused');
select ok(
  (select d ~ 'v_prior\.action <> ''join_queue''' and d ~ 'v_prior\.pro_id <> p_pro_id'
     from pg_get_functiondef('public.join_queue(uuid, uuid, uuid)'::regprocedure) d),
  'J3 the pre-lock replay lookup is keyed by actor, request id, action and pro'
);

-- k waits at pa; pb is closed: before the lock join_queue runs can_join in its own order, so k
-- is told pro_not_open (the pro's state comes before the customer's own limits).
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'closed', auto_close_at = null
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.join_queue(%L, null, gen_random_uuid()) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open',
  'J3 join_queue keeps can_join''s order before the lock: closed beats already_in_queue');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'open', auto_close_at = '2026-11-23 19:30+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;

-- J4 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 10:12+01');
do $$ begin perform set_config('t.rw', gen_random_uuid()::text, true); end; $$;
select ok(
  (select on_my_way_at = '2026-11-23 10:12+01' and state = 'waiting'
     from public.queue_on_my_way(current_setting('t.ek')::uuid, current_setting('t.rw')::uuid)),
  'J4 on my way stamps on_my_way_at'
);
select tests.freeze_now('2026-11-23 10:13+01');
select ok(
  (select on_my_way_at = '2026-11-23 10:12+01'
     from public.queue_on_my_way(current_setting('t.ek')::uuid, current_setting('t.rw')::uuid)),
  'J4 replaying on my way returns the ticket and does not restamp'
);
do $$ begin perform tests.clear_auth(); end; $$;
delete from realtime.messages;
do $$ begin perform set_config('t.rw2', gen_random_uuid()::text, true); end; $$;
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select ok(
  (select on_my_way_at = '2026-11-23 10:12+01'
     from public.queue_on_my_way(current_setting('t.ek')::uuid, current_setting('t.rw2')::uuid)),
  'J4 a second on my way (new request) returns the ticket unchanged'
);
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select count(*)::int from public.queue_requests where request_id = current_setting('t.rw2')::uuid)
  + (select count(*)::int from realtime.messages),
  0, 'J4 ... and records no request and sends no broadcast'
);
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_no order by position) from public.owner_queue(current_setting('t.pa')::uuid)
    where state = 'waiting'),
  array[2, 3, 4, 5], 'J4 on my way does not reorder the queue'
);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.queue_on_my_way(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  'P0001', 'entry_not_active', 'J4 another customer''s entry is entry_not_active');

-- J5 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.leave_queue(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  'P0001', 'entry_not_active', 'J5 a customer cannot leave another customer''s entry');
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
do $$ begin perform set_config('t.rl', gen_random_uuid()::text, true); end; $$;
select ok(
  (select state = 'cancelled' and end_reason = 'left' and ended_at = '2026-11-23 10:13+01'
          and position is null and wait_min is null
     from public.leave_queue(current_setting('t.ek')::uuid, current_setting('t.rl')::uuid)),
  'J5 leave cancels the entry with end_reason left'
);
select tests.freeze_now('2026-11-23 10:14+01');
select ok(
  (select state = 'cancelled' and ended_at = '2026-11-23 10:13+01'
     from public.leave_queue(current_setting('t.ek')::uuid, current_setting('t.rl')::uuid)),
  'J5 replaying leave returns the ended ticket, no error, nothing changed'
);
select throws_ok(
  format($$ select * from public.leave_queue(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  'P0001', 'entry_not_active', 'J5 leaving an ended entry is entry_not_active');
select throws_ok(
  format($$ select * from public.queue_on_my_way(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  'P0001', 'entry_not_active', 'J5 on my way on an ended entry is entry_not_active');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_no order by position) from public.owner_queue(current_setting('t.pa')::uuid)
    where state = 'waiting'),
  array[2, 3, 4], 'J5 the owner queue no longer lists the entry that left'
);

-- J6 ------------------------------------------------------------------------------------------
-- m was marked absent at 10:00, n's entry was closed by end of day at 10:05.
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, customer_id, state, end_reason, ended_at)
values
  (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 920, '2026-11-23', 'remote',
   current_setting('t.m')::uuid, 'absent', null, '2026-11-23 10:00+01'),
  (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 921, '2026-11-23', 'remote',
   current_setting('t.n')::uuid, 'cancelled', 'end_of_day', '2026-11-23 10:05+01');
select tests.freeze_now('2026-11-23 10:30+01');
do $$ begin perform tests.authenticate_as(current_setting('t.m')::uuid); end; $$;
select ok(
  (select state = 'absent' and ticket_no = 920 and display_name = 'Salon Bilal' from public.my_ticket()),
  'J6 my_ticket shows an absent entry within 30 min'
);
do $$ begin perform tests.authenticate_as(current_setting('t.n')::uuid); end; $$;
select ok(
  (select state = 'cancelled' and end_reason = 'end_of_day' from public.my_ticket()),
  'J6 my_ticket shows an end_of_day entry within 30 min'
);
select tests.freeze_now('2026-11-23 10:36+01');
do $$ begin perform tests.authenticate_as(current_setting('t.m')::uuid); end; $$;
select is((select count(*)::int from public.my_ticket()), 0,
  'J6 the absent entry is gone from my_ticket after 30 min');
do $$ begin perform tests.authenticate_as(current_setting('t.n')::uuid); end; $$;
select is((select count(*)::int from public.my_ticket()), 0,
  'J6 the end_of_day entry is gone from my_ticket after 30 min');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is((select entry_id from public.my_ticket()), current_setting('t.ec')::uuid,
  'J6 an active entry is always my_ticket');

-- J7 ------------------------------------------------------------------------------------------
do $$ begin perform tests.clear_auth(); end; $$;
do $$
begin
  perform set_config('t.nc', (select count(*) from public.queue_entries
                               where customer_id = current_setting('t.c')::uuid)::text, true);
end;
$$;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is(
  (select count(*)::int from public.queue_entries),
  current_setting('t.nc')::int,
  'J7 a customer selecting queue_entries gets exactly their own rows'
);
select is(
  (select count(*)::int from public.queue_entries where customer_id is distinct from current_setting('t.c')::uuid),
  0, 'J7 no other customer''s or walk-in row is visible'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is((select count(*)::int from public.queue_entries), 0,
  'J7 an owner selecting queue_entries sees none of their queue (no customer id reaches a pro)');
select throws_ok(
  format($$ update public.queue_entries set state = 'served' where id = %L $$, current_setting('t.ec')),
  '42501', null, 'J7 clients still cannot update queue_entries');

-- J8 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 10:40+01');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$ begin perform set_config('t.rs', gen_random_uuid()::text, true); end; $$;
select ok(
  (select queue_mode = 'paused' and hide_queue_count
     from public.set_queue_settings(current_setting('t.pa')::uuid, 'paused', true, current_setting('t.rs')::uuid)),
  'J8 the owner sets mode paused and hides the count'
);
select ok(
  (select queue_mode = 'paused' and hide_queue_count
     from public.set_queue_settings(current_setting('t.pa')::uuid, 'open', false, current_setting('t.rs')::uuid)),
  'J8 replaying the settings request changes nothing (still paused, count hidden)'
);
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select throws_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'queue_paused', 'J8 the paused setting refuses joins');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select ok(
  (select queue_mode = 'open' and not hide_queue_count and last_activity_at = '2026-11-23 10:40+01'
     from public.set_queue_settings(current_setting('t.pa')::uuid, 'open', false, gen_random_uuid())),
  'J8 the owner reopens the queue and shows the count (owner activity recorded)'
);
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.set_queue_settings(%L, 'paused', true, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'J8 another owner cannot change the settings');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.set_queue_settings(%L, 'paused', true, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'J8 a customer cannot change the settings');

-- J9 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$ begin perform set_config('t.rb', gen_random_uuid()::text, true); end; $$;
select is(
  (select array_agg(ticket_no order by position) from public.queue_block(current_setting('t.ec')::uuid, current_setting('t.rb')::uuid)
    where state = 'waiting'),
  array[2, 4], 'J9 blocking removes the entry from the queue'
);
select is(
  (select array_agg(ticket_no order by position) from public.queue_block(current_setting('t.ec')::uuid, current_setting('t.rb')::uuid)
    where state = 'waiting'),
  array[2, 4], 'J9 replaying the block returns the same queue, no error'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'cancelled' and end_reason = 'cleared' from public.queue_entries
    where id = current_setting('t.ec')::uuid),
  'J9 the blocked entry is stored cancelled with end_reason cleared (no block oracle)'
);
select is(
  (select count(*)::int from public.pro_blocks where pro_id = current_setting('t.pa')::uuid),
  2, 'J9 the replayed block stored one block row'
);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select is(
  (select end_reason::text from public.queue_entries where id = current_setting('t.ec')::uuid),
  'cleared', 'J9 the customer''s own direct select reads cleared'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_label order by created_at, ticket_label) from public.queue_blocked(current_setting('t.pa')::uuid)),
  array['Hamid', 'Chafik'], 'J9 queue_blocked lists the stored labels'
);
select is(
  (select array_agg(a order by a) from pg_proc p, unnest(p.proargnames) a
    where p.oid = 'public.queue_blocked(uuid)'::regprocedure),
  array['block_id', 'created_at', 'p_pro_id', 'ticket_label'],
  'J9 queue_blocked returns no customer id'
);
select throws_ok(
  format($$ select * from public.queue_block((select entry_id from public.owner_queue(%L) where ticket_no = 2), gen_random_uuid()) $$,
         current_setting('t.pa')),
  'P0001', 'not_remote', 'J9 a walk-in cannot be blocked');
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.queue_block(%L, gen_random_uuid()) $$, current_setting('t.ec')),
  'P0001', 'not_owner', 'J9 another owner cannot block on this pro');
select throws_ok(
  format($$ select * from public.queue_blocked(%L) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'J9 another owner cannot list this pro''s blocks');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select ok(
  (select state = 'cancelled' and end_reason = 'cleared' from public.my_ticket()),
  'J9 the blocked customer''s ticket reads as cleared'
);
select is(tests.error_detail(format($$ select tests.can_join(%L) $$, current_setting('t.pa'))),
  'pro_not_open|', 'J9 the blocked customer is refused as by a closed pro (pro_not_open)');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$
begin
  perform set_config('t.bc', (select block_id from public.queue_blocked(current_setting('t.pa')::uuid)
                               where ticket_label = 'Chafik')::text, true);
end;
$$;
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.queue_unblock(%L, %L, gen_random_uuid()) $$, current_setting('t.pa'), current_setting('t.bc')),
  'P0001', 'not_owner', 'J9 another owner cannot unblock');
select throws_ok(
  format($$ select * from public.queue_unblock(%L, %L, gen_random_uuid()) $$, current_setting('t.pb'), current_setting('t.bc')),
  'P0001', 'not_owner', 'J9 a block id of another pro is not_owner, even for an owner');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$ begin perform set_config('t.ru', gen_random_uuid()::text, true); end; $$;
select is(
  (select array_agg(ticket_label) from public.queue_unblock(current_setting('t.pa')::uuid, current_setting('t.bc')::uuid, current_setting('t.ru')::uuid)),
  array['Hamid'], 'J9 unblock removes the block and returns the remaining list'
);
select is(
  (select array_agg(ticket_label) from public.queue_unblock(current_setting('t.pa')::uuid, current_setting('t.bc')::uuid, current_setting('t.ru')::uuid)),
  array['Hamid'], 'J9 replaying the unblock returns the same remaining list, no error'
);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select lives_ok(format($$ select tests.can_join(%L) $$, current_setting('t.pa')),
  'J9 after unblock the customer can join again');

-- J10 -----------------------------------------------------------------------------------------
do $$ begin perform tests.clear_auth(); end; $$;
create temp table j10 on commit drop as
select id from public.queue_entries where customer_id = current_setting('t.c')::uuid;
delete from auth.users where id = current_setting('t.c')::uuid;
select is(
  (select count(*)::int from public.queue_entries e join j10 using (id) where e.customer_id is null),
  current_setting('t.nc')::int,
  'J10 deleting a customer account keeps their history rows with customer_id null'
);
delete from auth.users where id = current_setting('t.h')::uuid;
select is(
  (select count(*)::int from public.pro_blocks where pro_id = current_setting('t.pa')::uuid),
  0, 'J10 deleting a customer account removes the blocks on them'
);

-- J11 -----------------------------------------------------------------------------------------
select ok(
  (select indexdef ~ 'WHERE .*kind = ''remote''' from pg_indexes
    where schemaname = 'public' and indexname = 'queue_entries_active_remote_idx'),
  'J11 the one-active-entry index is remote-only'
);
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select count(*) from public.join_queue(current_setting('t.pa')::uuid, null, gen_random_uuid());
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid());
select is(
  (select array_agg(kind::text || ':' || coalesce(label, '-') order by position)
     from public.queue_set_details(
            (select entry_id from public.owner_queue(current_setting('t.pa')::uuid)
              order by position desc limit 1),
            'Kamel', null, gen_random_uuid())
    where state = 'waiting' and position > 2),
  array['remote:Kamel', 'walk_in:Kamel'],
  'J11 a walk-in and a remote entry for the same person wait side by side'
);

-- J13 -----------------------------------------------------------------------------------------
-- A blocked customer meets a closed pro, whatever pb's state: join_queue's refusal is what their
-- snapshot's join_block implies, and what an unblocked customer gets from a closed pro. x is
-- blocked at pb and waits at pa (status beats the customer's own limits); y is not blocked.
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.pro_blocks (pro_id, customer_id, ticket_label)
values (current_setting('t.pb')::uuid, current_setting('t.x')::uuid, 'Xavier');
do $$ begin perform tests.authenticate_as(current_setting('t.x')::uuid); end; $$;
select count(*) from public.join_queue(current_setting('t.pa')::uuid, null, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;

create function tests.join_code(p_pro uuid)
returns text
language sql
as $$
  select tests.error_detail(format($q$ select * from public.join_queue(%L, null, gen_random_uuid()) $q$, p_pro));
$$;
create function tests.join_block(p_pro uuid)
returns text
language sql
as $$
  select s.live ->> 'join_block' from public.pro_live_snapshots(array[p_pro]) s;
$$;

do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'closed', auto_close_at = null
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.x')::uuid); end; $$;
select is(tests.join_code(current_setting('t.pb')::uuid), 'pro_not_open|',
  'J13 closed pro: the blocked customer is refused pro_not_open');
select is(tests.join_block(current_setting('t.pb')::uuid), 'closed',
  'J13 closed pro: the blocked customer''s snapshot says closed');
do $$ begin perform tests.authenticate_as(current_setting('t.y')::uuid); end; $$;
select is(tests.join_code(current_setting('t.pb')::uuid), 'pro_not_open|',
  'J13 closed pro: an unblocked customer is refused pro_not_open too');

do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'open', auto_close_at = '2026-11-23 19:30+01', queue_mode = 'paused'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.x')::uuid); end; $$;
select is(tests.join_code(current_setting('t.pb')::uuid), 'pro_not_open|',
  'J13 paused pro: the blocked customer is refused pro_not_open, not queue_paused');
select is(tests.join_block(current_setting('t.pb')::uuid), 'closed',
  'J13 paused pro: the blocked customer''s snapshot says closed');
do $$ begin perform tests.authenticate_as(current_setting('t.y')::uuid); end; $$;
select is(tests.join_code(current_setting('t.pb')::uuid), 'queue_paused|',
  'J13 paused pro: an unblocked customer is refused queue_paused');
select is(tests.join_block(current_setting('t.pb')::uuid), 'paused',
  'J13 paused pro: the unblocked customer''s snapshot says paused');

do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set queue_mode = 'open' where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.x')::uuid); end; $$;
select is(tests.join_code(current_setting('t.pb')::uuid), 'pro_not_open|',
  'J13 open pro: the blocked customer is refused pro_not_open, not already_in_queue');
select is(tests.join_block(current_setting('t.pb')::uuid), 'closed',
  'J13 open pro: the blocked customer''s snapshot says closed');
do $$ begin perform tests.authenticate_as(current_setting('t.y')::uuid); end; $$;
select lives_ok(
  format($$ select * from public.join_queue(%L, null, gen_random_uuid()) $$, current_setting('t.pb')),
  'J13 open pro: an unblocked customer joins');

-- J12 -----------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  '42501', null, 'J12 anon cannot call can_join');
select throws_ok(format($$ select * from public.join_queue(%L, null, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'J12 anon cannot join');
select throws_ok(format($$ select * from public.queue_on_my_way(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  '42501', null, 'J12 anon cannot say on my way');
select throws_ok(format($$ select * from public.leave_queue(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  '42501', null, 'J12 anon cannot leave');
select throws_ok($$ select * from public.my_ticket() $$,
  '42501', null, 'J12 anon cannot read my_ticket');
select throws_ok(format($$ select * from public.set_queue_settings(%L, 'open', false, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'J12 anon cannot change settings');
select throws_ok(format($$ select * from public.queue_block(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  '42501', null, 'J12 anon cannot block');
select throws_ok(format($$ select * from public.queue_blocked(%L) $$, current_setting('t.pa')),
  '42501', null, 'J12 anon cannot list blocks');
select throws_ok(format($$ select * from public.queue_unblock(%L, %L, gen_random_uuid()) $$, current_setting('t.pa'), current_setting('t.ek')),
  '42501', null, 'J12 anon cannot unblock');
select throws_ok($$ select * from public.queue_entries $$,
  '42501', null, 'J12 anon cannot select queue_entries');

select * from finish();
rollback;
