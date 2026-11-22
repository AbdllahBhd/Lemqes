import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_tokens.dart';
import '../../../shared/widgets/lemqes_primary_button.dart';

/// What the customer is told before the OS location prompt: why, and that
/// the position stays on the phone. Pops `true` on "Continuer", `false` on
/// "Plus tard".
class LocationExplainerSheet extends StatelessWidget {
  const LocationExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.my_location,
                  size: 28,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.locationExplainerTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.locationExplainerBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            LemqesPrimaryButton(
              key: const Key('locationExplainerAllow'),
              label: l10n.locationExplainerAllow,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('locationExplainerBack'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.locationExplainerBack),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [LocationExplainerSheet]; true only when the customer continues.
Future<bool> showLocationExplainerSheet(BuildContext context) async {
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LemqesShape.sheetRadius),
      ),
    ),
    builder: (_) => const LocationExplainerSheet(),
  );
  return go ?? false;
}
