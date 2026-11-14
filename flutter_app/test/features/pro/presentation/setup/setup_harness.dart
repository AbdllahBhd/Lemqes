import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/router/app_router.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/geo_providers.dart';
import 'package:lemqes/features/geo/data/geo_repository.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart'
    show profileClockProvider;
import 'package:lemqes/features/pro/data/photo_uploader.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:lemqes/features/pro/data/pro_repository.dart';
import 'package:lemqes/features/pro/presentation/edit/hours_editor.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';
import 'package:lemqes/features/signup/data/signup_draft_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/harness.dart';

export '../../../auth/presentation/harness.dart'
    show byKey, fieldText, registerHarnessFallbacks, testSession;

Account proAccount({AppRole role = AppRole.barber, Space space = Space.men}) =>
    Account(
      id: 'u1',
      fullName: 'Amine Benali',
      customerSpace: space,
      proSpace: space,
      activeRole: role,
      roles: {AppRole.customer, role},
    );

const menCut = ServicePreset(
  key: 'men_cut',
  space: Space.men,
  home: false,
  category: ServiceCategory.hair,
  nameAr: 'قصة شعر',
  nameFr: 'Coupe homme',
  nameEn: "Men's haircut",
  nameKab: 'Tukksa n uzar',
  defaultPriceDzd: 600,
  defaultDurationMin: 30,
  sort: 1,
);

const menBeard = ServicePreset(
  key: 'men_beard',
  space: Space.men,
  home: false,
  category: ServiceCategory.beard,
  nameAr: 'تهذيب اللحية',
  nameFr: 'Taille de barbe',
  nameEn: 'Beard trim',
  nameKab: 'Tuksa n tmart',
  defaultPriceDzd: 300,
  defaultDurationMin: 15,
  sort: 2,
);

const _alger = Region(
  countryCode: 'DZ',
  code: '16',
  nameAr: 'الجزائر',
  nameFr: 'Alger',
);
const _algerCentre = Locality(
  id: 1601,
  regionCode: '16',
  nameAr: 'الجزائر الوسطى',
  nameFr: 'Alger Centre',
);

class FakeGeoRepository extends Fake implements GeoRepository {
  FakeGeoRepository({this.failLocality = false});

  /// The by-id lookup of a saved commune fails (e.g. offline).
  final bool failLocality;

  @override
  Future<List<Region>> regions(String country) async => [_alger];

  @override
  Future<List<Locality>> localities(String country, String regionCode) async =>
      regionCode == '16' ? [_algerCentre] : [];

  @override
  Future<Locality?> locality(int id) async {
    if (failLocality) throw const ProNetworkFailure();
    return id == 1601 ? _algerCentre : null;
  }
}

/// An in-memory pro backend with the database's publish rule.
class FakeProRepository extends Fake implements ProRepository {
  FakeProRepository({this.profile, this.space = Space.men});

  ProProfile? profile;
  final Space space;
  final calls = <String>[];
  List<DayHours>? savedWeek;

  /// When set, [publish] throws it instead of applying the rule.
  ProFailure? publishFailure;

  /// When set, the next write throws it (then it is cleared).
  ProFailure? nextFailure;

  void _failIfScripted() {
    final failure = nextFailure;
    if (failure == null) return;
    nextFailure = null;
    throw failure;
  }

  /// Like the database's trigger: a profile with no active service or no
  /// open day is no longer listed.
  void _unpublishIfIncomplete() {
    final p = profile!;
    if (p.isPublished &&
        (!p.services.any((s) => s.active) || p.hours.isEmpty)) {
      profile = copyProfile(p, unpublish: true);
    }
  }

  var _ids = 0;

  /// Answers for the next `mine` calls, in order (then the stored profile):
  /// a pending future, a lost profile, a failure.
  final mineScript = <Future<ProProfile?> Function()>[];

