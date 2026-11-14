import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/shared/widgets/choice_card.dart';
import 'package:lemqes/shared/widgets/code_field.dart';
import 'package:lemqes/shared/widgets/step_progress.dart';

Widget _host(Widget child, {Locale locale = const Locale('fr')}) => MaterialApp(
  theme: lemqesTheme(Brightness.light),
  locale: locale,
  localizationsDelegates: appDelegates,
  supportedLocales: supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('CodeField', () {
    testWidgets('fires onCompleted once with six digits', (tester) async {
      final codes = <String>[];
      await tester.pumpWidget(_host(CodeField(onCompleted: codes.add)));
      await tester.enterText(find.byType(EditableText), '12345');
      expect(codes, isEmpty);
      await tester.enterText(find.byType(EditableText), '123456');
      expect(codes, ['123456']);
    });

    testWidgets('maps Eastern Arabic digits and drops other characters', (
      tester,
    ) async {
      final codes = <String>[];
      await tester.pumpWidget(_host(CodeField(onCompleted: codes.add)));
      await tester.enterText(find.byType(EditableText), '۱٢ 3-4a56');
      expect(codes, ['123456']);
    });

    testWidgets('screen readers reach the field by its label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(CodeField(onCompleted: (_) {}, semanticsLabel: 'Code reçu')),
      );

      expect(
        find.semantics.byPredicate(
          (node) =>
              node.flagsCollection.isTextField &&
              node.label.contains('Code reçu'),
          describeMatch: (_) => 'a text field labelled "Code reçu"',
        ),
        findsOne,
      );
      semantics.dispose();
    });

    testWidgets('stays LTR, numeric and autofillable inside RTL', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(CodeField(onCompleted: (_) {}), locale: const Locale('ar')),
      );
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.textDirection, TextDirection.ltr);
    });
  });

  group('ChoiceCard', () {
    testWidgets('is a selectable button of at least 48 dp', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ChoiceCard(
            title: 'Hommes',
            subtitle: 'Barbiers',
            badge: 'Gratuit',
            selected: true,
            icon: Icons.man,
            onTap: () => taps++,
          ),
        ),
      );
      expect(tester.getSize(find.byType(ChoiceCard)).height, greaterThan(48));
      expect(find.text('Gratuit'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ChoiceCard)),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          label: 'Hommes\nBarbiers\nGratuit',
        ),
      );
      await tester.tap(find.byType(ChoiceCard));
      expect(taps, 1);
    });
  });

  group('StepProgress', () {
    testWidgets('names the step in words', (tester) async {
      await tester.pumpWidget(_host(const StepProgress(step: 2, total: 5)));
      expect(find.text('Étape 2 sur 5'), findsOneWidget);
    });
  });
}
