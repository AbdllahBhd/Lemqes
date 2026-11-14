import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/theme/lemqes_tokens.dart';
import 'package:lemqes/core/theme/status_colors.dart';

import 'contrast_test.dart' show contrast;

void main() {
  test('light status colours are the M1 tokens', () {
    final s = lemqesTheme(Brightness.light).extension<StatusColors>()!;
    expect(s.open, LemqesColors.open);
    expect(s.onBreak, LemqesColors.onBreak);
    expect(s.closed, LemqesColors.closed);
  });

  test('dark status colours meet AA on the dark surface', () {
    final theme = lemqesTheme(Brightness.dark);
    final s = theme.extension<StatusColors>()!;
    final surface = theme.colorScheme.surface;
    for (final (name, c) in [
      ('open', s.open),
      ('onBreak', s.onBreak),
      ('closed', s.closed),
    ]) {
      expect(contrast(c, surface), greaterThanOrEqualTo(4.5), reason: name);
    }
  });

  testWidgets('context.statusColors reads the theme extension', (tester) async {
    late StatusColors read;
    await tester.pumpWidget(
      MaterialApp(
        theme: lemqesTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            read = context.statusColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read.open, LemqesColors.open);
  });
}
