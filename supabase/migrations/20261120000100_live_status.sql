-- Live status (M3): one pro_live row per pro, its status RPCs, the auto-close job and the
-- request ledger every M3 mutating RPC goes through.
--
--   * pro_live is written only by the definer RPCs and jobs below; the owner may select it,
--     customers never read it (they get snapshots, Task 3).
--   * Every live function and every default on the new tables reads public.live_now(), the one
--     time seam; pgTAP freezes it with tests.freeze_now (which redefines it in the test
--     transaction).
--   * Effective status is derived on read (live_effective): the stored row may lag the
--     per-minute job, readers never do.
--   * Every mutating RPC takes p_request_id: live_request_seen records (actor, request_id) so a
--     replayed call changes nothing, and a reused id for another action raises request_reused.
--   * Every RPC locks the pro_live row first (serializes status and queue changes per pro) and
--     calls live_broadcast once, last.
--
-- pg_cron 1.6 (local stack: 1.6.4): cron.schedule(job_name text, schedule text, command text)
-- returns bigint and replaces an existing job of the same name (pg_cron README,
-- https://github.com/citusdata/pg_cron, "Scheduling jobs"; signature checked locally with
-- pg_proc). The job runs as the role that scheduled it (postgres, owner of the functions).

create extension if not exists pg_cron;

create type public.live_status as enum ('open', 'on_break', 'closed');
create type public.queue_mode as enum ('open', 'followers', 'paused');

-- Time seam -----------------------------------------------------------------------------------

create function public.live_now()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select now();
$$;

-- The service day of a moment: the local date of (at - 6 h 30). Shifts may close past midnight
-- until 06:00, so 06:30 is after every shift of the previous day.
create function public.service_day(p_at timestamptz, p_tz text)
returns date
language sql
immutable
parallel safe
set search_path = ''
as $$
  select ((p_at - interval '6 hours 30 minutes') at time zone p_tz)::date;
$$;

-- Tables ----------------------------------------------------------------------------------------

create table public.pro_live (
  pro_id uuid primary key references public.pro_profiles on delete cascade,
  status public.live_status not null default 'closed',
  break_until timestamptz,
  auto_close_at timestamptz,
  status_changed_at timestamptz not null default public.live_now(),
  last_activity_at timestamptz not null default public.live_now(),
  queue_mode public.queue_mode not null default 'open',
  hide_queue_count boolean not null default false,
  avg_service_min smallint not null default 20 check (avg_service_min between 5 and 120),
  queue_version bigint not null default 0,
  live_version bigint not null default 0,
  check (break_until is null or status = 'on_break'),
  check ((status = 'closed') = (auto_close_at is null))
);

create index pro_live_auto_close_idx on public.pro_live (auto_close_at)
  where status <> 'closed';

create table public.queue_requests (
  actor uuid not null references public.profiles on delete cascade,
  request_id uuid not null,
  action text not null,
  pro_id uuid not null references public.pro_profiles on delete cascade,
  created_at timestamptz not null default public.live_now(),
  primary key (actor, request_id)
);

create index queue_requests_created_idx on public.queue_requests (created_at);
create index queue_requests_pro_idx on public.queue_requests (pro_id);

-- Row creation ----------------------------------------------------------------------------------

create function public.pro_live_create()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pro_live (pro_id) values (new.id) on conflict (pro_id) do nothing;
  return null;
end;
$$;

create trigger pro_live_create
after insert on public.pro_profiles
for each row execute function public.pro_live_create();

insert into public.pro_live (pro_id)
select p.id from public.pro_profiles p
on conflict (pro_id) do nothing;

-- Internal helpers ------------------------------------------------------------------------------

