import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_theme.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../shared/widgets/lagoon_header_band.dart';
import 'login_form.dart';

/// Sign-in, with the way into sign-up. Language and theme sit in the band.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaler = media.textScaler;
    // The band grows with the user's text size so the top bar never clips.
    final rowHeight = math.max(48.0, scaler.scale(26) + 8);
    final bandHeight =
        media.padding.top +
        12 +
        rowHeight +
        8 +
        rowHeight +
        16 +
        LagoonHeaderBand.overlapRise;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: media.padding.bottom + 24),
        child: LagoonHeaderBand(
          height: bandHeight,
          overlap: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _AuthCard(),
          ),
          child: Padding(
            // End inset 8: the theme button's own padding makes up the 16.
            padding: EdgeInsetsDirectional.fromSTEB(
              16,
              media.padding.top + 12,
              8,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: rowHeight, child: const _TopBar()),
                const SizedBox(height: 8),
                SizedBox(height: rowHeight, child: const _LanguageChips()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              l10n.appName,
              style: lemqesWeight(theme.textTheme.titleMedium!, FontWeight.w600)
                  .copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 18 * 0.16,
                  ),
            ),
          ),
        ),
        IconButton(
          tooltip: dark ? l10n.themeToLight : l10n.themeToDark,
          color: Colors.white,
          icon: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          onPressed: () => ref
              .read(themeModeProvider.notifier)
              .setMode(dark ? ThemeMode.light : ThemeMode.dark),
        ),
      ],
    );
  }
}

class _LanguageChips extends ConsumerWidget {
  const _LanguageChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeProvider).languageCode;
    // Short codes are not translated: each names its own language.
    final options = [
      ('ar', 'AR', l10n.languageName_ar),
      ('fr', 'FR', l10n.languageName_fr),
      ('en', 'EN', l10n.languageName_en),
      ('kab', 'TZ', l10n.languageName_kab),
    ];
    return Semantics(
      label: l10n.languageChooserLabel,
      container: true,
      child: Row(
        children: [
          for (final (code, short, name) in options) ...[
            _LanguageChip(
              short: short,
              name: name,
              selected: code == current,
              onTap: () =>
                  ref.read(localeProvider.notifier).setLocale(Locale(code)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.short,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String short;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.6),
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                widthFactor: 1,
                child: Text(
                  short,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? LemqesColors.deepSea : Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.sheetRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_AuthTabs(), SizedBox(height: 20), LoginForm()],
        ),
      ),
    );
  }
}

/// "Sign in" is this screen; "Create an account" starts the wizard.
class _AuthTabs extends StatelessWidget {
  const _AuthTabs();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Semantics(
      label: l10n.authTabsLabel,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _TabPill(
                  key: const Key('tab_login'),
                  label: l10n.actionSignIn,
                  selected: true,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: _TabPill(
                  key: const Key('tab_signup'),
                  label: l10n.actionCreateAccount,
                  selected: false,
                  onTap: () => context.go('/signup/space'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge!;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: selected
                      ? style.copyWith(color: scheme.onSecondaryContainer)
                      : lemqesWeight(
                          style,
                          FontWeight.w500,
                        ).copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
