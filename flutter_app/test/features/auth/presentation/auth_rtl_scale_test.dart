import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/signup/data/signup_draft.dart';

import 'harness.dart';

const _full = SignupDraft(
  space: Space.men,
  role: AppRole.salonOwner,
  fullName: 'أمين بن علي',
  businessName: 'صالون الدبلوماسي',
  phone: '+213550123456',
);

/// Each screen, its draft, and the LTR inputs it must show.
const _screens = <String, (SignupDraft?, List<String>)>{
  '/auth': (null, ['phoneField']),
  '/auth/reset': (null, ['phoneField']),
  '/signup/space': (SignupDraft(), []),
  '/signup/role': (SignupDraft(space: Space.men), []),
  '/signup/credentials': (
    SignupDraft(space: Space.men, role: AppRole.salonOwner),
    ['phoneField'],
  ),
  '/signup/code': (_full, ['codeField']),
};

final _easternDigits = RegExp('[٠-٩۰-۹]');

void main() {
  for (final MapEntry(key: location, value: (draft, ltrKeys))
      in _screens.entries) {
    testWidgets('$location in Arabic at 2x text fits 360x740', (tester) async {
      await pumpApp(
        tester,
        location: location,
        auth: MockAuthRepository(),
        draft: draft,
        locale: const Locale('ar'),
        textScale: 2,
        size: const Size(360, 740),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
      for (final key in ltrKeys) {
        final input = find.descendant(
          of: byKey(key),
          matching: find.byType(EditableText),
        );
        expect(input, findsOneWidget, reason: '$key on $location');
        expect(
          tester.widget<EditableText>(input).textDirection,
          TextDirection.ltr,
          reason: '$key on $location',
        );
      }
      // Numbers (hint, phone, step count, countdown) use Latin digits.
      expect(find.textContaining(_easternDigits), findsNothing);
      if (ltrKeys.contains('phoneField')) {
        expect(find.text('0550 12 34 56'), findsOneWidget);
      }
      if (location == '/signup/code') {
        expect(find.text('+213 550 12 34 56'), findsOneWidget);
      }
    });
  }
}
