import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/time/clock_providers.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/origin.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_device_location.dart';

const _bab = Locality(
  id: 1601,
  regionCode: '16',
  nameAr: 'باب الزوار',
  nameFr: 'Bab Ezzouar',
  lat: 36.7233,
  lng: 3.1832,
);

void main() {
  late FakeDeviceLocation device;
  late StreamController<void> resumes;
  late DateTime now;
  late SharedPreferences prefs;

  Future<ProviderContainer> make() async {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocationProvider.overrideWithValue(device),
        utcClockProvider.overrideWithValue(() => now),
        appResumesProvider.overrideWithValue(resumes.stream),
      ],
    );
    addTearDown(c.dispose);
    c.listen(originProvider, (_, _) {});
    // The first build may resolve the device position asynchronously.
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    device = FakeDeviceLocation();
    resumes = StreamController<void>.broadcast();
    addTearDown(resumes.close);
    now = DateTime.utc(2026, 11, 22, 10);
  });

  test('no choice and no permission yet: none, and no prompt', () async {
    final c = await make();
    expect(c.read(originProvider), isA<NoOrigin>());
    expect(device.requests, isEmpty);
  });

  test('no choice but permission already granted: the device position, '
      'rounded to 3 decimals', () async {
    device
      ..status = DevicePermission.approximate
      ..position = const GeoPoint(36.753849, 3.058751);
    final c = await make();
    final o = c.read(originProvider);
    expect(o, isA<DeviceOrigin>());
    expect(o.point, const GeoPoint(36.754, 3.059));
    expect(device.requests, isEmpty);
  });

  for (final denied in [
    DevicePermission.denied,
    DevicePermission.deniedForever,
    DevicePermission.serviceOff,
  ]) {
    test('useDevice with $denied stays none', () async {
      device
        ..status = denied
        ..onRequest = denied;
      final c = await make();
      final r = await c.read(originProvider.notifier).useDevice();
      expect(r, denied);
      expect(c.read(originProvider), isA<NoOrigin>());
    });
  }

  test('useDevice asks for approximate only, then sets the origin', () async {
    final c = await make();
    final r = await c.read(originProvider.notifier).useDevice();
    expect(r, DevicePermission.approximate);
    expect(device.requests, [false]);
    expect(c.read(originProvider), isA<DeviceOrigin>());
  });

  test('a precise grant works the same', () async {
    device.onRequest = DevicePermission.precise;
    final c = await make();
    await c.read(originProvider.notifier).useDevice();
    expect(c.read(originProvider), isA<DeviceOrigin>());
  });

  test('granted but no fix reads as service off', () async {
    device
      ..status = DevicePermission.precise
      ..position = null;
    final c = await make();
    final r = await c.read(originProvider.notifier).useDevice();
    expect(r, DevicePermission.serviceOff);
    expect(c.read(originProvider), isA<NoOrigin>());
  });

  test('the last explicit choice wins: commune over device and back', () async {
    device.status = DevicePermission.approximate;
    final c = await make();
    final n = c.read(originProvider.notifier);
    expect(c.read(originProvider), isA<DeviceOrigin>());
    expect(n.useCommune(_bab), isTrue);
    final o = c.read(originProvider);
    expect(o, isA<CommuneOrigin>());
    expect((o as CommuneOrigin).localityId, 1601);
    expect(o.point, const GeoPoint(36.7233, 3.1832));
    await n.useDevice();
    expect(c.read(originProvider), isA<DeviceOrigin>());
  });

  test('a commune without coordinates is refused', () async {
    final c = await make();
    final ok = c
        .read(originProvider.notifier)
        .useCommune(
          const Locality(id: 1, regionCode: '01', nameAr: 'أ', nameFr: 'A'),
        );
    expect(ok, isFalse);
    expect(c.read(originProvider), isA<NoOrigin>());
  });

  test(
    'a commune choice survives a restart and beats a granted device',
    () async {
      final first = await make();
      first.read(originProvider.notifier).useCommune(_bab);
      first.dispose();

      device.status = DevicePermission.precise;
      final c = await make();
      final o = c.read(originProvider);
      expect(o, isA<CommuneOrigin>());
      expect((o as CommuneOrigin).localityId, 1601);
      expect(device.currentCalls, 0);
    },
  );

  test(
    'a device choice survives a restart; revoked permission gives none',
    () async {
      device.onRequest = DevicePermission.approximate;
      final first = await make();
      await first.read(originProvider.notifier).useDevice();
      first.dispose();

      final again = await make();
      expect(again.read(originProvider), isA<DeviceOrigin>());
      again.dispose();

      device.status = DevicePermission.denied;
      final c = await make();
      expect(c.read(originProvider), isA<NoOrigin>());
    },
  );

  group('resume', () {
    test('refreshes the device position only after 10 minutes', () async {
      device.status = DevicePermission.approximate;
      final c = await make();
      expect(device.currentCalls, 1);

      device.position = const GeoPoint(35.0, 4.0);
      now = now.add(const Duration(minutes: 9, seconds: 59));
      resumes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(device.currentCalls, 1);
      expect(c.read(originProvider).point, const GeoPoint(36.754, 3.059));

      now = now.add(const Duration(seconds: 1));
      resumes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(device.currentCalls, 2);
      expect(c.read(originProvider).point, const GeoPoint(35.0, 4.0));
    });

    test('never refreshes a commune choice', () async {
      device.status = DevicePermission.approximate;
      final c = await make();
      c.read(originProvider.notifier).useCommune(_bab);
      final calls = device.currentCalls;
      now = now.add(const Duration(hours: 1));
      resumes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(device.currentCalls, calls);
      expect(c.read(originProvider), isA<CommuneOrigin>());
    });

    test(
      'with no choice, a permission granted meanwhile is picked up',
      () async {
        final c = await make();
        expect(c.read(originProvider), isA<NoOrigin>());
        device.status = DevicePermission.approximate;
        resumes.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(originProvider), isA<DeviceOrigin>());
        expect(device.requests, isEmpty);
      },
    );
  });
}
