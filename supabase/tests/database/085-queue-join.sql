begin;
select plan(83);

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
  (select relrowsecurity from pg_class where oid = 'public.pro_blocks'::regclass)
  and not has_table_privilege('authenticated', 'public.pro_blocks', 'select')
  and not has_table_privilege('authenticated', 'public.pro_blocks', 'insert')
  and not has_table_privilege('anon', 'public.pro_blocks', 'select'),
  'pro_blocks has RLS and no client privilege (owners read it through queue_blocked)'
);

-- J1 ------------------------------------------------------------------------------------------
-- Each can_join code in isolation: every earlier check passes, only the named one fails.
do $$ begin perform tests.authenticate_as(current_setting('t.w')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'not_listable', 'J1 not_listable: a customer of the other space');
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pu')),
  'P0001', 'not_listable', 'J1 not_listable: an unpublished pro');
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'not_listable', 'J1 not_listable: a caller acting as barber');

do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'customer' where id = current_setting('t.a')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'own_queue', 'J1 own_queue: the owner acting as customer in their own space');
do $$ begin perform tests.clear_auth(); end; $$;
update public.profiles set active_role = 'barber' where id = current_setting('t.a')::uuid;

update public.pro_live set status = 'closed', auto_close_at = null
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: closed');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'open', auto_close_at = '2026-11-23 09:59+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: effective-closed (auto_close_at passed, row says open)');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set auto_close_at = '2026-11-23 19:30+01', last_activity_at = '2026-11-23 08:00+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: stale (no owner activity for 2 h)');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'on_break', last_activity_at = '2026-11-23 10:00+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: on break without a return time');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set break_until = '2026-11-23 10:30+01'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'pro_not_open', 'J1 pro_not_open: on break with a return time');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set status = 'open', break_until = null, queue_mode = 'paused'
 where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'queue_paused', 'J1 queue_paused: mode paused');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set queue_mode = 'followers' where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'P0001', 'queue_paused', 'J1 queue_paused: mode followers');
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_live set queue_mode = 'open' where pro_id = current_setting('t.pb')::uuid;

-- c waits at pb: joining pa is refused.
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, customer_id)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 950, '2026-11-23', 'remote',
        current_setting('t.c')::uuid);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
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
select lives_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'J1 join_limit_reached: 4 joins today (+ 1 yesterday) still allow a 5th');
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, customer_id, state, end_reason, ended_at)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 905, '2026-11-23', 'remote',
        current_setting('t.e')::uuid, 'cancelled', 'left', '2026-11-23 09:00+01');
do $$ begin perform tests.authenticate_as(current_setting('t.e')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'join_limit_reached', 'J1 join_limit_reached: the 6th remote join of the service day');

-- Absents (ended_at): d 20th 12:00 + 22nd 10:30 (blocked until 23rd 10:30); f 20th 12:00 +
-- 22nd 09:59 (lifted at 23rd 09:59); g 14th 10:00 + 22nd 12:00 (8 days apart, never blocked).
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, customer_id, state, ended_at)
select current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, t, d::date, 'remote',
       current_setting(c)::uuid, 'absent', at::timestamptz
from (values (910, '2026-11-20', 't.d', '2026-11-20 12:00+01'),
             (911, '2026-11-22', 't.d', '2026-11-22 10:30+01'),
             (912, '2026-11-20', 't.f', '2026-11-20 12:00+01'),
             (913, '2026-11-22', 't.f', '2026-11-22 09:59+01'),
             (914, '2026-11-14', 't.g', '2026-11-14 10:00+01'),
             (915, '2026-11-22', 't.g', '2026-11-22 12:00+01')) v(t, d, c, at);
do $$ begin perform tests.authenticate_as(current_setting('t.d')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'P0001', 'absent_block', 'J1 absent_block: 2 absents within 7 days, less than 24 h after the 2nd');
do $$ begin perform tests.authenticate_as(current_setting('t.f')::uuid); end; $$;
select lives_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'J1 absent_block: lifted 24 h after the 2nd absent');
do $$ begin perform tests.authenticate_as(current_setting('t.g')::uuid); end; $$;
select lives_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
  'J1 absent_block: 2 absents more than 7 days apart do not block');

