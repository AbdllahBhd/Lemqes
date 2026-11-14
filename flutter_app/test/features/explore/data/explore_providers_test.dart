import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/account/data/account_providers.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/data/explore_providers.dart';
import 'package:lemqes/features/explore/data/explore_repository.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:mocktail/mocktail.dart';

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
);

List<ProCard> _page(int from, int n) => [
  for (var i = 0; i < n; i++) _card(from + i),
];

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(const ExploreQuery()));

  ProviderContainer make({Duration debounce = Duration.zero}) {
    final c = ProviderContainer(
      overrides: [
        exploreRepositoryProvider.overrideWithValue(repo),
        exploreDebounceProvider.overrideWithValue(debounce),
        accountProvider.overrideWith(_FakeAccount.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(exploreResultsProvider, (_, _) {});
    return c;
  }

  setUp(() {
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
}
