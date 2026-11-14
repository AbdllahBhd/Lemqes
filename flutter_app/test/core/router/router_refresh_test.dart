import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/router/app_router.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/data/pro_providers.dart';

import '../../features/pro/presentation/dashboard/dashboard_harness.dart';

void main() {
  setUpAll(registerHarnessFallbacks);

  // Every refresh re-runs routing over the whole stack, which undoes a pop
  // made in the same frame (the profile edit's save, back from a pushed
  // page while an upload's reload lands).
  testWidgets('a profile write that leaves setup routing alone does not '
      'refresh the router', (tester) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    var refreshes = 0;
    h.container.read(routerRefreshProvider).addListener(() => refreshes++);

    await h.container
        .read(myProProvider.notifier)
        .updateProfile(const ProProfilePatch(displayName: 'Amine B.'));
    await tester.pump();
    expect(h.container.read(myProProvider).value?.displayName, 'Amine B.');
    expect(refreshes, 0);
    expect(h.location, '/home');
  });

  testWidgets('a write that opens a setup gap refreshes the router', (
    tester,
  ) async {
    final h = await pumpDashboard(tester, profile: publishedBarber());
    var refreshes = 0;
    h.container.read(routerRefreshProvider).addListener(() => refreshes++);

    final only = h.container.read(myProProvider).value!.services.single;
    await h.container.read(myProProvider.notifier).archiveService(only.id);
    await tester.pump();
    expect(
      h.container.read(myProProvider).value!.gaps,
      contains(ProfileGap.services),
    );
    expect(refreshes, greaterThan(0));
  });
}
