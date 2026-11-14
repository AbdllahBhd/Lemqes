import '../../pro/data/pro_failure.dart';
import 'geo_api.dart';
import 'geo_models.dart';

/// Reference data never changes within a session, so every lookup is cached;
/// a failed lookup is evicted so the next call retries.
class GeoRepository {
  GeoRepository(this._api);

  final GeoApi _api;
  final _regions = <String, Future<List<Region>>>{};
  final _localities = <(String, String), Future<List<Locality>>>{};
  final _byId = <int, Locality>{};

  Future<List<Region>> regions(String country) => _cached(
    _regions,
    country,
    () async => [
      for (final r in await _api.regions(country)) Region.fromRow(r),
    ],
  );

  Future<List<Locality>> localities(String country, String regionCode) =>
      _cached(_localities, (country, regionCode), () async {
        final list = [
          for (final r in await _api.localities(country, regionCode))
            Locality.fromRow(r),
        ];
        for (final l in list) {
          _byId[l.id] = l;
        }
        return list;
      });

  Future<Locality?> locality(int id) async {
    final known = _byId[id];
    if (known != null) return known;
    final row = await guardPro(() => _api.locality(id));
    if (row == null) return null;
    return _byId[id] = Locality.fromRow(row);
  }

  Future<V> _cached<K, V>(
    Map<K, Future<V>> cache,
    K key,
    Future<V> Function() load,
  ) async {
    final future = cache[key] ??= guardPro(load);
    try {
      return await future;
    } on Object {
      cache.remove(key);
      rethrow;
    }
  }
}
