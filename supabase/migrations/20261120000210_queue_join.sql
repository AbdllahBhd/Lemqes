-- Live queue (M3 Task 2b): customers join remotely, the abuse limits that guard it, the owner's
-- queue settings and blocks.
--
--   * can_join is the one place the join rules live (M10 extends it); internal, join_queue runs
--     it (the customer's own half, join_customer_check, also before the lock). It raises the first
--     failing code in a fixed order the app maps to messages: not_listable, own_queue,
--     pro_not_open, queue_paused, already_in_queue, join_limit_reached, absent_block,
--     join_unavailable. join_unavailable is deliberately neutral: a refusal never reveals a block,
--     and a block ends the ticket 'cleared' (customers select their own rows, so 'blocked' would
--     tell). queue_end_reason 'blocked' is unused since M3 (kept for compatibility).
--   * Customer RPCs follow the owner pattern of 20261120000200: lock the pro's pro_live row
--     (ticket numbers stay serialized with the owner's actions), record the request (a replay
--     returns the current ticket and changes nothing), change, live_broadcast once, last. They
--     do not live_touch: last_activity_at is owner presence.
--   * Customers read their own queue_entries rows (RLS) and their ticket through my_ticket; an
--     owner never reads a customer id (owner_queue_row, queue_blocked).
--   * The active-entry index of 20261120000200 is remote-only, so a walk-in typed by the barber
--     never collides with the same person's remote ticket.

-- Tables ----------------------------------------------------------------------------------------

-- ticket_label is the owner's label at block time (the customer's full_name): the owner's list
-- of blocks shows it, never the customer id.
create table public.pro_blocks (
  id uuid primary key default gen_random_uuid(),
  pro_id uuid not null references public.pro_profiles on delete cascade,
  customer_id uuid not null references public.profiles on delete cascade,
  ticket_label text,
  created_at timestamptz not null default public.live_now(),
  constraint pro_blocks_pro_customer_key unique (pro_id, customer_id)
);

create index pro_blocks_customer_idx on public.pro_blocks (customer_id);

-- What a customer sees of their own ticket and its pro. position: 0 serving, 1.. waiting, null
-- once ended; wait_min only while waiting.
create type public.my_ticket_row as (
  entry_id uuid,
  pro_id uuid,
  pro_space public.space,
  ticket_no integer,
  state public.queue_state,
  end_reason public.queue_end_reason,
  position integer,
  wait_min integer,
  on_my_way_at timestamptz,
  called_at timestamptz,
  ended_at timestamptz,
  display_name text,
  avatar_path text
);

-- Internal helpers ------------------------------------------------------------------------------

create function public.queue_ticket(p_entry_id uuid)
returns public.my_ticket_row
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.pro_id, p.space, e.ticket_no, e.state,
         e.end_reason,
         case e.state
           when 'serving' then 0
           when 'waiting' then (
             select count(*)::integer + 1
             from public.queue_entries o
             where o.pro_id = e.pro_id and o.state = 'waiting'
               and (o.sort_at, o.created_at, o.ticket_no) < (e.sort_at, e.created_at, e.ticket_no))
         end,
         case when e.state = 'waiting' then public.queue_wait_min(e.pro_id, e.sort_at) end,
         e.on_my_way_at, e.called_at, e.ended_at, p.display_name, p.avatar_path
  from public.queue_entries e
  join public.pro_profiles p on p.id = e.pro_id
  where e.id = p_entry_id;
$$;

-- Join rules ------------------------------------------------------------------------------------

-- The live-status half of the join rule, shared with live_snapshot's join_block (which must not
-- raise): fresh and effective-open, or on a break before its return time. A break with no return
-- time, or past it ("Pause prolongée"), is not joinable.
create function public.live_status_joinable(p_live public.pro_live)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    e.stale = false
      and (e.status = 'open'
           or (e.status = 'on_break' and p_live.break_until > public.live_now())),
    false)
  from public.live_effective(p_live) e;
$$;

