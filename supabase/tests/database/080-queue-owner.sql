begin;
select plan(100);

-- Calendar (Africa/Algiers, UTC+1, no DST): 2026-11-23 is a Monday. The service day is the local
-- date of (now - 6 h 30), so 2026-11-24 05:00 still belongs to 2026-11-23.
do $$
begin
  perform set_config('t.a', tests.create_account('213550000800', 'men', 'barber', 'Amine')::text, true);
  perform set_config('t.b', tests.create_account('213550000801', 'men', 'barber', 'Bilal')::text, true);
  perform set_config('t.c', tests.create_account('213550000802', 'men', 'customer', 'Chafik')::text, true);
  perform set_config('t.d', tests.create_account('213550000803', 'men', 'customer', 'Djamel')::text, true);
  perform set_config('t.pa', tests.create_pro(current_setting('t.a')::uuid, 'barber', 'Salon Amine')::text, true);
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Salon Bilal')::text, true);
  perform set_config('t.s30', (select id from public.pro_services
                                where pro_id = current_setting('t.pa')::uuid)::text, true);
  perform set_config('t.sb', (select id from public.pro_services
                               where pro_id = current_setting('t.pb')::uuid)::text, true);
end;
$$;
insert into public.pro_services (pro_id, name, category, price_dzd, duration_min)
values (current_setting('t.pa')::uuid, 'Coupe courte', 'hair', 500, 20);
insert into public.pro_services (pro_id, name, category, price_dzd, duration_min, active)
values (current_setting('t.pa')::uuid, 'Inactive', 'hair', 100, 15, false);
insert into public.pro_services (pro_id, name, category, price_dzd, duration_min, archived_at)
values (current_setting('t.pa')::uuid, 'Archived', 'hair', 100, 15, now());
do $$
begin
  perform set_config('t.s20', (select id from public.pro_services
                                where pro_id = current_setting('t.pa')::uuid and name = 'Coupe courte')::text, true);
  perform set_config('t.sin', (select id from public.pro_services
                                where pro_id = current_setting('t.pa')::uuid and name = 'Inactive')::text, true);
  perform set_config('t.sarch', (select id from public.pro_services
                                  where pro_id = current_setting('t.pa')::uuid and name = 'Archived')::text, true);
end;
$$;
select tests.freeze_now('2026-11-23 10:00+01');

