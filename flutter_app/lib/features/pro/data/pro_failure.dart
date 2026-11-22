import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'pro_models.dart';

sealed class ProFailure implements Exception {
  const ProFailure();
}

class ProRoleNotHeld extends ProFailure {
  const ProRoleNotHeld();
}

/// The caller has no account profile row (`profile_missing`), not a pro one.
class ProAccountMissing extends ProFailure {
  const ProAccountMissing();
}

class ProProfileExists extends ProFailure {
  const ProProfileExists();
}

class NotOwner extends ProFailure {
  const NotOwner();
}

class InvalidHours extends ProFailure {
  const InvalidHours();
}

class InvalidWeekday extends ProFailure {
  const InvalidWeekday();
}

class InvalidBreak extends ProFailure {
  const InvalidBreak();
}

class ProfileIncomplete extends ProFailure {
  const ProfileIncomplete(this.gaps);
  final Set<ProfileGap> gaps;
}

class TooManyServices extends ProFailure {
  const TooManyServices();
}

class TooManyPhotos extends ProFailure {
  const TooManyPhotos();
}

class PresetSpaceMismatch extends ProFailure {
  const PresetSpaceMismatch();
}

class UnsupportedImage extends ProFailure {
  const UnsupportedImage();
}

class PhotoTooLarge extends ProFailure {
  const PhotoTooLarge();
}

/// The pro has no commune yet (`no_locality`): a place needs one to be
/// checked against.
class PlaceNoLocality extends ProFailure {
  const PlaceNoLocality();
}

/// Mode and fields disagree, or the radius/landmark/point is not acceptable
/// (`place_invalid`).
class PlaceInvalid extends ProFailure {
  const PlaceInvalid();
}

class PlaceOutOfCountry extends ProFailure {
  const PlaceOutOfCountry();
}

/// The point is too far from the pro's commune (`place_too_far`).
class PlaceTooFar extends ProFailure {
  const PlaceTooFar();
}

/// The same request id came back with different values (`request_reused`).
class PlaceRequestReused extends ProFailure {
  const PlaceRequestReused();
}

class ProNetworkFailure extends ProFailure {
  const ProNetworkFailure();
}

class UnknownProFailure extends ProFailure {
  const UnknownProFailure(this.debug);
  final String debug;
}

/// Runs [body] and turns every escaping error into a [ProFailure].
Future<T> guardPro<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on ProFailure {
    rethrow;
  } on PostgrestException catch (e) {
    throw _map(e);
  } on StorageException catch (e) {
    throw _mapStorage(e);
  } on SocketException {
    throw const ProNetworkFailure();
  } on TimeoutException {
    throw const ProNetworkFailure();
  } on Object catch (e) {
    // package:http's ClientException is matched by name: http is not a direct
    // dependency of this package.
    if (e.runtimeType.toString() == 'ClientException') {
      throw const ProNetworkFailure();
    }
    throw UnknownProFailure(e.toString());
  }
}

ProFailure _mapStorage(StorageException e) {
  final status = e.statusCode;
  final m = e.message.toLowerCase();
  if (status == '413' || m.contains('too large') || m.contains('exceeded')) {
    return const PhotoTooLarge();
  }
  if (status == '415' || m.contains('mime')) return const UnsupportedImage();
  if (status == '403' || m.contains('row-level security')) {
    return const NotOwner();
  }
  return UnknownProFailure(e.message);
}

ProFailure _map(PostgrestException e) {
  final m = e.message;
  if (m.contains('role_not_held')) return const ProRoleNotHeld();
  if (m.contains('profile_missing')) return const ProAccountMissing();
  if (m.contains('pro_profile_exists')) return const ProProfileExists();
  if (m.contains('not_owner')) return const NotOwner();
  if (m.contains('invalid_hours')) return const InvalidHours();
  if (m.contains('invalid_weekday')) return const InvalidWeekday();
  if (m.contains('invalid_break')) return const InvalidBreak();
  if (m.contains('profile_incomplete')) {
    return ProfileIncomplete(_gaps(e.details));
  }
  if (m.contains('too_many_services')) return const TooManyServices();
  if (m.contains('too_many_photos')) return const TooManyPhotos();
  if (m.contains('preset_space_mismatch')) return const PresetSpaceMismatch();
  if (m.contains('no_locality')) return const PlaceNoLocality();
  if (m.contains('place_invalid')) return const PlaceInvalid();
  if (m.contains('place_out_of_country')) return const PlaceOutOfCountry();
  if (m.contains('place_too_far')) return const PlaceTooFar();
  if (m.contains('request_reused')) return const PlaceRequestReused();
  return UnknownProFailure(m);
}

Set<ProfileGap> _gaps(Object? details) {
  final out = <ProfileGap>{};
  if (details is! String) return out;
  for (final part in details.split(',')) {
    final key = part.trim();
    for (final g in ProfileGap.values) {
      if (g.dbKey == key) out.add(g);
    }
  }
  return out;
}
