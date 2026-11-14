import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/auth/data/phone_number.dart';

void main() {
  const expected = '+213550123456';
  const valid = [
    '0550 12 34 56',
    '+213 550 12 34 56',
    '00213550123456',
    '213550123456',
    '550123456',
    '0550-12-34-56',
    '0550.12.34.56',
    '(0550) 12 34 56',
    '٠٥٥٠ ١٢ ٣٤ ٥٦',
    '۰۵۵۰۱۲۳۴۵۶',
    '+213 0550 12 34 56',
    '002130550123456',
  ];
  const invalid = [
    '021 12 34 56',
    '0450123456',
    '+33612345678',
    '05501234',
    '055012345678',
    '',
    'abc',
  ];

  for (final input in valid) {
    test('normalizes "$input"', () {
      expect(normalizeAlgerianMobile(input), expected);
    });
  }
  for (final input in invalid) {
    test('rejects "$input"', () {
      expect(normalizeAlgerianMobile(input), isNull);
    });
  }
}
