-- Names other users will see must not hide characters: Unicode control (Cc) and format (Cf)
-- characters are refused, among them zero-width (U+200B-U+200F, U+2060-U+2064, U+FEFF) and
-- bidi controls (U+061C, U+202A-U+202E, U+2066-U+2069) that can disguise or reorder a name.
--
-- The class is spelled out (not [[:cntrl:]]) because Cf is not a POSIX class and the
-- database's ctype locale decides what [[:cntrl:]] matches. Both constraints share it: keep
-- them identical when Unicode adds format characters.

alter table public.profiles
  add constraint profiles_full_name_visible check (
    full_name !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]'
  );

alter table public.profile_roles
  add constraint profile_roles_business_name_visible check (
    business_name is null
    or business_name !~ '[\u0001-\u001F\u007F-\u009F­؀-؅؜۝܏࢐࢑࣢᠎​-‏‪-‮⁠-⁤⁦-⁯﻿￹-￻\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A\U000E0001\U000E0020-\U000E007F]'
  );
