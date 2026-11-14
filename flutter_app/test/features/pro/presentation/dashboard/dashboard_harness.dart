import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/edit/photo_gallery_editor.dart';
import 'package:lemqes/features/pro/presentation/setup/profile_step.dart';
import 'package:material_ui/material_ui.dart';

import '../../../explore/presentation/explore_harness.dart'
    show FakeExploreRepository;
import '../setup/setup_harness.dart';

export '../setup/setup_harness.dart';

/// The smallest JPEG header the uploader would accept.
XFile jpegFile([String name = 'photo.jpg']) => XFile.fromData(
  Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]),
  name: name,
  mimeType: 'image/jpeg',
);

/// A listed barber: [barberProfile] with a publish date and [photos] work
/// photos.
ProProfile publishedBarber({
  int photos = 0,
  bool showPrices = true,
  PhoneVisibility phone = PhoneVisibility.hidden,
  bool verified = false,
  String name = 'Amine Benali',
}) => copyProfile(
  barberProfile(),
  displayName: name,
  publishedAt: DateTime.utc(2026, 11, 1),
  showPrices: showPrices,
  phoneVisibility: phone,
  isVerified: verified,
  photos: [
    for (var i = 0; i < photos; i++)
      ProPhoto(id: 'ph$i', path: 'p1/photo$i.jpg', sort: i),
  ],
);

/// The real router on `/home` as a barber whose profile is [profile]; the
/// photo pickers answer [picked] (null = the user cancelled), or run
/// [picker] when given. [fetch] answers `fetchMine` instead of [account];
/// a customer home searches an empty explore backend.
Future<SetupHarness> pumpDashboard(
  WidgetTester tester, {
  ProProfile? profile,
  Account? account,
  Future<Account?> Function()? fetch,
  FakeProRepository? pros,
  XFile? Function()? picked,
  Future<XFile?> Function()? picker,
  List<TimeOfDay>? timeAnswers,
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(390, 844),
}) {
  final pick = picked ?? jpegFile;
  final choose = picker ?? () async => pick();
  return pumpSetup(
    tester,
    account: account ?? proAccount(),
    fetch: fetch,
    pros: pros ?? FakeProRepository(profile: profile),
    location: '/home',
    timeAnswers: timeAnswers,
    overrides: [
      workPhotoPickerProvider.overrideWithValue(choose),
      avatarPickerProvider.overrideWithValue(choose),
      exploreRepositoryProvider.overrideWithValue(FakeExploreRepository()),
      exploreDebounceProvider.overrideWithValue(Duration.zero),
    ],
    locale: locale,
    themeMode: themeMode,
    textScale: textScale,
    size: size,
  );
}

/// Scrolls the dashboard until [finder] is on screen ([delta] < 0 scrolls
/// up).
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  // Built is not yet on screen: the list builds ahead of its viewport.
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// Scrolls the dashboard until [key] is on screen, then taps it.
Future<void> scrollAndTap(WidgetTester tester, String key) async {
  await scrollTo(tester, byKey(key));
  await tapAndSettle(tester, key);
}

/// Back to the top of the dashboard (the visibility card).
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
  await settle(tester);
}
