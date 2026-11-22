import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/shared_preferences_provider.dart';
import '../../../core/time/clock_providers.dart';
import '../../account/data/account_providers.dart';
import '../../live/data/live_providers.dart';
import 'device_location.dart';
import 'geo_models.dart';

/// Where the customer measures distances from: a search parameter, never
/// written to the server.
sealed class Origin {
  const Origin();

  /// Null for [NoOrigin].
  GeoPoint? get point;
}

class NoOrigin extends Origin {
  const NoOrigin();

  @override
  GeoPoint? get point => null;
}

class DeviceOrigin extends Origin {
  const DeviceOrigin(this.position);

  /// Already rounded to 3 decimals (about 100 m).
  final GeoPoint position;

  @override
  GeoPoint get point => position;
}

class CommuneOrigin extends Origin {
  const CommuneOrigin({
    required this.localityId,
    required this.lat,
    required this.lng,
  });

  final int localityId;
  final double lat;
  final double lng;

  @override
  GeoPoint get point => GeoPoint(lat, lng);
}

/// SharedPreferences key holding the last explicit chip choice: the JSON
/// `{"kind":"device"}` or `{"kind":"commune","id":<int>,"lat":<d>,"lng":<d>}`.
/// A device choice stores no coordinates (a stale fix would mislead); a
/// commune keeps its centre so the origin is known before any network call.
const originChoiceKey = 'origin_choice_v1';

/// A device fix younger than this is not refreshed on resume.
const deviceFixMaxAge = Duration(minutes: 10);

/// The signed-in account's id, null while signed out or loading. The
/// origin is per account: a shared phone must not hand one customer's
/// commune to the next.
final originAccountIdProvider = Provider<String?>(
  (ref) => ref.watch(accountProvider.select((a) => a.value?.id)),
);

final originProvider = NotifierProvider<OriginController, Origin>(
  OriginController.new,
  retry: (_, _) => null,
);

class OriginController extends Notifier<Origin> {
  DateTime? _fixAt;

  // Bumped by every explicit choice so a slower device fix cannot overwrite
  // a choice made while it was in flight.
  var _choice = 0;

  @override
  Origin build() {
    final sub = ref.read(appResumesProvider).listen((_) {
      unawaited(_onResume());
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    // Only a change from a known account: the session resolving at start-up
    // (null, then the id) keeps the stored choice. location_requested_v1 is
    // the OS's answer for the device, so it stays.
    ref.listen(originAccountIdProvider, (previous, next) {
      if (previous == null || previous == next) return;
      _choice++;
      _fixAt = null;
      unawaited(ref.read(sharedPreferencesProvider).remove(originChoiceKey));
      // The change can be noticed while a widget first watches the origin,
      // when no provider may notify: the new state waits for that build.
      scheduleMicrotask(() {
        if (!ref.mounted) return;
        state = const NoOrigin();
        if (next != null) unawaited(_resolveDevice());
      });
    });

    // A stored commune wins at once. Otherwise (a stored device choice, or
    // none) the device position is used when permission is already granted.
    final commune = _storedCommune();
    if (commune != null) return commune;
    unawaited(_resolveDevice());
    return const NoOrigin();
  }

  /// "Ma position": asks for permission if needed (approximate), then takes
  /// a fix. Anything but a grant with a fix leaves the origin as it was and
  /// is returned, so the caller can offer the commune picker.
  Future<DevicePermission> useDevice() async {
    final location = ref.read(deviceLocationProvider);
    var p = await location.permission();
    if (!p.granted) p = await location.request(precise: false);
    if (!p.granted) return p;
    final choice = ++_choice;
    final fix = await location.current();
    if (!ref.mounted) return p;
    if (fix == null) return DevicePermission.serviceOff;
    if (choice == _choice) {
      _setDevice(fix);
      await _store({'kind': 'device'});
    }
    return p;
  }

  /// A commune's centre; false when the commune has no coordinates.
  bool useCommune(Locality locality) {
    final lat = locality.lat;
    final lng = locality.lng;
    if (lat == null || lng == null) return false;
    _choice++;
    state = CommuneOrigin(localityId: locality.id, lat: lat, lng: lng);
    unawaited(
      _store({'kind': 'commune', 'id': locality.id, 'lat': lat, 'lng': lng}),
    );
    return true;
  }

  /// The stored commune, or null (none stored, a device choice, or a
  /// malformed value: the customer simply picks again).
  CommuneOrigin? _storedCommune() {
    final raw = ref.read(sharedPreferencesProvider).getString(originChoiceKey);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      if (m['kind'] != 'commune') return null;
      return CommuneOrigin(
        localityId: m['id']! as int,
        lat: (m['lat']! as num).toDouble(),
        lng: (m['lng']! as num).toDouble(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _store(Map<String, Object?> value) => ref
      .read(sharedPreferencesProvider)
      .setString(originChoiceKey, jsonEncode(value));

  /// Start-up and resume: the device position when permission is already
  /// granted. Never prompts.
  Future<void> _resolveDevice() async {
    final choice = _choice;
    final location = ref.read(deviceLocationProvider);
    if (!(await location.permission()).granted) return;
    final fix = await location.current();
    if (!ref.mounted || fix == null || choice != _choice) return;
    _setDevice(fix);
  }

  void _setDevice(GeoPoint fix) {
    _fixAt = ref.read(utcClockProvider)();
    state = DeviceOrigin(GeoPoint(_round3(fix.lat), _round3(fix.lng)));
  }

  Future<void> _onResume() async {
    final current = state;
    if (current is CommuneOrigin) return;
    if (current is DeviceOrigin) {
      final at = _fixAt;
      if (at != null &&
          ref.read(utcClockProvider)().difference(at) < deviceFixMaxAge) {
        return;
      }
    }
    await _resolveDevice();
  }

  static double _round3(double v) => (v * 1000).round() / 1000;
}
