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

-- public.owns_pro_folder(name) (definer, 20261115000200) is the ownership join of the plan:
-- exists (pro_profiles p where p.id::text = (storage.foldername(name))[1] and p.owner_id = auth.uid()).
-- It is a definer helper because clients have no SELECT on pro_profiles.owner_id.
create policy pro_media_select_own on storage.objects
for select to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and public.owns_pro_folder(name)
);

create policy pro_media_insert_own on storage.objects
for insert to authenticated
with check (
  bucket_id in ('avatars', 'work-photos')
  and public.owns_pro_folder(name)
);

create policy pro_media_update_own on storage.objects
for update to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and public.owns_pro_folder(name)
)
with check (
  bucket_id in ('avatars', 'work-photos')
  and public.owns_pro_folder(name)
);

create policy pro_media_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and public.owns_pro_folder(name)
);