  @override
  Future<ProProfile?> mine(ProKind kind, {required AppRole activeRole}) async {
    if (mineScript.isNotEmpty) return mineScript.removeAt(0)();
    return profile?.kind == kind ? profile : null;
  }

  @override
  Future<ProProfile> create(
    ProKind kind, {
    required String displayName,
    required WorkplaceType workplaceType,
  }) async {
    calls.add('create');
    if (profile != null) throw const ProProfileExists();
    return profile = ProProfile(
      id: 'p1',
      kind: kind,
      space: space,
      displayName: displayName,
      workplaceType: workplaceType,
      phoneVisibility: PhoneVisibility.hidden,
      showPrices: true,
      isVerified: false,
    );
  }

  ProProfilePatch? lastPatch;

  @override
  Future<void> updateProfile(String proId, ProProfilePatch patch) async {
    calls.add('updateProfile');
    _failIfScripted();
    lastPatch = patch;
    final p = profile!;
    bool cleared(PatchField f) => patch.clear.contains(f);
    profile = copyProfile(
      p,
      displayName: patch.displayName ?? p.displayName,
      experienceYears: cleared(PatchField.experienceYears)
          ? null
          : patch.experienceYears ?? p.experienceYears,
      workplaceType: patch.workplaceType ?? p.workplaceType,
      workplaceName: cleared(PatchField.workplaceName)
          ? null
          : patch.workplaceName ?? p.workplaceName,
      localityId: patch.localityId ?? p.localityId,
      customerMix: patch.customerMix ?? p.customerMix,
      serviceRadiusKm: patch.serviceRadiusKm ?? p.serviceRadiusKm,
      travelFeeDzd: patch.travelFeeDzd ?? p.travelFeeDzd,
      phoneVisibility: patch.phoneVisibility,
      showPrices: patch.showPrices,
      avatarPath: patch.avatarPath,
    );
  }

  @override
  Future<ProService> upsertService(String proId, ProServiceDraft d) async {
    calls.add('upsertService');
    _failIfScripted();
    final s = ProService(
      id: d.id ?? 's${++_ids}',
      presetKey: d.presetKey,
      customName: d.customName,
      category: d.category,
      priceDzd: d.priceDzd,
      durationMin: d.durationMin,
      active: d.active,
    );
    final p = profile!;
    profile = copyProfile(
      p,
      services: [
        for (final o in p.services)
          if (o.id != s.id) o,
        s,
      ],
    );
    _unpublishIfIncomplete();
    return s;
  }

  @override
  Future<void> archiveService(String serviceId) async {
    calls.add('archiveService');
    _failIfScripted();
    final p = profile!;
    profile = copyProfile(
      p,
      services: [
        for (final o in p.services)
          if (o.id != serviceId) o,
      ],
    );
    _unpublishIfIncomplete();
  }

  @override
  Future<void> setHours(String proId, List<DayHours> week) async {
    calls.add('setHours');
    _failIfScripted();
    savedWeek = week;
    profile = copyProfile(profile!, hours: week);
    _unpublishIfIncomplete();
  }

  @override
  Future<DateTime> publish(String proId) async {
    calls.add('publish');
    final failure = publishFailure;
    if (failure != null) throw failure;
    final gaps = profile!.gaps;
    if (gaps.isNotEmpty) throw ProfileIncomplete(gaps);
    final at = DateTime.utc(2026, 11, 14);
    profile = copyProfile(profile!, publishedAt: at);
    return at;
  }

  @override
  Future<List<ServicePreset>> presets(
    Space space, {
    required bool home,
  }) async => [menCut, menBeard];
}

