import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/router/app_router.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/time/clock_providers.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/explore/data/explore_repository.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/geo/data/geo_providers.dart';
import 'package:lemqes/features/geo/data/geo_repository.dart';
import 'package:lemqes/features/pro/data/photo_uploader.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/harness.dart';
import '../../geo/data/fake_device_location.dart';
import '../../live/presentation/customer/customer_live_harness.dart';
import '../../pro/presentation/setup/setup_harness.dart'
    show FakeGeoRepository, FakeProRepository, settle;

export '../../auth/presentation/harness.dart'
    show MockAccountRepository, byKey, registerHarnessFallbacks;
export '../../pro/presentation/setup/setup_harness.dart'
    show FakeGeoRepository, barberProfile, proAccount, settle;

Account customer({Space space = Space.men}) => Account(
  id: 'u1',
  fullName: 'Lina Haddad',
  customerSpace: space,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: const {AppRole.customer},
);

const proUuid = '7f1c2b8e-4d3a-4c9b-9e21-0a5b6c7d8e9f';

/// A UUID-shaped id per card, so cards open real profiles.
String cardId(int i) =>
    '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';

ProCard card(
  int i, {
  String? name,
  bool verified = false,
  WorkplaceType workplace = WorkplaceType.salon,
  String? workplaceName,
  CustomerMix? mix = CustomerMix.adults,
  int? minPrice = 600,
  LiveSnapshot? live,
  int? distanceM,
  PlaceMode? placeMode,
  bool? comesToYou,
}) => ProCard(
  proId: cardId(i),
  kind: workplace == WorkplaceType.mobile ? ProKind.homeArtist : ProKind.barber,
  displayName: name ?? 'Pro $i',
  workplaceType: workplace,
  workplaceName: workplaceName,
  isVerified: verified,
  regionCode: '16',
  regionNameAr: 'الجزائر',
  regionNameFr: 'Alger',
  localityNameAr: 'باب الزوار',
  localityNameFr: 'Bab Ezzouar',
  customerMix: mix,
  minPriceDzd: minPrice,
  live: live,
  distanceM: distanceM,
  placeMode: placeMode,
  comesToYou: comesToYou,
);

/// Three cards that cover the variants: verified with a workplace name,
/// kids welcome with hidden prices, a home artist.
List<ProCard> threeCards({bool arabic = false}) => [
  card(
    1,
    name: arabic ? 'أمين بن علي' : 'Amine Benali',
    verified: true,
    workplaceName: arabic ? 'صالون البهجة' : 'Salon El Bahdja',
    minPrice: 600,
  ),
  card(
    2,
    name: arabic ? 'ياسين مراد' : 'Yacine Mourad',
    mix: CustomerMix.adultsAndKids,
    minPrice: null,
  ),
  card(
    3,
    name: arabic ? 'كريم سعدي' : 'Karim Saadi',
    workplace: WorkplaceType.mobile,
    minPrice: 1500,
  ),
];

/// [threeCards] with a live object each: open, on break, closed.
List<ProCard> threeLiveCards({bool arabic = false}) {
  final cards = threeCards(arabic: arabic);
  final lives = [
    custSnap(cardId(1)),
    breakSnap(cardId(2)),
    closedSnap(cardId(3)),
  ];
  return [
    for (final (i, c) in cards.indexed)
      ProCard(
        proId: c.proId,
        kind: c.kind,
        displayName: c.displayName,
        workplaceType: c.workplaceType,
        workplaceName: c.workplaceName,
        isVerified: c.isVerified,
        regionCode: c.regionCode,
        regionNameAr: c.regionNameAr,
        regionNameFr: c.regionNameFr,
        localityNameAr: c.localityNameAr,
        localityNameFr: c.localityNameFr,
        customerMix: c.customerMix,
        minPriceDzd: c.minPriceDzd,
        live: lives[i],
      ),
  ];
}

