import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase adapter (mockable). Every select/return lists its columns:
/// `pro_profiles.owner_id` is not grantable to clients, so `*` would be
/// denied.
abstract interface class ProApi {
  Future<Object?> rpc(String fn, Map<String, Object?> params);

  /// The caller's own profile of [kind] with embedded `pro_services`,
  /// `pro_hours` `pro_photos` and the own `pro_places` row; null when there is none.
  ///
  /// Precondition: the caller acts as that pro role. RLS then limits the
  /// result to the own row; acting as a customer it would also expose other
  /// pros' listable profiles. Go through `ProRepository.mine`, which checks.
  Future<Map<String, Object?>?> selectMine(String kind);

  /// A listable profile with embedded `pro_hours` and `pro_photos` (services
  /// come from the `pro_public_services` RPC); null when not visible.
  Future<Map<String, Object?>?> selectPublic(String proId);

  /// Updates one row and returns it with the table's client columns.
  Future<Map<String, Object?>> update(
    String table,
    String id,
    Map<String, Object?> values,
  );

  /// Inserts one row and returns it with the table's client columns.
  Future<Map<String, Object?>> insert(
    String table,
    Map<String, Object?> values,
  );

  Future<void> delete(String table, String id);

  Future<List<Map<String, Object?>>> selectPresets(String space, bool home);
}

class SupabaseProApi implements ProApi {
  SupabaseProApi(this._client);

  final SupabaseClient _client;

  static const _profileCols =
      'id, kind, space, display_name, bio, experience_years, workplace_type, '
      'workplace_name, locality_id, customer_mix, service_radius_km, '
      'travel_fee_dzd, avatar_path, phone_visibility, show_prices, '
      'is_verified, published_at';
  static const _serviceCols =
      'id, preset_key, name, category, price_dzd, duration_min, active, '
      'archived_at, sort';
  static const _hoursCols =
      'weekday, opens, closes, break_start, break_end, crosses_midnight';
  static const _photoCols = 'id, path, sort';

  // `search_point` and `place` are not client columns.
  static const _placeCols =
      'place_mode, lat, lng, area_radius_m, landmark, updated_at';

  /// What a customer reads of a pro's place: what it shows, never the
  /// search point. RLS hides the row from a reader the pro blocked.
  static const _publicPlaceCols =
      'place_mode, lat, lng, area_radius_m, landmark';

  @visibleForTesting
  static const publicSelect =
      '$_profileCols, pro_hours($_hoursCols), pro_photos($_photoCols), '
      'pro_places($_publicPlaceCols)';

  static const _returning = {
    'pro_profiles': _profileCols,
    'pro_services': _serviceCols,
    'pro_photos': _photoCols,
  };

  static String _cols(String table) {
    final cols = _returning[table];
    if (cols == null) throw ArgumentError.value(table, 'table');
    return cols;
  }

  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) =>
      _client.rpc(fn, params: params);

  @override
  Future<Map<String, Object?>?> selectMine(String kind) => _client
      .from('pro_profiles')
      .select(
        '$_profileCols, pro_services($_serviceCols), pro_hours($_hoursCols), '
        'pro_photos($_photoCols), pro_places($_placeCols)',
      )
      .eq('kind', kind)
      .maybeSingle();

  @override
  Future<Map<String, Object?>?> selectPublic(String proId) => _client
      .from('pro_profiles')
      .select(publicSelect)
      .eq('id', proId)
      .maybeSingle();

  @override
  Future<Map<String, Object?>> update(
    String table,
    String id,
    Map<String, Object?> values,
  ) => _client
      .from(table)
      .update(values)
      .eq('id', id)
      .select(_cols(table))
      .single();

  @override
  Future<Map<String, Object?>> insert(
    String table,
    Map<String, Object?> values,
  ) => _client.from(table).insert(values).select(_cols(table)).single();

  @override
  Future<void> delete(String table, String id) =>
      _client.from(table).delete().eq('id', id);

  @override
  Future<List<Map<String, Object?>>> selectPresets(String space, bool home) =>
      _client
          .from('service_presets')
          .select()
          .eq('space', space)
          .eq('home', home)
          .order('sort');
}
