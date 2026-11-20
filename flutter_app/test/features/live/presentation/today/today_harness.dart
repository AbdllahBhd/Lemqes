import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/time/clock_providers.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/live/data/live_repository.dart';
import 'package:lemqes/features/live/presentation/today/today_screen.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class MockLiveRepository extends Mock implements LiveRepository {}

/// A live repository that answers reads with nothing: for screens under
/// test elsewhere that merely mount the Today tab.
class QuietLiveRepository extends Fake implements LiveRepository {
  @override
  Future<List<OwnerQueueRow>> ownerQueue(String proId) async => const [];

  @override
  Future<List<BlockedCustomer>> blocked(String proId) async => const [];
}

/// "Hors ligne" driven by the test.
class FakeConnected extends LiveConnected {
  FakeConnected(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  void set(bool value) => state = value;
}

class FakeMyPro extends MyProController {
  FakeMyPro(this.profile);

  final ProProfile? profile;

  @override
  Future<ProProfile?> build() async => profile;
}

/// 10:00 UTC, 11:00 in Algiers.
final testNow = DateTime.utc(2026, 11, 20, 10);

/// Live providers over [repo] and a snapshot stream: no channel, no
/// Supabase. Every screen mounting the Today tab in tests uses these.
List<Override> liveOverrides({
  required LiveRepository repo,
  required Stream<LiveSnapshot> Function(String proId) snapshots,
  bool connected = true,
  void Function()? onRetry,
}) => [
  liveRepositoryProvider.overrideWithValue(repo),
  liveRetryProvider.overrideWithValue(onRetry ?? () {}),
  ownLiveSnapshotProvider.overrideWith((ref, proId) => snapshots(proId)),
  liveTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
  liveConnectedProvider.overrideWith(() => FakeConnected(connected)),
  utcClockProvider.overrideWithValue(() => testNow),
];

/// [liveOverrides] for screens that only need the Today tab to mount: a
/// closed pro with an empty queue.
List<Override> quietLiveOverrides() => liveOverrides(
  repo: QuietLiveRepository(),
  snapshots: (proId) => Stream.value(ownSnapshot(proId: proId)),
);

LiveSnapshot ownSnapshot({
  String proId = 'p1',
  LiveStatus status = LiveStatus.closed,
  DateTime? autoCloseAt,
  DateTime? breakUntil,
  int? waitingCount = 0,
  int? waitMin = 0,
  QueueMode mode = QueueMode.open,
  bool listed = true,
  int version = 1,
  DateTime? statusAgeFrom,
}) => LiveSnapshot(
  proId: proId,
  status: status,
  breakUntil: breakUntil,
  autoCloseAt: autoCloseAt,
  statusAgeFrom: statusAgeFrom ?? DateTime.utc(2026, 11, 20, 9, 55),
  queueMode: mode,
  listed: listed,
  joinBlock: null,
  waitingCount: waitingCount,
  waitMin: waitMin,
  servingCalledAt: null,
  servingDurationMin: null,
  aheadMinutes: waitMin ?? 0,
  queueVersion: version,
  liveVersion: version,
  serverNow: testNow,
);

/// Open until 19:30 Algiers time (18:30 UTC).
LiveSnapshot openSnapshot({int waiting = 3, bool listed = true}) => ownSnapshot(
  status: LiveStatus.open,
  autoCloseAt: DateTime.utc(2026, 11, 20, 18, 30),
  waitingCount: waiting,
  waitMin: 40,
  listed: listed,
);

OwnerQueueRow entry(
  int n, {
  QueueKind kind = QueueKind.walkIn,
  String? label,
  String? serviceId,
  EntryState state = EntryState.waiting,
  bool onMyWay = false,
  int? position,
}) => OwnerQueueRow(
  entryId: 'e$n',
  ticketNo: n,
  kind: kind,
  label: label,
  serviceId: serviceId,
  durationMin: serviceId == null ? null : 30,
  state: state,
  onMyWayAt: onMyWay ? DateTime.utc(2026, 11, 20, 9, 58) : null,
  calledAt: state == EntryState.serving
      ? DateTime.utc(2026, 11, 20, 9, 50)
      : null,
  sortAt: DateTime.utc(2026, 11, 20, 9, n),
  position: state == EntryState.waiting ? (position ?? n) : null,
);

/// The serving customer, then three waiting (one remote and on the way).
List<OwnerQueueRow> fourEntries({bool arabic = false}) => [
  entry(
    1,
    label: arabic ? 'سارة ب.' : 'Sami B.',
    serviceId: 's1',
    state: EntryState.serving,
  ),
  entry(2, serviceId: 's0', position: 1),
  entry(
    3,
    kind: QueueKind.remote,
    label: arabic ? 'ليلى م.' : 'Karim M.',
    serviceId: 's1',
    onMyWay: true,
    position: 2,
  ),
  entry(4, label: arabic ? 'أمينة ك.' : 'Yanis K.', position: 3),
];

Account todayAccount({AppRole role = AppRole.barber}) => Account(
  id: 'u1',
  fullName: 'Amine Benali',
  customerSpace: Space.men,
  proSpace: Space.men,
  activeRole: role,
  roles: {AppRole.customer, role},
);

ProProfile todayProfile({
  bool published = true,
  String name = 'Amine',
  bool arabic = false,
}) => ProProfile(
  id: 'p1',
  kind: ProKind.barber,
  space: Space.men,
  displayName: name,
  workplaceType: WorkplaceType.salon,
  phoneVisibility: PhoneVisibility.hidden,
  showPrices: true,
  isVerified: false,
  publishedAt: published ? DateTime.utc(2026, 11, 1) : null,
  services: [
    ProService(
      id: 's0',
      customName: arabic ? 'قص' : 'Coupe',
      category: ServiceCategory.hair,
      priceDzd: 600,
      durationMin: 30,
    ),
    ProService(
      id: 's1',
      customName: arabic ? 'لحية' : 'Barbe',
      category: ServiceCategory.beard,
      priceDzd: 300,
      durationMin: 15,
    ),
  ],
);

class TodayHarness {
  TodayHarness(this.repo, this.snapshots, this.container, this._retries);

