import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'media_storage.dart';
import 'pro_api.dart';
import 'pro_failure.dart';
import 'pro_models.dart';

const avatarsBucket = 'avatars';
const workPhotosBucket = 'work-photos';

/// Object names are `<proId>/<uuid>.<jpg|png|webp>` (never the account id: the path
/// reaches customers) and the stored row path equals the object name.
class PhotoUploader {
  PhotoUploader(this._api, this._storage, {String Function()? newId})
    : _newId = newId ?? _uuidV4;

  final ProApi _api;
  final MediaStorage _storage;
  final String Function() _newId;

  /// Needs the profile to exist (its id is the folder). Returns the path now
  /// stored in `avatar_path`.
  ///
  /// [previous] (the replaced `avatar_path`) is removed once the row points
  /// at the new photo: the bucket is public, so a kept object would stay
  /// reachable. Its removal is best effort and never fails the upload.
  Future<String> uploadAvatar(String proId, XFile file, {String? previous}) =>
      guardPro(() async {
        final path = await _upload(avatarsBucket, proId, file);
        try {
          await _api.update('pro_profiles', proId, {'avatar_path': path});
        } on Object {
          await _discard(avatarsBucket, path);
          rethrow;
        }
        if (previous != null && previous != path) {
          await _discard(avatarsBucket, previous);
        }
        return path;
      });

  Future<ProPhoto> addWorkPhoto(String proId, XFile file) => guardPro(() async {
    final path = await _upload(workPhotosBucket, proId, file);
    try {
      final row = await _api.insert('pro_photos', {
        'pro_id': proId,
        'path': path,
      });
      return ProPhoto.fromRow(row);
    } on Object {
      await _discard(workPhotosBucket, path);
      rethrow;
    }
  });

  /// Row first: if the object removal then fails, only an unreferenced file
  /// is left behind, never a row pointing at nothing.
  Future<void> removeWorkPhoto(ProPhoto photo) => guardPro(() async {
    await _api.delete('pro_photos', photo.id);
    await _storage.remove(workPhotosBucket, [photo.path]);
  });

  String publicUrl(String bucket, String path) =>
      _storage.publicUrl(bucket, path);

  Future<String> _upload(String bucket, String proId, XFile file) async {
    final bytes = await file.readAsBytes();
    final type = _sniff(bytes);
    if (type == null) throw const UnsupportedImage();
    final path = '$proId/${_newId()}.${type.ext}';
    await _storage.upload(bucket, path, bytes, type.mime);
    return path;
  }

  Future<void> _discard(String bucket, String path) async {
    try {
      await _storage.remove(bucket, [path]);
    } on Object catch (e, st) {
      // The caller's outcome matters more; an orphan only takes space.
      developer.log(
        'orphan object not removed: $bucket/$path',
        error: e,
        stackTrace: st,
      );
    }
  }
}

({String ext, String mime})? _sniff(Uint8List b) {
  bool at(int i, List<int> m) =>
      b.length >= i + m.length &&
      [for (var k = 0; k < m.length; k++) b[i + k] == m[k]].every((x) => x);
  if (at(0, [0xFF, 0xD8])) return (ext: 'jpg', mime: 'image/jpeg');
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return (ext: 'png', mime: 'image/png');
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
    return (ext: 'webp', mime: 'image/webp');
  }
  return null;
}

String _uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
