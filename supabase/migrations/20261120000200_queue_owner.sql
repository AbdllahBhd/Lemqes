-- Live queue (M3 Task 2a): queue entries and the owner's actions on them.
--
--   * queue_entries is history: rows change state but are never deleted (a before-delete
--     trigger raises history_is_kept unless the delete cascades from the pro being deleted; a
--     before-truncate trigger refuses truncate, which service_role still holds by default).
--   * Clients have no table privilege; owners act through the definer RPCs below and read
--     owner_queue_row, which never carries a customer id. Labels carry no UI text: an entry
--     without a name has a null label and the app shows its localized "Client N".
--   * Every owner RPC locks the pro's pro_live row first (for update): ticket numbers, call next
--     and finish are serialized per pro, so two devices tapping at once never serve two people.
--     supabase/tests/race/call_next_race.sh proves it with two sessions.
--   * Every owner RPC records its request (live_request_seen): a replay returns the current queue
--     and changes nothing. Then live_touch, and live_broadcast(pro, true) once, last.
--   * Time is public.live_now(); ticket numbers restart each service_day (country timezone).

create type public.queue_kind as enum ('walk_in', 'remote');
create type public.queue_state as enum
  ('waiting', 'serving', 'served', 'absent', 'cancelled', 'removed');
create type public.queue_end_reason as enum ('cleared', 'end_of_day', 'left', 'blocked', 'undo');

-- Tables ----------------------------------------------------------------------------------------

-- served_by = pro_id until M7 (salon staff). customer_id is set for remote entries only and
-- becomes null when the customer deletes the account (the entry stays as history). name is the
-- walk-in's optional label, with the same invisible-character class as 20261114000200.
-- duration_min and price_dzd are snapshotted from the service when it is set (null = average).
create table public.queue_entries (
  id uuid primary key default gen_random_uuid(),
  pro_id uuid not null references public.pro_profiles on delete cascade,
  served_by uuid not null references public.pro_profiles on delete cascade,
  ticket_no integer not null check (ticket_no > 0),
  service_day date not null,
  kind public.queue_kind not null,
  customer_id uuid references public.profiles on delete set null,
  name text check (
    name is null
    or (char_length(name) between 1 and 40 and name = btrim(name)
        and name !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]')
  ),
  service_id uuid references public.pro_services on delete set null,
  duration_min smallint check (duration_min between 5 and 300),
  price_dzd integer check (price_dzd between 0 and 200000),
  state public.queue_state not null default 'waiting',
  end_reason public.queue_end_reason,
  sort_at timestamptz not null default public.live_now(),
  on_my_way_at timestamptz,
  called_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default public.live_now(),
  check (kind = 'remote' or customer_id is null),
  check (kind = 'walk_in' or name is null),
  check ((state in ('waiting', 'serving')) = (ended_at is null)),
  check (end_reason is null or ended_at is not null),
  check (state <> 'serving' or called_at is not null),
  constraint queue_entries_ticket_key unique (pro_id, service_day, ticket_no)
);

create unique index queue_entries_active_remote_idx on public.queue_entries (customer_id)
  where state in ('waiting', 'serving') and kind = 'remote';
create unique index queue_entries_serving_idx on public.queue_entries (served_by)
  where state = 'serving';
create index queue_entries_active_idx on public.queue_entries (pro_id, sort_at)
  where state in ('waiting', 'serving');
create index queue_entries_served_idx on public.queue_entries (pro_id, ended_at desc)
  where state = 'served';
create index queue_entries_served_by_idx on public.queue_entries (served_by);
create index queue_entries_customer_idx on public.queue_entries (customer_id);
create index queue_entries_service_idx on public.queue_entries (service_id);

-- A delete is allowed only once the pro is gone (the FK cascade): the parent row is no longer
-- visible to the cascading statement.
create function public.queue_entries_keep_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.pro_profiles p where p.id = old.pro_id)
     and exists (select 1 from public.pro_profiles p where p.id = old.served_by) then
    raise exception 'history_is_kept';
  end if;
  return old;