ProProfile copyProfile(
  ProProfile p, {
  String? displayName,
  int? experienceYears,
  WorkplaceType? workplaceType,
  String? workplaceName,
  int? localityId,
  CustomerMix? customerMix,
  int? serviceRadiusKm,
  int? travelFeeDzd,
  DateTime? publishedAt,
  List<ProService>? services,
  List<DayHours>? hours,
  List<ProPhoto>? photos,
  PhoneVisibility? phoneVisibility,
  bool? showPrices,
  String? avatarPath,
  bool? isVerified,
  bool unpublish = false,
}) => ProProfile(
  id: p.id,
  kind: p.kind,
  space: p.space,
  displayName: displayName ?? p.displayName,
  experienceYears: experienceYears ?? p.experienceYears,
  workplaceType: workplaceType ?? p.workplaceType,
  workplaceName: workplaceName ?? p.workplaceName,
  localityId: localityId ?? p.localityId,
  customerMix: customerMix ?? p.customerMix,
  serviceRadiusKm: serviceRadiusKm ?? p.serviceRadiusKm,
  travelFeeDzd: travelFeeDzd ?? p.travelFeeDzd,
  phoneVisibility: phoneVisibility ?? p.phoneVisibility,
  showPrices: showPrices ?? p.showPrices,
  isVerified: isVerified ?? p.isVerified,
  avatarPath: avatarPath ?? p.avatarPath,
  publishedAt: unpublish ? null : publishedAt ?? p.publishedAt,
  services: services ?? p.services,
  hours: hours ?? p.hours,
  photos: photos ?? p.photos,
);

/// The photo backend over [FakeProRepository]'s profile, with the
/// database's 9-photo cap.
class FakeProPhotoUploader extends Fake implements PhotoUploader {
  FakeProPhotoUploader(this.pros);

  final FakeProRepository pros;
  final calls = <String>[];

  /// When set, the next upload (work photo or avatar) throws it, then it is
  /// cleared.
  ProFailure? nextFailure;

  /// When set, uploads (work photo or avatar) wait for it, so a test can
  /// see them in flight.
  Completer<void>? gate;
  var _n = 0;

  @override
  Future<ProPhoto> addWorkPhoto(String proId, XFile file) async {
    calls.add('addWorkPhoto');
    await gate?.future;
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    final p = pros.profile!;
    if (p.photos.length >= 9) throw const TooManyPhotos();
    final photo = ProPhoto(
      id: 'new${++_n}',
      path: '$proId/new$_n.jpg',
      sort: p.photos.length,
    );
    pros.profile = copyProfile(p, photos: [...p.photos, photo]);
    return photo;
  }

  @override
  Future<void> removeWorkPhoto(ProPhoto photo) async {
    calls.add('removeWorkPhoto:${photo.id}');
    final p = pros.profile!;
    pros.profile = copyProfile(
      p,
      photos: [
        for (final o in p.photos)
          if (o.id != photo.id) o,
      ],
    );
  }

  @override
  Future<String> uploadAvatar(String proId, XFile file) async {
    calls.add('uploadAvatar');
    await gate?.future;
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    final path = '$proId/avatar.jpg';
    pros.profile = copyProfile(pros.profile!, avatarPath: path);
    return path;
  }

  @override
  String publicUrl(String bucket, String path) =>
      'https://img.test/$bucket/$path';
}

/// A barber profile with every step done except what is switched off.
ProProfile barberProfile({
  bool located = true,
  bool service = true,
  bool hours = true,
}) => ProProfile(
  id: 'p1',
  kind: ProKind.barber,
  space: Space.men,
  displayName: 'Amine Benali',
  workplaceType: WorkplaceType.salon,
  phoneVisibility: PhoneVisibility.hidden,
  showPrices: true,
  isVerified: false,
  localityId: located ? 1601 : null,
  customerMix: located ? CustomerMix.adultsAndKids : null,
  services: [
    if (service)
      const ProService(
        id: 's0',
        presetKey: 'men_cut',
        category: ServiceCategory.hair,
        priceDzd: 600,
        durationMin: 30,
      ),
  ],
  hours: [
    if (hours)
      for (final wd in [6, 7, 1, 2, 3, 4])
        DayHours(
          weekday: wd,
          opens: const TimeOfDay(hour: 9, minute: 0),
          closes: const TimeOfDay(hour: 19, minute: 0),
        ),
  ],
);

