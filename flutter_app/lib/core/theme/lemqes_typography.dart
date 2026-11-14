import 'package:flutter/material.dart';

import 'lemqes_tokens.dart';

const String _display = 'Alexandria';
const String _body = 'Inter';
const List<String> _fallback = ['NotoSansArabic', 'NotoSansTifinagh'];

/// Counts, times and prices: tabular figures so digits do not jitter.
const TextStyle lemqesNumeric = TextStyle(
  fontFamily: _display,
  fontFamilyFallback: _fallback,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Sets a weight that actually renders: the bundled faces are variable fonts,
/// so `fontWeight` alone does not move their `wght` axis.
TextStyle lemqesWeight(TextStyle style, FontWeight weight) {
  return style.copyWith(
    fontWeight: weight,
    fontVariations: [
      ...?style.fontVariations?.where((v) => v.axis != 'wght'),
      FontVariation.weight(weight.value.toDouble()),
    ],
  );
}

TextStyle _style(
  String family,
  double size,
  double height,
  FontWeight weight, [
  double letterSpacing = 0,
]) {
  return lemqesWeight(
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: _fallback,
      fontSize: size,
      height: height / size,
      letterSpacing: letterSpacing,
    ),
    weight,
  );
}

/// Material 3 type scale (sizes in sp). Alexandria carries display, headline
/// and title roles (headings, names, big numbers); Inter carries body and
/// label roles.
TextTheme lemqesTextTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFE3ECEF) : LemqesColors.ink;
  return TextTheme(
    displayLarge: _style(_display, 57, 64, FontWeight.w600, -0.25),
    displayMedium: _style(_display, 45, 52, FontWeight.w600),
    displaySmall: _style(_display, 36, 44, FontWeight.w600),
    headlineLarge: _style(_display, 32, 40, FontWeight.w600),
    headlineMedium: _style(_display, 28, 36, FontWeight.w600),
    headlineSmall: _style(_display, 24, 32, FontWeight.w600),
    titleLarge: _style(_display, 22, 28, FontWeight.w500),
    titleMedium: _style(_display, 16, 24, FontWeight.w500, 0.15),
    titleSmall: _style(_display, 14, 20, FontWeight.w500, 0.1),
    bodyLarge: _style(_body, 16, 24, FontWeight.w400, 0.15),
    bodyMedium: _style(_body, 14, 20, FontWeight.w400, 0.25),
    bodySmall: _style(_body, 12, 16, FontWeight.w400, 0.4),
    labelLarge: _style(_body, 14, 20, FontWeight.w600, 0.1),
    labelMedium: _style(_body, 12, 16, FontWeight.w500, 0.5),
    labelSmall: _style(_body, 11, 16, FontWeight.w500, 0.5),
  ).apply(bodyColor: ink, displayColor: ink);
}