end;
$$;

create trigger queue_entries_keep_history
before delete on public.queue_entries
for each row execute function public.queue_entries_keep_history();

-- Truncate skips row triggers; refuse it outright.
create function public.queue_entries_no_truncate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'history_is_kept';
end;
$$;

create trigger queue_entries_no_truncate
before truncate on public.queue_entries
for each statement execute function public.queue_entries_no_truncate();

-- What an owner sees: no customer id, ever. label = walk-in name, else the remote customer's
-- full_name, else null (the app builds the localized "Client <ticket_no>").
-- position: 0 for the serving entry, 1.. for waiting.
create type public.owner_queue_row as (
  entry_id uuid,
  ticket_no integer,
  kind public.queue_kind,
  label text,
  service_id uuid,
  duration_min smallint,
  state public.queue_state,
  on_my_way_at timestamptz,
  called_at timestamptz,
  sort_at timestamptz,
  position integer
);

-- Internal helpers ------------------------------------------------------------------------------

-- Minutes until someone sorted at p_before_sort_at is called (null = after everyone waiting):
-- what is left of the serving entry (at least 5) + every waiting entry ahead, an entry without a
-- service counting the pro's average; rounded up to 5.
create function public.queue_wait_min(p_pro_id uuid, p_before_sort_at timestamptz)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select (ceil((
           coalesce((
             select greatest(coalesce(e.duration_min, l.avg_service_min)
                             - extract(epoch from public.live_now() - e.called_at) / 60, 5)
             from public.queue_entries e
             where e.pro_id = p_pro_id and e.state = 'serving'
             limit 1), 0)
           + coalesce((
             select sum(coalesce(e.duration_min, l.avg_service_min))
             from public.queue_entries e
             where e.pro_id = p_pro_id and e.state = 'waiting'
               and (p_before_sort_at is null or e.sort_at < p_before_sort_at)), 0)
         ) / 5.0) * 5)::integer
  from public.pro_live l
  where l.pro_id = p_pro_id;
$$;

