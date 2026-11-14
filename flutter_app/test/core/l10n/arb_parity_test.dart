import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String code) =>
    jsonDecode(File('lib/core/l10n/arb/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

// A placeholder is `{name}` or the head of `{name, plural|select, ...}`;
// words opening an ICU branch (`other{Je suis}`) are translated text, and so
// is a one-word branch body (`hair{Cheveux}`): its brace follows the keyword.
Set<String> _placeholders(String message) =>
    RegExp(r'(?<!\w)\{(\w+)\s*(?:\}|,)')
        .allMatches(message)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  final fr = _load('fr');

  for (final code in ['en', 'ar', 'kab']) {
    final other = _load(code);

    test('$code has the same keys as fr', () {
      expect(_keys(other), _keys(fr));
    });

    test('$code keeps every fr placeholder', () {
      for (final key in _keys(fr)) {
        final expected = _placeholders(fr[key] as String);
        final actual = _placeholders(other[key] as String);
        expect(actual, containsAll(expected), reason: key);
      }
    });
  }
}
