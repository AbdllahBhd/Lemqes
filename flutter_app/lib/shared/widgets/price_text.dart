import 'package:material_ui/material_ui.dart';

import '../../core/theme/lemqes_typography.dart';
import '../../features/pro/data/price_parse.dart';
import 'ltr.dart';

/// A dinar amount: Latin tabular digits and "DA", always left-to-right.
class PriceText extends StatelessWidget {
  const PriceText(this.dzd, {super.key, this.style});

  final int dzd;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    return Ltr(
      child: Text(
        formatDzd(dzd, Localizations.localeOf(context)),
        style: lemqesWeight(
          (base ?? const TextStyle()).merge(lemqesNumeric),
          FontWeight.w600,
        ),
      ),
    );
  }
}
