# M3 spike: Realtime private-channel delivery (findings)

Date: 2026-11-20. Throwaway branch `spike/m3-realtime` off `feat/live-queue` @ 33a9b66 (deleted after).
Stack: Supabase CLI 2.121.0, Postgres 17.11, Realtime image `public.ecr.aws/supabase/realtime:v2.143.4`.
Client: Dart script run with `scripts/sdk dart run tool/spike_realtime.dart` using `supabase` 2.16.5 /
`realtime_client` 2.13.2, plus a raw-WebSocket script to see the Phoenix frames.
Fixtures: 213550000001 = men barber owning published pro `P`; 213550000002 = men customer;
213550000003 = women customer; 40 more published men pros (owners inserted into `auth.users`).

**Verdict: the Approach holds.** (b) and (c) pass. A few observed facts change details of Tasks 1/4b/7
(see "Plan amendments").

## (a) Policy used (applied with psql as `postgres`, no migration)

```sql
create function public.live_topic_allowed(p_topic text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_topic is null or p_topic !~ '^pro:[0-9a-f-]{36}$' then return false; end if;
  v_id := substr(p_topic, 5)::uuid;
  return public.owns_pro(v_id) or public.is_listable(v_id);
end; $$;
revoke execute on function public.live_topic_allowed(text) from public, anon;
grant execute on function public.live_topic_allowed(text) to authenticated;

create policy live_topics on realtime.messages for select to authenticated
  using (realtime.messages.extension = 'broadcast'
         and public.live_topic_allowed((select realtime.topic())));
```

Stored qual (`pg_policy`): `((extension = 'broadcast'::text) AND live_topic_allowed(( SELECT realtime.topic() AS topic)))`.
RLS was already enabled on `realtime.messages`, so no `enable row level security` was needed.

## (b) DB `realtime.send` reaches a same-space private channel: PASS

`select realtime.send(jsonb_build_object('n', 1, 'kind', 'b'), 'live', 'pro:<P>', true)`, run as postgres.
The men customer and the owner (both `private: true`, `onBroadcast(event: 'live')`) each received it once,
**49–55 ms** after the psql call started (3 runs). Callback payload, verbatim:

```
{"type":"broadcast","event":"live","payload":{"n":1,"id":"1cd67a99-d786-4238-973e-73d6c1f67ede","kind":"b"},"meta":{"id":"1cd67a99-d786-4238-973e-73d6c1f67ede"}}
```

So the snapshot sits at `payload['payload']` and carries `id` (= `realtime.messages.id`, also
in `meta.id`). Inserted row: `id|pro:<P>|broadcast|live|t|{"n": 1, "id": "1cd6…", "kind": "b"}`.

What the local `realtime.send` source does:
- It adds `id` **only if the payload has no `id` key**. If the payload has its own `id`, that value is kept and the message id is lost.
- It runs `SET LOCAL realtime.topic`, which stays set for the rest of the transaction.
- It wraps the insert in `exception when others then raise warning 'WarnSendingBroadcastMessage: %'`. It never raises and returns `void`.

## (c) Refused join (women customer on `pro:<P>`; men customer on `pro:not-a-uuid`): PASS

Dart status callback, verbatim:

```
RealtimeSubscribeStatus.channelError | error: Exception: "Unauthorized: You do not have permissions to read from this Channel topic: pro:d6df986e-10c7-4963-865b-813539c919ca" (_Exception)
```

The text is the same for `pro:not-a-uuid`. The women client got 0 messages. The refused channel on the men
socket did not disturb that socket's other channels.

**The refusal arrives about 5 s after the join, every time.** We measured 5.0 s in 3 runs and on a raw socket. The server logs
the decision ~12 ms after the join but holds the reply. Raw frame at 5061 ms:
`{"ref":"1","event":"phx_reply","payload":{"status":"error","response":{"reason":"Unauthorized: You do not have permissions to read from this Channel topic: pro:…"}},"topic":"realtime:pro:…"}`.

Extra leak checks (raw WebSocket):
- The women customer joining the same topic with `private: false` is accepted and receives only a
  `realtime.send(…, false)` message. The `private => true` message sent at the same moment did
  **not** reach her.
- A client broadcast pushed on the public `pro:<P>` channel did **not** reach the men private subscriber.

## (d) 40+ channels on one client: PASS; limits

The men client held 41 private `pro:*` channels, all `subscribed` within ~100 ms. One
`realtime.send` per pro (41 sends) arrived on all 41 topics, with a max latency of 59–71 ms.

Going over the cap: an owner client with 1 private channel, then 101 public ones, gave
`{subscribed: 99, channelError (Exception: "ChannelRateLimitReached: Too many channels"): 1, timedOut: 1}`.
So the cap is 100 channels per connection. The first refused join got its error ~5 s later. The second got no reply within the 10 s timeout, which points to the same delay on refusals as in (c).

