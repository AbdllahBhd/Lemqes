import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/shared/widgets/ltr.dart';

void main() {
  testWidgets('ar is RTL and Ltr forces LTR inside it', (tester) async {
    late BuildContext outer;
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: appDelegates,
        supportedLocales: supportedLocales,
        home: Builder(
          builder: (context) {
            outer = context;
            return Ltr(
              child: Builder(
                builder: (c) {
                  inner = c;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(Directionality.of(outer), TextDirection.rtl);
    expect(Directionality.of(inner), TextDirection.ltr);
  });
}
