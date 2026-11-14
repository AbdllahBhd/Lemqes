import 'package:material_ui/material_ui.dart';

import '../../core/theme/lemqes_gradients.dart';

/// The Lagoon gradient band behind the top app bar.
///
/// [overlap] (a search field or the queue card) straddles the band's lower
/// edge: it starts [overlapRise] above the edge and hangs below it.
class LagoonHeaderBand extends StatelessWidget {
  const LagoonHeaderBand({
    super.key,
    required this.child,
    this.height = 150,
    this.overlap,
  });

  /// How far [overlap] reaches up into the band (from the reference comp).
  static const double overlapRise = 32;

  final Widget child;
  final double height;
  final Widget? overlap;

  @override
  Widget build(BuildContext context) {
    final gradients = Theme.of(context).extension<LemqesGradients>()!;
    final band = DecoratedBox(
      decoration: BoxDecoration(gradient: gradients.brand),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradients.bloom),
        child: SizedBox(height: height, width: double.infinity, child: child),
      ),
    );

    final overlap = this.overlap;
    if (overlap == null) return band;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: AlignmentDirectional.topCenter,
        children: [
          Positioned(top: 0, left: 0, right: 0, height: height, child: band),
          Padding(
            padding: EdgeInsets.only(top: height - overlapRise),
            child: overlap,
          ),
        ],
      ),
    );
  }
}