-- Contract ------------------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('queue_add_walk_in', 'queue_set_details', 'queue_undo_walk_in',
                      'queue_call_next', 'queue_finish', 'queue_mark_absent', 'queue_clear',
                      'owner_queue', 'queue_serve_current', 'queue_entries_keep_history',
                      'queue_wait_min')
      and prosecdef
      and proconfig @> array['search_path=""']),
  11,
  'the 11 new definer functions are security definer with search_path = '''''
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('queue_add_walk_in', 'queue_set_details', 'queue_undo_walk_in',
                      'queue_call_next', 'queue_finish', 'queue_mark_absent', 'queue_clear',
                      'owner_queue', 'queue_serve_current', 'queue_entries_keep_history',
                      'queue_wait_min', 'queue_entries_no_truncate')
      and (has_function_privilege('anon', oid, 'execute')
           or has_function_privilege('public', oid, 'execute'))),
  0,
  'no new function is executable by anon or public'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('queue_wait_min', 'queue_serve_current', 'queue_entries_keep_history',
                      'queue_entries_no_truncate')
      and has_function_privilege('authenticated', oid, 'execute')),
  0,
  'internal helpers and the trigger function are not executable by authenticated'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.queue_entries'::regclass),
  'RLS is enabled on queue_entries'
);

-- Q1 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select ticket_no from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())
    order by position desc limit 1),
  1, 'Q1 the first walk-in of the day gets ticket 1'
);
select is(
  (select ticket_no from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())
    order by position desc limit 1),
  2, 'Q1 the second gets ticket 2'
);
select is(
  (select ticket_no from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())
    order by position desc limit 1),
  3, 'Q1 the third gets ticket 3'
);
select is(
  (select array_agg(ticket_no order by position) from public.owner_queue(current_setting('t.pa')::uuid)),
  array[1, 2, 3],
  'Q1 owner_queue lists tickets 1, 2, 3 in order'
);
select tests.freeze_now('2026-11-24 05:00+01');
select is(
  (select ticket_no from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())
    order by position desc limit 1),
  4, 'Q1 05:00 the next morning is still the same service day'
);
select tests.freeze_now('2026-11-24 07:00+01');
select is(
  (select ticket_no from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())
    order by position desc limit 1),
  1, 'Q1 numbering restarts on the next service day'
);

-- Q5 ------------------------------------------------------------------------------------------
-- A later entry with an earlier sort_at (an M5 booking) is served first.
do $$ begin perform tests.clear_auth(); end; $$;
update public.queue_entries set sort_at = '2026-11-23 09:00+01'
 where pro_id = current_setting('t.pa')::uuid and service_day = '2026-11-23' and ticket_no = 3;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select ticket_no from public.queue_call_next(current_setting('t.pa')::uuid, gen_random_uuid())
    where state = 'serving'),
  3, 'Q5 call next serves the earliest sort_at, not the lowest ticket'
);
select tests.freeze_now('2026-11-24 07:20+01');
select is(
  (select array_agg(ticket_no order by position) from public.queue_call_next(current_setting('t.pa')::uuid, gen_random_uuid())
    where state = 'serving'),
  array[1], 'Q5 the next call serves the next by sort_at (ticket 1)'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'served' and called_at = '2026-11-24 07:00+01' and ended_at = '2026-11-24 07:20+01'
     from public.queue_entries
    where pro_id = current_setting('t.pa')::uuid and service_day = '2026-11-23' and ticket_no = 3),
  'Q5 call next finished the previous serving entry at now'
);
select is(
  (select count(*)::int from public.queue_entries
    where pro_id = current_setting('t.pa')::uuid and state = 'serving'),
  1, 'Q5 exactly one serving row'
);

-- Q10 -----------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(state::text) from public.queue_clear(current_setting('t.pa')::uuid, gen_random_uuid())),
  array['serving'], 'Q10 clear leaves only the serving entry'
);
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select count(*)::int from public.queue_entries
    where pro_id = current_setting('t.pa')::uuid and state = 'cancelled' and end_reason = 'cleared'
      and ended_at = '2026-11-24 07:20+01'),
  3, 'Q10 the 3 waiting entries are cancelled with end_reason cleared'
);

-- Q6 ------------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select tests.freeze_now('2026-11-24 07:45+01');
select is(
  (select count(*)::int from public.queue_finish(current_setting('t.pa')::uuid, gen_random_uuid())),
  0, 'Q6 finish leaves an empty queue'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'served' and ended_at = '2026-11-24 07:45+01' from public.queue_entries
    where pro_id = current_setting('t.pa')::uuid and service_day = '2026-11-23' and ticket_no = 1),
  'Q6 the serving entry is served at now'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.queue_finish(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'nothing_serving', 'Q6 finish with nobody serving raises nothing_serving'
);

-- Q4 ------------------------------------------------------------------------------------------
select throws_ok(
  format($$ select * from public.queue_call_next(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'queue_empty', 'Q4 call next on an empty queue raises queue_empty'
);

-- Q2 ------------------------------------------------------------------------------------------
select tests.freeze_now('2026-11-25 10:00+01');
do $$
begin
  perform set_config('t.r1', gen_random_uuid()::text, true);
  perform set_config('t.r2', gen_random_uuid()::text, true);
end;
$$;
select is(
  (select count(*)::int from public.queue_add_walk_in(current_setting('t.pa')::uuid, current_setting('t.r1')::uuid)),
  1, 'Q2 the first call adds one entry'
);
select is(
  (select count(*)::int from public.queue_add_walk_in(current_setting('t.pa')::uuid, current_setting('t.r1')::uuid)),
  1, 'Q2 the same request id again adds nothing and returns the queue'
);
select is(
  (select max(ticket_no) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())),
  2, 'Q2 the next walk-in still gets ticket 2'
);
select is(
  (select ticket_no from public.queue_call_next(current_setting('t.pa')::uuid, current_setting('t.r2')::uuid)
    where state = 'serving'),
  1, 'Q2 call next serves ticket 1'
);
select is(
  (select array_agg(ticket_no || ':' || state order by position)
     from public.queue_call_next(current_setting('t.pa')::uuid, current_setting('t.r2')::uuid)),
  array['1:serving', '2:waiting'],
  'Q2 call next replayed serves nobody else'
);
select throws_ok(
  format($$ select * from public.queue_undo_walk_in(%L, %L) $$, current_setting('t.pa'), current_setting('t.r1')),
  'P0001', 'request_reused', 'Q2 a request id reused for another action raises request_reused'
);

-- Q3 ------------------------------------------------------------------------------------------
select is(
  (select max(ticket_no) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())),
  3, 'Q3 a third walk-in gets ticket 3'
);
-- A remote entry created at the same moment, with a higher ticket: undo must skip it.
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, customer_id)
values (current_setting('t.pa')::uuid, current_setting('t.pa')::uuid, 4, '2026-11-25', 'remote',
        current_setting('t.c')::uuid);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_no order by position) from public.queue_undo_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())),
  array[1, 2, 4], 'Q3 undo removes only the latest waiting walk-in (3), not the remote 4'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'removed' and end_reason = 'undo' and ended_at = '2026-11-25 10:00+01'
     from public.queue_entries
    where pro_id = current_setting('t.pa')::uuid and service_day = '2026-11-25' and ticket_no = 3),
  'Q3 the undone entry is kept as removed with end_reason undo'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_no order by position) from public.queue_undo_walk_in(current_setting('t.pa')::uuid, gen_random_uuid())),
  array[1, 4], 'Q3 undo again removes walk-in 2, never the serving one'
);
select throws_ok(
  format($$ select * from public.queue_undo_walk_in(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'nothing_to_undo', 'Q3 undo with no waiting walk-in raises nothing_to_undo'
);

-- Q13 -----------------------------------------------------------------------------------------
do $$ begin perform tests.clear_auth(); end; $$;
-- A remote entry whose customer account is gone (customer_id set null).
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind)
values (current_setting('t.pa')::uuid, current_setting('t.pa')::uuid, 5, '2026-11-25', 'remote');
select is(
  (select array_agg(attname::text order by attnum) from pg_attribute
    where attrelid = (select typrelid from pg_type where oid = 'public.owner_queue_row'::regtype)
      and attnum > 0 and not attisdropped),
  array['entry_id', 'ticket_no', 'kind', 'label', 'service_id', 'duration_min', 'state',
        'on_my_way_at', 'called_at', 'sort_at', 'position'],
  'Q13 owner_queue_row has exactly the documented columns'
);
select is(
  (select count(*)::int from pg_attribute
    where attrelid = (select typrelid from pg_type where oid = 'public.owner_queue_row'::regtype)
      and attname = 'customer_id'),
  0, 'Q13 owner_queue_row has no customer_id column'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select array_agg(ticket_no || ':' || coalesce(label, '<null>') || ':' || position order by position)
     from public.owner_queue(current_setting('t.pa')::uuid)),
  array['1:<null>:0', '4:Chafik:1', '5:<null>:2'],
  'Q13 labels: unnamed walk-in null, remote full_name, remote without account null (the app shows Client N)'
);

-- Q8 ------------------------------------------------------------------------------------------
do $$
begin
  perform set_config('t.e1', (select entry_id::text from public.owner_queue(current_setting('t.pa')::uuid)
                                where ticket_no = 1), true);
  perform set_config('t.e4', (select entry_id::text from public.owner_queue(current_setting('t.pa')::uuid)
                                where ticket_no = 4), true);
end;
$$;
select throws_ok(
  format($$ select * from public.queue_set_details(%L, null, %L, gen_random_uuid()) $$,
         current_setting('t.e1'), current_setting('t.sb')),
  'P0001', 'invalid_service', 'Q8 another pro''s service raises invalid_service'
);
select throws_ok(
  format($$ select * from public.queue_set_details(%L, null, %L, gen_random_uuid()) $$,
         current_setting('t.e1'), current_setting('t.sin')),
  'P0001', 'invalid_service', 'Q8 an inactive service raises invalid_service'
);
select throws_ok(
  format($$ select * from public.queue_set_details(%L, null, %L, gen_random_uuid()) $$,
         current_setting('t.e1'), current_setting('t.sarch')),
  'P0001', 'invalid_service', 'Q8 an archived service raises invalid_service'
);
select throws_ok(
  format($$ select * from public.queue_set_details(%L, %L, null, gen_random_uuid()) $$,
         current_setting('t.e1'), repeat('a', 41)),
  'P0001', 'invalid_name', 'Q8 a 41-character name raises invalid_name'
);
select throws_ok(
  format($$ select * from public.queue_set_details(%L, %L, null, gen_random_uuid()) $$,
         current_setting('t.e1'), 'Ka' || chr(8203) || 'rim'),
  'P0001', 'invalid_name', 'Q8 a name hiding a zero-width space raises invalid_name'
);
select throws_ok(
  format($$ select * from public.queue_set_details(%L, %L, null, gen_random_uuid()) $$,
         current_setting('t.e4'), 'Karim'),
  'P0001', 'invalid_name', 'Q8 a remote entry cannot be named'
);
select is(
  (select label || ':' || duration_min || ':' || service_id
     from public.queue_set_details(current_setting('t.e1')::uuid, '  Karim  ',
                                   current_setting('t.s20')::uuid, gen_random_uuid())
    where entry_id = current_setting('t.e1')::uuid),
  'Karim:20:' || current_setting('t.s20'),
  'Q8 set_details trims the name and sets the service and its duration'
);
do $$ begin perform tests.clear_auth(); end; $$;
update public.pro_services set price_dzd = 900, duration_min = 25 where id = current_setting('t.s20')::uuid;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select duration_min from public.queue_set_details(current_setting('t.e1')::uuid, 'Karim B',
                                                     current_setting('t.s20')::uuid, gen_random_uuid())
    where entry_id = current_setting('t.e1')::uuid),
  20::smallint, 'Q8 keeping the same service keeps the snapshotted duration'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select price_dzd = 500 and duration_min = 20 and name = 'Karim B' from public.queue_entries
    where id = current_setting('t.e1')::uuid),
  'Q8 duration and price are snapshotted when the service is set'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select label || ':' || coalesce(duration_min::text, 'avg')
     from public.queue_set_details(current_setting('t.e4')::uuid, null,
                                   current_setting('t.s30')::uuid, gen_random_uuid())
    where entry_id = current_setting('t.e4')::uuid),
  'Chafik:30', 'Q8 a remote entry takes a service'
);
select is(
  (select coalesce(label, '<null>') || ':' || coalesce(duration_min::text, 'avg')
     from public.queue_set_details(current_setting('t.e1')::uuid, '', null, gen_random_uuid())
    where entry_id = current_setting('t.e1')::uuid),
  '<null>:avg', 'Q8 an empty name and no service clear both (duration falls back to the average)'
);

-- Q9 ------------------------------------------------------------------------------------------
select throws_ok(
  format($$ select * from public.queue_mark_absent(%L, gen_random_uuid()) $$, current_setting('t.e1')),
  'P0001', 'not_remote', 'Q9 a walk-in cannot be marked absent'
);
do $$ begin perform set_config('t.r3', gen_random_uuid()::text, true); end; $$;
select is(
  (select array_agg(ticket_no order by position)
     from public.queue_mark_absent(current_setting('t.e4')::uuid, current_setting('t.r3')::uuid)),
  array[1, 5], 'Q9 marking a remote entry absent takes it out of the queue'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'absent' and ended_at = '2026-11-25 10:00+01' from public.queue_entries
    where id = current_setting('t.e4')::uuid),
  'Q9 the absent entry is kept with ended_at at now'
);
do $$
begin
  perform set_config('t.v', (select queue_version::text from public.pro_live
                              where pro_id = current_setting('t.pa')::uuid), true);
  perform tests.authenticate_as(current_setting('t.a')::uuid);
end;
$$;
select tests.freeze_now('2026-11-25 10:05+01');
select is(
  (select array_agg(ticket_no order by position)
     from public.queue_mark_absent(current_setting('t.e4')::uuid, current_setting('t.r3')::uuid)),
  array[1, 5], 'Q9 replaying mark_absent with the same request id returns the queue without error'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select e.ended_at = '2026-11-25 10:00+01' and l.queue_version = current_setting('t.v')::bigint
          and l.last_activity_at = '2026-11-25 10:00+01'
     from public.queue_entries e join public.pro_live l on l.pro_id = e.pro_id
    where e.id = current_setting('t.e4')::uuid),
  'Q9 the replay changes nothing (ended_at, queue_version, last_activity_at)'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  format($$ select * from public.queue_mark_absent(%L, gen_random_uuid()) $$, current_setting('t.e4')),
  'P0001', 'entry_not_active', 'Q9 an entry already out of the queue cannot change again'
);
select throws_ok(
  format($$ select * from public.queue_set_details(%L, null, null, gen_random_uuid()) $$, current_setting('t.e4')),
  'P0001', 'entry_not_active', 'Q8 details of an ended entry cannot change (entry_not_active)'
);

-- Q7 ------------------------------------------------------------------------------------------
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  exists (select 1 from pg_indexes
           where schemaname = 'public' and tablename = 'queue_entries'
             and indexdef ilike 'CREATE UNIQUE INDEX % USING btree (customer_id) WHERE %state%''waiting''%''serving''%kind = ''remote''%'),
  'Q7 unique (customer_id) where active and remote exists'
);
select ok(
  exists (select 1 from pg_indexes
           where schemaname = 'public' and tablename = 'queue_entries'
             and indexdef ilike 'CREATE UNIQUE INDEX % USING btree (served_by) WHERE (state = ''serving''%'),
  'Q7 unique (served_by) where serving exists'
);
select ok(
  exists (select 1 from pg_indexes
           where schemaname = 'public' and tablename = 'queue_entries'
             and indexdef ilike 'CREATE UNIQUE INDEX % USING btree (pro_id, service_day, ticket_no)'),
  'Q7 unique (pro_id, service_day, ticket_no) exists'
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('queue_add_walk_in', 'queue_set_details', 'queue_undo_walk_in',
                      'queue_call_next', 'queue_finish', 'queue_mark_absent', 'queue_clear')
      and pg_get_functiondef(oid) ilike '%for update%'),
  7, 'Q7 every owner RPC locks with for update'
);
select throws_ok(
  format($$ insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, state, called_at)
            values (%L, %L, 90, '2026-11-25', 'walk_in', 'serving', now()) $$,
         current_setting('t.pa'), current_setting('t.pa')),
  '23505', null, 'Q7 a second serving row for the same pro is refused'
);
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, customer_id)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 90, '2026-11-25', 'remote',
        current_setting('t.d')::uuid);
select throws_ok(
  format($$ insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, customer_id)
            values (%L, %L, 91, '2026-11-25', 'remote', %L) $$,
         current_setting('t.pa'), current_setting('t.pa'), current_setting('t.d')),
  '23505', null, 'Q7 a customer cannot be active in two queues'
);
select throws_ok(
  format($$ insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind)
            values (%L, %L, 1, '2026-11-25', 'walk_in') $$,
         current_setting('t.pa'), current_setting('t.pa')),
  '23505', null, 'Q7 a ticket number is unique per pro and service day'
);
update public.queue_entries set state = 'cancelled', end_reason = 'cleared', ended_at = now()
 where pro_id = current_setting('t.pb')::uuid;

-- Q11 -----------------------------------------------------------------------------------------
-- pro B at 2026-11-26 12:00: ticket 1 serving (20 min, called 11:50), ticket 2 waiting (30 min,
-- sorted 11:55), ticket 3 waiting (no service, sorted 12:00).
select tests.freeze_now('2026-11-26 12:00+01');
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, duration_min, state, sort_at, called_at)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 1, '2026-11-26', 'walk_in', 20, 'serving',
        '2026-11-26 11:45+01', '2026-11-26 11:50+01'),
       (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 2, '2026-11-26', 'walk_in', 30, 'waiting',
        '2026-11-26 11:55+01', null),
       (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 3, '2026-11-26', 'walk_in', null, 'waiting',
        '2026-11-26 12:00+01', null);
select is(
  public.queue_wait_min(current_setting('t.pb')::uuid, '2026-11-26 12:00+01'),
  40, 'Q11 serving 20 min called 10 min ago + one 30-min entry ahead = 40'
);
select is(
  public.queue_wait_min(current_setting('t.pb')::uuid, null),
  60, 'Q11 with no position, every waiting entry counts (no service = the 20-min average)'
);
select tests.freeze_now('2026-11-26 12:03+01');
select is(
  public.queue_wait_min(current_setting('t.pb')::uuid, '2026-11-26 12:00+01'),
  40, 'Q11 7 + 30 = 37 rounds up to 40'
);
select tests.freeze_now('2026-11-26 12:20+01');
select is(
  public.queue_wait_min(current_setting('t.pb')::uuid, '2026-11-26 12:00+01'),
  35, 'Q11 an overrunning serving entry still counts 5 minutes'
);
select is(
  public.queue_wait_min(current_setting('t.pb')::uuid, '2026-11-26 11:00+01'),
  5, 'Q11 first in line waits only for the serving entry'
);

-- Q12 -----------------------------------------------------------------------------------------
-- 3 earlier served entries of 10, 12 and 14 minutes.
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, state, called_at, ended_at)
select current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 100 + m, '2026-11-26', 'walk_in', 'served',
       '2026-11-26 09:00+01'::timestamptz, '2026-11-26 09:00+01'::timestamptz + make_interval(mins => m)
from unnest(array[10, 12, 14]) m;
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select tests.freeze_now('2026-11-26 12:08+01');
select is(
  (select ticket_no from public.queue_call_next(current_setting('t.pb')::uuid, gen_random_uuid())
    where state = 'serving'),
  2, 'Q12 call next serves ticket 2 and finishes ticket 1 (18 min)'
);
select is(
  (select avg_service_min from public.pro_live where pro_id = current_setting('t.pb')::uuid),
  20::smallint, 'Q12 with 4 served entries the average stays 20'
);
select tests.freeze_now('2026-11-26 12:48+01');
select is(
  (select count(*)::int from public.queue_finish(current_setting('t.pb')::uuid, gen_random_uuid())),
  1, 'Q12 finish serves ticket 2 (40 min)'
);
select is(
  (select avg_service_min from public.pro_live where pro_id = current_setting('t.pb')::uuid),
  14::smallint, 'Q12 after 5 served entries (10, 12, 14, 18, 40) the average is the median, 14'
);
do $$ begin perform tests.clear_auth(); end; $$;
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, state, called_at, ended_at)
select current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 200 + i, '2026-11-26', 'walk_in', 'served',
       '2026-11-25 10:00+01', '2026-11-25 18:20+01'
from generate_series(1, 8) i;
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select public.queue_call_next(current_setting('t.pb')::uuid, gen_random_uuid());
-- Q4 (serving, nobody waiting): ticket 3 is serving since 12:48 and nobody waits.
select tests.freeze_now('2026-11-26 13:00+01');
select throws_ok(
  format($$ select * from public.queue_call_next(%L, gen_random_uuid()) $$, current_setting('t.pb')),
  'P0001', 'queue_empty', 'Q4 call next with someone serving but nobody waiting raises queue_empty'
);
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  (select state = 'serving' and called_at = '2026-11-26 12:48+01' and ended_at is null
     from public.queue_entries
    where pro_id = current_setting('t.pb')::uuid and service_day = '2026-11-26' and ticket_no = 3)
  and (select avg_service_min = 14 from public.pro_live where pro_id = current_setting('t.pb')::uuid),
  'Q4 the serving entry and the average are unchanged'
);
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select tests.freeze_now('2026-11-26 13:18+01');
select is(
  (select count(*)::int from public.queue_finish(current_setting('t.pb')::uuid, gen_random_uuid())),
  0, 'Q12 finish serves ticket 3 (30 min)'
);
select is(
  (select avg_service_min from public.pro_live where pro_id = current_setting('t.pb')::uuid),
  120::smallint, 'Q12 a median of 500 minutes is clamped to 120'
);
do $$ begin perform tests.clear_auth(); end; $$;
-- 21 one-minute services, ended after everything above: the last 20 are all short.
insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind, state, called_at, ended_at)
select current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 300 + i, '2026-11-26', 'walk_in', 'served',
       '2026-11-26 13:18+01'::timestamptz + make_interval(secs => i),
       '2026-11-26 13:19+01'::timestamptz + make_interval(secs => i)
from generate_series(1, 21) i;
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select tests.freeze_now('2026-11-26 13:30+01');
select public.queue_add_walk_in(current_setting('t.pb')::uuid, gen_random_uuid());
select public.queue_call_next(current_setting('t.pb')::uuid, gen_random_uuid());
select tests.freeze_now('2026-11-26 13:31+01');
select public.queue_finish(current_setting('t.pb')::uuid, gen_random_uuid());
select is(
  (select avg_service_min from public.pro_live where pro_id = current_setting('t.pb')::uuid),
  5::smallint, 'Q12 a median of 1 minute over the last 20 is clamped to 5'
);

-- Q14 -----------------------------------------------------------------------------------------
do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(format($$ select * from public.queue_add_walk_in(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 a customer cannot add a walk-in');
select throws_ok(format($$ select * from public.queue_set_details(%L, null, null, gen_random_uuid()) $$, current_setting('t.e1')),
  'P0001', 'not_owner', 'Q14 a customer cannot set details');
select throws_ok(format($$ select * from public.queue_undo_walk_in(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 a customer cannot undo');
select throws_ok(format($$ select * from public.queue_call_next(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 a customer cannot call next');
select throws_ok(format($$ select * from public.queue_finish(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 a customer cannot finish');
select throws_ok(format($$ select * from public.queue_mark_absent(%L, gen_random_uuid()) $$, current_setting('t.e4')),
  'P0001', 'not_owner', 'Q14 a customer cannot mark absent');
select throws_ok(format($$ select * from public.queue_clear(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 a customer cannot clear');
select throws_ok(format($$ select * from public.owner_queue(%L) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 a customer cannot read the owner queue');
do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(format($$ select * from public.queue_set_details(%L, null, null, gen_random_uuid()) $$, current_setting('t.e1')),
  'P0001', 'not_owner', 'Q14 another owner cannot set details on this pro''s entry');
select throws_ok(format($$ select * from public.queue_call_next(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  'P0001', 'not_owner', 'Q14 another owner cannot call next');
do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok(format($$ select * from public.queue_add_walk_in(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'Q14 anon cannot add a walk-in');
select throws_ok(format($$ select * from public.queue_set_details(%L, null, null, gen_random_uuid()) $$, current_setting('t.e1')),
  '42501', null, 'Q14 anon cannot set details');
select throws_ok(format($$ select * from public.queue_undo_walk_in(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'Q14 anon cannot undo');
select throws_ok(format($$ select * from public.queue_call_next(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'Q14 anon cannot call next');
select throws_ok(format($$ select * from public.queue_finish(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'Q14 anon cannot finish');
select throws_ok(format($$ select * from public.queue_mark_absent(%L, gen_random_uuid()) $$, current_setting('t.e4')),
  '42501', null, 'Q14 anon cannot mark absent');
select throws_ok(format($$ select * from public.queue_clear(%L, gen_random_uuid()) $$, current_setting('t.pa')),
  '42501', null, 'Q14 anon cannot clear');
select throws_ok(format($$ select * from public.owner_queue(%L) $$, current_setting('t.pa')),
  '42501', null, 'Q14 anon cannot read the owner queue');

-- Q16 -----------------------------------------------------------------------------------------
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select array_agg(distinct action order by action) from public.queue_requests
    where actor = current_setting('t.a')::uuid and pro_id = current_setting('t.pa')::uuid),
  array['queue_add_walk_in', 'queue_call_next', 'queue_clear', 'queue_finish', 'queue_mark_absent',
        'queue_set_details', 'queue_undo_walk_in'],
  'Q16 each owner RPC records its queue_requests row'
);
select is(
  (select count(*)::int from public.queue_requests
    where actor = current_setting('t.a')::uuid and request_id = current_setting('t.r1')::uuid),
  1, 'Q16 a replayed request is recorded once'
);
select ok(
  (select queue_version > 0 and last_activity_at = '2026-11-25 10:00+01'
     from public.pro_live where pro_id = current_setting('t.pa')::uuid),
  'Q16 owner actions bump queue_version and touch last_activity_at'
);

-- Q15 -----------------------------------------------------------------------------------------
select throws_ok(
  'truncate public.queue_entries',
  'P0001', 'history_is_kept', 'Q15 truncating queue_entries raises history_is_kept, even as postgres'
);
select throws_ok(
  format($$ delete from public.queue_entries where pro_id = %L $$, current_setting('t.pa')),
  'P0001', 'history_is_kept', 'Q15 deleting queue entries raises history_is_kept, even as postgres'
);
select ok(
  not has_table_privilege('authenticated', 'public.queue_entries', 'delete')
  and not has_table_privilege('authenticated', 'public.queue_entries', 'insert')
  and not has_table_privilege('authenticated', 'public.queue_entries', 'update')
  and not has_table_privilege('authenticated', 'public.queue_entries', 'select')
  and not has_table_privilege('anon', 'public.queue_entries', 'select'),
  'Q15 clients have no table privilege on queue_entries (no delete grant)'
);
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select throws_ok(
  format($$ delete from public.queue_entries where pro_id = %L $$, current_setting('t.pa')),
  '42501', null, 'Q15 the owner cannot delete queue entries'
);
do $$ begin perform tests.clear_auth(); end; $$;
delete from public.profiles where id = current_setting('t.d')::uuid;
select ok(
  (select customer_id is null from public.queue_entries
    where pro_id = current_setting('t.pb')::uuid and ticket_no = 90),
  'Q15 deleting a customer keeps the entry with customer_id set null'
);
delete from public.pro_profiles where id = current_setting('t.pa')::uuid;
select is(
  (select count(*)::int from public.queue_entries where pro_id = current_setting('t.pa')::uuid),
  0, 'Q15 deleting the pro cascades to its queue entries'
);

select * from finish();
rollback;
