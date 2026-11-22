import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ExploreApi {
  Future<List<Map<String, Object?>>> searchPros(Map<String, Object?> params);
}

class SupabaseExploreApi implements ExploreApi {
  SupabaseExploreApi(this._client);

  final SupabaseClient _client;

  /// Added in M4: a server still on the older `search_pros` would fail to
  /// resolve a call naming them, so they are sent only when set.
  static const _nearMeArgs = {'p_origin_lat', 'p_origin_lng', 'p_bbox'};

  @visibleForTesting
  static Map<String, Object?> rpcParams(Map<String, Object?> params) => {
    for (final e in params.entries)
      if (e.value != null || !_nearMeArgs.contains(e.key)) e.key: e.value,
  };

  @override
  Future<List<Map<String, Object?>>> searchPros(
    Map<String, Object?> params,
  ) async {
    final rows = await _client.rpc<Object?>(
      'search_pros',
      params: rpcParams(params),
    );
    return [for (final r in rows as List<Object?>) r! as Map<String, Object?>];
  }
}
