import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'lemqes_tokens.dart';

/// The Lagoon gradients. Used only on the header band, primary buttons and
/// the live ring around an open barber's photo.
@immutable
class LemqesGradients extends ThemeExtension<LemqesGradients> {
  const LemqesGradients({
    required this.brand,
    required this.button,
    required this.bloom,
  });

  /// Deep sea to teal to blue at a CSS-style 160 degrees.
  final Gradient brand;

  /// Teal to blue, for the primary pill and the live ring.
  final Gradient button;

  /// Soft white light in the top trailing corner, painted over [brand].
  final Gradient bloom;

  static const LemqesGradients lagoon = LemqesGradients(
    brand: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [LemqesColors.deepSea, LemqesColors.teal, LemqesColors.blue],
      stops: [0, 0.55, 1],
      transform: CssLinearAngle(160),
    ),
    button: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [LemqesColors.teal, LemqesColors.blue],
      transform: CssLinearAngle(120),
    ),
    bloom: RadialGradient(
      center: AlignmentDirectional.topEnd,
      radius: 1,
      colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
      stops: [0, 0.6],
      transform: _TopEndEllipse(),
    ),
  );

  @override
  LemqesGradients copyWith({
    Gradient? brand,
    Gradient? button,
    Gradient? bloom,
  }) {
    return LemqesGradients(
      brand: brand ?? this.brand,
      button: button ?? this.button,
      bloom: bloom ?? this.bloom,
    );
  }

  @override
  LemqesGradients lerp(LemqesGradients? other, double t) {
    if (other == null) return this;
    return LemqesGradients(
      brand: Gradient.lerp(brand, other.brand, t) ?? other.brand,
      button: Gradient.lerp(button, other.button, t) ?? other.button,
      bloom: Gradient.lerp(bloom, other.bloom, t) ?? other.bloom,
    );
  }
}

/// Lays a top-to-bottom [LinearGradient] along a CSS `linear-gradient` angle,
/// with the CSS gradient-line length, so the band matches the reference comp
/// at any aspect ratio.
class CssLinearAngle extends GradientTransform {
  const CssLinearAngle(this.degrees);

  final double degrees;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final radians = degrees * math.pi / 180;
    final length =
        (bounds.width * math.sin(radians)).abs() +
        (bounds.height * math.cos(radians)).abs();
    final c = bounds.center;
    return Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(Matrix4.rotationZ(radians - math.pi))
      ..multiply(Matrix4.diagonal3Values(1, length / bounds.height, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }
}

/// Stretches the bloom into an ellipse of 90 % width by 70 % height,
/// anchored at the top trailing corner.
class _TopEndEllipse extends GradientTransform {
  const _TopEndEllipse();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = AlignmentDirectional.topEnd
        .resolve(textDirection)
        .withinRect(bounds);
    final side = bounds.shortestSide;
    return Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(
        Matrix4.diagonal3Values(
          0.9 * bounds.width / side,
          0.7 * bounds.height / side,
          1,
        ),
      )
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }
}
