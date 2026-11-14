import 'package:flutter/material.dart';

import 'lemqes_gradients.dart';
import 'lemqes_tokens.dart';
import 'lemqes_typography.dart';

export 'lemqes_typography.dart'
    show lemqesNumeric, lemqesTextTheme, lemqesWeight;

const ColorScheme _light = ColorScheme(
  brightness: Brightness.light,
  primary: LemqesColors.teal,
  onPrimary: Colors.white,
  primaryContainer: LemqesColors.pill,
  onPrimaryContainer: LemqesColors.tealDark,
  secondary: LemqesColors.blue,
  onSecondary: Colors.white,
  secondaryContainer: LemqesColors.pill,
  onSecondaryContainer: LemqesColors.tealDark,
  tertiary: LemqesColors.gold,
  onTertiary: LemqesColors.ink,
  tertiaryContainer: Color(0xFFF6ECD4),
  onTertiaryContainer: Color(0xFF6B4E12),
  error: Color(0xFFB3261E),
  onError: Colors.white,
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF8C1D18),
  surface: LemqesColors.ground,
  onSurface: LemqesColors.ink,
  onSurfaceVariant: LemqesColors.muted,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Colors.white,
  surfaceContainer: Color(0xFFF1F1F6),
  surfaceContainerHigh: Color(0xFFEEEFF5),
  surfaceContainerHighest: Color(0xFFE4E4EC),
  outline: Color(0xFF8A90A0),
  outlineVariant: Color(0xFFE4E4EC),
  inverseSurface: LemqesColors.ink,
  onInverseSurface: LemqesColors.ground,
  inversePrimary: Color(0xFF7DD3DD),
  shadow: Color(0xFF141228),
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

/// Dark Lagoon: surfaces are deep-sea tones (not an inverted light theme),
/// with the brand teal lifted to stay legible.
const ColorScheme _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF7DD3DD),
  onPrimary: Color(0xFF00363D),
  primaryContainer: LemqesColors.teal,
  onPrimaryContainer: Colors.white,
  secondary: Color(0xFFA8C8FF),
  onSecondary: Color(0xFF0A305F),
  secondaryContainer: Color(0xFF1D4250),
  onSecondaryContainer: Color(0xFFCFE8F1),
  tertiary: LemqesColors.gold,
  onTertiary: Color(0xFF2B1E00),
  tertiaryContainer: Color(0xFF4A3A14),
  onTertiaryContainer: Color(0xFFF6E9C9),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF071A21),
  onSurface: Color(0xFFE3ECEF),
  onSurfaceVariant: Color(0xFFA3B6BD),
  surfaceContainerLowest: Color(0xFF04141A),
  surfaceContainerLow: Color(0xFF0E242C),
  surfaceContainer: Color(0xFF122A33),
  surfaceContainerHigh: Color(0xFF17313B),
  surfaceContainerHighest: Color(0xFF1D3943),
  outline: Color(0xFF6E858D),
  outlineVariant: Color(0xFF2A444D),
  inverseSurface: Color(0xFFE3ECEF),
  onInverseSurface: Color(0xFF13262D),
  inversePrimary: LemqesColors.teal,
  shadow: Colors.black,
  scrim: Colors.black,
  surfaceTint: Colors.transparent,
);

ThemeData lemqesTheme(Brightness brightness) {
  final scheme = brightness == Brightness.dark ? _dark : _light;
  final textTheme = lemqesTextTheme(brightness);
  final cardRadius = BorderRadius.circular(LemqesShape.cardRadius);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    textTheme: textTheme,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansArabic', 'NotoSansTifinagh'],
    scaffoldBackgroundColor: scheme.surface,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: const [LemqesGradients.lagoon],
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
    ),
    chipTheme: ChipThemeData(
      selectedColor: LemqesColors.teal,
      checkmarkColor: Colors.white,
      // M3 would use onSecondaryContainer, unreadable on the solid teal fill.
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) return Colors.white;
          return scheme.onSurfaceVariant;
        }),
      ),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.secondaryContainer,
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}
