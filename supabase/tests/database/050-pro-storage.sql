begin;
select plan(26);

-- storage.objects RLS checked at SQL level, writing rows directly as `authenticated` the way the
-- Storage API does on the caller's behalf. MIME and size limits are enforced by the Storage API
-- itself and are covered by the integration test, not here.
do $$
begin
  perform set_config('t.a', tests.create_account('213550000450', 'men', 'barber')::text, true);
  perform set_config('t.b', tests.create_account('213550000451', 'men', 'barber')::text, true);
  perform set_config('t.pa', tests.create_pro(current_setting('t.a')::uuid, 'barber', 'Salon A')::text, true);
  perform set_config('t.pb', tests.create_pro(current_setting('t.b')::uuid, 'barber', 'Salon B')::text, true);
end;
$$;

select results_eq(
  $$ select id, public, file_size_limit, allowed_mime_types
       from storage.buckets where id in ('avatars', 'work-photos') order by id $$,
  $$ values ('avatars'::text, true, 5242880::bigint, array['image/jpeg', 'image/png', 'image/webp']),
            ('work-photos'::text, true, 5242880::bigint, array['image/jpeg', 'image/png', 'image/webp']) $$,
  'both buckets are public, 5 MB, JPEG/PNG/WebP only'
);

-- Owner of pro A ---------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', current_setting('t.pa') || '/x.jpg', auth.uid()) $$,
  'the owner uploads a work photo under its pro folder');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('avatars', current_setting('t.pa') || '/avatar.jpg', auth.uid()) $$,
  'the owner uploads an avatar under its pro folder');
select is(
  (select count(*)::int from storage.objects where name like current_setting('t.pa') || '/%'),
  2, 'the owner selects its own objects');
select lives_ok(
  $$ update storage.objects set metadata = '{"mimetype":"image/jpeg"}'
      where name = current_setting('t.pa') || '/x.jpg' $$,
  'the owner updates its own object (upsert path)');
select throws_ok(
  $$ update storage.objects set name = current_setting('t.pb') || '/x.jpg'
      where name = current_setting('t.pa') || '/x.jpg' $$,
  '42501', null, 'the owner cannot move an object into another pro''s folder');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', current_setting('t.a') || '/x.jpg', auth.uid()) $$,
  '42501', null, 'a folder named after the account id (not a pro id) is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', 'not-a-uuid/x.jpg', auth.uid()) $$,
  '42501', null, 'a folder that is not a pro id is refused');

-- Exactly `<pro id>/<name>.<jpg|png|webp>`, the shape PhotoUploader writes.
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', current_setting('t.pa') || '/sub/x.jpg', auth.uid()) $$,
  '42501', null, 'a nested folder under my pro folder is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', current_setting('t.pa') || '/../x.jpg', auth.uid()) $$,
  '42501', null, 'a path with .. is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('avatars', current_setting('t.pa') || '/x..jpg', auth.uid()) $$,
  '42501', null, 'a name with dots before the extension is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', current_setting('t.pa') || '/x.svg', auth.uid()) $$,
  '42501', null, 'an extension other than jpg, png or webp is refused');
select throws_ok(
  $$ update storage.objects set name = current_setting('t.pa') || '/sub/x.jpg'
      where name = current_setting('t.pa') || '/x.jpg' $$,
  '42501', null, 'the owner cannot move its object into a nested folder');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos',
             current_setting('t.pa') || '/0b6f1a52-6a4e-4b7e-9d1c-2f1f6c1f0a11.webp', auth.uid()) $$,
  'an uploader-shaped name (uuid.webp) is accepted');
select is(
  (select count(*)::int from storage.objects where name like current_setting('t.pa') || '/%'),
  3, 'none of the refused names was stored');
do $$
begin
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where name like current_setting('t.pa') || '/0b6f1a52-%';
end;
$$;
do $$ begin perform tests.clear_auth(); end; $$;

-- Another pro --------------------------------------------------------------------------------------

do $$ begin perform tests.authenticate_as(current_setting('t.b')::uuid); end; $$;
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('work-photos', current_setting('t.pa') || '/evil.jpg', auth.uid()) $$,
  '42501', null, 'another user cannot upload into my pro folder');
select is(
  (select count(*)::int from storage.objects where name like current_setting('t.pa') || '/%'),
  0, 'another user does not select my objects through the API');
do $$
declare
  n int;
begin
  perform set_config('storage.allow_delete_query', 'true', true);
  with d as (
    delete from storage.objects where name like current_setting('t.pa') || '/%' returning 1
  )
  select count(*) into n from d;
  perform set_config('t.deleted_by_b', n::text, true);
end;
$$;
select is(current_setting('t.deleted_by_b'), '0', 'another user deletes none of my objects');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as_anon(); end; $$;
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('work-photos', current_setting('t.pa') || '/anon.jpg') $$,
  '42501', null, 'anon cannot upload');
do $$ begin perform tests.clear_auth(); end; $$;

do $$ begin perform tests.authenticate_as(current_setting('t.a')::uuid); end; $$;
select is(
  (select count(*)::int from storage.objects where name like current_setting('t.pa') || '/%'),
  2, 'my objects still exist after the denied delete');
do $$
declare
  n int;
begin
  perform set_config('storage.allow_delete_query', 'true', true);
  with d as (
    delete from storage.objects where name like current_setting('t.pa') || '/%' returning 1
  )
  select count(*) into n from d;
  perform set_config('t.deleted_by_a', n::text, true);
end;
$$;
select is(current_setting('t.deleted_by_a'), '2', 'the owner deletes its own objects');

-- Row paths take the same shape as the objects ---------------------------------------------------

select throws_ok(
  $$ insert into public.pro_photos (pro_id, path)
     values (current_setting('t.pa')::uuid, current_setting('t.pa') || '/..') $$,
  '23514', null, 'a photo row path of .. is refused');
select throws_ok(
  $$ update public.pro_profiles set avatar_path = current_setting('t.pa') || '/a.gif'
      where id = current_setting('t.pa')::uuid $$,
  '23514', null, 'an avatar_path with another extension is refused');

-- At most 9 work-photo rows per pro ------------------------------------------------------------------

select lives_ok(
  $$ insert into public.pro_photos (pro_id, path, sort)
     select current_setting('t.pa')::uuid, current_setting('t.pa') || '/p' || i || '.jpg', i
       from generate_series(1, 9) i $$,
  'nine photo rows are accepted');
select throws_ok(
  $$ insert into public.pro_photos (pro_id, path)
     values (current_setting('t.pa')::uuid, current_setting('t.pa') || '/p10.jpg') $$,
  'P0001', 'too_many_photos', 'the 10th photo row is refused');
select lives_ok(
  $$ delete from public.pro_photos where path = current_setting('t.pa') || '/p1.jpg' $$,
  'the owner deletes a photo row');
do $$ begin perform tests.clear_auth(); end; $$;

select * from finish();
rollback;
