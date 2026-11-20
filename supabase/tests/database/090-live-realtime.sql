begin;
select plan(92);

-- Calendar (Africa/Algiers, UTC+1, no DST): 2026-11-23 is a Monday (create_pro gives Monday
-- 09:00-18:00); time is frozen at 10:00, then at Tuesday 07:00 for the end-of-day job.
-- pa (Salon Amine) takes every client RPC; pb (Salon Bilal) carries the status fixtures; pu is
-- unpublished; pw is in the women space.
--
-- Broadcast assertions read realtime.messages, partitioned by the real insert time (not
-- live_now). `supabase db reset` leaves partitions for yesterday .. +3 days; a stack up for more
-- than 3 days with no client connection has none for today and realtime.send then silently
-- inserts nothing (spike finding f): R0 says so instead of letting every R7 fail obscurely.
do $$
begin
  perform set_config('t.a', tests.create_account('213550000900', 'men', 'barber', 'Amine')::text, true);
  perform set_config('t.b', tests.create_account('213550000901', 'men', 'barber', 'Bilal')::text, true);
  perform set_config('t.u', tests.create_account('213550000902', 'men', 'barber', 'Unpub')::text, true);
  perform set_config('t.ow', tests.create_account('213550000903', 'women', 'home_artist', 'Wassila')::text, true);
  perform set_config('t.c', tests.create_account('213550000904', 'men', 'customer', 'Chafik')::text, true);
  perform set_config('t.d', tests.create_account('213550000905', 'men', 'customer', 'Djamel')::text, true);
  perform set_config('t.e', tests.create_account('213550000906', 'men', 'customer', 'Elias')::text, true);
  perform set_config('t.wc', tests.create_account('213550000907', 'women', 'customer', 'Wafa')::text, true);
  perform set_config('t.pa', tests.create_pro(current_setting('t.a')::uuid, 'barber', 'Salon Amine')::text, true);
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Salon Bilal')::text, true);
  perform set_config('t.pu', tests.create_pro(current_setting('t.u')::uuid, 'barber', 'Hidden', published => false)::text, true);
  perform set_config('t.pw', tests.create_pro(current_setting('t.ow')::uuid, 'home_artist', 'Lina')::text, true);
end;
$$;
select tests.freeze_now('2026-11-23 10:00+01');
delete from realtime.messages;

-- Exactly one broadcast since the last call, on pro:<p_pro>, event live, private, its payload
-- (minus the id realtime.send adds) equal to the pro's snapshot now; 'ok' or what differs.
-- Clears the messages either way. Runs as postgres (live_snapshot is internal).
create function tests.one_broadcast(p_pro uuid)
returns text
language plpgsql
as $$
declare
  v_n integer;
  v_m realtime.messages;
begin
  select count(*) into v_n from realtime.messages;
  select m.* into v_m from realtime.messages m limit 1;
  delete from realtime.messages;
  if v_n <> 1 then
    return 'rows=' || v_n;
  end if;
  if v_m.topic is distinct from 'pro:' || p_pro then
    return 'topic=' || v_m.topic;
  end if;
  if v_m.event is distinct from 'live' or v_m.extension is distinct from 'broadcast' then
    return 'event=' || v_m.event || ' extension=' || v_m.extension;
  end if;
  if v_m.private is not true then
    return 'not private';
  end if;
  if not (v_m.payload ? 'id') then
    return 'no id';
  end if;
  if (v_m.payload - 'id') is distinct from public.live_snapshot(p_pro) then
    return 'payload=' || (v_m.payload - 'id')::text || ' snapshot=' || public.live_snapshot(p_pro)::text;
  end if;
  return 'ok';
end;
$$;

create function tests.broadcast_count()
returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  select count(*) into v_n from realtime.messages;
  delete from realtime.messages;
  return v_n;
end;
$$;

-- R0 ------------------------------------------------------------------------------------------

