import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/intl_locale.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';

void main() {
  testWidgets('kab renders Material widgets without throwing', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('kab'),
        localizationsDelegates: appDelegates,
        supportedLocales: supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return Scaffold(
              body: TextButton(
                onPressed: () => showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDate: DateTime(2025),
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(MaterialLocalizations.of(captured), isNotNull);
    expect(Directionality.of(captured), TextDirection.ltr);
    expect(
      () =>
          NumberFormat.decimalPattern(intlLocaleFor(const Locale('kab')))
              .format(1234),
      returnsNormally,
    );
  });
}
