import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/presentation/pro_labels.dart';

void main() {
  group('placeLine', () {
    test('joins the commune and the wilaya', () {
      expect(placeLine('Hydra', 'Alger'), 'Hydra · Alger');
    });

    test('names a commune once when the wilaya carries its name', () {
      // Seen in the M2 review: "بوسعادة · بوسعادة", "Bou Saada · Bou Saâda".
      expect(placeLine('بوسعادة', 'بوسعادة'), 'بوسعادة');
      expect(placeLine('Bou Saada', 'Bou Saâda'), 'Bou Saada');
    });

    test('keeps whichever part is known', () {
      expect(placeLine(null, 'Alger'), 'Alger');
      expect(placeLine('Hydra', ''), 'Hydra');
      expect(placeLine(null, null), isNull);
    });
  });
}