class SetupHarness {
  SetupHarness(
    this.router,
    this.container,
    this.pros,
    this.accounts,
    this.photos,
  );

  final GoRouter router;
  final ProviderContainer container;
  final FakeProRepository pros;
  final MockAccountRepository accounts;
  final FakeProPhotoUploader photos;

  String get location => router.routerDelegate.currentConfiguration.uri.path;

  Uri get uri => router.routerDelegate.currentConfiguration.uri;
}

/// The real app router over fake account, pro and geo backends.
///
/// [fetch] answers `fetchMine`; by default [account]. Starts at [location]
/// once the account has loaded, unless [draft] drives a sign-up resume.
Future<SetupHarness> pumpSetup(
  WidgetTester tester, {
  Account? account,
  Future<Account?> Function()? fetch,
  FakeProRepository? pros,
  String? location,
  SignupDraft? draft,
  void Function()? stubSignup,
  List<TimeOfDay>? timeAnswers,
  FakeGeoRepository? geo,
  FakeProPhotoUploader Function(FakeProRepository pros)? photos,
  List<Override> overrides = const [],
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    LocaleController.prefsKey: locale.languageCode,
    ThemeModeController.prefsKey: themeMode.name,
    if (draft != null) SignupDraftStore.prefsKey: jsonEncode(draft.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = MockAuthRepository();
  when(() => auth.currentSession).thenReturn(testSession);
  final accounts = MockAccountRepository();
  when(() => accounts.fetchMine()).thenAnswer(
    (_) => fetch != null ? fetch() : Future<Account?>.value(account),
  );
  when(() => accounts.setActiveRole(any())).thenAnswer((_) async {});
  if (stubSignup != null) {
    when(
      () => accounts.completeSignup(
        fullName: any(named: 'fullName'),
        space: any(named: 'space'),
        role: any(named: 'role'),
        businessName: any(named: 'businessName'),
      ),
    ).thenAnswer((_) async {
      stubSignup();
      return (await accounts.fetchMine())!;
    });
  }
  final fakePros = pros ?? FakeProRepository();
  final fakePhotos = (photos ?? FakeProPhotoUploader.new)(fakePros);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      accountRepositoryProvider.overrideWithValue(accounts),
      sessionProvider.overrideWith((ref) => Stream.value(testSession)),
      proRepositoryProvider.overrideWithValue(fakePros),
      geoRepositoryProvider.overrideWithValue(geo ?? FakeGeoRepository()),
      photoUploaderProvider.overrideWithValue(fakePhotos),
      // A Wednesday, so the hours table's "today" is stable.
      profileClockProvider.overrideWithValue(() => DateTime(2026, 11, 18, 10)),
      ...overrides,
      if (timeAnswers != null)
        timePickProvider.overrideWithValue(
          (_, _) async => timeAnswers.removeAt(0),
        ),
    ],
  );
  addTearDown(container.dispose);
  final router = container.listen(routerProvider, (_, _) {}).read();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: lemqesTheme(Brightness.light),
          darkTheme: lemqesTheme(Brightness.dark),
          themeMode: ref.watch(themeModeProvider),
          locale: ref.watch(localeProvider),
          localizationsDelegates: appDelegates,
          supportedLocales: supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await settle(tester);
  if (location != null) {
    router.go(location);
    await settle(tester);
  }
  return SetupHarness(router, container, fakePros, accounts, fakePhotos);
}

/// Steps time instead of pumpAndSettle: the code step's countdown never
/// settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapAndSettle(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  // The scroll lands on the next layout; tapping before it aims at where
  // the widget was.
  await tester.pump();
  await tester.tap(byKey(key));
  await settle(tester);
}
