import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/explore/data/explore_repository.dart';
import 'package:lemqes/features/geo/data/device_location.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/origin.dart';
import 'package:lemqes/features/live/data/live_models.dart';
import 'package:lemqes/features/live/data/live_providers.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../geo/data/fake_device_location.dart';
import '../../live/data/live_fakes.dart';

class _MockRepo extends Mock implements ExploreRepository {}

class _FakeAccount extends AccountController {
  @override
  Future<Account?> build() async => _account(Space.men);
}

Account _account(Space space) => Account(
  id: 'u1',
  fullName: 'Lina',
  customerSpace: space,
  proSpace: null,
  activeRole: AppRole.customer,
  roles: const {AppRole.customer},
);

ProCard _card(int i) => ProCard(
  proId: 'p$i',
  kind: ProKind.barber,
  displayName: 'Pro $i',
  workplaceType: WorkplaceType.salon,
  isVerified: false,
  live: LiveSnapshot.fromJson(live('p$i')),
);

List<ProCard> _page(int from, int n) => [
  for (var i = 0; i < n; i++) _card(from + i),
];

void main() {
  late _MockRepo repo;
  late ProviderContainer container;
  late StreamController<Session?> sessions;
  late FakeFactory factory;

  setUpAll(() => registerFallbackValue(const ExploreQuery()));

  late SharedPreferences prefs;
  late FakeDeviceLocation device;

  ProviderContainer make({Duration debounce = Duration.zero}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocationProvider.overrideWithValue(device),
        exploreRepositoryProvider.overrideWithValue(repo),
        exploreDebounceProvider.overrideWithValue(debounce),
        accountProvider.overrideWith(_FakeAccount.new),
        sessionProvider.overrideWith((ref) => sessions.stream),
        liveChannelFactoryProvider.overrideWithValue(factory.call),
      ],
    );
    addTearDown(c.dispose);
    c.listen(exploreResultsProvider, (_, _) {});
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    device = FakeDeviceLocation();
    factory = FakeFactory();
    sessions = StreamController<Session?>.broadcast();
    addTearDown(sessions.close);
    repo = _MockRepo();
    when(
      () => repo.search(
        any(),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((i) async {
      final offset = i.namedArguments[#offset] as int;
      return offset == 0 ? _page(0, 30) : _page(offset, 5);
    });
  });

  test('first page is 30 and more is available', () async {
    container = make();
    final r = await container.read(exploreResultsProvider.future);
    expect(r.items.length, 30);
    expect(r.hasMore, isTrue);
    verify(() => repo.search(const ExploreQuery(), offset: 0, limit: 30))
        .called(1);
  });

  test('loadMore appends the next page and stops at a short page', () async {
    container = make();
    await container.read(exploreResultsProvider.future);
    await container.read(exploreResultsProvider.notifier).loadMore();
    final r = container.read(exploreResultsProvider).requireValue;
    expect(r.items.length, 35);
    expect(r.hasMore, isFalse);
    verify(() => repo.search(any(), offset: 30, limit: 30)).called(1);
    await container.read(exploreResultsProvider.notifier).loadMore();
    verifyNever(
      () => repo.search(any(), offset: 35, limit: any(named: 'limit')),
    );
  });

  test('a query change resets to page one', () async {
    container = make();
    await container.read(exploreResultsProvider.future);
    await container.read(exploreResultsProvider.notifier).loadMore();
    container.read(exploreQueryProvider.notifier).setKidsOnly(true);
    final r = await container.read(exploreResultsProvider.future);
    expect(r.items.length, 30);
    verify(
      () =>
          repo.search(const ExploreQuery(kidsOnly: true), offset: 0, limit: 30),
    ).called(1);
  });

  test('a new origin re-runs the search with it, other fields kept', () async {
    container = make();
    container.read(exploreQueryProvider.notifier).setKidsOnly(true);
    await container.read(exploreResultsProvider.future);
    container
        .read(originProvider.notifier)
        .useCommune(
          const Locality(
            id: 1601,
            regionCode: '16',
            nameAr: 'a',
            nameFr: 'b',
            lat: 36.7233,
            lng: 3.1832,
          ),
        );
    await container.read(exploreResultsProvider.future);
    verify(
      () => repo.search(
        const ExploreQuery(kidsOnly: true, origin: GeoPoint(36.7233, 3.1832)),
        offset: 0,
        limit: 30,
      ),
    ).called(1);
  });

  test('the origin and bbox survive every other filter change', () {
    device.status = DevicePermission.approximate;
    container = make();
    final n = container.read(exploreQueryProvider.notifier);
    n.setBbox(const GeoBounds(2.9, 36.6, 3.2, 36.8));
    n.setText('karim');
    n.setRegion('16');
    n.setLocality(1601);
    n.setKidsOnly(true);
    n.setCategory(ServiceCategory.beard);
    final q = container.read(exploreQueryProvider);
    expect(q.bbox, const GeoBounds(2.9, 36.6, 3.2, 36.8));
    n.setBbox(null);
    expect(container.read(exploreQueryProvider).bbox, isNull);
  });

  test('picking a region clears the locality; locality is kept otherwise', () {
    container = make();
    final n = container.read(exploreQueryProvider.notifier);
    n.setLocality(1601);
    n.setCategory(ServiceCategory.beard);
    expect(container.read(exploreQueryProvider).localityId, 1601);
    n.setRegion('16');
    final q = container.read(exploreQueryProvider);
    expect(q.regionCode, '16');
    expect(q.localityId, isNull);
    expect(q.category, ServiceCategory.beard);
    n.setText('  ');
    expect(container.read(exploreQueryProvider).text, isNull);
    n.reset();
    expect(container.read(exploreQueryProvider), const ExploreQuery());
  });

  test('typing is debounced: one search for the last text', () async {
    container = make(debounce: const Duration(milliseconds: 60));
    await container.read(exploreResultsProvider.future);
    final n = container.read(exploreQueryProvider.notifier);
    n.setText('a');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    n.setText('ab');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    n.setText('abc');
    await container.read(exploreResultsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    verify(
      () => repo.search(const ExploreQuery(text: 'abc'), offset: 0, limit: 30),
    ).called(1);
    verifyNever(
      () => repo.search(const ExploreQuery(text: 'a'), offset: 0, limit: 30),
    );
    verifyNever(
      () => repo.search(const ExploreQuery(text: 'ab'), offset: 0, limit: 30),
    );
  });

  test('a space change reloads the results', () async {
    container = make();
    await container.read(exploreResultsProvider.future);
    // The account controller exposes the space; switching it refetches.
    final notifier = container.read(accountProvider.notifier);
    notifier.state = AsyncData(_account(Space.women));
    await container.pump();
    await container.read(exploreResultsProvider.future);
    verify(() => repo.search(const ExploreQuery(), offset: 0, limit: 30))
        .called(2);
  });

  test('a failing first page surfaces as an error', () async {
    when(
      () => repo.search(
        any(),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(Exception('x'));
    container = make();
    await expectLater(
      container.read(exploreResultsProvider.future),
      throwsA(anything),
    );
  });

  test('a failing loadMore keeps the items and flags the failure', () async {
    container = make();
    await container.read(exploreResultsProvider.future);
    when(() => repo.search(any(), offset: 30, limit: any(named: 'limit')))
        .thenThrow(Exception('x'));
    await container.read(exploreResultsProvider.notifier).loadMore();
    final r = container.read(exploreResultsProvider).requireValue;
    expect(r.items.length, 30);
    expect(r.loadMoreFailed, isTrue);
    expect(r.loadingMore, isFalse);
  });

  test('a new signed-in user starts from an empty query', () async {
    container = make();
    container.listen(exploreQueryProvider, (_, _) {});
    sessions.add(_session('u1'));
    await container.pump();
    container.read(exploreQueryProvider.notifier)
      ..setText('salon')
      ..setKidsOnly(true);
    expect(container.read(exploreQueryProvider).text, 'salon');

    sessions.add(null);
    await container.pump();
    sessions.add(_session('u2'));
    await container.pump();

    expect(container.read(exploreQueryProvider), const ExploreQuery());
  });

  test(
    'a space switch drops the category and searches once without it',
    () async {
      container = make();
      await container.read(exploreResultsProvider.future);
      container.read(exploreQueryProvider.notifier)
        ..setText('coupe')
        ..setCategory(ServiceCategory.beard);
      await container.read(exploreResultsProvider.future);
      clearInteractions(repo);

      container.read(accountProvider.notifier).state = AsyncData(
        _account(Space.women),
      );
      await container.pump();
      await container.read(exploreResultsProvider.future);

      expect(container.read(exploreQueryProvider).category, isNull);
      expect(container.read(exploreQueryProvider).text, 'coupe');
      verify(
        () => repo.search(
          const ExploreQuery(text: 'coupe'),
          offset: 0,
          limit: 30,
        ),
      ).called(1);
      verifyNoMoreInteractions(repo);
    },
  );

  test('results remember the space they were fetched for', () async {
    container = make();
    expect(
      (await container.read(exploreResultsProvider.future)).space,
      Space.men,
    );
    container.read(accountProvider.notifier).state = AsyncData(
      _account(Space.women),
    );
    await container.pump();
    expect(
      (await container.read(exploreResultsProvider.future)).space,
      Space.women,
    );
  });

  test('loadMore waits while a new query loads', () async {
    container = make();
    await container.read(exploreResultsProvider.future);
    final gate = Completer<List<ProCard>>();
    when(
      () =>
          repo.search(const ExploreQuery(kidsOnly: true), offset: 0, limit: 30),
    ).thenAnswer((_) => gate.future);
    container.read(exploreQueryProvider.notifier).setKidsOnly(true);
    container.read(exploreResultsProvider);
    await container.pump();
    expect(container.read(exploreResultsProvider).isLoading, isTrue);

    await container.read(exploreResultsProvider.notifier).loadMore();

    verifyNever(
      () => repo.search(any(), offset: 30, limit: any(named: 'limit')),
    );
    gate.complete(_page(0, 30));
  });

  test('ProCard reads the live object, or none', () {
    final row = {
      'pro_id': 'p1',
      'kind': 'barber',
      'display_name': 'Pro 1',
      'avatar_path': null,
      'workplace_type': 'salon',
      'is_verified': false,
    };
    expect(ProCard.fromRow(row).live, isNull);
    final card = ProCard.fromRow({...row, 'live': live('p1')});
    expect(card.live, LiveSnapshot.fromJson(live('p1')));
  });

  test(
    'results seed each card\'s live view before any channel answers',
    () async {
      container = make();
      await container.read(exploreResultsProvider.future);
      final sub = container.listen(proLiveProvider('p3'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().requireValue.snapshot, _card(3).live);

      await container.read(exploreResultsProvider.notifier).loadMore();
      final next = container.listen(proLiveProvider('p31'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(next.read().requireValue.snapshot, _card(31).live);
      sub.close();
      next.close();
    },
  );

  test(
    'a men search answering after a switch to women seeds nothing',
    () async {
      final men = Completer<List<ProCard>>();
      var calls = 0;
      when(
        () => repo.search(
          any(),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) {
        // The first search is the men one; later ones are women's.
        if (calls++ == 0) return men.future;
        return Future.value([_card(100)]);
      });
      container = make();
      await container.read(accountProvider.future);
      container.read(exploreResultsProvider);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      container.read(accountProvider.notifier).state = AsyncData(
        _account(Space.women),
      );
      await container.pump();
      final women = await container.read(exploreResultsProvider.future);
      men.complete(_page(0, 30));
      await Future<void>.delayed(Duration.zero);

      expect(women.space, Space.women);
      final channels = container.read(liveChannelsProvider);
      expect(channels.latest('p100'), isNotNull);
      expect(channels.latest('p0'), isNull);
    },
  );

  test('loadMore pages the query its list came from', () async {
    container = make();
    await container.read(exploreResultsProvider.future);
    // The query changes but the results have not rebuilt yet.
    container.read(exploreQueryProvider.notifier).setKidsOnly(true);
    await container.read(exploreResultsProvider.notifier).loadMore();

    verifyNever(
      () => repo.search(
        const ExploreQuery(kidsOnly: true),
        offset: 30,
        limit: any(named: 'limit'),
      ),
    );
  });
}

Session _session(String userId) => Session(
  accessToken: 't',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);