/// In-memory `search_pros`: [answer] decides each page.
class FakeExploreRepository extends Fake implements ExploreRepository {
  FakeExploreRepository({this.cards = const [], this.answer});

  final List<ProCard> cards;
  List<ProCard> Function(ExploreQuery q, int offset)? answer;

  /// When set, the next searches throw it.
  ProFailure? failure;
  final queries = <ExploreQuery>[];
  final offsets = <int>[];

  @override
  Future<List<ProCard>> search(
    ExploreQuery q, {
    required int offset,
    required int limit,
  }) async {
    queries.add(q);
    offsets.add(offset);
    final f = failure;
    if (f != null) throw f;
    final a = answer;
    if (a != null) return a(q, offset);
    return offset == 0 ? cards : const [];
  }
}

/// The pro backend seen by a customer: listable profiles and public phones.
class PublicProRepository extends FakeProRepository {
  PublicProRepository({
    super.profile,
    Map<String, ProProfile>? listed,
    Map<String, String>? phones,
  }) : listed = listed ?? {},
       phones = phones ?? {};

  final Map<String, ProProfile> listed;
  final Map<String, String> phones;
  ProFailure? publicFailure;

  /// When set, `pro_contact_phone` throws it.
  ProFailure? phoneFailure;
  final publicCalls = <String>[];
  final phoneCalls = <String>[];

  @override
  Future<ProProfile?> publicProfile(String proId) async {
    publicCalls.add(proId);
    final f = publicFailure;
    if (f != null) throw f;
    return listed[proId];
  }

  @override
  Future<String?> contactPhone(String proId) async {
    phoneCalls.add(proId);
    final f = phoneFailure;
    if (f != null) throw f;
    return phones[proId];
  }
}

/// A geo backend whose by-id commune lookup fails while [fail] is set.
class FlakyGeoRepository extends FakeGeoRepository {
  bool fail = false;

  @override
  Future<Locality?> locality(int id) async {
    if (fail) throw const ProNetworkFailure();
    return super.locality(id);
  }
}

class FakePhotoUploader extends Fake implements PhotoUploader {
  @override
  String publicUrl(String bucket, String path) =>
      'https://img.test/$bucket/$path';
}

/// A listable barber with every public section filled.
ProProfile publicBarber({
  String id = proUuid,
  bool arabic = false,
  bool showPrices = true,
  int photos = 3,
}) => ProProfile(
  id: id,
  kind: ProKind.barber,
  space: Space.men,
  displayName: arabic ? 'أمين بن علي' : 'Amine Benali',
  bio: arabic
      ? 'حلاق منذ 2016. قصات كلاسيكية وتدرج ناعم.'
      : 'Barbier depuis 2016. Coupes classiques et dégradés nets.',
  experienceYears: 7,
  workplaceType: WorkplaceType.salon,
  workplaceName: arabic ? 'صالون البهجة' : 'Salon El Bahdja',
  localityId: 1601,
  customerMix: CustomerMix.adultsAndKids,
  phoneVisibility: PhoneVisibility.public,
  showPrices: showPrices,
  isVerified: true,
  publishedAt: DateTime.utc(2026, 11, 1),
  services: [
    ProService(
      id: 's1',
      presetKey: 'men_cut',
      category: ServiceCategory.hair,
      priceDzd: showPrices ? 600 : null,
      durationMin: 30,
    ),
    ProService(
      id: 's2',
      presetKey: 'men_beard',
      category: ServiceCategory.beard,
      priceDzd: showPrices ? 1500 : null,
      durationMin: 15,
    ),
  ],
  hours: [
    for (final wd in [6, 7, 1, 2, 3, 4])
      DayHours(
        weekday: wd,
        opens: const TimeOfDay(hour: 9, minute: 0),
        closes: const TimeOfDay(hour: 19, minute: 0),
        breakStart: wd == 4 ? const TimeOfDay(hour: 12, minute: 30) : null,
        breakEnd: wd == 4 ? const TimeOfDay(hour: 14, minute: 0) : null,
      ),
  ],
  photos: [
    for (var i = 0; i < photos; i++)
      ProPhoto(id: 'ph$i', path: '$id/photo$i.jpg', sort: i),
  ],
);

