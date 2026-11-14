import 'dart:ui';

import 'package:intl/date_symbol_data_local.dart';

/// The `intl` locale used for number/date formatting. Kabyle has no CLDR data
/// in `intl`, so it formats like French; Arabic uses Algerian conventions
/// (Latin digits).
String intlLocaleFor(Locale locale) => switch (locale.languageCode) {
  'ar' => 'ar_DZ',
  'kab' => 'fr',
  final code => code,
};

/// Loads the date symbols for [locale]; `DateFormat` throws until this ran.
Future<void> ensureDateFormatting(Locale locale) =>
    initializeDateFormatting(intlLocaleFor(locale));
