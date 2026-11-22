import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/explore/data/explore_models.dart'
    show PlaceMode;
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/place/place_picker_screen.dart';

import 'dashboard_harness.dart';

final fr = AppLocalizationsFr();

ProProfile _with(WorkplaceType type, {ProPlace? place}) =>
    copyProfile(publishedBarber(), workplaceType: type, place: place);

const _pin = ProPlace(mode: PlaceMode.exact, lat: 36.78, lng: 3.06);

void main() {
  setUpAll(registerHarnessFallbacks);

  group('S2: the nudge', () {
    testWidgets('shows for a salon that shows no place', (tester) async {
      await pumpDashboard(tester, profile: _with(WorkplaceType.salon));
      await scrollTo(tester, byKey('placeCard'));
      expect(find.text(fr.placeNudgeTitle), findsOneWidget);
      expect(byKey('dashPlaceNudgeAction'), findsOneWidget);
    });

    for (final type in [WorkplaceType.ownStudio, WorkplaceType.mobile]) {
      testWidgets('never shows for ${type.toDb()}', (tester) async {
        await pumpDashboard(tester, profile: _with(type));
        await scrollTo(tester, byKey('placeCard'));
        expect(find.text(fr.placeNudgeTitle), findsNothing);
        expect(find.text(fr.placeSummaryNone), findsOneWidget);
        expect(byKey('dashEditPlace'), findsOneWidget);
      });
    }

    testWidgets('never shows once a salon shows a place', (tester) async {
      await pumpDashboard(
        tester,
        profile: _with(WorkplaceType.salon, place: _pin),
      );
      await scrollTo(tester, byKey('placeCard'));
      expect(find.text(fr.placeNudgeTitle), findsNothing);
      expect(find.text(fr.placeSummaryExact), findsOneWidget);
    });

    testWidgets('its action opens the picker', (tester) async {
      final h = await pumpDashboard(
        tester,
        profile: _with(WorkplaceType.salon),
      );
      await scrollAndTap(tester, 'dashPlaceNudgeAction');
      expect(h.router.state.uri.toString(), '/pro/setup/location?edit=1');
      expect(find.byType(PlacePickerScreen), findsOneWidget);
    });
  });

  group('S1: "Masquer mon emplacement"', () {
    testWidgets('sets none in one tap', (tester) async {
      final h = await pumpDashboard(
        tester,
        profile: _with(WorkplaceType.ownStudio, place: _pin),
      );
      await scrollAndTap(tester, 'dashHidePlace');

      expect(h.pros.placeCalls.single.mode, PlaceMode.none);
      expect(find.text(fr.placeHidden), findsOneWidget);
      expect(find.text(fr.placeSummaryNone), findsOneWidget);
      expect(byKey('dashHidePlace'), findsNothing);
    });

    testWidgets('a failure says so and keeps the place', (tester) async {
      final h = await pumpDashboard(
        tester,
        profile: _with(WorkplaceType.ownStudio, place: _pin),
      );
      h.pros.nextFailure = const ProNetworkFailure();
      await scrollAndTap(tester, 'dashHidePlace');

      expect(find.text(fr.errorNetwork), findsOneWidget);
      expect(find.text(fr.placeSummaryExact), findsOneWidget);
    });

    testWidgets('is not offered when nothing is shown', (tester) async {
      await pumpDashboard(tester, profile: _with(WorkplaceType.ownStudio));
      await scrollTo(tester, byKey('placeCard'));
      expect(byKey('dashHidePlace'), findsNothing);
    });
  });

  testWidgets('an area reads its size', (tester) async {
    await pumpDashboard(
      tester,
      profile: _with(
        WorkplaceType.mobile,
        place: const ProPlace(
          mode: PlaceMode.area,
          lat: 36.78,
          lng: 3.06,
          areaRadiusM: 2000,
        ),
      ),
    );
    await scrollTo(tester, byKey('placeCard'));
    expect(find.text(fr.placeSummaryArea('2 km')), findsOneWidget);
  });
}
