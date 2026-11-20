import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/time/country_clock.dart';

void main() {
  test('UTC 23:30 is 00:30 the next day in Algiers', () {
    final now = countryNow(
      'Africa/Algiers',
      DateTime.utc(2026, 11, 18, 23, 30),
    );
    expect(now.year, 2026);
    expect(now.month, 11);
    expect(now.day, 19);
    expect(now.hour, 0);
    expect(now.minute, 30);
    expect(now.weekday, DateTime.thursday);
  });

  test('a local-zone input is treated as the same instant', () {
    final utc = DateTime.utc(2026, 11, 18, 10);
    expect(
      countryNow('Africa/Algiers', utc.toLocal()),
      countryNow('Africa/Algiers', utc),
    );
  });

  test('an unknown zone throws', () {
    expect(
      () => countryNow('Mars/Olympus', DateTime.utc(2026)),
      throwsArgumentError,
    );
  });
}
