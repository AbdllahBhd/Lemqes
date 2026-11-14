import 'package:flutter/material.dart';
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

const _screens = {
  '/auth': null,
  '/auth/reset': null,
  '/signup/space': SignupDraft(),
  '/signup/role': SignupDraft(space: Space.men),
  '/signup/credentials': SignupDraft(
    space: Space.men,
    role: AppRole.salonOwner,
  ),
  '/signup/code': _full,
};

void main() {
  for (final MapEntry(key: location, value: draft) in _screens.entries) {
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
      for (final key in ['phoneField', 'codeField']) {
        final field = byKey(key);
        if (field.evaluate().isEmpty) continue;
        final input = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        expect(
          Directionality.of(tester.element(input)),
          TextDirection.ltr,
          reason: '$key on $location',
        );
      }
    });
  }
}
