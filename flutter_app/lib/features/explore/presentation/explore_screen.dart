import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/data/account.dart';
import '../../pro/presentation/pro_failure_message.dart';
import '../data/explore_models.dart';
import '../data/explore_providers.dart';
import 'explore_filters.dart';
import 'pro_card_tile.dart';

/// How close to the end of the list the next page starts loading.
const _loadMoreExtent = 400.0;

/// The customer's list of pros in their space: search, filters, results.
///
/// [header] builds the home band around the search field, which straddles
/// the band's lower edge; the band and search stay put while results scroll.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({required this.space, required this.header, super.key});

  final Space space;
  final Widget Function(Widget search) header;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(exploreQueryProvider).text,
  );

  @override
  void didUpdateWidget(ExploreScreen old) {
    super.didUpdateWidget(old);
    // Categories differ between spaces (no beard in Femmes): a category
    // chosen in the other space must not silently empty this one. Deferred
    // because providers cannot change while widgets build.
    if (old.space != widget.space &&
        ref.read(exploreQueryProvider).category != null) {
      scheduleMicrotask(() {
        if (mounted) {
          ref.read(exploreQueryProvider.notifier).setCategory(null);
        }
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll() {
    _search.clear();
    ref.read(exploreQueryProvider.notifier).reset();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.extentAfter > _loadMoreExtent) return false;
    final v = ref.read(exploreResultsProvider).value;
    // After a failed page only the footer's retry asks again, so scrolling
    // never hammers a failing network.
    if (v != null && v.hasMore && !v.loadingMore && !v.loadMoreFailed) {
      ref.read(exploreResultsProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(exploreResultsProvider);
    final query = ref.watch(exploreQueryProvider);
    final search = ExploreSearchField(
      controller: _search,
      onChanged: ref.read(exploreQueryProvider.notifier).setText,
    );

    return Column(
      children: [
        widget.header(search),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: ExploreFilters(space: widget.space)),
                ..._results(context, results, query),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _results(
    BuildContext context,
    AsyncValue<ExploreResults> results,
    ExploreQuery query,
  ) {
    final l10n = context.l10n;
    final value = results.value;
    if (results.hasError && !results.isLoading) {
      return [
        SliverFillRemaining(
          child: ErrorView(
            message: proFailureMessage(l10n, results.error),
            retryLabel: l10n.actionRetry,
            onRetry: () => ref.invalidate(exploreResultsProvider),
          ),
        ),
      ];
    }
    if (value == null) return const [SliverToBoxAdapter(child: _Skeleton())];
    if (value.items.isEmpty && !results.isLoading) {
      final space = widget.space.toDb();
      final filtered = query != const ExploreQuery();
      return [
        SliverFillRemaining(
          child: filtered
              ? EmptyView(
                  icon: Icons.search_off,
                  title: l10n.exploreNoMatchTitle(space),
                  body: l10n.exploreNoMatchBody,
                  action: LemqesPrimaryButton(
                    key: const Key('exploreClearFilters'),
                    label: l10n.exploreClearFilters,
                    icon: Icons.filter_alt_off_outlined,
                    onPressed: _clearAll,
                  ),
                )
              : EmptyView(
                  icon: Icons.storefront_outlined,
                  title: l10n.homeCustomerEmptyTitle(space),
                  body: l10n.exploreEmptyBody,
                ),
        ),
      ];
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return [
      // A new search keeps the previous results on screen until it answers.
      SliverToBoxAdapter(
        child: SizedBox(
          height: 4,
          child: results.isLoading ? const LinearProgressIndicator() : null,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.separated(
          itemCount: value.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final card = value.items[i];
            return ProCardTile(
              key: Key('proCard_${card.proId}'),
              card: card,
              onTap: () => context.push('/pro/${card.proId}'),
            );
          },
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
        sliver: SliverToBoxAdapter(child: _Footer(results: value)),
      ),
    ];
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.results});

  final ExploreResults results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (results.loadingMore) {
      return Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: l10n.loading,
          ),
        ),
      );
    }
    if (results.loadMoreFailed) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            l10n.exploreLoadMoreFailed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            key: const Key('exploreLoadMoreRetry'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () =>
                ref.read(exploreResultsProvider.notifier).loadMore(),
            child: Text(l10n.actionRetry),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Three still card shapes while the first page loads: the list's layout
/// arrives before its content, so nothing jumps.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('exploreSkeleton'),
      label: context.l10n.loading,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                const _SkeletonCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerHigh;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  bar(0.6, 16),
                  const SizedBox(height: 10),
                  bar(0.45, 12),
                  const SizedBox(height: 8),
                  bar(0.5, 12),
                  const SizedBox(height: 14),
                  bar(0.3, 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
