import 'dart:ui';

import 'package:intl/intl.dart';

import '../../../core/l10n/intl_locale.dart';

String _latinDigits(String input) {
  final b = StringBuffer();
  for (final u in input.runes) {
    if (u >= 0x0660 && u <= 0x0669) {
      b.writeCharCode(0x30 + u - 0x0660);
    } else if (u >= 0x06F0 && u <= 0x06F9) {
      b.writeCharCode(0x30 + u - 0x06F0);
    } else {
      b.writeCharCode(u);
    }
  }
  return b.toString();
}

int? _parseInt(String input, int min, int max) {
  final s = _latinDigits(input)
      .replaceAll(RegExp(r'[\s\u00A0\u202F\u066C]'), '');
  if (!RegExp(r'^[0-9]{1,9}$').hasMatch(s)) return null;
  final v = int.parse(s);
  return v < min || v > max ? null : v;
}

/// Integer dinars, 0..200000 (the database CHECK); null for anything else.
int? parsePriceDzd(String input) => _parseInt(input, 0, 200000);

/// Whole minutes, 5..300 (the database CHECK); null for anything else.
int? parseDurationMin(String input) => _parseInt(input, 5, 300);

/// "1 500 DA" with the locale's grouping and always Latin digits.
String formatDzd(int v, Locale l) {
  final grouped = NumberFormat.decimalPattern(intlLocaleFor(l)).format(v);
  return '${_latinDigits(grouped)} DA';
}
