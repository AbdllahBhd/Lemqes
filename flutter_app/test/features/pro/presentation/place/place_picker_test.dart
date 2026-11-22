import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/explore/data/explore_models.dart'
    show PlaceMode;
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/map/presentation/commune_pin.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/place/place_picker_screen.dart';
import 'package:lemqes/features/pro/presentation/setup/services_step.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../geo/data/fake_device_location.dart';
import '../setup/setup_harness.dart';

final fr = AppLocalizationsFr();

ProProfile _women(ProProfile p) => ProProfile(
  id: p.id,
  kind: p.kind,
  space: Space.women,
  displayName: 'Amina',
  workplaceType: p.workplaceType,
  phoneVisibility: p.phoneVisibility,
  showPrices: p.showPrices,
  isVerified: p.isVerified,
  localityId: p.localityId,
  customerMix: p.customerMix,
  services: p.services,
  hours: p.hours,
  place: p.place,
);

const _pin = ProPlace(
  mode: PlaceMode.exact,
  lat: 36.78,
  lng: 3.06,
  landmark: 'En face de la poste',
);

Future<SetupHarness> _pumpPicker(
  WidgetTester tester, {
  ProProfile? profile,
  Space space = Space.men,
  bool edit = false,
  DeviceLocation? device,
  Locale locale = const Locale('fr'),
}) => pumpSetup(
  tester,
  account: proAccount(space: space),
  pros: FakeProRepository(
    profile: profile ?? barberProfile(service: false, hours: false),
    space: space,
  ),
  device: device,
  locale: locale,
  location: edit ? '/pro/setup/location?edit=1' : '/pro/setup/location',
);

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<LemqesPrimaryButton>(byKey('placeSave')).onPressed != null;

