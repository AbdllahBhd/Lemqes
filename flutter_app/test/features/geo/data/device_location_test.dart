import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as g;
import 'package:lemqes/features/geo/data/device_location.dart';

DevicePermission _map(
  g.LocationPermission p, {
  bool everRequested = false,
  bool serviceEnabled = true,
  g.LocationAccuracyStatus accuracy = g.LocationAccuracyStatus.precise,
}) => mapDevicePermission(
  permission: p,
  everRequested: everRequested,
  serviceEnabled: serviceEnabled,
  accuracy: accuracy,
);

void main() {
  group('mapDevicePermission', () {
    test('denied before any request is notAsked', () {
      expect(_map(g.LocationPermission.denied), DevicePermission.notAsked);
      expect(
        _map(g.LocationPermission.unableToDetermine),
        DevicePermission.notAsked,
      );
    });

    test('denied after a request is denied', () {
      expect(
        _map(g.LocationPermission.denied, everRequested: true),
        DevicePermission.denied,
      );
      expect(
        _map(g.LocationPermission.unableToDetermine, everRequested: true),
        DevicePermission.denied,
      );
    });

    test('deniedForever stays deniedForever either way', () {
      for (final asked in [false, true]) {
        expect(
          _map(g.LocationPermission.deniedForever, everRequested: asked),
          DevicePermission.deniedForever,
        );
      }
    });

    test('service off wins over every permission', () {
      for (final p in g.LocationPermission.values) {
        expect(_map(p, serviceEnabled: false), DevicePermission.serviceOff);
      }
    });

    test('granted reads approximate when the accuracy is reduced', () {
      for (final p in [
        g.LocationPermission.whileInUse,
        g.LocationPermission.always,
      ]) {
        expect(
          _map(p, accuracy: g.LocationAccuracyStatus.reduced),
          DevicePermission.approximate,
        );
        expect(_map(p), DevicePermission.precise);
        expect(
          _map(p, accuracy: g.LocationAccuracyStatus.unknown),
          DevicePermission.precise,
        );
      }
    });
  });
}