select ok(
  exists (
    select 1 from pg_inherits i join pg_class c on c.oid = i.inhrelid
    where i.inhparent = 'realtime.messages'::regclass
      and c.relname = 'messages_' || to_char(timezone('utc', clock_timestamp()), 'YYYY_MM_DD')),
  'R0 today''s realtime.messages partition exists (missing: Realtime creates it ~18 s after '
  '`supabase db reset`, or the stack has been up > 3 days with no client: reset, wait, rerun)'
);

-- Contract ------------------------------------------------------------------------------------

select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('live_snapshot', 'pro_live_snapshots', 'live_broadcast',
                      'live_topic_allowed', 'queue_end_of_day', 'pro_profiles_live_broadcast')
      and prosecdef
      and proconfig @> array['search_path=""']),
  6,
  'the live realtime functions are security definer with search_path = '''''
);
select is(
  (select count(*)::int from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('live_snapshot', 'pro_live_snapshots', 'live_broadcast',
                      'live_topic_allowed', 'queue_end_of_day', 'pro_profiles_live_broadcast',
                      'search_pros')
      and (has_function_privilege('anon', oid, 'execute')
           or has_function_privilege('public', oid, 'execute'))),
  0,
  'no live realtime function (nor search_pros) is executable by anon or public'
);
select ok(
  has_function_privilege('authenticated', 'public.pro_live_snapshots(uuid[])', 'execute')
  and has_function_privilege('authenticated', 'public.live_topic_allowed(text)', 'execute'),
  'pro_live_snapshots and live_topic_allowed are executable by authenticated'
);

-- R1 ------------------------------------------------------------------------------------------

select is(
  (select array_agg(k order by k collate "C")
     from jsonb_object_keys(public.live_snapshot(current_setting('t.pa')::uuid)) k),
  array['ahead_minutes', 'auto_close_at', 'break_until', 'join_block', 'listed', 'pro_id',
        'queue_mode', 'queue_version', 'server_now', 'serving_called_at', 'serving_duration_min',
        'status', 'status_age_from', 'wait_min', 'waiting_count'],
  'R1 the snapshot keys are exactly the Approach list'
);
select ok(
  not exists (
    select 1 from jsonb_object_keys(public.live_snapshot(current_setting('t.pa')::uuid)) k
    where k ~ 'name|customer|phone' or k = 'id'),
  'R1 no snapshot key carries a name, a customer, a phone, or a top-level id'
);
select is(
  public.live_snapshot(current_setting('t.pa')::uuid) ->> 'pro_id', current_setting('t.pa'),
  'R1 the snapshot names its pro'
);
select is(
  public.live_snapshot(current_setting('t.pa')::uuid) -> 'listed', 'true'::jsonb,
  'R1 a published pro is listed'
);

-- R2 ------------------------------------------------------------------------------------------

insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind)
values (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 1, '2026-11-23', 'walk_in');
select is(
  public.live_snapshot(current_setting('t.pb')::uuid) -> 'waiting_count', '1'::jsonb,
  'R2 waiting_count counts the waiting entries when shown'
);
update public.pro_live set hide_queue_count = true where pro_id = current_setting('t.pb')::uuid;
select ok(
  (public.live_snapshot(current_setting('t.pb')::uuid) -> 'waiting_count') = 'null'::jsonb,
  'R2 waiting_count is null when the pro hides it'
);
select is(
  public.live_snapshot(current_setting('t.pb')::uuid) -> 'wait_min', '20'::jsonb,
  'R2 wait_min is still present when the count is hidden'
);
select is(
  public.live_snapshot(current_setting('t.pb')::uuid) -> 'ahead_minutes', '20'::jsonb,
  'R2 ahead_minutes sums the waiting durations (the average when no service)'
);

-- R3 ------------------------------------------------------------------------------------------

select is(public.live_snapshot(current_setting('t.pb')::uuid) ->> 'join_block', 'closed',
  'R3 closed -> join_block closed');
update public.pro_live
   set status = 'open', auto_close_at = '2026-11-23 09:59+01', last_activity_at = '2026-11-23 09:00+01'
 where pro_id = current_setting('t.pb')::uuid;
select is(
  (select array[s ->> 'status', s ->> 'join_block']
     from public.live_snapshot(current_setting('t.pb')::uuid) s),
  array['closed', 'closed'],
  'R3 open past auto_close_at -> effective status closed, join_block closed'
);
update public.pro_live
   set auto_close_at = '2026-11-23 19:30+01', last_activity_at = '2026-11-23 07:59+01'
 where pro_id = current_setting('t.pb')::uuid;
select is(
  (select array[s ->> 'status', s ->> 'join_block']
     from public.live_snapshot(current_setting('t.pb')::uuid) s),
  array['open', 'closed'],
  'R3 stale open (2 h without activity) -> join_block closed'
);
update public.pro_live
   set status = 'on_break', break_until = '2026-11-23 10:30+01', last_activity_at = '2026-11-23 10:00+01'
 where pro_id = current_setting('t.pb')::uuid;
select is(public.live_snapshot(current_setting('t.pb')::uuid) ->> 'join_block', 'on_break',
  'R3 on break with a return time -> on_break');
update public.pro_live set break_until = null, queue_mode = 'paused'
 where pro_id = current_setting('t.pb')::uuid;
select is(public.live_snapshot(current_setting('t.pb')::uuid) ->> 'join_block', 'on_break',
  'R3 on break without a return time (even paused) -> on_break');
update public.pro_live set status = 'open' where pro_id = current_setting('t.pb')::uuid;
select is(public.live_snapshot(current_setting('t.pb')::uuid) ->> 'join_block', 'paused',
  'R3 open and paused -> paused');
update public.pro_live set queue_mode = 'followers' where pro_id = current_setting('t.pb')::uuid;
select is(public.live_snapshot(current_setting('t.pb')::uuid) ->> 'join_block', 'followers',
  'R3 open and followers-only -> followers');
update public.pro_live set queue_mode = 'open' where pro_id = current_setting('t.pb')::uuid;
select ok((public.live_snapshot(current_setting('t.pb')::uuid) -> 'join_block') = 'null'::jsonb,
  'R3 open, fresh and queue open -> join_block null');
update public.pro_live
   set status = 'open', auto_close_at = '2026-11-23 19:30+01'
 where pro_id = current_setting('t.pu')::uuid;
select is(public.live_snapshot(current_setting('t.pu')::uuid) ->> 'join_block', 'closed',
  'R3 an unpublished pro, even open -> closed');

-- R4 ------------------------------------------------------------------------------------------

update public.pro_live set last_activity_at = '2026-11-23 09:58:59+01'
 where pro_id = current_setting('t.pb')::uuid;
select is(
  (public.live_snapshot(current_setting('t.pb')::uuid) ->> 'status_age_from')::timestamptz,
  '2026-11-23 09:55+01'::timestamptz,
  'R4 status_age_from is last_activity_at rounded down to 5 min'
);
update public.pro_live set last_activity_at = '2026-11-23 10:00+01'
 where pro_id = current_setting('t.pb')::uuid;
select is(
  (public.live_snapshot(current_setting('t.pb')::uuid) ->> 'status_age_from')::timestamptz,
  '2026-11-23 10:00+01'::timestamptz,
  'R4 a time on the 5-minute grid stays as is'
);
select is(
  (public.live_snapshot(current_setting('t.pb')::uuid) ->> 'server_now')::timestamptz,
  '2026-11-23 10:00+01'::timestamptz,
  'R4 server_now is live_now()'
);
delete from realtime.messages;

-- R5 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select results_eq(
  format($$ select pro_id from public.pro_live_snapshots(array[%L, %L, %L, %L, null]::uuid[])
            order by pro_id $$,
         current_setting('t.pa'), current_setting('t.pb'), current_setting('t.pu'),
         current_setting('t.pw')),
  format($$ select x from unnest(array[%L, %L]::uuid[]) x order by x $$,
         current_setting('t.pa'), current_setting('t.pb')),
  'R5 a customer gets snapshots of listable pros only (other space, unpublished, null dropped)'
);
select is(
  (select count(*)::int from public.pro_live_snapshots(
     array[current_setting('t.pa'), current_setting('t.pa')]::uuid[])),
  1, 'R5 a repeated id gives one row'
);
select is(
  (select count(*)::int from public.pro_live_snapshots(
     (select array_agg(gen_random_uuid()) from generate_series(1, 60)))),
  0, 'R5 60 ids are accepted'
);
select throws_ok(
  $$ select * from public.pro_live_snapshots(
       (select array_agg(gen_random_uuid()) from generate_series(1, 61))) $$,
  'too_many_ids', 'R5 61 ids -> too_many_ids'
);
do $$
begin
  perform set_config('t.snap',
    (select s.live::text from public.pro_live_snapshots(array[current_setting('t.pb')]::uuid[]) s),
    true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select is(current_setting('t.snap')::jsonb, public.live_snapshot(current_setting('t.pb')::uuid),
  'R5 the live object is the snapshot');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select results_eq(
  format($$ select pro_id from public.pro_live_snapshots(array[%L, %L, %L]::uuid[]) $$,
         current_setting('t.pa'), current_setting('t.pb'), current_setting('t.pu')),
  format($$ values (%L::uuid) $$, current_setting('t.pa')),
  'R5 an owner acting as barber gets its own pro only'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- R6 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
do $$
begin
  perform set_config('t.search',
    (select s.live::text from public.search_pros() s where s.pro_id = current_setting('t.pb')::uuid),
    true);
end;
$$;
select is(
  (select count(*)::int from public.search_pros() s where (s.live ->> 'pro_id')::uuid = s.pro_id),
  (select count(*)::int from public.search_pros()),
  'R6 every search row carries its own pro''s live object'
);
do $$ begin perform tests.clear_auth(); end; $$;
select is(current_setting('t.search')::jsonb, public.live_snapshot(current_setting('t.pb')::uuid),
  'R6 search_pros live equals live_snapshot for the same pro');
do $$ begin perform tests.authenticate_as(current_setting('t.wc')::uuid); end; $$;
select results_eq(
  $$ select s.pro_id, s.live ->> 'pro_id' from public.search_pros() s $$,
  format($$ values (%L::uuid, %L::text) $$, current_setting('t.pw'), current_setting('t.pw')),
  'R6 a women customer gets only the women pro and its live object'
);
do $$ begin perform tests.clear_auth(); end; $$;

-- R7 ------------------------------------------------------------------------------------------
-- Every client mutating RPC runs as authenticated (postgres would bypass RLS and hide a missing
-- definer) and sends exactly one broadcast; replays and refusals send none.

delete from realtime.messages;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                              '00000000-0000-4000-8000-000000000001');
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 set_live_status broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select public.set_live_status(current_setting('t.pa')::uuid, 'open', null,
                              '00000000-0000-4000-8000-000000000001');
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.broadcast_count(), 0, 'R7 a replayed request sends nothing');

do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  format($$ select public.set_live_status(%L, 'closed', null, gen_random_uuid()) $$,
         current_setting('t.pa')),
  'not_owner', 'R7 another barber cannot change the status');
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.broadcast_count(), 0, 'R7 a refused RPC sends nothing');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select public.extend_auto_close(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 extend_auto_close broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
do $$
begin
  perform set_config('t.walk',
    (select q.entry_id::text
       from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid()) q
      order by q.ticket_no desc limit 1),
    true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_add_walk_in broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_set_details(current_setting('t.walk')::uuid, 'Zinedine', null,
                                               gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select ok(strpos(public.live_snapshot(current_setting('t.pa')::uuid)::text, 'Zinedine') = 0,
  'R7 a walk-in name never reaches the snapshot');
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_set_details broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_undo_walk_in(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_undo_walk_in broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
do $$
begin
  perform set_config('t.ec',
    (public.join_queue(current_setting('t.pa')::uuid, null, gen_random_uuid())).entry_id::text, true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 join_queue broadcasts once');
select ok(
  strpos(public.live_snapshot(current_setting('t.pa')::uuid)::text, 'Chafik') = 0
  and strpos(public.live_snapshot(current_setting('t.pa')::uuid)::text, current_setting('t.c')) = 0,
  'R7 a customer''s name and id never reach the snapshot');

do $$ begin perform tests.authenticate_as(current_setting('t.wc')::uuid); end; $$;
select throws_ok(
  format($$ select public.join_queue(%L, null, gen_random_uuid()) $$, current_setting('t.pa')),
  'not_listable', 'R7 a women customer cannot join a men pro');
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.broadcast_count(), 0, 'R7 a refused join sends nothing');

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select public.queue_on_my_way(current_setting('t.ec')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_on_my_way broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_call_next(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select ok(
  public.live_snapshot(current_setting('t.pa')::uuid) ->> 'serving_called_at' is not null
  and (public.live_snapshot(current_setting('t.pa')::uuid) -> 'serving_duration_min') = '20'::jsonb,
  'R7 the snapshot carries the serving entry''s call time and duration');
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_call_next broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_finish(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_finish broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.d')::uuid); end; $$;
do $$
begin
  perform set_config('t.ed',
    (public.join_queue(current_setting('t.pa')::uuid, null, gen_random_uuid())).entry_id::text, true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select tests.broadcast_count();
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_mark_absent(current_setting('t.ed')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_mark_absent broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.e')::uuid); end; $$;
do $$
begin
  perform set_config('t.ee',
    (public.join_queue(current_setting('t.pa')::uuid, null, gen_random_uuid())).entry_id::text, true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select tests.broadcast_count();
do $$ begin perform tests.authenticate_as(current_setting('t.e')::uuid); end; $$;
select public.leave_queue(current_setting('t.ee')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 leave_queue broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_add_walk_in(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select tests.broadcast_count();
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_clear(current_setting('t.pa')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_clear broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select public.set_queue_settings(current_setting('t.pa')::uuid, null, true, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 set_queue_settings broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_block(current_setting('t.ed')::uuid, gen_random_uuid());
do $$
begin
  perform set_config('t.block',
    (select b.block_id::text from public.queue_blocked(current_setting('t.pa')::uuid) b limit 1),
    true);
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_block broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.queue_unblock(current_setting('t.pa')::uuid,
                                           current_setting('t.block')::uuid, gen_random_uuid());
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok', 'R7 queue_unblock broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select count(*) from public.my_ticket();
select count(*) from public.pro_live_snapshots(array[current_setting('t.pa')]::uuid[]);
select count(*) from public.search_pros();
do $$ begin perform tests.clear_auth(); end; $$;
do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select count(*) from public.owner_queue(current_setting('t.pa')::uuid);
select count(*) from public.queue_blocked(current_setting('t.pa')::uuid);
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.broadcast_count(), 0, 'R7 read RPCs send nothing');

-- R8 ------------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
update public.pro_profiles set display_name = 'Salon Amine II'
 where id = current_setting('t.pa')::uuid;
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.one_broadcast(current_setting('t.pa')::uuid), 'ok',
  'R8 a direct client display_name update broadcasts once');

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
update public.pro_profiles set bio = 'Depuis 2010' where id = current_setting('t.pa')::uuid;
do $$ begin perform tests.clear_auth(); end; $$;
select is(tests.broadcast_count(), 0, 'R8 an update of another column sends nothing');

do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
update public.pro_services set active = false where pro_id = current_setting('t.pb')::uuid;
do $$ begin perform tests.clear_auth(); end; $$;
select is(
  (select array[m.topic, m.payload ->> 'join_block', m.private::text] from realtime.messages m),
  array['pro:' || current_setting('t.pb'), 'closed', 'true'],
  'R8 unpublishing (last service deactivated) broadcasts join_block closed'
);
select is(
  (select m.payload -> 'listed' from realtime.messages m), 'false'::jsonb,
  'R8 unpublishing broadcasts listed = false'
);
select is(tests.one_broadcast(current_setting('t.pb')::uuid), 'ok', 'R8 ... exactly once');

-- R9 ------------------------------------------------------------------------------------------

select realtime.send(jsonb_build_object('probe', 1), 'live', 'pro:' || current_setting('t.pa'), true);
select ok(
  exists (select 1 from pg_policy
           where polname = 'live_topics' and polrelid = 'realtime.messages'::regclass
             and polcmd = 'r' and polroles = array['authenticated'::regrole::oid]),
  'R9 live_topics is a select policy for authenticated on realtime.messages'
);
select is(
  (select count(*)::int from pg_policy
    where polrelid = 'realtime.messages'::regclass and polcmd in ('a', '*')),
  0, 'R9 no insert policy on realtime.messages (clients cannot send)'
);

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select ok(public.live_topic_allowed('pro:' || current_setting('t.pa')), 'R9 owner: own topic allowed');
select ok(not public.live_topic_allowed('pro:' || current_setting('t.pb')),
  'R9 acting as barber: another pro''s topic refused');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select ok(public.live_topic_allowed('pro:' || current_setting('t.pa')),
  'R9 same-space customer: listable pro allowed');
select ok(not public.live_topic_allowed('pro:' || current_setting('t.pw')),
  'R9 customer: other-space pro refused');
select ok(not public.live_topic_allowed('pro:' || current_setting('t.pu')),
  'R9 customer: unpublished pro refused');
select ok(not public.live_topic_allowed('pro:abc'), 'R9 pro:abc refused without error');
select ok(not public.live_topic_allowed('pro:' || current_setting('t.pa') || 'x'),
  'R9 pro:<uuid>x refused without error');
select ok(not public.live_topic_allowed('pro:------------------------------------'),
  'R9 a uuid-length run of dashes refused without error');
select ok(not public.live_topic_allowed('PRO:' || current_setting('t.pa')),
  'R9 another prefix refused');
select ok(not coalesce(public.live_topic_allowed(null), false), 'R9 null refused');
select set_config('realtime.topic', 'pro:' || current_setting('t.pa'), true);
select ok((select count(*) from realtime.messages) > 0,
  'R9 policy: a same-space customer reads the topic''s broadcasts');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.wc')::uuid); end; $$;
select set_config('realtime.topic', 'pro:' || current_setting('t.pa'), true);
select is((select count(*)::int from realtime.messages), 0,
  'R9 policy: an other-space customer reads nothing on the topic');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as_anon(); end; $$;
select set_config('realtime.topic', 'pro:' || current_setting('t.pa'), true);
select is((select count(*)::int from realtime.messages), 0, 'R9 anon reads nothing on the topic');
select throws_ok(
  format($$ select public.live_topic_allowed(%L) $$, 'pro:' || current_setting('t.pa')),
  '42501', null, 'R9 anon cannot call live_topic_allowed');
do $$ begin perform tests.clear_auth(); end; $$;
select set_config('realtime.topic', '', true);
delete from realtime.messages;

-- R10 -----------------------------------------------------------------------------------------
-- Tuesday 07:00 is service day 2026-11-24; Monday's entries still waiting or serving are ended.

select tests.freeze_now('2026-11-24 07:00+01');
update public.queue_entries
   set state = 'removed', end_reason = 'undo', ended_at = '2026-11-23 18:00+01'
 where state in ('waiting', 'serving');
insert into public.queue_entries
  (pro_id, served_by, ticket_no, service_day, kind, state, called_at, created_at, sort_at)
values
  (current_setting('t.pa')::uuid, current_setting('t.pa')::uuid, 100, '2026-11-23', 'walk_in',
   'waiting', null, '2026-11-23 17:00+01', '2026-11-23 17:00+01'),
  (current_setting('t.pa')::uuid, current_setting('t.pa')::uuid, 101, '2026-11-23', 'walk_in',
   'serving', '2026-11-23 17:30+01', '2026-11-23 16:00+01', '2026-11-23 16:00+01'),
  (current_setting('t.pa')::uuid, current_setting('t.pa')::uuid, 1, '2026-11-24', 'walk_in',
   'waiting', null, '2026-11-24 06:45+01', '2026-11-24 06:45+01'),
  (current_setting('t.pb')::uuid, current_setting('t.pb')::uuid, 100, '2026-11-23', 'walk_in',
   'waiting', null, '2026-11-23 17:00+01', '2026-11-23 17:00+01');
insert into public.queue_requests (actor, request_id, action, pro_id, created_at)
values
  (current_setting('t.c')::uuid, '00000000-0000-4000-8000-0000000000a1', 'join_queue',
   current_setting('t.pa')::uuid, '2026-11-21 06:59+01'),
  (current_setting('t.c')::uuid, '00000000-0000-4000-8000-0000000000a2', 'join_queue',
   current_setting('t.pa')::uuid, '2026-11-22 07:01+01');
do $$
begin
  perform set_config('t.qv', (select queue_version::text from public.pro_live
                               where pro_id = current_setting('t.pa')::uuid), true);
end;
$$;

select is(public.queue_end_of_day(), 3, 'R10 queue_end_of_day returns the number of ended entries');
select results_eq(
  format($$ select ticket_no, state::text, end_reason::text, ended_at from public.queue_entries
             where pro_id = %L and ticket_no in (100, 101, 1) and service_day >= '2026-11-23'
               and (ticket_no <> 1 or service_day = '2026-11-24')
             order by service_day, ticket_no $$, current_setting('t.pa')),
  $$ values (100, 'cancelled'::text, 'end_of_day'::text, '2026-11-24 07:00+01'::timestamptz),
            (101, 'cancelled', 'end_of_day', '2026-11-24 07:00+01'::timestamptz),
            (1, 'waiting', null, null::timestamptz) $$,
  'R10 yesterday''s waiting and serving are cancelled end_of_day; today''s entry is kept'
);
select is(
  (select state::text from public.queue_entries
    where pro_id = current_setting('t.pb')::uuid and ticket_no = 100 and service_day = '2026-11-23'),
  'cancelled', 'R10 every pro''s earlier entries are ended'
);
select is(
  (select array_agg(topic order by topic) from realtime.messages),
  (select array_agg(t order by t) from unnest(array['pro:' || current_setting('t.pa'),
                                                    'pro:' || current_setting('t.pb')]) t),
  'R10 one broadcast per affected pro'
);
select ok(
  (select bool_and((m.payload - 'id') = public.live_snapshot(substr(m.topic, 5)::uuid))
     from realtime.messages m),
  'R10 each broadcast is the pro''s fresh snapshot'
);
select ok(
  (select queue_version from public.pro_live where pro_id = current_setting('t.pa')::uuid)
    > current_setting('t.qv')::bigint,
  'R10 the queue version moves for an affected pro'
);
select results_eq(
  $$ select request_id from public.queue_requests
      where request_id in ('00000000-0000-4000-8000-0000000000a1',
                           '00000000-0000-4000-8000-0000000000a2') $$,
  $$ values ('00000000-0000-4000-8000-0000000000a2'::uuid) $$,
  'R10 requests older than 2 days are pruned, newer ones kept'
);
delete from realtime.messages;
select is(
  (select schedule from cron.job where jobname = 'lemqes_queue_end_of_day'),
  '30 5 * * *', 'R10 the job runs at 05:30 UTC (06:30 Africa/Algiers)'
);
select lives_ok(
  (select command from cron.job where jobname = 'lemqes_queue_end_of_day'),
  'R10 the job''s command text runs'
);
select is(tests.broadcast_count(), 0, 'R10 a second run has nothing left to end');

-- R11 -----------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.c')::uuid); end; $$;
select throws_ok(
  format($$ select public.live_snapshot(%L) $$, current_setting('t.pa')),
  '42501', null, 'R11 authenticated cannot call live_snapshot');
select throws_ok(
  format($$ select public.live_broadcast(%L, false) $$, current_setting('t.pa')),
  '42501', null, 'R11 authenticated cannot call live_broadcast');
select throws_ok(
  $$ select public.queue_end_of_day() $$,
  '42501', null, 'R11 authenticated cannot call queue_end_of_day');
select throws_ok(
  format($$ select public.queue_wait_min(%L, null) $$, current_setting('t.pa')),
  '42501', null, 'R11 authenticated cannot call queue_wait_min');
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
