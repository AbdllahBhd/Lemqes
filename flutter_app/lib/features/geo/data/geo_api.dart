import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class GeoApi {
  Future<List<Map<String, Object?>>> regions(String country);
  Future<List<Map<String, Object?>>> localities(
    String country,
    String regionCode,
  );
  Future<Map<String, Object?>?> locality(int id);
}

class SupabaseGeoApi implements GeoApi {
  SupabaseGeoApi(this._client);

  final SupabaseClient _client;

  static const _regionCols =
      'country_code, code, parent_code, name_ar, name_fr';
  static const _localityCols = 'id, region_code, name_ar, name_fr';

  @override
  Future<List<Map<String, Object?>>> regions(String country) => _client
      .from('geo_regions')
      .select(_regionCols)
      .eq('country_code', country)
      .order('code');

  @override
  Future<List<Map<String, Object?>>> localities(
    String country,
    String regionCode,
  ) => _client
      .from('geo_localities')
      .select(_localityCols)
      .eq('country_code', country)
      .eq('region_code', regionCode)
      .order('name_fr');

  @override
  Future<Map<String, Object?>?> locality(int id) => _client
      .from('geo_localities')
      .select(_localityCols)
      .eq('id', id)
      .maybeSingle();
}
