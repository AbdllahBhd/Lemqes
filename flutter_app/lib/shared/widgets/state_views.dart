import 'package:flutter/material.dart';

import 'lemqes_primary_button.dart';

const double _maxWidth = 400;

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Scrollable so large font scales never overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// Content is on its way; [label] is what screen readers announce.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(semanticsLabel: label));
  }
}

/// Nothing to show yet; [action] offers the way forward.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.icon,
    this.body,
    this.action,
  });

  /// Names what will fill this space, in the same tinted disc as the
  /// choice cards.
  final IconData? icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = this.icon;
    final body = this.body;
    final action = this.action;
    return _CenteredState(
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 64,
                child: Icon(icon, size: 28, color: scheme.onSecondaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[const SizedBox(height: 24), action],
      ],
    );
  }
}

/// Something failed; [message] names the problem, retry is the recovery.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CenteredState(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        LemqesPrimaryButton(
          label: retryLabel,
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
