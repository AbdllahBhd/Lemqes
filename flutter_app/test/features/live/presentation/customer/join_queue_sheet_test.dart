import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/live/data/live_failure.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';
import 'package:lemqes/shared/widgets/price_text.dart';
import 'package:material_ui/material_ui.dart';

import '../../../explore/presentation/explore_harness.dart';
import 'customer_live_harness.dart';

final _fr = AppLocalizationsFr();

Future<void> _pickAndConfirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('joinService_s1')));
  await settleLive(tester);
  await tester.tap(find.byKey(const Key('joinConfirm')));
  await settleLive(tester);
}

void main() {
  setUpAll(registerHarnessFallbacks);

  testWidgets('lists the services with duration and price', (tester) async {
    await pumpJoinable(tester);
    await openJoinSheet(tester);

    expect(find.text(_fr.liveJoinTitle), findsOneWidget);
    final sheet = find.byKey(const Key('joinSheet'));
    expect(
      find.descendant(of: sheet, matching: find.byType(PriceText)),
      findsNWidgets(2),
    );
    for (final t in ['30 min', '15 min', '600 DA']) {
      expect(
        find.descendant(of: sheet, matching: find.textContaining(t)),
        findsWidgets,
        reason: t,
      );
    }
    // Nothing is taken until a service is picked.
    final confirm = tester.widget<LemqesPrimaryButton>(
      find.byKey(const Key('joinConfirm')),
    );
    expect(confirm.onPressed, isNull);
    await unmountLive(tester);
  });

  final refusals = <(LiveFailure, String)>[
    (const NotListable(), _fr.joinErrorNotListable),
    (const OwnQueue(), _fr.joinErrorOwnQueue),
    (const ProNotOpen(), _fr.joinErrorNotOpen),
    (const QueuePaused(), _fr.joinErrorPaused),
    (const AlreadyInQueue(), _fr.joinErrorAlreadyInQueue),
    (const JoinLimitReached(), _fr.joinErrorLimit),
    (const AbsentBlock(), _fr.joinErrorAbsentBlock),
    (const InvalidService(), _fr.liveErrorInvalidService),
    (const LiveNetworkFailure(), _fr.errorNetwork),
  ];

  for (final (failure, sentence) in refusals) {
    testWidgets('${failure.runtimeType} has its own sentence', (tester) async {
      final h = await pumpJoinable(tester);
      h.live.repo.joinFailure = failure;
      await openJoinSheet(tester);
      await _pickAndConfirm(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('joinError')),
          matching: find.text(sentence),
        ),
        findsOneWidget,
      );
      // The sheet stays, so the customer can read it and pick again.
      expect(find.byKey(const Key('joinSheet')), findsOneWidget);
      expect(h.live.repo.joins, [(proUuid, 's1')]);
      await unmountLive(tester);
    });
  }

  test(
    'a blocked customer hears the closed pro\'s sentence, naming no block',
    () {
      // The server refuses a blocked customer pro_not_open, as a closed pro.
      expect(_fr.joinErrorNotOpen.toLowerCase(), isNot(contains('bloqu')));
    },
  );

  testWidgets('a join shows the ticket in place of the button', (tester) async {
    final h = await pumpJoinable(tester);
    h.live.repo.joinResult = ticketFor(proId: proUuid);
    await openJoinSheet(tester);
    await _pickAndConfirm(tester);

    expect(find.byKey(const Key('joinSheet')), findsNothing);
    expect(find.text('Vous êtes 3e · ~25 min'), findsWidgets);
    expect(find.byKey(const Key('liveJoin')), findsNothing);
    expect(h.live.repo.joins, [(proUuid, 's1')]);
    await unmountLive(tester);
  });
}
