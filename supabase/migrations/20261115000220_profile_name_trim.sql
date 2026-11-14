-- complete_signup trims full_name, but the column-level UPDATE grant let clients store leading or
-- trailing spaces afterwards. Trim on every write so the stored name is always the visible one.

create function public.trim_profile_full_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.full_name := btrim(new.full_name);
  return new;
end;
$$;

revoke execute on function public.trim_profile_full_name() from public, anon, authenticated;

create trigger profiles_trim_full_name
before insert or update of full_name on public.profiles
for each row execute function public.trim_profile_full_name();
