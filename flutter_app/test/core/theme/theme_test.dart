import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/lemqes_gradients.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/theme/lemqes_tokens.dart';

void main() {
  final light = lemqesTheme(Brightness.light);
  final dark = lemqesTheme(Brightness.dark);

  test('both themes carry the Lagoon gradients', () {
    expect(light.extension<LemqesGradients>(), isNotNull);
    expect(dark.extension<LemqesGradients>(), isNotNull);
  });

  test('display uses Alexandria, body uses Inter with script fallbacks', () {
    for (final theme in [light, dark]) {
      expect(theme.textTheme.displayLarge!.fontFamily, 'Alexandria');
      final body = theme.textTheme.bodyMedium!;
      expect(body.fontFamily, 'Inter');
      expect(
        body.fontFamilyFallback,
        containsAll(<String>['NotoSansArabic', 'NotoSansTifinagh']),
      );
    }
  });

  test('Material 3 with the Lagoon grounds', () {
    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.scaffoldBackgroundColor, LemqesColors.ground);
    expect(dark.scaffoldBackgroundColor, isNot(Colors.black));
    expect(dark.scaffoldBackgroundColor, isNot(LemqesColors.ground));
    expect(dark.brightness, Brightness.dark);
  });

  test('numeric style uses tabular figures', () {
    expect(
      lemqesNumeric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('lemqesWeight drives both fontWeight and the wght axis', () {
    final style = lemqesWeight(light.textTheme.bodyMedium!, FontWeight.w700);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontVariations, contains(const FontVariation('wght', 700)));
    expect(style.fontVariations!.where((v) => v.axis == 'wght'), hasLength(1));
  });
}
