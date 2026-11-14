import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: lemqesTheme(Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('a loading button tells screen readers it is not tappable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        LemqesPrimaryButton(label: 'Send', loading: true, onPressed: () {}),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Send')),
      isSemantics(
        label: 'Send',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('an idle button is an enabled, tappable button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(LemqesPrimaryButton(label: 'Send', onPressed: () {})),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Send')),
      isSemantics(
        label: 'Send',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
