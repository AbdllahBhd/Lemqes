import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../geo/presentation/search_fold.dart';
import '../../pro/data/pro_models.dart';
import '../data/explore_models.dart';

/// "Salon · Salon El Bahdja", or the workplace word alone.
String workplaceLine(AppLocalizations l10n, WorkplaceType type, String? name) {
  final word = l10n.exploreWorkplaceType(type.toDb());
  final n = name?.trim();
  return n == null || n.isEmpty ? word : '$word · $n';
}

/// "Commune · Wilaya"; null when neither is known. A commune that gives its
/// name to its wilaya (Bou Saâda, wilaya 68) is named once.
String? placeLine(String? locality, String? region) {
  final parts = [
    for (final p in [locality, region])
      if (p != null && p.isNotEmpty) p,
  ];
  if (parts.length == 2 && searchFold(parts[0]) == searchFold(parts[1])) {
    return parts.first;
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The distance of a result: "700 m", "1,5 km", or "≈ 3 km" for a pro that
/// shows only its commune. Null without an origin, and for a pro the server
/// hides the point of (a blocked reader), so no distance leaks.
String? distanceLabel(AppLocalizations l10n, Locale locale, ProCard card) {
  final m = card.distanceM;
  if (m == null) return null;
  if (card.placeMode == PlaceMode.none) {
    // Whole kilometres only: the commune centre is not the pro's place.
    return l10n.exploreDistanceAbout('${(m / 1000).round().clamp(1, 99999)}');
  }
  if (m < 1000) return l10n.exploreDistanceM('$m');
  final tenths = (m / 100).round();
  final whole = tenths ~/ 10;
  final frac = tenths % 10;
  final sep = locale.languageCode == 'en' ? '.' : ',';
  return l10n.exploreDistanceKm(frac == 0 ? '$whole' : '$whole$sep$frac');
}

/// Whether the nearest result is far enough for the "nothing within 10 km"
/// notice. Judged on the distance as displayed, so a commune-only pro shown
/// as "≈ 10 km" never sits under a notice that says nothing is within 10 km.
bool isFarResult(ProCard card) {
  final m = card.distanceM;
  if (m == null) return false;
  if (card.placeMode == PlaceMode.none) return (m / 1000).round() > 10;
  return m > 10000;
}

/// The kids tag of a customer mix; null for adults only.
String? kidsTagOf(AppLocalizations l10n, CustomerMix? mix) => switch (mix) {
  CustomerMix.adultsAndKids => l10n.exploreKidsWelcome,
  CustomerMix.kidsOnly => l10n.customerMixKidsOnly,
  _ => null,
};

/// The verified tick after a pro's name; screen readers say what it means.
class VerifiedTick extends StatelessWidget {
  const VerifiedTick({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.verified_outlined,
    size: size,
    color: Theme.of(context).colorScheme.primary,
    semanticLabel: context.l10n.proVerified,
  );
}

/// A mist tag ("Enfants acceptés").
class MistTag extends StatelessWidget {
  const MistTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
