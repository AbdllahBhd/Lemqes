import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lemqes/core/l10n/intl_locale.dart';

void main() {
  final saturday = DateTime(2026, 11, 14);

  test('Arabic weekday names format after ensureDateFormatting', () async {
    await ensureDateFormatting(const Locale('ar'));
    expect(
      DateFormat.EEEE(intlLocaleFor(const Locale('ar'))).format(saturday),
      'السبت',
    );
  });

  test('Kabyle formats like French', () async {
    await ensureDateFormatting(const Locale('kab'));
    expect(
      DateFormat.EEEE(intlLocaleFor(const Locale('kab'))).format(saturday),
      'samedi',
    );
  });
}
