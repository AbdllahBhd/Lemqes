-- Live realtime (M3 Task 3): snapshots, the live column of search_pros, real broadcasts on
-- private channels, the channel policy and the end-of-day job.
--
--   * live_snapshot(pro) is the one shape a client ever sees of a pro's live state: in
--     search_pros (live), in pro_live_snapshots and in every broadcast. It carries no name, no
--     customer and no phone, and never a top-level id (realtime.send keeps an existing id and the
--     message id would be lost; spike finding b).
--   * A customer the pro blocked sees it permanently closed, and nothing else: their reads
--     (pro_live_snapshots, search_pros) get the closed shape a genuinely closed pro gives, their
--     channel is refused (so the real broadcasts never reach them), and join_queue refuses them
--     pro_not_open (20261120000210).
--   * live_broadcast sends it with realtime.send(..., private => true) on topic pro:<id>; a
--     public send can be read by any client in any space (spike finding c). Every RPC and job
--     calls it once, last; the one trigger is on pro_profiles, which clients update directly.
--     realtime.send swallows its errors (and inserts nothing when today's realtime.messages
--     partition is missing): pgTAP asserts the inserted rows.
--   * Channel authorization: the live_topics select policy on realtime.messages, checked by
--     Realtime when a client joins a private channel. RLS is already enabled on that table by
--     Supabase; migrations must not enable it (Supabase docs, Realtime Authorization). No insert
--     policy: clients never send on pro:* topics.
--   * Internal helpers (live_snapshot, live_broadcast, queue_end_of_day, queue_wait_min, ...) are
--     not executable by clients.
--
-- realtime.send(payload jsonb, event text, topic text, private boolean default true) returns void
-- (local stack, pg_get_functiondef; spike FINDINGS.md). pg_cron 1.6 cron.schedule(job_name,
-- schedule, command) replaces a job of the same name (see 20261120000100).

-- Snapshot ---------------------------------------------------------------------------------------

