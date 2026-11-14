import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../account/data/account_providers.dart';
import '../../account/presentation/role_switch_sheet.dart';

/// Material's `logout` glyph, mirrored in right-to-left layouts.
const IconData logoutIcon = IconData(
  0xe3b3,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);

/// Language, theme, role switch and sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final repo = ref.read(authRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('confirmSignOut'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsSignOut),
          ),
        ],
      ),
    );
    // The session change sends the router to /auth.
    if (confirmed ?? false) await repo.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final mode = ref.watch(themeModeProvider);

    final languages = [
      ('ar', l10n.languageName_ar),
      ('fr', l10n.languageName_fr),
      ('en', l10n.languageName_en),
      ('kab', l10n.languageName_kab),
    ];
    final themes = [
      (ThemeMode.system, l10n.themeSystem, Icons.brightness_auto_outlined),
      (ThemeMode.light, l10n.themeLight, Icons.light_mode_outlined),
      (ThemeMode.dark, l10n.themeDark, Icons.dark_mode_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.settingsTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _GroupTitle(l10n.languageChooserLabel),
            _Group(
              children: [
                for (final (code, name) in languages)
                  _OptionRow(
                    key: Key('language_$code'),
                    label: name,
                    selected: code == locale,
                    onTap: () => ref
                        .read(localeProvider.notifier)
                        .setLocale(Locale(code)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _GroupTitle(l10n.settingsThemeTitle),
            _Group(
              children: [
                for (final (value, label, icon) in themes)
                  _OptionRow(
                    key: Key('theme_${value.name}'),
                    label: label,
                    icon: icon,
                    selected: value == mode,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).setMode(value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              children: [
                _NavRow(
                  key: const Key('roleSwitch'),
                  icon: Icons.swap_horiz,
                  label: l10n.roleSwitchTitle,
                  onTap: () => showRoleSwitchSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              key: const Key('signOut'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(logoutIcon),
              label: Text(l10n.settingsSignOut),
              onPressed: () => _confirmSignOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Semantics(
        header: true,
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// A white rounded group; its rows are divided by a hairline.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        boxShadow: LemqesShape.cardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  ExcludeSemantics(
                    child: Icon(icon, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LemqesShape.cardRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                ExcludeSemantics(
                  child: Icon(Icons.chevron_right, color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
