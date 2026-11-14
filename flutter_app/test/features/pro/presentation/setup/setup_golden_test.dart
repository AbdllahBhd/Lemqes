import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/features/pro/presentation/setup/hours_step.dart';
import 'package:lemqes/features/pro/presentation/setup/profile_step.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/golden_host.dart';
import 'setup_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);

  for (final v in goldenVariants) {
    final theme = v.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    testWidgets('profile step ${goldenName(v)}', (tester) async {
      await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(service: false)),
        location: '/pro/setup/profile',
        locale: v.locale,
        themeMode: theme,
      );
      await expectLater(
        find.byType(ProfileStep),
        matchesGoldenFile('goldens/profile_step_${goldenName(v)}.png'),
      );
    });

    testWidgets('hours step ${goldenName(v)}', (tester) async {
      await pumpSetup(
        tester,
        account: proAccount(),
        pros: FakeProRepository(profile: barberProfile(hours: false)),
        location: '/pro/setup/hours',
        locale: v.locale,
        themeMode: theme,
      );
      await expectLater(
        find.byType(HoursStep),
        matchesGoldenFile('goldens/hours_step_${goldenName(v)}.png'),
      );
    });
  }
}