class ExploreHarness {
  ExploreHarness(
    this.router,
    this.container,
    this.explore,
    this.pros,
    this.accounts,
    this.live,
  );

  final GoRouter router;
  final ProviderContainer container;
  final FakeExploreRepository explore;
  final PublicProRepository pros;
  final MockAccountRepository accounts;

  /// The live backend: snapshots, channels, ticket, clock.
  final CustomerLive live;

  /// The top-most route, pushed ones included.
  String get location => router.state.uri.path;

  ExploreQuery get query => container.read(exploreQueryProvider);
}

/// The real app router signed in as a customer over fake backends; starts on
/// /home (the explore list) or [location].
Future<ExploreHarness> pumpExplore(
  WidgetTester tester, {
  Account? account,
  Future<Account?> Function()? fetch,
  FakeExploreRepository? explore,
  PublicProRepository? pros,
  String? location,
  Future<bool> Function(Uri)? launcher,
  GeoRepository? geo,
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(390, 844),
  CustomerLive? live,
  DeviceLocation? deviceLocation,
}) async {
  final customerLive = live ?? CustomerLive();
  addTearDown(customerLive.dispose);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    LocaleController.prefsKey: locale.languageCode,
    ThemeModeController.prefsKey: themeMode.name,
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = MockAuthRepository();
  when(() => auth.currentSession).thenReturn(testSession);
  final accounts = MockAccountRepository();
  final me = account ?? customer();
  when(() => accounts.fetchMine())
      .thenAnswer((_) => fetch != null ? fetch() : Future<Account?>.value(me));
  when(() => accounts.setActiveRole(any())).thenAnswer((_) async {});
  when(() => accounts.setCustomerSpace(any())).thenAnswer((_) async {});
  final fakeExplore = explore ?? FakeExploreRepository();
  final fakePros = pros ?? PublicProRepository();

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      accountRepositoryProvider.overrideWithValue(accounts),
      sessionProvider.overrideWith((ref) => Stream.value(testSession)),
      exploreRepositoryProvider.overrideWithValue(fakeExplore),
      exploreDebounceProvider.overrideWithValue(Duration.zero),
      proRepositoryProvider.overrideWithValue(fakePros),
      photoUploaderProvider.overrideWithValue(FakePhotoUploader()),
      geoRepositoryProvider.overrideWithValue(geo ?? FakeGeoRepository()),
      // Never the real platform service: a test that does not script the
      // device must not be able to prompt.
      deviceLocationProvider.overrideWithValue(
        deviceLocation ?? FakeDeviceLocation(),
      ),
      // A Wednesday, so the hours table's "today" is stable.
      countryClockProvider.overrideWithValue(() => DateTime(2026, 11, 18, 10)),
      // Cards and the ticket run on the real channels over fakes; a pro
      // passing through /home mounts the Today tab on its own snapshot.
      ...customerLive.overrides(),
      if (launcher != null) phoneLauncherProvider.overrideWithValue(launcher),
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
  return ExploreHarness(
    router,
    container,
    fakeExplore,
    fakePros,
    accounts,
    customerLive,
  );
}

/// The public profile of an open, joinable barber.
Future<ExploreHarness> pumpJoinable(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
}) {
  final live = CustomerLive();
  live.repo.server[proUuid] = custSnap(proUuid);
  return pumpExplore(
    tester,
    pros: PublicProRepository(
      listed: {proUuid: publicBarber(arabic: locale.languageCode == 'ar')},
      phones: {proUuid: '+213550123456'},
    ),
    location: '/pro/$proUuid',
    live: live,
    locale: locale,
    themeMode: themeMode,
    textScale: textScale,
  );
}

Future<void> openJoinSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('liveJoin')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('liveJoin')));
  await settleLive(tester);
}