-- status is the effective status (closed once auto_close_at passed); break_until and
-- auto_close_at are raw so the client derives "Pause prolongée" and the close on its own.
-- join_block: closed (effective-closed, stale or unpublished), on_break (no return time or past
-- it; live_status_joinable), paused, followers, else null. status_age_from = last_activity_at
-- rounded down to 5 min (coarse presence).
-- listed = published: an unpublish broadcast tells subscribed customers to drop the pro (the
-- channel stays authorized until they leave, since authorization is checked at join only).
-- serving_duration_min and ahead_minutes count the pro's average for an entry without a service,
-- as queue_wait_min does.
-- Closed (effective-closed, or blocked for p_viewer): no times, no age, no queue and no wait,
-- whoever reads it, so a blocked viewer's snapshot is exactly a closed pro's. A blocked viewer
-- also reads the versions, queue_mode and count_hidden frozen on the block (pro_blocks): their
-- snapshot never moves, as a pro that stayed closed (server_now apart). count_hidden (hide_queue_count): the count, ahead_minutes,
-- the serving fields and queue_version would recount it exactly, so they are left out and only
-- wait_min, already rounded up to 5, remains. p_viewer: the reading customer (null for
-- broadcasts, which every subscriber shares).
create function public.live_snapshot(p_pro_id uuid, p_viewer uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_live public.pro_live;
  v_effective record;
  v_published boolean;
  v_serving_called_at timestamptz;
  v_serving_duration_min integer;
  v_waiting integer;
  v_ahead integer;
  v_closed boolean;
  v_block public.pro_blocks;
  v_blocked boolean := false;
  v_hidden boolean;
  v_snapshot jsonb;
begin
  select l.* into v_live from public.pro_live l where l.pro_id = p_pro_id;
  if not found then
    return null;
  end if;
  select e.* into v_effective from public.live_effective(v_live) e;
  select p.published_at is not null into v_published
  from public.pro_profiles p where p.id = p_pro_id;
  if p_viewer is not null then
    select b.* into v_block
    from public.pro_blocks b
    where b.pro_id = p_pro_id and b.customer_id = p_viewer;
    v_blocked := found;
  end if;
  v_closed := v_effective.status = 'closed' or v_blocked;
  v_hidden := case when v_blocked then v_block.frozen_count_hidden else v_live.hide_queue_count end;

  select e.called_at, coalesce(e.duration_min, v_live.avg_service_min)
    into v_serving_called_at, v_serving_duration_min
  from public.queue_entries e
  where e.pro_id = p_pro_id and e.state = 'serving'
  limit 1;

  select count(*)::integer, coalesce(sum(coalesce(e.duration_min, v_live.avg_service_min)), 0)
    into v_waiting, v_ahead
  from public.queue_entries e
  where e.pro_id = p_pro_id and e.state = 'waiting';

  v_snapshot := jsonb_build_object(
    'pro_id', p_pro_id,
    'status', case when v_closed then 'closed'::public.live_status else v_effective.status end,
    'break_until', case when not v_closed then v_live.break_until end,
    'auto_close_at', case when not v_closed then v_live.auto_close_at end,
    'status_age_from', case when not v_closed then
                         date_bin('5 minutes', v_live.last_activity_at,
                                  timestamptz '2000-01-01 00:00:00+00') end,
    'queue_mode', case when v_blocked then v_block.frozen_queue_mode else v_live.queue_mode end,
    'listed', coalesce(v_published, false),
    'count_hidden', v_hidden,
    'join_block', case
                    when v_published is not true or v_closed or v_effective.stale then 'closed'
                    when not public.live_status_joinable(v_live) then 'on_break'
                    when v_live.queue_mode = 'paused' then 'paused'
                    when v_live.queue_mode = 'followers' then 'followers'
                  end,
    'wait_min', case when not v_closed then public.queue_wait_min(p_pro_id, null) end,
    'live_version', case when v_blocked then v_block.frozen_live_version
                         else v_live.live_version end,
    'server_now', public.live_now()
  );
  if v_hidden then
    return v_snapshot;
  end if;
  return v_snapshot || jsonb_build_object(
    'waiting_count', case when not v_closed then v_waiting end,
    'serving_called_at', case when not v_closed then v_serving_called_at end,
    'serving_duration_min', case when not v_closed then v_serving_duration_min end,
    'ahead_minutes', case when not v_closed then v_ahead end,
    'queue_version', case when v_blocked then v_block.frozen_queue_version
                          else v_live.queue_version end
  );
end;
$$;

-- Batched reads (cards re-fetch on subscribe and on resume): a customer gets the listable pros of
-- the list (closed for one that blocked them), an owner its own; other ids are dropped silently.
-- At most 60 ids per call.
create function public.pro_live_snapshots(p_pro_ids uuid[])
returns table (pro_id uuid, live jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if cardinality(p_pro_ids) > 60 then
    raise exception 'too_many_ids';
  end if;

  return query
  select i.id, public.live_snapshot(i.id, (select auth.uid()))
  from (select distinct u.id from unnest(p_pro_ids) u(id) where u.id is not null) i
  where public.owns_pro(i.id) or public.is_listable(i.id)
  order by i.id;
end;
$$;

-- Broadcast --------------------------------------------------------------------------------------

-- Same signature as the 20261120000100 stub; now also sends the snapshot.
create or replace function public.live_broadcast(p_pro_id uuid, p_queue_changed boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_snapshot jsonb;
begin
  -- The row update also serializes concurrent broadcasts of one pro (the pro_profiles trigger
  -- path takes no pro_live lock first): live_version orders their snapshots strictly, where
  -- server_now (transaction start) can tie or invert.
  update public.pro_live l
     set live_version = l.live_version + 1,
         queue_version = l.queue_version + case when p_queue_changed then 1 else 0 end
   where l.pro_id = p_pro_id;

  v_snapshot := public.live_snapshot(p_pro_id);
  if v_snapshot is not null then
    perform realtime.send(v_snapshot, 'live', 'pro:' || p_pro_id::text, true);
  end if;
end;
$$;

-- Clients update pro_profiles directly (column grants), and publishing changes are made by M2
-- RPCs and triggers: any change of what a live card shows or of listability is broadcast once.
-- A plain WHEN (not UPDATE OF): pro_profiles_before_write may unpublish without the column being
-- in the statement.
create function public.pro_profiles_live_broadcast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.live_broadcast(new.id);
  return null;
end;
$$;

create trigger pro_profiles_live_broadcast
after update on public.pro_profiles
for each row
when (old.published_at is distinct from new.published_at
      or old.display_name is distinct from new.display_name
      or old.avatar_path is distinct from new.avatar_path)
execute function public.pro_profiles_live_broadcast();

-- Channel authorization --------------------------------------------------------------------------

-- The topic is checked against the full uuid shape before the cast, so a malformed topic is a
-- refusal, never an error. A customer the pro blocked is refused: the broadcasts carry the real
-- state, and that customer reads the closed shape from fetches only.
create function public.live_topic_allowed(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_topic is null
     or p_topic !~ '^pro:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  v_id := substr(p_topic, 5)::uuid;
  return public.owns_pro(v_id)
      or (public.is_listable(v_id)
          and not exists (select 1 from public.pro_blocks b
                          where b.pro_id = v_id and b.customer_id = auth.uid()));
end;
$$;

-- The helper is wrapped in a select so it runs once per query (initPlan), not per row; the row's
-- own topic must be the joined one, so a client authorized on one topic reads no other's rows.
create policy live_topics on realtime.messages
for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and realtime.messages.topic = (select realtime.topic())
  and (select public.live_topic_allowed((select realtime.topic())))
);

-- search_pros ------------------------------------------------------------------------------------

-- Same parameters, M2 columns and body as 20261119000100, plus live (the pro's snapshot). Still
-- security invoker: live comes through pro_live_snapshots, which applies the same listable rule.
-- The page is cut first so snapshots are built for the returned rows only.
drop function public.search_pros(text, text, integer, boolean, public.service_category, int, int);

create function public.search_pros(
  p_query text default null,
  p_region_code text default null,
  p_locality_id integer default null,
  p_kids boolean default null,
  p_category public.service_category default null,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  pro_id uuid,
  kind public.pro_kind,
  display_name text,
  avatar_path text,
  workplace_type public.workplace_type,
  workplace_name text,
  region_code text,
  region_name_ar text,
  region_name_fr text,
  locality_name_ar text,
  locality_name_fr text,
  customer_mix public.customer_mix,
  min_price_dzd integer,
  is_verified boolean,
  live jsonb
)
language sql
stable
security invoker
set search_path = ''
as $$
  with q as (
    select '%' || replace(replace(replace(
             lower(public.f_unaccent(nullif(btrim(p_query), ''))),
             '\', '\\'), '%', '\%'), '_', '\_') || '%' as pattern
  ),
  page as (
    select p.id, p.kind, p.display_name, p.avatar_path, p.workplace_type, p.workplace_name,
           l.region_code, r.name_ar as region_name_ar, r.name_fr as region_name_fr,
           l.name_ar as locality_name_ar, l.name_fr as locality_name_fr, p.customer_mix,
           (select min(s.price_dzd) from public.pro_public_services(p.id) s) as min_price_dzd,
           p.is_verified, p.published_at
    from public.pro_profiles p
    cross join q
    left join public.geo_localities l on l.id = p.locality_id
    left join public.geo_regions r on r.country_code = l.country_code and r.code = l.region_code
    where p.published_at is not null
      and p.space = (select public.current_space())
      and (select public.acts_as('customer'))
      and (p_region_code is null or l.region_code = p_region_code)
      and (p_locality_id is null or p.locality_id = p_locality_id)
      and (p_kids is not true or p.customer_mix in ('adults_and_kids', 'kids_only'))
      and (p_category is null or exists (
        select 1 from public.pro_public_services(p.id) s where s.category = p_category
      ))
      and (q.pattern is null
        or lower(public.f_unaccent(p.display_name)) like q.pattern
        or lower(public.f_unaccent(coalesce(p.workplace_name, ''))) like q.pattern
        or exists (
          select 1
          from public.pro_public_services(p.id) s
          left join public.service_presets sp on sp.key = s.preset_key
          where lower(public.f_unaccent(concat_ws(' ', s.name, sp.name_ar, sp.name_fr, sp.name_en,
                                                  sp.name_kab))) like q.pattern
        ))
    order by p.is_verified desc, p.published_at desc, p.id
    limit least(greatest(coalesce(p_limit, 30), 0), 50)
    offset least(greatest(coalesce(p_offset, 0), 0), 1000)
  )
  select g.id, g.kind, g.display_name, g.avatar_path, g.workplace_type, g.workplace_name,
         g.region_code, g.region_name_ar, g.region_name_fr, g.locality_name_ar,
         g.locality_name_fr, g.customer_mix, g.min_price_dzd, g.is_verified,
         (select s.live from public.pro_live_snapshots(array[g.id]) s)
  from page g
  order by g.is_verified desc, g.published_at desc, g.id;
$$;

-- End of day -------------------------------------------------------------------------------------

-- Ends every entry still waiting or serving from an earlier service day (country timezone)
-- 'end_of_day', one broadcast per affected pro, and prunes the request ledger older than 2 days.
-- Locks the affected pro_live rows first, in id order, like the RPCs it may race with.
-- Returns the number of entries ended.
create function public.queue_end_of_day()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := public.live_now();
  v_pros uuid[];
  v_pro_id uuid;
  v_count integer;
begin
  perform 1
  from public.pro_live l
  where l.pro_id in (
    select e.pro_id
    from public.queue_entries e
    join public.pro_profiles p on p.id = e.pro_id
    join public.geo_countries c on c.code = p.country_code
    where e.state in ('waiting', 'serving')
      and e.service_day < public.service_day(v_now, c.timezone))
  order by l.pro_id
  for update;

  with ended as (
    update public.queue_entries e
       set state = 'cancelled', end_reason = 'end_of_day', ended_at = v_now
      from public.pro_profiles p
      join public.geo_countries c on c.code = p.country_code
     where p.id = e.pro_id
       and e.state in ('waiting', 'serving')
       and e.service_day < public.service_day(v_now, c.timezone)
    returning e.pro_id
  )
  select array_agg(distinct x.pro_id), count(*)::integer into v_pros, v_count from ended x;

  foreach v_pro_id in array coalesce(v_pros, '{}'::uuid[]) loop
    perform public.live_broadcast(v_pro_id, true);
  end loop;

  delete from public.queue_requests r where r.created_at < v_now - interval '2 days';
  return v_count;
end;
$$;

-- Grants -----------------------------------------------------------------------------------------

revoke execute on function
  public.live_snapshot(uuid, uuid),
  public.pro_live_snapshots(uuid[]),
  public.pro_profiles_live_broadcast(),
  public.live_topic_allowed(text),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int),
  public.queue_end_of_day()
from public, anon;

revoke execute on function
  public.live_snapshot(uuid, uuid),
  public.pro_profiles_live_broadcast(),
  public.queue_end_of_day()
from authenticated;

grant execute on function
  public.pro_live_snapshots(uuid[]),
  public.live_topic_allowed(text),
  public.search_pros(text, text, integer, boolean, public.service_category, int, int)
to authenticated;

-- Jobs -------------------------------------------------------------------------------------------

-- 05:30 UTC = 06:30 Africa/Algiers, the start of a service day.
select cron.schedule('lemqes_queue_end_of_day', '30 5 * * *', 'select public.queue_end_of_day()');
