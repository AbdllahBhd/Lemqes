import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_theme.dart';
import '../../../shared/widgets/lagoon_header_band.dart';
import '../../account/presentation/role_switch_sheet.dart';

/// The Lagoon band that heads both homes: actions on top, [children] below.
///
/// The band grows with the user's text size so nothing clips; [extraRows]
/// is how many 48 dp-high rows [children] holds beyond the action row.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.children,
    this.extraRows = 1,
    this.title,
    super.key,
  });

  final List<Widget> children;
  final int extraRows;

  /// Replaces the wordmark in the action row (a pro's name).
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rowHeight = math.max(48.0, media.textScaler.scale(26) + 8);
    final height =
        media.padding.top + 8 + rowHeight + extraRows * (rowHeight + 8) + 20;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: LagoonHeaderBand(
        height: height,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            media.padding.top + 8,
            8,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: title ?? const Wordmark(),
                      ),
                    ),
                    const HeaderActions(),
                  ],
                ),
              ),
              for (final child in children) ...[
                const SizedBox(height: 8),
                SizedBox(height: rowHeight, child: child),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// LEMQES in the display face, spaced out, white on the band.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        context.l10n.appName,
        style: lemqesWeight(
          theme.textTheme.titleMedium!,
          FontWeight.w600,
        ).copyWith(color: Colors.white, fontSize: 18, letterSpacing: 18 * 0.16),
      ),
    );
  }
}

/// Role switch and settings, the two actions both homes share.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('roleSwitch'),
          tooltip: l10n.roleSwitchTitle,
          color: Colors.white,
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => showRoleSwitchSheet(context),
        ),
        IconButton(
          key: const Key('settings'),
          tooltip: l10n.settingsTitle,
          color: Colors.white,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

/// A small outlined tag on the band, e.g. the space name.
class BandTag extends StatelessWidget {
  const BandTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