  final MockLiveRepository repo;
  final StreamController<LiveSnapshot> snapshots;
  final ProviderContainer container;
  final List<void> _retries;

  /// How many times the offline banner's Retry asked the channels to retry.
  int get retries => _retries.length;

  FakeConnected get connected =>
      container.read(liveConnectedProvider.notifier) as FakeConnected;

  void push(LiveSnapshot s) => snapshots.add(s);
}

/// Pumps the Today screen for [profile] with [rows] in the queue and
/// [snapshot] as the pro's live state.
Future<TodayHarness> pumpToday(
  WidgetTester tester, {
  ProProfile? profile,
  bool noProfile = false,
  Account? account,
  List<OwnerQueueRow> rows = const [],
  LiveSnapshot? snapshot,
  bool connected = true,
  MockLiveRepository? repo,
  Locale locale = const Locale('fr'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final mock = repo ?? MockLiveRepository();
  if (repo == null) {
    when(() => mock.ownerQueue(any())).thenAnswer((_) async => rows);
    when(() => mock.blocked(any())).thenAnswer((_) async => const []);
  }
  final snapshots = StreamController<LiveSnapshot>.broadcast();
  addTearDown(snapshots.close);
  var latest = snapshot ?? openSnapshot(waiting: 0);
  snapshots.stream.listen((s) => latest = s);

  final retries = <void>[];
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...liveOverrides(
        repo: mock,
        snapshots: (_) async* {
          yield latest;
          yield* snapshots.stream;
        },
        connected: connected,
        onRetry: () => retries.add(null),
      ),
      myProProvider.overrideWith(
        () => FakeMyPro(noProfile ? null : (profile ?? todayProfile())),
      ),
      presetsProvider.overrideWith((ref, key) async => const []),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lemqesTheme(Brightness.light),
        darkTheme: lemqesTheme(Brightness.dark),
        themeMode: themeMode,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TodayScreen(account: account ?? todayAccount()),
      ),
    ),
  );
  await settle(tester);
  return TodayHarness(mock, snapshots, container, retries);
}

/// Whether the button under [key] (the keyed widget or one inside it) is
/// enabled.
bool buttonEnabled(WidgetTester tester, String key) => tester
    .widget<ButtonStyleButton>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            matchRoot: true,
          )
          .first,
    )
    .enabled;

/// Riverpod rebuilds and stream hops need pumps that advance time.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  // The list builds lazily: an entry below the fold does not exist yet.
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

void registerTodayFallbacks() {
  registerFallbackValue(LiveStatus.open);
  registerFallbackValue(QueueMode.open);
}