-- Marks the serving entry served at now and recomputes the average: the median of
-- (ended_at - called_at) over the last 20 served, clamped 5..120; 20 until 5 exist.
-- Returns false when nobody was serving. The caller holds the pro_live lock.
create function public.queue_serve_current(p_pro_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.queue_entries e
     set state = 'served', ended_at = public.live_now()
   where e.pro_id = p_pro_id and e.state = 'serving';
  if not found then
    return false;
  end if;

  update public.pro_live l
     set avg_service_min = (
       select case
                when count(*) < 5 then 20
                else least(greatest(round(percentile_cont(0.5) within group (order by s.minutes)),
                                    5), 120)
              end::smallint
       from (
         select extract(epoch from e.ended_at - e.called_at) / 60 as minutes
         from public.queue_entries e
         where e.pro_id = p_pro_id and e.state = 'served' and e.called_at is not null
         order by e.ended_at desc
         limit 20
       ) s)
   where l.pro_id = p_pro_id;
  return true;
end;
$$;

-- Reads -----------------------------------------------------------------------------------------

create function public.owner_queue(p_pro_id uuid)
returns setof public.owner_queue_row
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.owns_pro(p_pro_id) then
    raise exception 'not_owner';
  end if;

  return query
  select e.id, e.ticket_no, e.kind,
         coalesce(e.name, c.full_name),
         e.service_id, e.duration_min, e.state, e.on_my_way_at, e.called_at, e.sort_at,
         case
           when e.state = 'serving' then 0
           else (row_number() over (partition by e.state
                                    order by e.sort_at, e.created_at, e.ticket_no))::integer
         end
  from public.queue_entries e
  left join public.profiles c on c.id = e.customer_id
  where e.pro_id = p_pro_id and e.state in ('waiting', 'serving')
  order by e.state = 'waiting', e.sort_at, e.created_at, e.ticket_no;
end;
$$;

-- Owner RPCs ------------------------------------------------------------------------------------
-- Each one: owner check + pro_live row lock in one statement (not_owner), the request ledger
-- (a replay returns the queue unchanged), the change, live_touch, live_broadcast, the queue.

create function public.queue_add_walk_in(p_pro_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day date;
begin
  select public.service_day(public.live_now(), c.timezone) into v_day
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  join public.geo_countries c on c.code = p.country_code
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_add_walk_in', p_pro_id) then
    return query select * from public.owner_queue(p_pro_id);
    return;
  end if;

  insert into public.queue_entries (pro_id, served_by, ticket_no, service_day, kind)
  select p_pro_id, p_pro_id, coalesce(max(e.ticket_no), 0) + 1, v_day, 'walk_in'
  from public.queue_entries e
  where e.pro_id = p_pro_id and e.service_day = v_day;

  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id, true);
  return query select * from public.owner_queue(p_pro_id);
end;
$$;

-- p_name: walk-ins only, trimmed, blank = none, at most 40 visible characters. p_service_id:
-- one of this pro's active, unarchived services, or null (= the average). Duration and price are
-- snapshotted when the service changes; keeping the same service keeps the snapshot.
create function public.queue_set_details(
  p_entry_id uuid,
  p_name text,
  p_service_id uuid,
  p_request_id uuid
)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
  v_service public.pro_services;
  v_name text := nullif(btrim(p_name), '');
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.pro_profiles p on p.id = e.pro_id
  where e.id = p_entry_id and p.owner_id = auth.uid();
  if not found then
    raise exception 'not_owner';
  end if;
  perform 1 from public.pro_live l where l.pro_id = v_entry.pro_id for update;
  select e.* into v_entry from public.queue_entries e where e.id = p_entry_id;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_set_details', v_entry.pro_id) then
    return query select * from public.owner_queue(v_entry.pro_id);
    return;
  end if;

  if v_entry.state not in ('waiting', 'serving') then
    raise exception 'entry_not_active';
  end if;
  if v_name is not null
     and (v_entry.kind <> 'walk_in' or char_length(v_name) > 40
          or v_name ~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]') then
    raise exception 'invalid_name';
  end if;

  if p_service_id is not distinct from v_entry.service_id then
    v_service.duration_min := v_entry.duration_min;
    v_service.price_dzd := v_entry.price_dzd;
  elsif p_service_id is not null then
    select s.* into v_service
    from public.pro_services s
    where s.id = p_service_id and s.pro_id = v_entry.pro_id
      and s.active and s.archived_at is null;
    if not found then
      raise exception 'invalid_service';
    end if;
  end if;

  update public.queue_entries e
     set name = v_name,
         service_id = p_service_id,
         duration_min = v_service.duration_min,
         price_dzd = v_service.price_dzd
   where e.id = p_entry_id;

  perform public.live_touch(v_entry.pro_id);
  perform public.live_broadcast(v_entry.pro_id, true);
  return query select * from public.owner_queue(v_entry.pro_id);
end;
$$;

-- Removes the most recently added walk-in still waiting (a mistaken +1); remote entries and the
-- serving entry are never undone.
create function public.queue_undo_walk_in(p_pro_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_id uuid;
begin
  perform 1
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_undo_walk_in', p_pro_id) then
    return query select * from public.owner_queue(p_pro_id);
    return;
  end if;

  select e.id into v_entry_id
  from public.queue_entries e
  where e.pro_id = p_pro_id and e.state = 'waiting' and e.kind = 'walk_in'
  order by e.created_at desc, e.ticket_no desc
  limit 1;
  if not found then
    raise exception 'nothing_to_undo';
  end if;

  update public.queue_entries e
     set state = 'removed', end_reason = 'undo', ended_at = public.live_now()
   where e.id = v_entry_id;

  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id, true);
  return query select * from public.owner_queue(p_pro_id);
end;
$$;

-- Finishes the serving entry (if any) and serves the first waiting by sort_at.
create function public.queue_call_next(p_pro_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_id uuid;
begin
  perform 1
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_call_next', p_pro_id) then
    return query select * from public.owner_queue(p_pro_id);
    return;
  end if;

  select e.id into v_entry_id
  from public.queue_entries e
  where e.pro_id = p_pro_id and e.state = 'waiting'
  order by e.sort_at, e.created_at, e.ticket_no
  limit 1;
  if not found then
    raise exception 'queue_empty';
  end if;

  perform public.queue_serve_current(p_pro_id);
  update public.queue_entries e
     set state = 'serving', called_at = public.live_now()
   where e.id = v_entry_id;

  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id, true);
  return query select * from public.owner_queue(p_pro_id);
end;
$$;

create function public.queue_finish(p_pro_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_finish', p_pro_id) then
    return query select * from public.owner_queue(p_pro_id);
    return;
  end if;

  if not public.queue_serve_current(p_pro_id) then
    raise exception 'nothing_serving';
  end if;

  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id, true);
  return query select * from public.owner_queue(p_pro_id);
end;
$$;

-- A remote customer who did not show up (waiting or called). Walk-ins are in front of the
-- barber: they are undone or cleared instead.
create function public.queue_mark_absent(p_entry_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  join public.pro_profiles p on p.id = e.pro_id
  where e.id = p_entry_id and p.owner_id = auth.uid();
  if not found then
    raise exception 'not_owner';
  end if;
  perform 1 from public.pro_live l where l.pro_id = v_entry.pro_id for update;
  select e.* into v_entry from public.queue_entries e where e.id = p_entry_id;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_mark_absent', v_entry.pro_id) then
    return query select * from public.owner_queue(v_entry.pro_id);
    return;
  end if;

  if v_entry.kind <> 'remote' then
    raise exception 'not_remote';
  end if;
  if v_entry.state not in ('waiting', 'serving') then
    raise exception 'entry_not_active';
  end if;

  update public.queue_entries e
     set state = 'absent', ended_at = public.live_now()
   where e.id = p_entry_id;

  perform public.live_touch(v_entry.pro_id);
  perform public.live_broadcast(v_entry.pro_id, true);
  return query select * from public.owner_queue(v_entry.pro_id);
end;
$$;

-- Cancels everyone waiting; the serving entry is left to finish.
create function public.queue_clear(p_pro_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_clear', p_pro_id) then
    return query select * from public.owner_queue(p_pro_id);
    return;
  end if;

  update public.queue_entries e
     set state = 'cancelled', end_reason = 'cleared', ended_at = public.live_now()
   where e.pro_id = p_pro_id and e.state = 'waiting';

  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id, true);
  return query select * from public.owner_queue(p_pro_id);
end;
$$;

-- RLS and grants --------------------------------------------------------------------------------

alter table public.queue_entries enable row level security;
revoke all on public.queue_entries from anon, authenticated;

revoke execute on function
  public.queue_entries_keep_history(),
  public.queue_entries_no_truncate(),
  public.queue_wait_min(uuid, timestamptz),
  public.queue_serve_current(uuid),
  public.owner_queue(uuid),
  public.queue_add_walk_in(uuid, uuid),
  public.queue_set_details(uuid, text, uuid, uuid),
  public.queue_undo_walk_in(uuid, uuid),
  public.queue_call_next(uuid, uuid),
  public.queue_finish(uuid, uuid),
  public.queue_mark_absent(uuid, uuid),
  public.queue_clear(uuid, uuid)
from public, anon;

revoke execute on function
  public.queue_entries_keep_history(),
  public.queue_entries_no_truncate(),
  public.queue_wait_min(uuid, timestamptz),
  public.queue_serve_current(uuid)
from authenticated;

grant execute on function
  public.owner_queue(uuid),
  public.queue_add_walk_in(uuid, uuid),
  public.queue_set_details(uuid, text, uuid, uuid),
  public.queue_undo_walk_in(uuid, uuid),
  public.queue_call_next(uuid, uuid),
  public.queue_finish(uuid, uuid),
  public.queue_mark_absent(uuid, uuid),
  public.queue_clear(uuid, uuid)
to authenticated;
