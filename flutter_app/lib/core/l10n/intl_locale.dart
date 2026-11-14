import 'dart:ui';

/// The `intl` locale used for number/date formatting. Kabyle has no CLDR data
/// in `intl`, so it formats like French; Arabic uses Algerian conventions
/// (Latin digits).
String intlLocaleFor(Locale locale) => switch (locale.languageCode) {
  'ar' => 'ar_DZ',
  'kab' => 'fr',
  final code => code,
};
