import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/geo/presentation/search_fold.dart';

void main() {
  test('foldLatin drops accents, case and apostrophes', () {
    expect(foldLatin('Bou Saâda'), 'bou saada');
    expect(foldLatin('Boumerdès'), 'boumerdes');
    expect(foldLatin("M'Sila"), 'msila');
    expect(foldLatin('Béni-Abbès'), 'beni abbes');
  });

  test('foldLatin leaves Arabic untouched', () {
    expect(foldLatin('بوسعادة'), 'بوسعادة');
  });
}