void main() {
  setUpAll(registerHarnessFallbacks);

  group('in the setup flow', () {
    testWidgets('the step follows the profile; "Plus tard" goes on to the '
        'services without saving', (tester) async {
      final h = await _pumpPicker(tester);
      expect(h.location, '/pro/setup/location');
      expect(find.byType(PlacePickerScreen), findsOneWidget);
      expect(find.text(fr.stepProgress(2, 4)), findsOneWidget);

      await tapAndSettle(tester, 'placeLater');
      expect(h.location, '/pro/setup/services');
      expect(find.byType(ServicesStep), findsOneWidget);
      expect(h.pros.placeCalls, isEmpty);
    });

    testWidgets('a pin is saved with its landmark, then the services open', (
      tester,
    ) async {
      final h = await _pumpPicker(tester);
      await tapAndSettle(tester, 'placeMode_exact');
      await tester.enterText(byKey('placeLandmark'), '  En face de la poste ');
      await tapAndSettle(tester, 'placeSave');

      final call = h.pros.placeCalls.single;
      expect(call.mode, PlaceMode.exact);
      // Nobody moved the map: the pin is the commune centre.
      expect(call.lat, closeTo(algerCentreLat, 1e-6));
      expect(call.lng, closeTo(algerCentreLng, 1e-6));
      expect(call.radiusM, isNull);
      expect(call.landmark, 'En face de la poste');
      expect(h.location, '/pro/setup/services');
    });

    testWidgets('an area is saved with its radius and no landmark', (
      tester,
    ) async {
      final h = await _pumpPicker(tester);
      await tapAndSettle(tester, 'placeMode_area');
      await tapAndSettle(tester, 'placeRadius_2000');
      await tapAndSettle(tester, 'placeSave');

      final call = h.pros.placeCalls.single;
      expect(call.mode, PlaceMode.area);
      expect(call.radiusM, 2000);
      expect(call.landmark, isNull);
      expect(call.lat, isNotNull);
    });
  });

  group('the controls follow the mode', () {
    testWidgets('radius chips only for an area, the landmark only for a pin, '
        'and a preview line for each', (tester) async {
      await _pumpPicker(tester);
      // Nothing saved yet: commune only, the most private choice.
      expect(find.text(fr.placePreviewNone('men')), findsOneWidget);
      expect(byKey('placeRadius_1000'), findsNothing);
      expect(byKey('placeLandmark'), findsNothing);
      expect(find.byType(CommunePin), findsOneWidget);

      await tapAndSettle(tester, 'placeMode_exact');
      expect(byKey('placeLandmark'), findsOneWidget);
      expect(byKey('placeRadius_1000'), findsNothing);
      expect(byKey('placeCrosshair'), findsOneWidget);
      expect(find.text(fr.placePreviewExact('men')), findsOneWidget);

      await tapAndSettle(tester, 'placeMode_area');
      expect(byKey('placeLandmark'), findsNothing);
      for (final r in [500, 1000, 2000]) {
        expect(byKey('placeRadius_$r'), findsOneWidget);
      }
      expect(find.text(fr.placePreviewArea('men', '1 km')), findsOneWidget);
      await tapAndSettle(tester, 'placeRadius_500');
      expect(find.text(fr.placePreviewArea('men', '500 m')), findsOneWidget);
    });

    testWidgets('the area is drawn as a polygon around the point', (
      tester,
    ) async {
      await _pumpPicker(tester);
      await tapAndSettle(tester, 'placeMode_area');
      final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
      expect(layer.polygons.single.points.length, greaterThanOrEqualTo(72));
      expect(find.byType(CircleLayer), findsNothing);
    });

    testWidgets('"Commune seulement" clears the pin and saves none', (
      tester,
    ) async {
      final h = await _pumpPicker(
        tester,
        profile: copyProfile(barberProfile(), place: _pin),
        edit: true,
      );
      expect(byKey('placeCrosshair'), findsOneWidget);
      expect(fieldText(tester, 'placeLandmark'), 'En face de la poste');

      await tapAndSettle(tester, 'placeMode_none');
      expect(byKey('placeCrosshair'), findsNothing);
      expect(byKey('placeLandmark'), findsNothing);
      await tapAndSettle(tester, 'placeSave');

      final call = h.pros.placeCalls.single;
      expect(call.mode, PlaceMode.none);
      expect(
        (call.lat, call.lng, call.radiusM, call.landmark),
        (null, null, null, null),
      );
    });

    testWidgets('a saved pin opens where it is, not at the commune', (
      tester,
    ) async {
      final h = await _pumpPicker(
        tester,
        profile: copyProfile(barberProfile(), place: _pin),
        edit: true,
      );
      await tapAndSettle(tester, 'placeSave');
      final call = h.pros.placeCalls.single;
      expect(call.lat, closeTo(36.78, 1e-6));
      expect(call.lng, closeTo(3.06, 1e-6));
    });
  });

  group('"Ma position actuelle"', () {
    testWidgets('asks for a precise fix and moves the point there', (
      tester,
    ) async {
      final device = FakeDeviceLocation(
        onRequest: DevicePermission.precise,
        position: const GeoPoint(36.7, 3.1),
      );
      final h = await _pumpPicker(tester, device: device);
      await tapAndSettle(tester, 'placeMode_exact');
      await tapAndSettle(tester, 'placeLocate');
      expect(device.requests, [true]);

      await tapAndSettle(tester, 'placeSave');
      final call = h.pros.placeCalls.single;
      expect(call.lat, closeTo(36.7, 1e-6));
      expect(call.lng, closeTo(3.1, 1e-6));
    });

    for (final mode in ['exact', 'area']) {
      testWidgets('an $mode never opens on a fix already granted: the commune '
          'centre until the pro asks', (tester) async {
        final device = FakeDeviceLocation(
          status: DevicePermission.precise,
          position: const GeoPoint(36.7, 3.1),
        );
        final h = await _pumpPicker(tester, device: device);
        await tapAndSettle(tester, 'placeMode_$mode');
        await tapAndSettle(tester, 'placeSave');

        final call = h.pros.placeCalls.single;
        expect(call.lat, closeTo(algerCentreLat, 1e-6));
        expect(call.lng, closeTo(algerCentreLng, 1e-6));
        expect(device.currentCalls, 0);
      });
    }

    testWidgets('used for an area, it says the centre is visible', (
      tester,
    ) async {
      final device = FakeDeviceLocation(
        onRequest: DevicePermission.precise,
        position: const GeoPoint(36.7, 3.1),
      );
      await _pumpPicker(tester, device: device);
      await tapAndSettle(tester, 'placeMode_area');
      expect(byKey('placeAreaDeviceNote'), findsNothing);

      await tapAndSettle(tester, 'placeLocate');
      expect(find.text(fr.placeAreaDeviceNote), findsOneWidget);

      await tapAndSettle(tester, 'placeMode_exact');
      expect(byKey('placeAreaDeviceNote'), findsNothing);
    });

    testWidgets('without a fix it says so and the point stays', (tester) async {
      final device = FakeDeviceLocation(onRequest: DevicePermission.denied);
      final h = await _pumpPicker(tester, device: device);
      await tapAndSettle(tester, 'placeMode_exact');
      await tapAndSettle(tester, 'placeLocate');
      expect(find.text(fr.placeLocateFailed), findsOneWidget);

      await tapAndSettle(tester, 'placeSave');
      expect(h.pros.placeCalls.single.lat, closeTo(algerCentreLat, 1e-6));
    });
  });

  group('refusals', () {
    testWidgets('a point too far from the commune says so and stays', (
      tester,
    ) async {
      final h = await _pumpPicker(tester);
      h.pros.nextFailure = const PlaceTooFar();
      await tapAndSettle(tester, 'placeMode_exact');
      await tapAndSettle(tester, 'placeSave');

      expect(find.text(fr.placeErrorTooFar), findsOneWidget);
      expect(h.location, '/pro/setup/location');
    });

    testWidgets('a refusal is brought into view wherever the pro scrolled', (
      tester,
    ) async {
      final h = await _pumpPicker(
        tester,
        space: Space.women,
        profile: _women(barberProfile(service: false, hours: false)),
      );
      h.pros.nextFailure = const PlaceTooFar();
      await tapAndSettle(tester, 'placeMode_exact');
      // Down at the acknowledgement, the top of the controls is scrolled away.
      await tapAndSettle(tester, 'placeWarningAck');
      expect(find.text(fr.placeTitle).hitTestable(), findsNothing);

      await tapAndSettle(tester, 'placeSave');
      expect(find.text(fr.placeErrorTooFar).hitTestable(), findsOneWidget);
    });
  });

  group('S1: the women\'s space', () {
    for (final mode in ['exact', 'area']) {
      testWidgets('a $mode must be acknowledged before it is saved', (
        tester,
      ) async {
        final h = await _pumpPicker(
          tester,
          space: Space.women,
          profile: _women(barberProfile(service: false, hours: false)),
        );
        expect(byKey('placeWarning'), findsNothing);
        expect(_saveEnabled(tester), isTrue);

        await tapAndSettle(tester, 'placeMode_$mode');
        expect(find.text(fr.placeWarningTitle), findsOneWidget);
        expect(find.text(fr.placeWarningBody), findsOneWidget);
        expect(_saveEnabled(tester), isFalse);

        await tapAndSettle(tester, 'placeWarningAck');
        expect(_saveEnabled(tester), isTrue);
        await tapAndSettle(tester, 'placeSave');
        expect(h.pros.placeCalls.single.mode.toDb(), mode);
      });
    }

    testWidgets('commune only needs no warning', (tester) async {
      await _pumpPicker(
        tester,
        space: Space.women,
        profile: _women(barberProfile(service: false, hours: false)),
      );
      await tapAndSettle(tester, 'placeMode_exact');
      await tapAndSettle(tester, 'placeMode_none');
      expect(byKey('placeWarning'), findsNothing);
      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('the men\'s space shows no warning', (tester) async {
      await _pumpPicker(tester);
      await tapAndSettle(tester, 'placeMode_exact');
      expect(byKey('placeWarning'), findsNothing);
    });
  });

  group('edit', () {
    testWidgets('saving returns to where the editor was opened from', (
      tester,
    ) async {
      final h = await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile()),
        location: '/home',
      );
      h.router.push('/pro/setup/location?edit=1');
      await settle(tester);
      expect(byKey('placeLater'), findsNothing);
      await tapAndSettle(tester, 'placeMode_exact');
      await tapAndSettle(tester, 'placeSave');
      expect(h.location, '/home');
      expect(h.pros.profile!.place?.mode, PlaceMode.exact);
    });
  });

  group('200 % text in Arabic', () {
    for (final mode in ['none', 'exact', 'area']) {
      testWidgets('the $mode picker does not overflow', (tester) async {
        await pumpSetup(
          tester,
          account: proAccount(space: Space.women),
          pros: FakeProRepository(
            profile: _women(barberProfile()),
            space: Space.women,
          ),
          location: '/pro/setup/location',
          locale: const Locale('ar'),
          textScale: 2,
        );
        await tapAndSettle(tester, 'placeMode_$mode');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
