import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase adapter (mockable): every live call is an RPC.
abstract interface class LiveApi {
  Future<Object?> rpc(String fn, Map<String, Object?> params);
}

class SupabaseLiveApi implements LiveApi {
  SupabaseLiveApi(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) =>
      _client.rpc(fn, params: params);
}
