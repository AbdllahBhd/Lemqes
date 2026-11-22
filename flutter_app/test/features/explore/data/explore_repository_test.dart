import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/explore/data/explore_api.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/data/explore_repository.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements ExploreApi {}

void main() {
  late _MockApi api;
  late ExploreRepository repo;

  setUp(() {
    api = _MockApi();
    repo = ExploreRepository(api);
    when(() => api.searchPros(any())).thenAnswer((_) async => []);
  });

  test('origin and bbox go out as the near-me arguments', () async {
    await repo.search(
      const ExploreQuery(
        origin: GeoPoint(36.754, 3.059),
        bbox: GeoBounds(2.9, 36.6, 3.2, 36.8),
      ),
      offset: 0,
      limit: 30,
    );
    final p =
        verify(() => api.searchPros(captureAny())).captured.single
            as Map<String, Object?>;
    expect(p['p_origin_lat'], 36.754);
    expect(p['p_origin_lng'], 3.059);
    expect(p['p_bbox'], [2.9, 36.6, 3.2, 36.8]);
  });

  test('without them the arguments are null (dropped by the api)', () async {
    await repo.search(const ExploreQuery(), offset: 0, limit: 30);
    final p =
        verify(() => api.searchPros(captureAny())).captured.single
            as Map<String, Object?>;
    expect(p['p_origin_lat'], isNull);
    expect(p['p_origin_lng'], isNull);
    expect(p['p_bbox'], isNull);
  });
}
