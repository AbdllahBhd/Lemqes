import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../account/data/account.dart';
import '../../account/data/account_providers.dart';
import '../../live/data/live_providers.dart';
import '../../pro/data/pro_models.dart';
import 'explore_api.dart';
import 'explore_models.dart';
import 'explore_repository.dart';

const exploreRepositoryPageSize = 30;

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) =>
      ExploreRepository(SupabaseExploreApi(ref.watch(supabaseClientProvider))),
);

/// Overridable so tests need not wait 300 ms.
final exploreDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

final exploreQueryProvider =
    NotifierProvider<ExploreQueryController, ExploreQuery>(
      ExploreQueryController.new,
    );

class ExploreQueryController extends Notifier<ExploreQuery> {
  @override
  ExploreQuery build() {
    // Each signed-in user starts from an empty search: never the previous
    // user's text or filters.
    ref.watch(sessionProvider.select((s) => s.value?.user.id));
    // Categories differ between spaces (no beard in Femmes), so a switch
    // drops the category and keeps the rest. Done here, in the same
    // notification as the space change, so the results rebuild once with
    // both instead of searching the new space with the old category.
    ref.listen(accountProvider.select((a) => a.value?.currentSpace), (
      previous,
      next,
    ) {
      if (previous != null && next != previous && state.category != null) {
        setCategory(null);
      }
    });
    return const ExploreQuery();
  }

  void setText(String text) {
    final t = text.trim();
    state = ExploreQuery(
      text: t.isEmpty ? null : t,
      regionCode: state.regionCode,
      localityId: state.localityId,
      kidsOnly: state.kidsOnly,
      category: state.category,
    );
  }

  /// A locality belongs to one region, so changing the region drops it.
  void setRegion(String? regionCode) {
    state = ExploreQuery(
      text: state.text,
      regionCode: regionCode,
      kidsOnly: state.kidsOnly,
      category: state.category,
    );
  }

  void setLocality(int? localityId) {
    state = ExploreQuery(
      text: state.text,
      regionCode: state.regionCode,
      localityId: localityId,
      kidsOnly: state.kidsOnly,
      category: state.category,
    );
  }

  void setKidsOnly(bool value) {
    state = ExploreQuery(
      text: state.text,
      regionCode: state.regionCode,
      localityId: state.localityId,
      kidsOnly: value,
      category: state.category,
    );
  }

  void setCategory(ServiceCategory? category) {
    state = ExploreQuery(
      text: state.text,
      regionCode: state.regionCode,
      localityId: state.localityId,
      kidsOnly: state.kidsOnly,
      category: category,
    );
  }

  void reset() => state = const ExploreQuery();
}

class ExploreResults {
  const ExploreResults({
    required this.items,
    required this.hasMore,
    this.space,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ProCard> items;

  /// The space the items were searched in; a list from another space must
  /// never be shown, even while the new one loads.
  final Space? space;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  ExploreResults copyWith({
    List<ProCard>? items,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => ExploreResults(
    items: items ?? this.items,
    space: space,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

final exploreResultsProvider =
    AsyncNotifierProvider<ExploreResultsController, ExploreResults>(
      ExploreResultsController.new,
      // The screen offers its own retry; silent backoff retries would keep it
      // loading with no feedback.
      retry: (_, _) => null,
    );

class ExploreResultsController extends AsyncNotifier<ExploreResults> {
  // A rebuild supersedes an in-flight build: only the latest generation may
  // hit the network after the debounce.
  var _generation = 0;
  String? _lastText;

  // What the current list was searched with: further pages must continue
  // that search, not whatever the query has become since.
  ExploreQuery? _listQuery;

  @override
  Future<ExploreResults> build() async {
    final generation = ++_generation;
    final query = ref.watch(exploreQueryProvider);
    // Results are per space (the server filters by the caller's space).
    // Selected from the last known account, not awaited from its future: a
    // failed space switch keeps the account on screen in an error state, and
    // must keep this list too instead of turning it into an error.
    final space = ref.watch(
      accountProvider.select((a) => a.value?.currentSpace),
    );
    // Stays loading until the account is known, so the first build does not
    // search twice (before and after the account loads).
    if (space == null) return Completer<ExploreResults>().future;
    final debounce = ref.read(exploreDebounceProvider);

    if (query.text != _lastText && debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
      if (generation != _generation) return state.value ?? _empty;
    }
    _lastText = query.text;

    final page = await ref
        .read(exploreRepositoryProvider)
        .search(query, offset: 0, limit: exploreRepositoryPageSize);
    if (generation == _generation) {
      _listQuery = query;
      // A superseded search may belong to the previous space: its
      // snapshots must not outlive the channels' reset.
      _seedLive(page);
    }
    return ExploreResults(
      items: page,
      space: space,
      hasMore: page.length == exploreRepositoryPageSize,
    );
  }

  static const _empty = ExploreResults(items: [], hasMore: false);

  /// Cards show their live line at once; channels only refresh it. A seed
  /// older than what the channels hold is ignored there.
  void _seedLive(List<ProCard> page) {
    final channels = ref.read(liveChannelsProvider);
    for (final card in page) {
      final live = card.live;
      if (live != null) channels.seed(live);
    }
  }

  Future<void> loadMore() async {
    // While a new search loads, the list on screen belongs to the old one.
    if (state.isLoading) return;
    final current = state.value;
    final query = _listQuery;
    if (current == null ||
        query == null ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(exploreRepositoryProvider)
          .search(
            query,
            offset: current.items.length,
            limit: exploreRepositoryPageSize,
          );
      if (!ref.mounted || generation != _generation) return;
      _seedLive(page);
      state = AsyncData(
        ExploreResults(
          items: [...current.items, ...page],
          space: current.space,
          hasMore: page.length == exploreRepositoryPageSize,
        ),
      );
    } on Object catch (e, st) {
      // The footer offers the retry; the cause goes to the log.
      developer.log('explore next page failed', error: e, stackTrace: st);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}
