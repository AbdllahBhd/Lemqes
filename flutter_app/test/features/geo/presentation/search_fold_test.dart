import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/geo/presentation/search_fold.dart';

void main() {
  // One vector table drives this test and the generated pgTAP file, so the Dart and SQL folds
  // cannot drift (scripts/fold_vectors.py).
  final vectors = (jsonDecode(
    File('../supabase/tests/fold_vectors.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  test('the vector table covers every rule', () {
    expect(vectors.length, greaterThanOrEqualTo(40));
  });

  group('searchFold', () {
    for (final v in vectors) {
      test('${v['input']}', () {
        expect(searchFold(v['input'] as String), v['fold']);
      });
    }
  });

  group('nameSkeleton', () {
    for (final v in vectors) {
      test('${v['input']}', () {
        expect(nameSkeleton(v['input'] as String), v['skeleton']);
      });
    }
  });

  group('matchesPlace', () {
    bool hit(String q, String fr, String ar, {String? code}) =>
        matchesPlace(q, nameFr: fr, nameAr: ar, code: code);

    test('folds Latin and Arabic within a script', () {
      expect(hit('bou saada', 'Bou Saâda', 'بوسعادة'), isTrue);
      expect(hit('بوسعاده', 'Bou Saâda', 'بوسعادة'), isTrue);
    });

    test('finds an Arabic name from its Latin spelling', () {
      expect(hit('Tizi', 'Tizi Ouzou', 'تيزي وزو'), isTrue);
      expect(hit('تيزي', 'Tizi Ouzou', 'تيزي وزو'), isTrue);
      expect(hit('Tizi', 'Oran', 'وهران'), isFalse);
    });

    test('an empty query keeps every place and a code still matches', () {
      expect(hit('  ', 'Oran', 'وهران'), isTrue);
      expect(hit('31', 'Oran', 'وهران', code: '31'), isTrue);
    });
  });
}