Local tenant (`_realtime.tenants`, external_id `realtime-dev`): `max_channels_per_client 100`,
`max_concurrent_users 200`, `max_events_per_second 100`, `max_joins_per_second 100`,
`max_bytes_per_second 100000`, `max_payload_size_in_kb 3000`, `private_only f`.

Hosted limits (https://supabase.com/docs/guides/realtime/limits):

| Limit | Free | Pro | Pro, no spend cap / Team |
|---|---|---|---|
| Channels per connection | 100 | 100 | 100 |
| Concurrent connections | 200 | 500 | 10,000 |
| Messages/s | 100 | 500 | 2,500 |
| Channel joins/s | 100 | 500 | 2,500 |
| Broadcast payload | 256 KB | 3,000 KB | 3,000 KB |

Refusal codes on the socket: `too_many_channels`, `too_many_connections`, `too_many_joins`, `tenant_events`.
The ~35-channel plan fits under the cap. On Free, the ceiling to watch is 100 messages/s per project, which a busy
per-minute job (one send per affected pro) could hit.

## (e) `auth.refreshSession()` keeps channels receiving: PASS

After `men.auth.refreshSession()`, the token was new and `men.realtime.accessToken` had been updated to it
(supabase 2.16.5 `_handleTokenChanged` calls `realtime.setAuth`). The 41 joined channels stayed joined, and the
next 41 sends arrived on all 41 topics (max 52–71 ms).
Per the docs (https://supabase.com/docs/guides/realtime/authorization):
- Access policies are "cached for the duration of the connection".
- They are re-evaluated when a new JWT is sent with the `access_token` message.
- If no new JWT arrives, the client is disconnected when its JWT expires.

## (f) Today's `realtime.messages_*` partition after `supabase db reset`

We polled the partitions every 0.25 s during a reset that ran from 16:23:39.8 to 16:24:05.9 UTC.
- `realtime.messages` did not exist until ~16:23:43.
- From **16:23:47.5**, the 5 daily partitions `messages_2026_11_19 … _23` (yesterday to +3 days) existed. That is ~18 s **before** the reset command returned, and before any client had connected.

So locally, **today's partition exists as soon as `supabase db reset` finishes**.
The docs (https://supabase.com/docs/guides/realtime/broadcast) say: "A client connecting over WebSocket
creates those daily partitions. `realtime.send` does not". With no partition for today, the insert
fails and only `WarnSendingBroadcastMessage` is logged. Partitions older than 3 days are dropped.

## Other checks

- `pg_cron` on the lemqes DB (`supabase_db_lemqes`): `pg_cron|1.6.4||Job scheduler for PostgreSQL` → available.

## Plan amendments (proposed, not applied)

1. **Task 4b / 7: a refused join takes ~5 s.** In `LiveChannels`:
   - Never treat "no `subscribed` within N s" as a refusal while N < 6 s. Keep the subscribe timeout ≥ 10 s (the default).
   - Treat a `channelError` whose error text starts with `Unauthorized:` as "not allowed": drop the card's live line and do not retry.
   - Retry only on `timedOut`/`closed`.
   - Integration tests that wait for a refusal need ≥ 6 s.
2. **Task 1: `live_snapshot` must never contain a top-level `id` key.** Otherwise `realtime.send` keeps that value and the message id is lost.
   The current shape (`pro_id`, …) is fine; pin it with a pgTAP `not (snapshot ? 'id')`.
   Dart reads the snapshot from `payload['payload']`.
3. **Task 1: always `private => true`.** A `false` send can be read by any client, in any space, through a
   public join of the same topic (observed). Pin in pgTAP that the inserted `realtime.messages.private` is true.
4. **Task 1 pgTAP / Task 7: partition dependency.** Broadcast assertions read `realtime.messages`.
   This works right after `supabase db reset`, which leaves partitions for today to +3 days. If a stack stays up for more than 3 days with no
   client connection, `realtime.send` silently inserts nothing. Say so in the test
   comment, and run broadcast tests after a reset (as `scripts/integration.sh` does). On hosted, a missing partition is harmless:
   a day with no connected client has no one to deliver to.
5. **Hosted rollout note (Task 7 / deploy):** turn off "Allow public access" in the hosted Realtime
   settings (the docs say it is needed to enforce private channels). The design does not depend on it, since private sends did not leak,
   but it stops arbitrary public-channel chatter on `pro:*` topics.
6. Optional: the `SET LOCAL realtime.topic` from `realtime.send` stays set for the rest of the RPC
   transaction. Call `live_broadcast` last (already the plan); nothing else reads `realtime.topic()`.

## Sources

- https://supabase.com/docs/guides/realtime/limits
- https://supabase.com/docs/guides/realtime/authorization
- https://supabase.com/docs/guides/realtime/broadcast
- Local: `pg_get_functiondef('realtime.send(jsonb,text,text,boolean)')`, `_realtime.tenants`,
  `realtime_client-2.13.2/lib/src/realtime_channel.dart` (subscribe error path),
  `supabase-2.16.5/lib/src/supabase_client.dart` (`_handleTokenChanged`).
