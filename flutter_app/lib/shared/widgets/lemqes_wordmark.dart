import 'package:material_ui/material_ui.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/lemqes_theme.dart';

/// LEMQES in the display face, spaced out, white on the Lagoon band.
class LemqesWordmark extends StatelessWidget {
  const LemqesWordmark({super.key});

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
