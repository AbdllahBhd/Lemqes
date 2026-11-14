import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountApi {
  Future<Object?> rpc(String fn, Map<String, Object?> params);
  Future<Map<String, Object?>?> myProfile();
  Future<List<Map<String, Object?>>> myRoles();
}

class SupabaseAccountApi implements AccountApi {
  SupabaseAccountApi(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String fn, Map<String, Object?> params) =>
      _client.rpc(fn, params: params);

  // RLS limits both tables to the caller's own rows.
  @override
  Future<Map<String, Object?>?> myProfile() =>
      _client.from('profiles').select().maybeSingle();

  @override
  Future<List<Map<String, Object?>>> myRoles() =>
      _client.from('profile_roles').select();
}
