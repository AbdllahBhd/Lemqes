import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ExploreApi {
  Future<List<Map<String, Object?>>> searchPros(Map<String, Object?> params);
}

class SupabaseExploreApi implements ExploreApi {
  SupabaseExploreApi(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, Object?>>> searchPros(
    Map<String, Object?> params,
  ) async {
    final rows = await _client.rpc<Object?>('search_pros', params: params);
    return [for (final r in rows as List<Object?>) r! as Map<String, Object?>];
  }
}
