import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/explore/data/explore_models.dart';
import 'package:lemqes/features/explore/presentation/explore_screen.dart';
import 'package:lemqes/features/explore/presentation/pro_public_profile_screen.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/shared/widgets/lagoon_header_band.dart';
import 'package:lemqes/shared/widgets/state_views.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'explore_harness.dart';

void main() {
  setUpAll(() {
    registerHarnessFallbacks();
    registerFallbackValue(const ExploreQuery());
  });
  final fr = AppLocalizationsFr();

  testWidgets('results render as cards on the customer home', (tester) async {
    await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.text('Amine Benali'), findsOneWidget);
    expect(find.text('Yacine Mourad'), findsOneWidget);
    expect(find.text('Karim Saadi'), findsOneWidget);
    expect(find.text('Bab Ezzouar · Alger'), findsNWidgets(3));
    expect(find.text('600 DA'), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(EmptyView), findsNothing);
  });

  testWidgets('the search field straddles the band', (tester) async {
    await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );

    final band = tester.getRect(find.byType(LagoonHeaderBand));
    final bandEdge =
        band.top +
        tester.widget<LagoonHeaderBand>(find.byType(LagoonHeaderBand)).height;
    final field = tester.getRect(byKey('exploreSearch'));
    expect(field.top, lessThan(bandEdge));
    expect(field.bottom, greaterThan(bandEdge));
  });

  testWidgets('tapping a card opens its public profile', (tester) async {
    final id = cardId(1);
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
      pros: PublicProRepository(listed: {id: publicBarber(id: id)}),
    );

    await tester.tap(byKey('proCard_$id'));
    await settle(tester);

    expect(h.location, '/pro/$id');
    expect(find.byType(ProPublicProfileScreen), findsOneWidget);
    expect(byKey('proUnavailable'), findsNothing);
    expect(find.textContaining('Barbier depuis 2016'), findsOneWidget);
  });

  testWidgets('switching space hides the old cards while the new space loads', (
    tester,
  ) async {
    var account = customer();
    final womenGate = Completer<List<ProCard>>();
    final explore = _SpaceExplore(menCards: threeCards(), women: womenGate);
    final h = await pumpExplore(
      tester,
      explore: explore,
      fetch: () async => account,
    );
    when(() => h.accounts.setCustomerSpace(Space.women)).thenAnswer((_) async {
      account = customer(space: Space.women);
      explore.inWomen = true;
    });
    expect(find.text('Amine Benali'), findsOneWidget);

    await tester.tap(byKey('spaceSwitch_women'));
    await settle(tester);

    expect(find.text('Amine Benali'), findsNothing);
    expect(byKey('exploreSkeleton'), findsOneWidget);

    womenGate.complete(const []);
    await settle(tester);
    expect(find.text(fr.homeCustomerEmptyTitle('women')), findsOneWidget);
  });

  testWidgets('a space switch searches the new space once, without the '
      'category', (tester) async {
    var account = customer();
    final explore = FakeExploreRepository(cards: threeCards());
    final h = await pumpExplore(
      tester,
      explore: explore,
      fetch: () async => account,
    );
    when(() => h.accounts.setCustomerSpace(Space.women)).thenAnswer((_) async {
      account = customer(space: Space.women);
    });
    await tester.ensureVisible(byKey('filterCategory_beard'));
    await tester.tap(byKey('filterCategory_beard'));
    await settle(tester);
    final before = explore.queries.length;

    await tester.tap(byKey('spaceSwitch_women'));
    await settle(tester);

    final after = explore.queries.sublist(before);
    expect(after, [const ExploreQuery()]);
  });

  testWidgets('typing searches with the trimmed text', (tester) async {
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );

    await tester.enterText(byKey('exploreSearch'), '  amine ');
    await settle(tester);

    expect(h.query.text, 'amine');
    expect(h.explore.queries.last.text, 'amine');
  });

  testWidgets('the search text is capped at the server limit', (tester) async {
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );

    await tester.enterText(byKey('exploreSearch'), 'a' * 120);
    await settle(tester);

    // search_pros refuses more than 100 characters (query_invalid).
    expect(h.query.text, 'a' * 100);
    expect(h.explore.queries.last.text, 'a' * 100);
  });

  testWidgets('the kids and category chips update the query', (tester) async {
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );

    await tester.tap(byKey('filterKids'));
    await settle(tester);
    expect(h.query.kidsOnly, isTrue);
    expect(h.explore.queries.last.kidsOnly, isTrue);

    await tester.ensureVisible(byKey('filterCategory_beard'));
    await tester.tap(byKey('filterCategory_beard'));
    await settle(tester);
    expect(h.query.category, ServiceCategory.beard);
    expect(h.explore.queries.last.category, ServiceCategory.beard);

    // Tapping the selected category again lifts it.
    await tester.tap(byKey('filterCategory_beard'));
    await settle(tester);
    expect(h.query.category, isNull);
  });

  testWidgets('only the categories of the space presets are offered', (
    tester,
  ) async {
    await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );

    expect(byKey('filterCategory_hair'), findsOneWidget);
    expect(byKey('filterCategory_beard'), findsOneWidget);
    expect(byKey('filterCategory_nails'), findsNothing);
    expect(byKey('filterCategory_makeup'), findsNothing);
  });

  testWidgets('the place chip picks a wilaya and commune', (tester) async {
    final h = await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards()),
    );
    expect(find.text(fr.explorePlaceAny), findsOneWidget);

    await tester.tap(byKey('filterPlace'));
    await settle(tester);
    await tester.tap(byKey('pickRegion'));
    await settle(tester);
    await tester.tap(byKey('option_16'));
    await settle(tester);
    await tester.tap(byKey('option_1601'));
    await settle(tester);

    expect(h.query.regionCode, '16');
    expect(h.query.localityId, 1601);
    expect(h.explore.queries.last.localityId, 1601);
    expect(find.text('Alger Centre'), findsOneWidget);

    await tester.tap(byKey('filterPlace'));
    await settle(tester);
    await tester.tap(byKey('placeClear'));
    await settle(tester);
    expect(h.query.localityId, isNull);
    expect(h.query.regionCode, isNull);
    expect(find.text(fr.explorePlaceAny), findsOneWidget);
  });

  testWidgets('an empty space says pros are coming, with no filter reset', (
    tester,
  ) async {
    await pumpExplore(tester, explore: FakeExploreRepository());

    expect(find.text(fr.homeCustomerEmptyTitle('men')), findsOneWidget);
    expect(find.text(fr.exploreNoMatchTitle('men')), findsNothing);
    expect(byKey('exploreClearFilters'), findsNothing);
  });

  testWidgets('no match under filters offers to clear them', (tester) async {
    final explore = FakeExploreRepository(
      answer: (q, offset) => q.kidsOnly || offset > 0 ? const [] : threeCards(),
    );
    final h = await pumpExplore(tester, explore: explore);
    await tester.enterText(byKey('exploreSearch'), 'zzz');
    await tester.tap(byKey('filterKids'));
    await settle(tester);

    expect(find.text(fr.exploreNoMatchTitle('men')), findsOneWidget);
    expect(find.text(fr.homeCustomerEmptyTitle('men')), findsNothing);

    await tester.tap(byKey('exploreClearFilters'));
    await settle(tester);

    expect(h.query, const ExploreQuery());
    expect(
      tester.widget<TextField>(byKey('exploreSearch')).controller!.text,
      isEmpty,
    );
    expect(find.text('Amine Benali'), findsOneWidget);
  });

  testWidgets('a failed load shows the error and retry reloads', (
    tester,
  ) async {
    final explore = FakeExploreRepository(cards: threeCards())
      ..failure = const ProNetworkFailure();
    await pumpExplore(tester, explore: explore);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text(fr.errorNetwork), findsOneWidget);
    expect(find.text('Amine Benali'), findsNothing);

    explore.failure = null;
    await tester.tap(find.text(fr.actionRetry));
    await settle(tester);

    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('Amine Benali'), findsOneWidget);
  });

  testWidgets('a new search after an empty answer keeps the screen up', (
    tester,
  ) async {
    final gate = Completer<List<ProCard>>();
    final explore = _PendingExplore(gate.future, first: const []);
    await pumpExplore(tester, explore: explore);
    expect(find.byType(EmptyView), findsOneWidget);

    // The empty answer stays on screen while the next search loads.
    await tester.enterText(byKey('exploreSearch'), 'amine');
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(byKey('exploreFarNotice'), findsNothing);

    gate.complete(threeCards());
    await settle(tester);
    expect(find.text('Amine Benali'), findsOneWidget);
  });

  testWidgets('the first load shows a skeleton, not a spinner', (tester) async {
    final gate = Completer<List<ProCard>>();
    await pumpExplore(tester, explore: _PendingExplore(gate.future));

    expect(byKey('exploreSkeleton'), findsOneWidget);
    expect(find.bySemanticsLabel(fr.loading), findsOneWidget);

    gate.complete(threeCards());
    await settle(tester);
    expect(byKey('exploreSkeleton'), findsNothing);
    expect(find.text('Amine Benali'), findsOneWidget);
  });

  testWidgets('switching space reloads the list for that space', (
    tester,
  ) async {
    var account = customer();
    final explore = FakeExploreRepository(cards: threeCards());
    final h = await pumpExplore(
      tester,
      explore: explore,
      fetch: () async => account,
    );
    when(() => h.accounts.setCustomerSpace(Space.women)).thenAnswer((_) async {
      account = customer(space: Space.women);
      explore.answer = (_, _) => const [];
    });
    final before = explore.queries.length;

    await tester.tap(byKey('spaceSwitch_women'));
    await settle(tester);

    expect(explore.queries.length, greaterThan(before));
    expect(find.text('Amine Benali'), findsNothing);
    expect(find.text(fr.homeCustomerEmptyTitle('women')), findsOneWidget);
  });

  testWidgets('a failed space switch keeps the list, without a new search', (
    tester,
  ) async {
    final explore = FakeExploreRepository(cards: threeCards());
    final h = await pumpExplore(tester, explore: explore);
    when(() => h.accounts.setCustomerSpace(Space.women))
        .thenThrow(const ProNetworkFailure());
    final before = explore.queries.length;

    await tester.tap(byKey('spaceSwitch_women'));
    await settle(tester);

    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('Amine Benali'), findsOneWidget);
    expect(explore.queries.length, before);
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final explore = FakeExploreRepository(
      answer: (q, offset) => offset == 0
          ? [for (var i = 0; i < 30; i++) card(i)]
          : [card(100, name: 'Dernier Pro')],
    );
    await pumpExplore(tester, explore: explore);

    await tester.dragUntilVisible(
      find.text('Dernier Pro'),
      find.byType(CustomScrollView),
      const Offset(0, -600),
    );
    await settle(tester);

    expect(explore.offsets, contains(30));
    expect(find.text('Dernier Pro'), findsOneWidget);
  });

  testWidgets('a failed next page offers its own retry', (tester) async {
    var failNext = true;
    final explore = FakeExploreRepository(
      answer: (q, offset) {
        if (offset == 0) return [for (var i = 0; i < 30; i++) card(i)];
        if (failNext) throw const ProNetworkFailure();
        return [card(100, name: 'Dernier Pro')];
      },
    );
    await pumpExplore(tester, explore: explore);

    await tester.dragUntilVisible(
      byKey('exploreLoadMoreRetry'),
      find.byType(CustomScrollView),
      const Offset(0, -600),
    );
    failNext = false;
    await tester.tap(byKey('exploreLoadMoreRetry'));
    await settle(tester);

    expect(find.text('Dernier Pro'), findsOneWidget);
  });

  testWidgets('does not overflow at 2x text in Arabic', (tester) async {
    await pumpExplore(
      tester,
      explore: FakeExploreRepository(cards: threeCards(arabic: true)),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}

/// A search that never answers until [gate] completes.
class _PendingExplore extends FakeExploreRepository {
  _PendingExplore(this.gate, {this.first});

  final Future<List<ProCard>> gate;

  /// When set, the first search answers it at once; the next ones wait.
  final List<ProCard>? first;

  @override
  Future<List<ProCard>> search(
    ExploreQuery q, {
    required int offset,
    required int limit,
  }) async {
    queries.add(q);
    final first = this.first;
    if (first != null && queries.length == 1) return first;
    return gate;
  }
}

/// Answers the men's space at once and the women's through [women].
class _SpaceExplore extends FakeExploreRepository {
  _SpaceExplore({required this.menCards, required this.women});

  final List<ProCard> menCards;
  final Completer<List<ProCard>> women;
  bool inWomen = false;

  @override
  Future<List<ProCard>> search(
    ExploreQuery q, {
    required int offset,
    required int limit,
  }) {
    queries.add(q);
    if (inWomen) return women.future;
    return Future.value(offset == 0 ? menCards : const []);
  }
}
