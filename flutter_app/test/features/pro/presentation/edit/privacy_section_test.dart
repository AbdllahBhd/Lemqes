import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/shared/widgets/ltr.dart';

import '../dashboard/dashboard_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  Future<void> enterNumber(WidgetTester tester, String text) async {
    await scrollTo(tester, byKey('contactPhoneField'));
    await tester.enterText(byKey('contactPhoneField'), text);
    await tester.pump();
  }

  Finder ltrNumber(String formatted) =>
      find.ancestor(of: find.text(formatted), matching: find.byType(Ltr));

  testWidgets('choosing Visible asks for a number in an empty field', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    expect(byKey('contactPhoneField'), findsOneWidget);
    expect(fieldText(tester, 'contactPhoneField'), isEmpty);
    expect(h.pros.calls, isNot(contains('updateProfile')));
    expect(h.pros.profile!.phoneVisibility, PhoneVisibility.hidden);
  });

  testWidgets('a valid number is saved with the visibility in one write', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    await enterNumber(tester, '0661 23 45 67');
    await tapAndSettle(tester, 'contactPhoneSave');
    expect(h.pros.lastPatch!.toDb(), {
      'phone_visibility': 'public',
      'contact_phone': '+213661234567',
    });
    expect(h.pros.profile!.phoneVisibility, PhoneVisibility.public);
    expect(byKey('contactPhoneField'), findsNothing);
    await scrollTo(tester, ltrNumber('+213 661 23 45 67'));
    expect(ltrNumber('+213 661 23 45 67'), findsOneWidget);
  });

  testWidgets('Eastern Arabic digits are read as the same number', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    await enterNumber(tester, '٠٧٧١٢٣٤٥٦٧');
    await tapAndSettle(tester, 'contactPhoneSave');
    expect(h.pros.lastPatch!.contactPhone, '+213771234567');
  });

  testWidgets('an invalid number shows an inline error and saves nothing', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    await enterNumber(tester, '0261234567');
    await tapAndSettle(tester, 'contactPhoneSave');
    expect(find.text(fr.phoneInvalid), findsOneWidget);
    expect(h.pros.calls, isNot(contains('updateProfile')));
    expect(h.pros.profile!.phoneVisibility, PhoneVisibility.hidden);
  });

  testWidgets('an empty number shows an inline error and saves nothing', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    await tapAndSettle(tester, 'contactPhoneSave');
    expect(find.text(fr.phoneRequired), findsOneWidget);
    expect(h.pros.calls, isNot(contains('updateProfile')));
  });

  testWidgets('cancelling closes the field and saves nothing', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    await enterNumber(tester, '0661234567');
    await tapAndSettle(tester, 'contactPhoneCancel');
    expect(byKey('contactPhoneField'), findsNothing);
    expect(h.pros.calls, isNot(contains('updateProfile')));
  });

  testWidgets('a failed save keeps the field and the typed number', (
    tester,
  ) async {
    final pros = FakeProRepository(profile: publishedBarber())
      ..nextFailure = const ProNetworkFailure();
    await pumpDashboard(tester, pros: pros);
    await scrollAndTap(tester, 'phone_public');
    await enterNumber(tester, '0661234567');
    await tapAndSettle(tester, 'contactPhoneSave');
    expect(fieldText(tester, 'contactPhoneField'), '0661234567');
    expect(pros.profile!.phoneVisibility, PhoneVisibility.hidden);
  });

  testWidgets(
    'hiding the phone sends only the visibility and keeps the number',
    (tester) async {
      final h = await pumpDashboard(
        tester,
        profile: publishedBarber(phone: PhoneVisibility.public),
      );
      await scrollTo(tester, ltrNumber('+213 661 23 45 67'));
      expect(ltrNumber('+213 661 23 45 67'), findsOneWidget);
      await scrollAndTap(tester, 'phone_hidden');
      expect(h.pros.lastPatch!.toDb(), {'phone_visibility': 'hidden'});
      expect(h.pros.profile!.contactPhone, barberContactPhone);
      expect(find.text('+213 661 23 45 67'), findsNothing);

      // Visible again offers the kept number.
      await scrollAndTap(tester, 'phone_public');
      expect(fieldText(tester, 'contactPhoneField'), '+213 661 23 45 67');
      await tapAndSettle(tester, 'contactPhoneSave');
      expect(h.pros.profile!.phoneVisibility, PhoneVisibility.public);
    },
  );

  testWidgets('a public number can be changed', (tester) async {
    final h = await pumpDashboard(
      tester,
      profile: publishedBarber(phone: PhoneVisibility.public),
    );
    await scrollAndTap(tester, 'contactPhoneEdit');
    await enterNumber(tester, '0550 11 22 33');
    await tapAndSettle(tester, 'contactPhoneSave');
    expect(h.pros.lastPatch!.toDb(), {
      'phone_visibility': 'public',
      'contact_phone': '+213550112233',
    });
  });

  testWidgets('the current choice is not sent again', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_hidden');
    expect(h.pros.calls, isNot(contains('updateProfile')));
  });

  testWidgets('followers only is shown as coming soon and cannot be picked', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollTo(tester, byKey('phone_followers'));
    expect(find.text(fr.privacySoon), findsOneWidget);
    await tester.tap(byKey('phone_followers'));
    await settle(tester);
    expect(h.pros.calls, isNot(contains('updateProfile')));
  });

  testWidgets('the prices switch sends only show_prices', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'showPricesSwitch');
    expect(h.pros.lastPatch!.toDb(), {'show_prices': false});
    expect(h.pros.profile!.showPrices, isFalse);

    await tapAndSettle(tester, 'showPricesSwitch');
    expect(h.pros.lastPatch!.toDb(), {'show_prices': true});
  });

  testWidgets('the phone choices read as a selectable group', (tester) async {
    await pumpDashboard(tester, profile: publishedBarber());
    await scrollTo(tester, byKey('phone_hidden'));
    expect(
      tester.getSemantics(byKey('phone_hidden')),
      isSemantics(
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        label: fr.privacyPhoneHidden,
      ),
    );
  });
}