-- The caller's own half of the join rule, in can_join's order: already_in_queue,
-- join_limit_reached, absent_block, join_unavailable (blocked by this pro). It reads only the
-- caller's rows and the pro's block list, so join_queue runs it before taking the pro's lock.
-- Absents: blocked while a 2nd absent within 7 days of another one is less than 24 h old.
create function public.join_customer_check(p_pro_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := public.live_now();
  v_tz text;
begin
  if exists (
    select 1 from public.queue_entries e
    where e.customer_id = v_uid and e.kind = 'remote' and e.state in ('waiting', 'serving')
  ) then
    raise exception 'already_in_queue';
  end if;

  select c.timezone into v_tz
  from public.pro_profiles p
  join public.geo_countries c on c.code = p.country_code
  where p.id = p_pro_id;
  if v_tz is null then
    raise exception 'not_listable';
  end if;
  if (select count(*) from public.queue_entries e
       where e.customer_id = v_uid and e.kind = 'remote'
         and e.service_day = public.service_day(v_now, v_tz)) >= 5 then
    raise exception 'join_limit_reached';
  end if;

  if exists (
    select 1
    from public.queue_entries a2
    where a2.customer_id = v_uid and a2.state = 'absent'
      and a2.ended_at > v_now - interval '24 hours'
      and exists (
        select 1 from public.queue_entries a1
        where a1.customer_id = v_uid and a1.state = 'absent' and a1.id <> a2.id
          and a1.ended_at between a2.ended_at - interval '7 days' and a2.ended_at)
  ) then
    raise exception 'absent_block';
  end if;

  if exists (
    select 1 from public.pro_blocks b where b.pro_id = p_pro_id and b.customer_id = v_uid
  ) then
    raise exception 'join_unavailable';
  end if;
end;
$$;

-- Raises the first failing rule for the caller joining p_pro_id; returns when joining is allowed.
-- Internal (join_queue runs it under the pro's lock): a client-callable can_join would be a free
-- probe of the rules, blocks included.
create function public.can_join(p_pro_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_live public.pro_live;
begin
  if not public.is_listable(p_pro_id) then
    raise exception 'not_listable';
  end if;
  if public.owns_pro(p_pro_id) then
    raise exception 'own_queue';
  end if;

  select l.* into v_live from public.pro_live l where l.pro_id = p_pro_id;
  if not found or not public.live_status_joinable(v_live) then
    raise exception 'pro_not_open';
  end if;

  if v_live.queue_mode is distinct from 'open' then
    raise exception 'queue_paused';
  end if;

  perform public.join_customer_check(p_pro_id);
end;
$$;

-- Customer RPCs ---------------------------------------------------------------------------------

-- p_service_id: one of this pro's active, unarchived services, or null (= the average).
-- Duration and price are snapshotted. A replay returns the caller's latest ticket at this pro.
create function public.join_queue(p_pro_id uuid, p_service_id uuid, p_request_id uuid)
returns public.my_ticket_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_day date;
  v_service public.pro_services;
  v_entry_id uuid;
  v_constraint text;
begin
  -- Before the lock, so no account can lock a pro it may not join (another space, unpublished,
  -- or a customer refused on their own account: active ticket, limits, block; so a refused
  -- customer hears their own code before pro_not_open). A replay skips the customer half: its
  -- ticket is the active entry. The full can_join runs again under the lock.
  if not public.is_listable(p_pro_id) then
    raise exception 'not_listable';
  end if;
  if public.owns_pro(p_pro_id) then
    raise exception 'own_queue';
  end if;
  if not exists (
    select 1 from public.queue_requests r where r.actor = v_uid and r.request_id = p_request_id
  ) then
    perform public.join_customer_check(p_pro_id);
  end if;

  select public.service_day(public.live_now(), c.timezone) into v_day
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  join public.geo_countries c on c.code = p.country_code
  where l.pro_id = p_pro_id
  for update of l;
  if not found then
    raise exception 'not_listable';
  end if;

  if public.live_request_seen(v_uid, p_request_id, 'join_queue', p_pro_id) then
    return (
      select public.queue_ticket(e.id)
      from public.queue_entries e
      where e.pro_id = p_pro_id and e.customer_id = v_uid and e.kind = 'remote'
      order by e.created_at desc, e.ticket_no desc
      limit 1);
  end if;

  perform public.can_join(p_pro_id);

  if p_service_id is not null then
    select s.* into v_service
    from public.pro_services s
    where s.id = p_service_id and s.pro_id = p_pro_id and s.active and s.archived_at is null;
    if not found then
      raise exception 'invalid_service';
    end if;
  end if;

  -- The pro_live lock serializes joins per pro, not per customer: two joins at two pros at once
  -- both pass can_join, and the remote-only unique index refuses the second.
  begin
    insert into public.queue_entries
      (pro_id, served_by, ticket_no, service_day, kind, customer_id, service_id, duration_min,
       price_dzd)
    select p_pro_id, p_pro_id, coalesce(max(e.ticket_no), 0) + 1, v_day, 'remote', v_uid,
           p_service_id, v_service.duration_min, v_service.price_dzd
    from public.queue_entries e
    where e.pro_id = p_pro_id and e.service_day = v_day
    returning id into v_entry_id;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'queue_entries_active_remote_idx' then
      raise exception 'already_in_queue';
    end if;
    raise;
  end;

  perform public.live_broadcast(p_pro_id, true);
  return public.queue_ticket(v_entry_id);
end;
$$;

-- Stamps on_my_way_at (waiting, or called but not there yet); the queue order is unchanged.
-- Only the caller's own remote entry: anything else is entry_not_active, like an ended one.
create function public.queue_on_my_way(p_entry_id uuid, p_request_id uuid)
returns public.my_ticket_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  where e.id = p_entry_id and e.customer_id = auth.uid() and e.kind = 'remote';
  if not found then
    raise exception 'entry_not_active';
  end if;
  -- Already on the way: nothing to change, so no ledger row, no lock and no broadcast (a client
  -- repeating the call cannot make the pro's subscribers re-render).
  if v_entry.on_my_way_at is not null and v_entry.state in ('waiting', 'serving') then
    return public.queue_ticket(p_entry_id);
  end if;
  perform 1 from public.pro_live l where l.pro_id = v_entry.pro_id for update;
  select e.* into v_entry from public.queue_entries e where e.id = p_entry_id;

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_on_my_way', v_entry.pro_id) then
    return public.queue_ticket(p_entry_id);
  end if;

  if v_entry.state not in ('waiting', 'serving') then
    raise exception 'entry_not_active';
  end if;

  update public.queue_entries e set on_my_way_at = public.live_now() where e.id = p_entry_id;

  perform public.live_broadcast(v_entry.pro_id, true);
  return public.queue_ticket(p_entry_id);
end;
$$;

create function public.leave_queue(p_entry_id uuid, p_request_id uuid)
returns public.my_ticket_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
begin
  select e.* into v_entry
  from public.queue_entries e
  where e.id = p_entry_id and e.customer_id = auth.uid() and e.kind = 'remote';
  if not found then
    raise exception 'entry_not_active';
  end if;
  perform 1 from public.pro_live l where l.pro_id = v_entry.pro_id for update;
  select e.* into v_entry from public.queue_entries e where e.id = p_entry_id;

  if public.live_request_seen(auth.uid(), p_request_id, 'leave_queue', v_entry.pro_id) then
    return public.queue_ticket(p_entry_id);
  end if;

  if v_entry.state not in ('waiting', 'serving') then
    raise exception 'entry_not_active';
  end if;

  update public.queue_entries e
     set state = 'cancelled', end_reason = 'left', ended_at = public.live_now()
   where e.id = p_entry_id;

  perform public.live_broadcast(v_entry.pro_id, true);
  return public.queue_ticket(p_entry_id);
end;
$$;

-- The caller's active entry, else their latest entry ended within the last 30 min, else nothing.
-- pro_space lets the app show it only in that space.
create function public.my_ticket()
returns setof public.my_ticket_row
language sql
stable
security definer
set search_path = ''
as $$
  select t.*
  from (
    select e.id
    from public.queue_entries e
    where e.customer_id = auth.uid() and e.kind = 'remote'
      and (e.state in ('waiting', 'serving')
           or e.ended_at >= public.live_now() - interval '30 minutes')
    order by e.ended_at is null desc, e.ended_at desc, e.created_at desc
    limit 1
  ) x
  cross join lateral public.queue_ticket(x.id) t;
$$;

-- Owner RPCs ------------------------------------------------------------------------------------

-- A null argument keeps the current value.
create function public.set_queue_settings(
  p_pro_id uuid,
  p_mode public.queue_mode,
  p_hide_count boolean,
  p_request_id uuid
)
returns public.pro_live
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_live public.pro_live;
begin
  select l.* into v_live
  from public.pro_live l
  join public.pro_profiles p on p.id = l.pro_id
  where l.pro_id = p_pro_id and p.owner_id = auth.uid()
  for update of l;
  if not found then
    raise exception 'not_owner';
  end if;

  if public.live_request_seen(auth.uid(), p_request_id, 'set_queue_settings', p_pro_id) then
    return v_live;
  end if;

  update public.pro_live l
     set queue_mode = coalesce(p_mode, l.queue_mode),
         hide_queue_count = coalesce(p_hide_count, l.hide_queue_count)
   where l.pro_id = p_pro_id;
  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id, true);

  select l.* into v_live from public.pro_live l where l.pro_id = p_pro_id;
  return v_live;
end;
$$;

-- Blocks the customer of a remote entry from this pro's queue (any state: an absent customer can
-- be blocked afterwards) and cancels the entry 'cleared' when it is still active. An entry whose
-- customer deleted the account has nobody left to block.
create function public.queue_block(p_entry_id uuid, p_request_id uuid)
returns setof public.owner_queue_row
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry public.queue_entries;
  v_cancelled boolean := false;
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

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_block', v_entry.pro_id) then
    return query select * from public.owner_queue(v_entry.pro_id);
    return;
  end if;

  if v_entry.kind <> 'remote' then
    raise exception 'not_remote';
  end if;

  if v_entry.customer_id is not null then
    insert into public.pro_blocks (pro_id, customer_id, ticket_label)
    select v_entry.pro_id, v_entry.customer_id, c.full_name
    from public.profiles c
    where c.id = v_entry.customer_id
    on conflict on constraint pro_blocks_pro_customer_key do nothing;
  end if;

  if v_entry.state in ('waiting', 'serving') then
    update public.queue_entries e
       set state = 'cancelled', end_reason = 'cleared', ended_at = public.live_now()
     where e.id = p_entry_id;
    v_cancelled := true;
  end if;

  perform public.live_touch(v_entry.pro_id);
  perform public.live_broadcast(v_entry.pro_id, v_cancelled);
  return query select * from public.owner_queue(v_entry.pro_id);
end;
$$;

create function public.queue_blocked(p_pro_id uuid)
returns table (block_id uuid, ticket_label text, created_at timestamptz)
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
  select b.id, b.ticket_label, b.created_at
  from public.pro_blocks b
  where b.pro_id = p_pro_id
  order by b.created_at desc, b.id;
end;
$$;

-- Returns the remaining blocks. The pro is an argument (not read from the block) so a replay
-- after the delete still resolves it and returns the current list.
create function public.queue_unblock(p_pro_id uuid, p_block_id uuid, p_request_id uuid)
returns table (block_id uuid, ticket_label text, created_at timestamptz)
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

  if public.live_request_seen(auth.uid(), p_request_id, 'queue_unblock', p_pro_id) then
    return query select * from public.queue_blocked(p_pro_id);
    return;
  end if;

  delete from public.pro_blocks b where b.id = p_block_id and b.pro_id = p_pro_id;
  if not found then
    raise exception 'not_owner';
  end if;

  perform public.live_touch(p_pro_id);
  perform public.live_broadcast(p_pro_id);
  return query select * from public.queue_blocked(p_pro_id);
end;
$$;

-- RLS and grants --------------------------------------------------------------------------------

alter table public.pro_blocks enable row level security;
revoke all on public.pro_blocks from anon, authenticated;

-- A customer reads their own entries; nobody else's, and an owner none through the table.
grant select on public.queue_entries to authenticated;

create policy queue_entries_select_own on public.queue_entries
for select to authenticated
using (customer_id = (select auth.uid()));

revoke execute on function
  public.live_status_joinable(public.pro_live),
  public.queue_ticket(uuid),
  public.join_customer_check(uuid),
  public.can_join(uuid),
  public.join_queue(uuid, uuid, uuid),
  public.queue_on_my_way(uuid, uuid),
  public.leave_queue(uuid, uuid),
  public.my_ticket(),
  public.set_queue_settings(uuid, public.queue_mode, boolean, uuid),
  public.queue_block(uuid, uuid),
  public.queue_blocked(uuid),
  public.queue_unblock(uuid, uuid, uuid)
from public, anon;

revoke execute on function
  public.live_status_joinable(public.pro_live),
  public.queue_ticket(uuid),
  public.join_customer_check(uuid),
  public.can_join(uuid)
from authenticated;

grant execute on function
  public.join_queue(uuid, uuid, uuid),
  public.queue_on_my_way(uuid, uuid),
  public.leave_queue(uuid, uuid),
  public.my_ticket(),
  public.set_queue_settings(uuid, public.queue_mode, boolean, uuid),
  public.queue_block(uuid, uuid),
  public.queue_blocked(uuid),
  public.queue_unblock(uuid, uuid, uuid)
to authenticated;
