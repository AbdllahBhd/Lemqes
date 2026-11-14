import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class MediaStorage {
  Future<void> upload(String bucket, String path, Uint8List bytes);
  Future<void> remove(String bucket, List<String> paths);
  String publicUrl(String bucket, String path);
}

class SupabaseMediaStorage implements MediaStorage {
  SupabaseMediaStorage(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload(String bucket, String path, Uint8List bytes) => _client
      .storage
      .from(bucket)
      .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

  @override
  Future<void> remove(String bucket, List<String> paths) =>
      _client.storage.from(bucket).remove(paths);

  @override
  String publicUrl(String bucket, String path) =>
      _client.storage.from(bucket).getPublicUrl(path);
}
