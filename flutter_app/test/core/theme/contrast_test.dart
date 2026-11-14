import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/theme/lemqes_tokens.dart';

double _channel(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const aa = 4.5;

  void expectAa(String name, Color fg, Color bg) {
    final ratio = contrast(fg, bg);
    expect(ratio, greaterThanOrEqualTo(aa), reason: '$name is $ratio:1');
  }

  test('contrast helper matches known WCAG values', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrast(Colors.white, Colors.white), closeTo(1, 0.01));
  });

  test('white text on every gradient stop meets AA', () {
    expectAa('white/deepSea', Colors.white, LemqesColors.deepSea);
    expectAa('white/teal', Colors.white, LemqesColors.teal);
    expectAa('white/blue', Colors.white, LemqesColors.blue);
  });

  test('light text pairs meet AA', () {
    expectAa('ink/ground', LemqesColors.ink, LemqesColors.ground);
    expectAa('muted/white', LemqesColors.muted, Colors.white);
    expectAa('muted/ground', LemqesColors.muted, LemqesColors.ground);
    expectAa('muted/rowTint', LemqesColors.muted, LemqesColors.rowTint);
    expectAa('tealDark/pill', LemqesColors.tealDark, LemqesColors.pill);
    expectAa('open/white', LemqesColors.open, Colors.white);
    expectAa('onBreak/white', LemqesColors.onBreak, Colors.white);
    expectAa('closed/white', LemqesColors.closed, Colors.white);
    expectAa('ink/gold', LemqesColors.ink, LemqesColors.gold);
  });

  test('status colours meet AA on the dark surface', () {
    final surface = lemqesTheme(Brightness.dark).colorScheme.surface;
    expectAa('openOnDark', LemqesColors.openOnDark, surface);
    expectAa('onBreakOnDark', LemqesColors.onBreakOnDark, surface);
    expectAa('closedOnDark', LemqesColors.closedOnDark, surface);
  });

  for (final brightness in Brightness.values) {
    testWidgets('selected chip label meets AA on its fill ($brightness)', (
      tester,
    ) async {
      final theme = lemqesTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: FilterChip(
                label: const Text('Ouverts'),
                selected: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      final label = tester.renderObject<RenderParagraph>(find.text('Ouverts'));
      final color = label.text.style!.color!;
      expect(theme.chipTheme.selectedColor, LemqesColors.teal);
      expectAa('selected chip label', color, LemqesColors.teal);
    });
  }

  test('dark scheme text pairs meet AA', () {
    final s = lemqesTheme(Brightness.dark).colorScheme;
    expectAa('onSurface/surface', s.onSurface, s.surface);
    expectAa('onSurfaceVariant/surface', s.onSurfaceVariant, s.surface);
    expectAa('onPrimary/primary', s.onPrimary, s.primary);
  });
}
