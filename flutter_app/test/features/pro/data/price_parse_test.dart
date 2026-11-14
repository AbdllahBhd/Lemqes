import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/pro/data/price_parse.dart';

void main() {
  group('parsePriceDzd', () {
    test('plain, spaced and Eastern digits', () {
      expect(parsePriceDzd('1500'), 1500);
      expect(parsePriceDzd('1 500'), 1500);
      expect(parsePriceDzd('1 500'), 1500);
      expect(parsePriceDzd('١٥٠٠'), 1500);
      expect(parsePriceDzd('۱۵۰۰'), 1500);
    });
    test('rejects empty, non-integer and out of range', () {
      expect(parsePriceDzd(''), isNull);
      expect(parsePriceDzd('   '), isNull);
      expect(parsePriceDzd('12.5'), isNull);
      expect(parsePriceDzd('abc'), isNull);
      expect(parsePriceDzd('-5'), isNull);
      expect(parsePriceDzd('999999'), isNull);
      expect(parsePriceDzd('200001'), isNull);
    });
    test('bounds are inclusive', () {
      expect(parsePriceDzd('0'), 0);
      expect(parsePriceDzd('200000'), 200000);
    });
  });

  group('parseDurationMin', () {
    test('5..300 inclusive', () {
      expect(parseDurationMin('4'), isNull);
      expect(parseDurationMin('5'), 5);
      expect(parseDurationMin('300'), 300);
      expect(parseDurationMin('301'), isNull);
      expect(parseDurationMin('٣٠'), 30);
      expect(parseDurationMin(''), isNull);
      expect(parseDurationMin('2.5'), isNull);
    });
  });

  group('formatDzd', () {
    test('Arabic uses Latin digits', () {
      final s = formatDzd(1500, const Locale('ar'));
      expect(s, matches(RegExp(r'^[0-9\s  .,٬٫]+ DA$')));
      expect(s, contains('1'));
      expect(s, isNot(matches(RegExp(r'[٠-٩]'))));
      expect(s.endsWith(' DA'), isTrue);
    });
    test('French groups thousands', () {
      final s = formatDzd(12500, const Locale('fr'));
      expect(s.replaceAll(RegExp(r'[\s  ]'), ''), '12500DA');
      expect(s, isNot('12500 DA'));
    });
    test('Kabyle falls back without throwing', () {
      expect(formatDzd(600, const Locale('kab')), '600 DA');
    });
  });
}