-- The end of the shift that contains p_at (yesterday's past-midnight shift included), else of
-- the shift starting later today, else null. Wall-clock hours are in the country's timezone.
create function public.pro_shift_end(p_pro_id uuid, p_at timestamptz)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz text;
  v_local timestamp;
  v_day date;
  v_time time;
  v_hours public.pro_hours;
begin
  select c.timezone into v_tz
  from public.pro_profiles p
  join public.geo_countries c on c.code = p.country_code
  where p.id = p_pro_id;
  if v_tz is null then
    return null;
  end if;

  v_local := p_at at time zone v_tz;
  v_day := v_local::date;
  v_time := v_local::time;

  select h.* into v_hours
  from public.pro_hours h
  where h.pro_id = p_pro_id
    and h.weekday = extract(isodow from v_day - 1)::smallint
    and h.crosses_midnight
    and v_time < h.closes;
  if found then
    return (v_day + v_hours.closes) at time zone v_tz;
  end if;

  select h.* into v_hours
  from public.pro_hours h
  where h.pro_id = p_pro_id and h.weekday = extract(isodow from v_day)::smallint;
  if not found then
    return null;
  end if;
  if v_hours.crosses_midnight then
    return (v_day + 1 + v_hours.closes) at time zone v_tz;
  end if;
  if v_time < v_hours.closes then
    return (v_day + v_hours.closes) at time zone v_tz;
  end if;
  return null;
end;
$$;

create function public.live_touch(p_pro_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.pro_live l set last_activity_at = public.live_now() where l.pro_id = p_pro_id;
$$;

-- STUB: Task 3 adds the realtime.send of the snapshot. Keep this signature.
-- live_version moves on every broadcast (the client's ordering key for snapshots);
-- queue_version only when the queue changed (the owner queue and ticket refetch on it).
create function public.live_broadcast(p_pro_id uuid, p_queue_changed boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.pro_live l
     set live_version = l.live_version + 1,
         queue_version = l.queue_version + case when p_queue_changed then 1 else 0 end
   where l.pro_id = p_pro_id;
end;
$$;

-- Returns true when (p_actor, p_request_id) was already recorded for this action and pro: the
-- caller then returns its current result without changing anything.
create function public.live_request_seen(
  p_actor uuid,
  p_request_id uuid,
  p_action text,
  p_pro_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seen public.queue_requests;
begin
  if p_request_id is null then
    raise exception 'request_id_required';
  end if;

  insert into public.queue_requests (actor, request_id, action, pro_id)
  values (p_actor, p_request_id, p_action, p_pro_id)
  on conflict (actor, request_id) do nothing;
  if found then
    return false;
  end if;

  select r.* into v_seen
  from public.queue_requests r
  where r.actor = p_actor and r.request_id = p_request_id;
  if v_seen.action <> p_action or v_seen.pro_id <> p_pro_id then
    raise exception 'request_reused';
  end if;
  return true;
end;
$$;

-- Closes every row whose auto_close_at has passed; one broadcast per closed pro.
create function public.live_auto_close()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pro_id uuid;
  v_count integer := 0;
begin
  for v_pro_id in
    update public.pro_live l
       set status = 'closed', break_until = null, auto_close_at = null,
           status_changed_at = public.live_now()
     where l.status <> 'closed' and l.auto_close_at <= public.live_now()
    returning l.pro_id
  loop
    perform public.live_broadcast(v_pro_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Reads -----------------------------------------------------------------------------------------

-- Closed once auto_close_at passed, whatever the row says; stale when open or on break with no
-- owner activity for 2 h.
create function public.live_effective(p_live public.pro_live)
returns table (status public.live_status, stale boolean)
language sql
stable
set search_path = ''
as $$
  select e.status,
         e.status <> 'closed' and p_live.last_activity_at <= public.live_now() - interval '2 hours'
  from (
    select case
             when p_live.status <> 'closed' and p_live.auto_close_at <= public.live_now()
               then 'closed'::public.live_status
             else p_live.status
           end as status
  ) e;
$$;

-- RPCs ------------------------------------------------------------------------------------------

-- p_break_until only with on_break (null = no return time), in the future and at most 4 h away.
-- Opening (or a break) from closed sets auto_close_at to the shift end (now + 3 h when there is
-- none) + 30 min; switching between open and on_break keeps it, so an extension is not lost.
create function public.set_live_status(
  p_pro_id uuid,
  p_status public.live_status,
  p_break_until timestamptz,
  p_request_id uuid
)
returns public.pro_live
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := public.live_now();
  v_live public.pro_live;
  v_auto_close_at timestamptz;
begin
  select l.* into v_live
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'set_live_status', p_pro_id) then
    return v_live;
  end if;

  if p_status is null then
    raise exception 'invalid_status';
  end if;
  if p_break_until is not null
     and (p_status <> 'on_break' or p_break_until <= v_now
          or p_break_until > v_now + interval '4 hours') then
    raise exception 'invalid_break_until';
  end if;

  if p_status = 'closed' then
    v_auto_close_at := null;
  elsif v_live.status <> 'closed' and v_live.auto_close_at > v_now then
    v_auto_close_at := v_live.auto_close_at;
  else
    v_auto_close_at := coalesce(public.pro_shift_end(p_pro_id, v_now), v_now + interval '3 hours')
                       + interval '30 minutes';
  end if;

  update public.pro_live l
     set status = p_status,
         break_until = p_break_until,
         auto_close_at = v_auto_close_at,
         status_changed_at = case when l.status = p_status then l.status_changed_at else v_now end
   where l.pro_id = p_pro_id;
  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id);

  select l.* into v_live from public.pro_live l where l.pro_id = p_pro_id;
  return v_live;
end;
$$;

-- +60 min, capped at now + 12 h but never earlier than the current close. Allowed while open or on break (not effective-closed).
create function public.extend_auto_close(p_pro_id uuid, p_request_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := public.live_now();
  v_live public.pro_live;
  v_auto_close_at timestamptz;
begin
  select l.* into v_live
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'extend_auto_close', p_pro_id) then
    return v_live.auto_close_at;
  end if;

  if (select e.status from public.live_effective(v_live) e) = 'closed' then
    raise exception 'not_open';
  end if;

  -- A long shift may already close beyond the cap: the cap limits the extension, it never
  -- brings the close earlier.
  v_auto_close_at := greatest(v_live.auto_close_at,
                              least(v_live.auto_close_at + interval '60 minutes',
                                    v_now + interval '12 hours'));
  update public.pro_live l set auto_close_at = v_auto_close_at where l.pro_id = p_pro_id;
  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id);
  return v_auto_close_at;
end;
$$;

-- RLS and grants --------------------------------------------------------------------------------

alter table public.pro_live enable row level security;
alter table public.queue_requests enable row level security;

revoke all on public.pro_live, public.queue_requests from anon, authenticated;
grant select on public.pro_live to authenticated;

create policy pro_live_select_own on public.pro_live
for select to authenticated
using (
  public.owns_pro(pro_id)
);

revoke execute on function
  public.live_now(),
  public.service_day(timestamptz, text),
  public.pro_live_create(),
  public.pro_shift_end(uuid, timestamptz),
  public.live_touch(uuid),
  public.live_broadcast(uuid, boolean),
  public.live_request_seen(uuid, uuid, text, uuid),
  public.live_auto_close(),
  public.live_effective(public.pro_live),
  public.set_live_status(uuid, public.live_status, timestamptz, uuid),
  public.extend_auto_close(uuid, uuid)
from public, anon;

revoke execute on function
  public.pro_live_create(),
  public.pro_shift_end(uuid, timestamptz),
  public.live_touch(uuid),
  public.live_broadcast(uuid, boolean),
  public.live_request_seen(uuid, uuid, text, uuid),
  public.live_auto_close()
from authenticated;

grant execute on function
  public.live_now(),
  public.service_day(timestamptz, text),
  public.live_effective(public.pro_live),
  public.set_live_status(uuid, public.live_status, timestamptz, uuid),
  public.extend_auto_close(uuid, uuid)
to authenticated;

-- Jobs ------------------------------------------------------------------------------------------

select cron.schedule('lemqes_live_auto_close', '* * * * *', 'select public.live_auto_close()');
