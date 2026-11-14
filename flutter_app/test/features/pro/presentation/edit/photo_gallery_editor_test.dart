import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';

import '../dashboard/dashboard_harness.dart';

Future<void> _toGallery(WidgetTester tester) =>
    scrollTo(tester, byKey('photoAdd'));

Future<void> _tapRemove(WidgetTester tester) async {
  final remove = byKey('photoRemove').first;
  await tester.ensureVisible(remove);
  await tester.pump();
  await tester.tap(remove);
  await settle(tester);
}

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('a picked photo is uploaded and joins the grid', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber(photos: 2));
    await _toGallery(tester);
    expect(find.text('2/9'), findsOneWidget);

    await tapAndSettle(tester, 'photoAdd');
    expect(h.photos.calls, ['addWorkPhoto']);
    expect(h.pros.profile!.photos, hasLength(3));
    expect(byKey('photo_new1'), findsOneWidget);
    expect(find.text('3/9'), findsOneWidget);
  });

  testWidgets('a cancelled pick uploads nothing', (tester) async {
    final h = await pumpDashboard(
      tester,
      profile: publishedBarber(),
      picked: () => null,
    );
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');
    expect(h.photos.calls, isEmpty);
  });

  testWidgets('an upload in flight shows its progress', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    final gate = Completer<void>();
    h.photos.gate = gate;
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');
    expect(byKey('photoUploading_0'), findsOneWidget);
    expect(find.bySemanticsLabel(fr.photosUploading), findsOneWidget);

    gate.complete();
    await settle(tester);
    expect(byKey('photoUploading_0'), findsNothing);
    expect(byKey('photo_new1'), findsOneWidget);
  });

  testWidgets('the tenth photo cannot be added and says why', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber(photos: 9));
    await _toGallery(tester);
    expect(find.text('9/9'), findsOneWidget);
    expect(find.text(fr.photosLimit), findsOneWidget);

    await tester.tap(byKey('photoAdd'));
    await settle(tester);
    expect(h.photos.calls, isEmpty);
  });

  testWidgets('the ninth photo fills the gallery', (tester) async {
    await pumpDashboard(tester, profile: publishedBarber(photos: 8));
    await _toGallery(tester);
    expect(find.text(fr.photosLimit), findsNothing);
    await tapAndSettle(tester, 'photoAdd');
    expect(find.text(fr.photosLimit), findsOneWidget);
  });

  testWidgets('removing a photo asks to confirm first', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber(photos: 2));
    await _toGallery(tester);

    await _tapRemove(tester);
    expect(find.text(fr.photoRemoveConfirmTitle), findsOneWidget);
    await tester.tap(find.text(fr.actionCancel));
    await settle(tester);
    expect(h.photos.calls, isEmpty);
    expect(h.pros.profile!.photos, hasLength(2));

    await _tapRemove(tester);
    await tapAndSettle(tester, 'photoRemoveConfirm');
    expect(h.photos.calls, ['removeWorkPhoto:ph0']);
    expect(byKey('photo_ph0'), findsNothing);
    expect(byKey('photo_ph1'), findsOneWidget);
  });

  testWidgets('a failed upload says why and can be retried', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.photos.nextFailure = const PhotoTooLarge();
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');

    expect(find.text(fr.proErrorImageTooLarge), findsOneWidget);
    expect(byKey('photoRetry_0'), findsOneWidget);
    expect(h.pros.profile!.photos, isEmpty);

    await tapAndSettle(tester, 'photoRetry_0');
    expect(h.photos.calls, ['addWorkPhoto', 'addWorkPhoto']);
    expect(byKey('photoRetry_0'), findsNothing);
    expect(byKey('photo_new1'), findsOneWidget);
  });

  testWidgets('a failed upload can be dropped', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.photos.nextFailure = const ProNetworkFailure();
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');
    await tapAndSettle(tester, 'photoDiscard_0');
    expect(byKey('photoRetry_0'), findsNothing);
    expect(h.photos.calls, ['addWorkPhoto']);
  });

  testWidgets('the server cap reads as the photo limit', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.photos.nextFailure = const TooManyPhotos();
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');
    expect(find.text(fr.proErrorTooManyPhotos), findsOneWidget);
  });

  testWidgets('a photo stored but not reloaded is not offered again', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.pros.mineScript.add(() async => throw const ProNetworkFailure());
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');

    expect(h.photos.calls, ['addWorkPhoto']);
    expect(byKey('photoRetry_0'), findsNothing);
    expect(byKey('photoUploading_0'), findsNothing);
    // The reload that follows shows it.
    expect(byKey('photo_new1'), findsOneWidget);
  });

  testWidgets('a reload that keeps failing is said, never retried', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    h.pros.mineScript
      ..add(() async => throw const ProNetworkFailure())
      ..add(() async => throw const ProNetworkFailure());
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');

    expect(find.text(fr.errorNetwork), findsOneWidget);
    expect(byKey('photoRetry_0'), findsNothing);
    expect(h.photos.calls, ['addWorkPhoto']);
  });

  testWidgets('a picker that fails says so and frees the add tile', (
    tester,
  ) async {
    var opened = 0;
    final h = await pumpDashboard(
      tester,
      profile: publishedBarber(),
      picker: () async {
        opened++;
        throw PlatformException(code: 'already_active');
      },
    );
    await _toGallery(tester);
    await tapAndSettle(tester, 'photoAdd');
    expect(find.text(fr.photoPickFailed), findsOneWidget);

    await tapAndSettle(tester, 'photoAdd');
    expect(opened, 2);
    expect(h.photos.calls, isEmpty);
  });
}
