import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/geo/data/geo_api.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/geo_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements GeoApi {}

const _regionRow = {
  'country_code': 'DZ',
  'code': '16',
  'parent_code': null,
  'name_ar': 'الجزائر',
  'name_fr': 'Alger',
};
const _localityRow = {
  'id': 1601,
  'region_code': '16',
  'name_ar': 'باب الزوار',
  'name_fr': 'Bab Ezzouar',
  'lat': 36.7233,
  'lng': 3,
};

void main() {
  late _MockApi api;
  late GeoRepository repo;

  setUp(() {
    api = _MockApi();
    repo = GeoRepository(api);
    when(() => api.regions(any())).thenAnswer((_) async => [_regionRow]);
    when(() => api.localities(any(), any()))
        .thenAnswer((_) async => [_localityRow]);
    when(() => api.locality(any())).thenAnswer((_) async => _localityRow);
  });

  test('a locality carries its centre; JSON may drop the fraction', () async {
    final l = await repo.locality(1601);
    expect(l!.lat, 36.7233);
    expect(l.lng, 3.0);
    final bare = Locality.fromRow({..._localityRow, 'lat': null, 'lng': null});
    expect(bare.lat, isNull);
    expect(bare.lng, isNull);
  });

  test('regions are cached per country', () async {
    final a = await repo.regions('DZ');
    final b = await repo.regions('DZ');
    expect(a.single.code, '16');
    expect(identical(a, b), isTrue);
    verify(() => api.regions('DZ')).called(1);
  });

  test('localities are cached per region', () async {
    await repo.localities('DZ', '16');
    await repo.localities('DZ', '16');
    verify(() => api.localities('DZ', '16')).called(1);
  });

  test('a locality already listed needs no second query', () async {
    await repo.localities('DZ', '16');
    final l = await repo.locality(1601);
    expect(l?.nameFr, 'Bab Ezzouar');
    verifyNever(() => api.locality(any()));
  });

  test('locality(id) fetches once, null when unknown', () async {
    when(() => api.locality(9)).thenAnswer((_) async => null);
    expect(await repo.locality(9), isNull);
    await repo.locality(1601);
    await repo.locality(1601);
    verify(() => api.locality(1601)).called(1);
  });

  test('a failed fetch is not cached', () async {
    var calls = 0;
    when(() => api.regions(any())).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('boom');
      return [_regionRow];
    });
    await expectLater(repo.regions('DZ'), throwsA(anything));
    expect((await repo.regions('DZ')).length, 1);
  });

  test('names follow the locale: ar Arabic, everything else French', () async {
    final r = (await repo.regions('DZ')).single;
    final l = (await repo.localities('DZ', '16')).single;
    expect(r.name(const Locale('ar')), 'الجزائر');
    expect(r.name(const Locale('kab')), 'Alger');
    expect(r.name(const Locale('en')), 'Alger');
    expect(l.name(const Locale('ar')), 'باب الزوار');
    expect(l.name(const Locale('kab')), 'Bab Ezzouar');
    expect(r, isA<Region>());
    expect(l, isA<Locality>());
  });
}
