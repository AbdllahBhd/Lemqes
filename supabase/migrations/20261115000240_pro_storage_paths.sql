-- Pro media paths take exactly one shape: `<pro id>/<name>.<jpg|png|webp>`, a single file directly
-- under the pro's folder, the name letters, digits, `_` or `-` only (PhotoUploader writes
-- `<pro id>/<uuid>.<ext>`). The first policies (20261115000210) accepted nested folders and any
-- name, and the row CHECKs (20261115000200) accepted `..` and any extension.

create function public.is_pro_media_name(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_length(storage.foldername(p_name), 1) = 1, false)
     and storage.filename(p_name) ~ '^[A-Za-z0-9_-]+\.(jpg|png|webp)$'
$$;

revoke execute on function public.is_pro_media_name(text) from public, anon;
grant execute on function public.is_pro_media_name(text) to authenticated;

drop policy pro_media_insert_own on storage.objects;
create policy pro_media_insert_own on storage.objects
for insert to authenticated
with check (
  bucket_id in ('avatars', 'work-photos')
  and public.is_pro_media_name(name)
  and public.owns_pro_folder(name)
);

drop policy pro_media_update_own on storage.objects;
create policy pro_media_update_own on storage.objects
for update to authenticated
using (
  bucket_id in ('avatars', 'work-photos')
  and public.owns_pro_folder(name)
)
with check (
  bucket_id in ('avatars', 'work-photos')
  and public.is_pro_media_name(name)
  and public.owns_pro_folder(name)
);

alter table public.pro_profiles
  drop constraint pro_profiles_avatar_path_own_folder,
  add constraint pro_profiles_avatar_path_own_folder check (
    avatar_path is null
    or avatar_path ~ ('^' || id::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$')
  );

alter table public.pro_photos
  drop constraint pro_photos_path_own_folder,
  add constraint pro_photos_path_own_folder check (
    path ~ ('^' || pro_id::text || '/[A-Za-z0-9_-]+\.(jpg|png|webp)$')
  );
