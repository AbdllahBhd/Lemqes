import '../../pro/data/pro_failure.dart';
import 'explore_api.dart';
import 'explore_models.dart';

class ExploreRepository {
  ExploreRepository(this._api);

  final ExploreApi _api;

  Future<List<ProCard>> search(
    ExploreQuery q, {
    required int offset,
    required int limit,
  }) => guardPro(() async {
    final rows = await _api.searchPros({
      'p_query': q.text,
      'p_region_code': q.regionCode,
      'p_locality_id': q.localityId,
      'p_kids': q.kidsOnly ? true : null,
      'p_category': q.category?.toDb(),
      'p_origin_lat': q.origin?.lat,
      'p_origin_lng': q.origin?.lng,
      'p_bbox': q.bbox?.toRpc(),
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final r in rows) ProCard.fromRow(r)];
  });
}
