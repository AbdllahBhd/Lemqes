import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';

import '../dashboard/dashboard_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  testWidgets('making the phone public sends only the visibility', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    await scrollAndTap(tester, 'phone_public');
    expect(h.pros.lastPatch!.toDb(), {'phone_visibility': 'public'});
    expect(h.pros.profile!.phoneVisibility, PhoneVisibility.public);
  });

  testWidgets('hiding the phone sends only the visibility', (tester) async {
    final h = await pumpDashboard(
      tester,
      profile: publishedBarber(phone: PhoneVisibility.public),
    );
    await scrollAndTap(tester, 'phone_hidden');
    expect(h.pros.lastPatch!.toDb(), {'phone_visibility': 'hidden'});
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