do $$ begin perform tests.clear_auth(); end; $$;
insert into public.pro_blocks (pro_id, customer_id, ticket_label)
values (current_setting('t.pa')::uuid, current_setting('t.h')::uuid, 'Hamid');
do $$ begin perform tests.authenticate_as(current_setting('t.h')::uuid); end; $$;
select is(tests.error_detail(format($$ select public.can_join(%L) $$, current_setting('t.pa'))),
  'join_unavailable|', 'J1 join_unavailable: blocked by this pro, with no detail revealing why');
select lives_ok(format($$ select public.can_join(%L) $$, current_setting('t.pb')),
  'J1 join_unavailable: a block at pa does not refuse pb');

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
do $$ begin perform set_config('t.ec', (select entry_id from j2)::text, true); end; $$;
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
select ok(
  (select queue_version > current_setting('t.v0')::bigint
          and last_activity_at = '2026-11-23 10:06+01'
     from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  'J2 a join bumps queue_version and does not count as owner activity'
);
select tests.freeze_now('2026-11-23 10:10+01');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_call_next(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select ok(
  (select position = 2 and wait_min = 40 from public.my_ticket()),
  'J2 after W1 is called: position 2, wait 40 (20 left of W1 + W2)'
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

-- J4 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-23 10:12+01');
select ok(
  (select on_my_way_at = '2026-11-23 10:12+01' and state = 'waiting'
     from public.queue_on_my_way(current_setting('t.ek')::uuid, gen_random_uuid())),
  'J4 on my way stamps on_my_way_at'
);
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
select ok(
  (select state = 'cancelled' and end_reason = 'left' and ended_at = '2026-11-23 10:12+01'
          and position is null and wait_min is null
     from public.leave_queue(current_setting('t.ek')::uuid, gen_random_uuid())),
  'J5 leave cancels the entry with end_reason left'
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
select ok(
  (select queue_mode = 'paused' and hide_queue_count
     from public.set_queue_settings(current_setting('t.pa')::uuid, 'paused', true, gen_random_uuid())),
  'J8 the owner sets mode paused and hides the count'
);
do $$ begin perform tests.authenticate_as(current_setting('t.k')::uuid); end; $$;
select throws_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
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
select is(
  (select array_agg(ticket_no order by position) from public.queue_block(current_setting('t.ec')::uuid, gen_random_uuid())
    where state = 'waiting'),
  array[2, 4], 'J9 blocking removes the entry from the queue'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'cancelled' and end_reason = 'blocked' from public.queue_entries
    where id = current_setting('t.ec')::uuid),
  'J9 the entry is cancelled with end_reason blocked'
);
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
  'J9 the blocked customer''s ticket reads as cleared, never blocked'
);
select is(tests.error_detail(format($$ select public.can_join(%L) $$, current_setting('t.pa'))),
  'join_unavailable|', 'J9 the blocked customer gets the neutral join_unavailable');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$
begin
  perform set_config('t.bc', (select block_id from public.queue_blocked(current_setting('t.pa')::uuid)
                               where ticket_label = 'Chafik')::text, true);
end;
$$;
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.queue_unblock(%L, gen_random_uuid()) $$, current_setting('t.bc')),
  'P0001', 'not_owner', 'J9 another owner cannot unblock');
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_label) from public.queue_unblock(current_setting('t.bc')::uuid, gen_random_uuid())),
  array['Hamid'], 'J9 unblock removes the block and returns the remaining list'
);
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select lives_ok(format($$ select public.can_join(%L) $$, current_setting('t.pa')),
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
select throws_ok(format($$ select * from public.queue_unblock(%L, gen_random_uuid()) $$, current_setting('t.ek')),
  '42501', null, 'J12 anon cannot unblock');
select throws_ok($$ select * from public.queue_entries $$,
  '42501', null, 'J12 anon cannot select queue_entries');

select * from finish();
rollback;
