import 'package:flutter/painting.dart';

/// Lagoon palette. Light-scheme values; the dark scheme is designed in
/// `lemqes_theme.dart` from these hues.
abstract final class LemqesColors {
  static const Color deepSea = Color(0xFF062A35);
  static const Color teal = Color(0xFF0F6E7A);
  static const Color blue = Color(0xFF1F6FD1);
  static const Color tealDark = Color(0xFF0B5560);
  static const Color pill = Color(0xFFD3E7EF);
  static const Color rowTint = Color(0xFFE8F3F7);

  /// Reserved for "you" (your queue place) and money (wallet). Never decorative.
  static const Color gold = Color(0xFFD8B46A);
  static const Color ground = Color(0xFFF5F5F8);
  static const Color ink = Color(0xFF111827);

  /// Darker than the spec's #6B7280, which is 4.44:1 on [ground] and fails AA.
  static const Color muted = Color(0xFF5E6573);
  static const Color open = Color(0xFF15803D);
  static const Color onBreak = Color(0xFFB45309);
  static const Color closed = muted;

  // The light status inks fall below AA on the deep-sea dark surface.
  static const Color openOnDark = Color(0xFF4ADE80);
  static const Color onBreakOnDark = Color(0xFFFBBF24);
  static const Color closedOnDark = Color(0xFFA3B6BD);
}

/// Corner radii and shadows shared by cards and brand surfaces.
abstract final class LemqesShape {
  static const double cardRadius = 20;
  static const double sheetRadius = 24;

  /// Layered soft shadow: a tight contact shadow plus a wide ambient one.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D141228), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x17141228), offset: Offset(0, 10), blurRadius: 28),
  ];
}
