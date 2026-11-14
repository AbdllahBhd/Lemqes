import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled faces and Material Icons so goldens show real glyphs
/// instead of the test font's boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fonts = {
    'Alexandria': 'assets/fonts/Alexandria-Variable.ttf',
    'Inter': 'assets/fonts/Inter-Variable.ttf',
    'NotoSansArabic': 'assets/fonts/NotoSansArabic-Variable.ttf',
    'NotoSansTifinagh': 'assets/fonts/NotoSansTifinagh-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
  }
  await testMain();
}
