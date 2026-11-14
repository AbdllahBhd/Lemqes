import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../account/data/account_providers.dart';
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
  ExploreQuery build() => const ExploreQuery();

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
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ProCard> items;
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

  @override
  Future<ExploreResults> build() async {
    final generation = ++_generation;
    final query = ref.watch(exploreQueryProvider);
    // Results are per space (the server filters by the caller's space).
    // Awaited so the first build does not run twice (before and after the
    // account loads).
    await ref.watch(accountProvider.selectAsync((a) => a?.currentSpace));
    final debounce = ref.read(exploreDebounceProvider);

    if (query.text != _lastText && debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
      if (generation != _generation) return state.value ?? _empty;
    }
    _lastText = query.text;

    final page = await ref
        .read(exploreRepositoryProvider)
        .search(query, offset: 0, limit: exploreRepositoryPageSize);
    return ExploreResults(
      items: page,
      hasMore: page.length == exploreRepositoryPageSize,
    );
  }

  static const _empty = ExploreResults(items: [], hasMore: false);

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(exploreRepositoryProvider)
          .search(
            ref.read(exploreQueryProvider),
            offset: current.items.length,
            limit: exploreRepositoryPageSize,
          );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        ExploreResults(
          items: [...current.items, ...page],
          hasMore: page.length == exploreRepositoryPageSize,
        ),
      );
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}
