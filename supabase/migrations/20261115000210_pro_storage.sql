-- Pro media buckets. Objects live at '<pro id>/<file>' (never the account id: these paths reach
-- customers). Reads are public by design (the bucket is public; work photos and avatars are meant
-- to be seen). Through the API only the owner of that pro profile may list, upload, replace or
-- remove its objects; SELECT is granted to the owner too because Storage's remove() and upsert
-- read the row first. MIME type and size limits are enforced by the Storage API from the bucket
-- settings below.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('work-photos', 'work-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']);

-- The folder is compared as text, so a segment that is not a uuid is simply no match (no cast
-- error). pro_profiles RLS applies inside the subquery and only adds the owner's own rows.
create policy pro_media_select_own on storage.objects
for select to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and exists (
    select 1 from public.pro_profiles p
    where p.id::text = (storage.foldername(name))[1] and p.owner_id = (select auth.uid())
  )
);

create policy pro_media_insert_own on storage.objects
for insert to authenticated
with check (
  bucket_id in ('avatars', 'work-photos')
  and exists (
    select 1 from public.pro_profiles p
    where p.id::text = (storage.foldername(name))[1] and p.owner_id = (select auth.uid())
  )
);

create policy pro_media_update_own on storage.objects
for update to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and exists (
    select 1 from public.pro_profiles p
    where p.id::text = (storage.foldername(name))[1] and p.owner_id = (select auth.uid())
  )
)
with check (
  bucket_id in ('avatars', 'work-photos')
  and exists (
    select 1 from public.pro_profiles p
    where p.id::text = (storage.foldername(name))[1] and p.owner_id = (select auth.uid())
  )
);

create policy pro_media_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and exists (
    select 1 from public.pro_profiles p
    where p.id::text = (storage.foldername(name))[1] and p.owner_id = (select auth.uid())
  )
);
