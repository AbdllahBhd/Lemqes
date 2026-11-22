import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:material_ui/material_ui.dart';

/// A metre-accurate circle as a polygon. `CircleLayer` draws its fill as
/// one huge point, which breaks into a square at street zoom on this
/// renderer, so areas are polygons of at least 72 points.
List<LatLng> circlePoints(LatLng centre, num radiusM, {int count = 72}) {
  assert(count >= 72);
  const distance = Distance();
  return [
    for (var i = 0; i < count; i++)
      distance.offset(centre, radiusM, 360 * i / count),
  ];
}

/// A pro's area: a translucent fill with a solid edge in [color].
Polygon areaPolygon(LatLng centre, num radiusM, {required Color color}) =>
    Polygon(
      points: circlePoints(centre, radiusM),
      color: color.withValues(alpha: 0.16),
      borderColor: color,
      borderStrokeWidth: 2,
    );

/// The pin's size; its tip sits on the point.
const proPinSize = Size(40, 48);

/// A map pin: a teardrop in the primary colour with a white disc, and a
/// status dot inside when [dotColor] is given.
class ProPin extends StatelessWidget {
  const ProPin({this.dotColor, this.semanticLabel, super.key});

  final Color? dotColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = dotColor;
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: SizedBox.fromSize(
        size: proPinSize,
        child: CustomPaint(
          painter: _PinPainter(fill: scheme.primary),
          child: Align(
            alignment: const Alignment(0, -0.38),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: dot ?? Colors.white,
                shape: BoxShape.circle,
                border: dot == null
                    ? null
                    : Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({required this.fill});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final centre = Offset(r, r);
    final tip = Offset(r, size.height);
    // Tangent points from the tip to the head circle, so the sides meet the
    // head smoothly.
    final d = tip.dy - centre.dy;
    final angle = math.acos(r / d);
    final left = centre + Offset(-r * math.sin(angle), r * math.cos(angle));
    final right = centre + Offset(r * math.sin(angle), r * math.cos(angle));
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..arcToPoint(right, radius: Radius.circular(r), largeArc: true)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.fill != fill;
}

/// A [ProPin] whose tip is on [point].
Marker exactPinMarker(
  LatLng point, {
  Color? dotColor,
  String? semanticLabel,
  Key? key,
}) => Marker(
  key: key,
  point: point,
  width: proPinSize.width,
  height: proPinSize.height,
  alignment: Alignment.topCenter,
  child: ProPin(dotColor: dotColor, semanticLabel: semanticLabel),
);
