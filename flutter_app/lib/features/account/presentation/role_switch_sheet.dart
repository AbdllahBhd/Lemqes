import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../shared/widgets/choice_card.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../signup/presentation/signup_wizard.dart' show SignupRoleIcon;
import '../data/account.dart';
import '../data/account_providers.dart';
import 'account_failure_listener.dart';

/// Opens [RoleSwitchSheet] as a modal bottom sheet.
Future<void> showRoleSwitchSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LemqesShape.sheetRadius),
        ),
      ),
      builder: (_) => const RoleSwitchSheet(),
    );

String _title(AppLocalizations l10n, AppRole role, Space space) {
  final s = space.toDb();
  return switch (role) {
    AppRole.customer => l10n.roleCustomerTitle(s),
    AppRole.barber => l10n.roleBarberTitle(s),
    AppRole.homeArtist => l10n.roleHomeArtistTitle(s),
    AppRole.salonOwner => l10n.roleSalonOwnerTitle(s),
  };
}

String _body(AppLocalizations l10n, AppRole role, Space space) {
  final s = space.toDb();
  return switch (role) {
    AppRole.customer => l10n.roleCustomerBody(s),
    AppRole.barber => l10n.roleBarberBody(s),
    AppRole.homeArtist => l10n.roleHomeArtistBody(s),
    AppRole.salonOwner => l10n.roleSalonOwnerBody(s),
  };
}

/// The roles the user holds (tap to switch) and the ones they can add.
///
/// A pro role needs a space only while the account has none; afterwards the
/// fixed space is shown instead. A salon owner also names the business.
class RoleSwitchSheet extends ConsumerStatefulWidget {
  const RoleSwitchSheet({super.key});

  @override
  ConsumerState<RoleSwitchSheet> createState() => _RoleSwitchSheetState();
}

enum _View { held, pick, form }

class _RoleSwitchSheetState extends ConsumerState<RoleSwitchSheet> {
  final _business = TextEditingController();
  _View _view = _View.held;
  AppRole? _adding;
  Space? _space;
  String? _businessError;
  String? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _business.dispose();
    super.dispose();
  }

  void _go(_View view) => setState(() {
    _view = view;
    _businessError = null;
  });

  void _back() => switch (_view) {
    _View.form => _go(_View.pick),
    _ => _go(_View.held),
  };

  /// Runs [action]; closes the sheet on success, else stays open and says why.
  Future<void> _run(Future<void> Function(AccountController) action) async {
    if (_busy) return;
    final notifier = ref.read(accountProvider.notifier);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _failure = null;
    });
    await action(notifier);
    if (!mounted) return;
    final state = ref.read(accountProvider);
    if (state.hasError) {
      setState(() {
        _busy = false;
        _failure = accountErrorMessage(context.l10n, state.error);
      });
    } else {
      navigator.pop();
    }
  }

  void _switchTo(AppRole role) => _run((n) => n.switchRole(role));

  Future<void> _confirm(Account account) async {
    final role = _adding!;
    final needsSpace = account.proSpace == null;
    final business = _business.text.trim();
    if (role == AppRole.salonOwner && business.isEmpty) {
      setState(() => _businessError = context.l10n.businessNameRequired);
      return;
    }
    await _run(
      (n) => n.addRole(
        role,
        space: needsSpace ? _space : null,
        businessName: role == AppRole.salonOwner ? business : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account = ref.watch(accountProvider).value;
    if (account == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final canAdd = AppRole.values.any((r) => !account.roles.contains(r));

    final title = _view == _View.held
        ? l10n.roleSwitchTitle
        : l10n.roleAddAction;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_view != _View.held) BackButton(onPressed: _back),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          if (_failure != null) ...[
            FailureBanner(message: _failure!),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 16),
          ...switch (_view) {
            _View.held => _held(l10n, account, canAdd),
            _View.pick => _pick(l10n, account),
            _View.form => _form(l10n, account),
          },
        ],
      ),
    );
  }

  Space _spaceOf(Account a, AppRole role) =>
      role.isPro ? (a.proSpace ?? a.customerSpace) : a.customerSpace;

  List<Widget> _held(AppLocalizations l10n, Account account, bool canAdd) {
    final held = [
      for (final r in AppRole.values)
        if (account.roles.contains(r)) r,
    ];
    return [
      for (final role in held) ...[
        ChoiceCard(
          key: Key('role_${role.toDb()}'),
          title: _title(l10n, role, _spaceOf(account, role)),
          badge: role == account.activeRole ? l10n.roleActive : null,
          icon: role.icon,
          selected: role == account.activeRole,
          onTap: () => _switchTo(role),
        ),
        const SizedBox(height: 12),
      ],
      if (canAdd)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('addRole'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.add),
            label: Text(l10n.roleAddAction),
            onPressed: () => _go(_View.pick),
          ),
        ),
    ];
  }

  List<Widget> _pick(AppLocalizations l10n, Account account) {
    final available = [
      for (final r in AppRole.values)
        if (!account.roles.contains(r)) r,
    ];
    if (available.isEmpty) {
      return [
        Text(l10n.roleAddNone, style: Theme.of(context).textTheme.bodyLarge),
      ];
    }
    return [
      for (final role in available) ...[
        ChoiceCard(
          key: Key('add_${role.toDb()}'),
          title: _title(l10n, role, _spaceOf(account, role)),
          subtitle: _body(l10n, role, _spaceOf(account, role)),
          icon: role.icon,
          selected: false,
          onTap: () {
            _adding = role;
            _go(_View.form);
          },
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _form(AppLocalizations l10n, Account account) {
    final role = _adding!;
    final theme = Theme.of(context);
    final needsSpace = account.proSpace == null;
    final space = needsSpace
        ? (_space ?? account.customerSpace)
        : account.proSpace!;
    final ready = !needsSpace || _space != null;
    return [
      Text(_title(l10n, role, space), style: theme.textTheme.titleMedium),
      const SizedBox(height: 16),
      if (needsSpace) ...[
        Text(l10n.roleChooseSpace, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        ChoiceCard(
          key: const Key('addSpace_men'),
          title: l10n.spaceMen,
          subtitle: l10n.spaceMenBody,
          icon: Icons.man,
          selected: _space == Space.men,
          onTap: () => setState(() => _space = Space.men),
        ),
        const SizedBox(height: 12),
        ChoiceCard(
          key: const Key('addSpace_women'),
          title: l10n.spaceWomen,
          subtitle: l10n.spaceWomenBody,
          icon: Icons.woman,
          selected: _space == Space.women,
          onTap: () => setState(() => _space = Space.women),
        ),
      ] else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.roleSpaceLockedNote(space.toDb()),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      if (role == AppRole.salonOwner) ...[
        const SizedBox(height: 16),
        TextField(
          key: const Key('businessNameField'),
          controller: _business,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: lemqesFieldDecoration(
            context,
            label: l10n.businessNameLabel(space.toDb()),
            error: _businessError,
            icon: Icons.storefront_outlined,
          ),
        ),
      ],
      const SizedBox(height: 24),
      LemqesPrimaryButton(
        key: const Key('confirmAddRole'),
        label: l10n.roleAddConfirm,
        expand: true,
        loading: _busy,
        onPressed: ready && !_busy ? () => _confirm(account) : null,
      ),
    ];
  }
}
