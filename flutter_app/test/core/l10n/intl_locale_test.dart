import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lemqes/core/l10n/intl_locale.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';

void main() {
  test('ar numbers use Latin digits', () {
    final text = NumberFormat.decimalPattern(intlLocaleFor(const Locale('ar')))
        .format(1234);
    expect(text, matches(RegExp(r'^[0-9.,   ]+$')));
  });

  test('intlLocaleFor maps kab to fr', () {
    expect(intlLocaleFor(const Locale('kab')), 'fr');
    expect(intlLocaleFor(const Locale('ar')), 'ar_DZ');
    expect(intlLocaleFor(const Locale('en')), 'en');
  });

  test('resolveInitialLocale picks the first supported language', () {
    expect(
      resolveInitialLocale([const Locale('de'), const Locale('fr', 'DZ')]),
      const Locale('fr'),
    );
    expect(resolveInitialLocale([const Locale('de')]), const Locale('ar'));
  });
}
