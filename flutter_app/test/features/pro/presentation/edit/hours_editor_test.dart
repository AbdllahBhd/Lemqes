import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/edit/hours_editor.dart';
import 'package:material_ui/material_ui.dart';

import '../../../auth/presentation/harness.dart' show byKey;
import '../pro_test_host.dart';
import '../setup/setup_harness.dart'
    show
        FakeProRepository,
        barberProfile,
        proAccount,
        pumpSetup,
        registerHarnessFallbacks,
        tapAndSettle;

TimeOfDay _t(int h, [int m = 0]) => TimeOfDay(hour: h, minute: m);

DayHours _day(
  int wd,
  int opens,
  int closes, {
  TimeOfDay? breakStart,
  TimeOfDay? breakEnd,
}) => DayHours(
  weekday: wd,
  opens: _t(opens),
  closes: _t(closes),
  breakStart: breakStart,
  breakEnd: breakEnd,
);

void main() {
  setUpAll(registerHarnessFallbacks);
  final fr = AppLocalizationsFr();

  late List<DayHours> week;
  late bool valid;
  late List<TimeOfDay> answers;

  setUp(() {
    week = [];
    valid = true;
    answers = [];
  });

  Future<void> pump(WidgetTester tester, List<DayHours> initial) =>
      pumpLocalized(
        tester,
        HoursEditor(
          initial: initial,
          onChanged: (w, v) {
            week = w;
            valid = v;
          },
          pickTime: (_, _) async => answers.removeAt(0),
        ),
      );

  Future<void> pick(WidgetTester tester, String key, TimeOfDay answer) async {
    answers.add(answer);
    await tester.ensureVisible(byKey(key));
    await tester.tap(byKey(key));
    await tester.pump();
  }

  Finder inDay(int wd, String text) =>
      find.descendant(of: byKey('day_$wd'), matching: find.text(text));

  testWidgets('a past-midnight day is accepted and says so', (tester) async {
    await pump(tester, [_day(6, 14, 19)]);
    await pick(tester, 'day_6_closes', _t(1));

    expect(valid, isTrue);
    expect(week.single.pastMidnight, isTrue);
    expect(week.single.closes, _t(1));
    expect(inDay(6, '14:00'), findsOneWidget);
    expect(inDay(6, '01:00'), findsOneWidget);
    expect(inDay(6, fr.hoursPastMidnightNote), findsOneWidget);
    expect(byKey('day_6_error'), findsNothing);
  });

  testWidgets('closing after 06:00 the next day is refused', (tester) async {
    await pump(tester, [_day(6, 14, 19)]);
    await pick(tester, 'day_6_closes', _t(7));

    expect(valid, isFalse);
    expect(inDay(6, fr.hoursErrorLateClose), findsOneWidget);
  });

  testWidgets('the same opening and closing time is refused', (tester) async {
    await pump(tester, [_day(6, 9, 19)]);
    await pick(tester, 'day_6_closes', _t(9));

    expect(valid, isFalse);
    expect(inDay(6, fr.hoursErrorSameTimes), findsOneWidget);
  });

  testWidgets('a break outside the opening hours is refused', (tester) async {
    await pump(tester, [_day(6, 14, 19)]);
    await tester.ensureVisible(byKey('day_6_addBreak'));
    await tester.tap(byKey('day_6_addBreak'));
    await tester.pump();
    expect(valid, isTrue);

    await pick(tester, 'day_6_breakStart', _t(10));
    await pick(tester, 'day_6_breakEnd', _t(11));

    expect(valid, isFalse);
    expect(inDay(6, fr.hoursErrorBreakOutside), findsOneWidget);
  });

  testWidgets('a break ending before it starts is refused', (tester) async {
    await pump(tester, [_day(6, 9, 19, breakStart: _t(13), breakEnd: _t(14))]);
    await pick(tester, 'day_6_breakEnd', _t(12));

    expect(valid, isFalse);
    expect(inDay(6, fr.hoursErrorBreakOrder), findsOneWidget);
  });

  testWidgets('a break after midnight on a late day is accepted', (
    tester,
  ) async {
    await pump(tester, [_day(6, 14, 2, breakStart: _t(20), breakEnd: _t(21))]);
    await pick(tester, 'day_6_breakStart', _t(0, 15));
    await pick(tester, 'day_6_breakEnd', _t(0, 45));

    expect(valid, isTrue);
    expect(week.single.breakStart, _t(0, 15));
  });

  testWidgets('removing the break saves the day without it', (tester) async {
    await pump(tester, [_day(6, 9, 19, breakStart: _t(13), breakEnd: _t(14))]);
    await tester.ensureVisible(byKey('day_6_removeBreak'));
    await tester.tap(byKey('day_6_removeBreak'));
    await tester.pump();

    expect(week.single.breakStart, isNull);
    expect(week.single.breakEnd, isNull);
  });

  testWidgets('copy to all days keeps closed days closed', (tester) async {
    await pump(tester, [
      _day(6, 10, 18, breakStart: _t(13), breakEnd: _t(14)),
      _day(1, 9, 19),
    ]);
    await tester.ensureVisible(byKey('day_6_copy'));
    await tester.tap(byKey('day_6_copy'));
    await tester.pump();

    // Only the open days change: a closure is never undone off-screen.
    expect(week.map((d) => d.weekday), [1, 6]);
    for (final d in week) {
      expect(d.opens, _t(10));
      expect(d.closes, _t(18));
      expect(d.breakStart, _t(13));
      expect(d.breakEnd, _t(14));
    }

    // A closed day opened afterwards starts from the copied hours.
    await tester.ensureVisible(byKey('day_5_open'));
    await tester.tap(byKey('day_5_open'));
    await tester.pump();
    final friday = week.singleWhere((d) => d.weekday == 5);
    expect(friday.opens, _t(10));
    expect(friday.breakEnd, _t(14));
  });

  testWidgets('switching a day off leaves it out of the week', (tester) async {
    await pump(tester, [_day(6, 9, 19), _day(5, 9, 12)]);
    await tester.ensureVisible(byKey('day_5_open'));
    await tester.tap(byKey('day_5_open'));
    await tester.pump();

    expect(week.map((d) => d.weekday), [6]);
    expect(inDay(5, fr.hoursClosed), findsOneWidget);
  });

  testWidgets('switching a closed day on offers usual hours', (tester) async {
    await pump(tester, [_day(6, 9, 19)]);
    await tester.ensureVisible(byKey('day_5_open'));
    await tester.tap(byKey('day_5_open'));
    await tester.pump();

    expect(week.map((d) => d.weekday).toSet(), {5, 6});
    expect(valid, isTrue);
  });

  testWidgets('200 % text in Arabic does not overflow', (tester) async {
    await pumpLocalized(
      tester,
      HoursEditor(
        initial: [
          _day(6, 14, 1, breakStart: _t(20), breakEnd: _t(21)),
          _day(7, 9, 19),
        ],
        onChanged: (_, _) {},
      ),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  group('hoursIssue mirrors set_pro_hours', () {
    test('valid day, past-midnight up to 06:00', () {
      expect(hoursIssue(_day(1, 9, 19)), isNull);
      expect(hoursIssue(_day(1, 14, 6)), isNull);
      expect(hoursIssue(_day(1, 14, 7)), HoursIssue.lateClose);
      expect(hoursIssue(_day(1, 9, 9)), HoursIssue.sameTimes);
    });

    test('break strictly inside the span', () {
      expect(
        hoursIssue(_day(1, 9, 19, breakStart: _t(9), breakEnd: _t(10))),
        HoursIssue.breakOutside,
      );
      expect(
        hoursIssue(_day(1, 9, 19, breakStart: _t(18), breakEnd: _t(19))),
        HoursIssue.breakOutside,
      );
      expect(
        hoursIssue(_day(1, 14, 1, breakStart: _t(2), breakEnd: _t(3))),
        HoursIssue.breakOutside,
      );
      expect(
        hoursIssue(_day(1, 14, 1, breakStart: _t(23), breakEnd: _t(0, 30))),
        HoursIssue.breakOrder,
      );
    });
  });

  group('publishing from the hours step', () {
    testWidgets('every day closed blocks publishing with a message', (
      tester,
    ) async {
      final pros = FakeProRepository(profile: barberProfile(hours: false));
      await pumpSetup(
        tester,
        account: proAccount(),
        pros: pros,
        location: '/pro/setup/hours',
      );
      for (final wd in [6, 7, 1, 2, 3, 4]) {
        await tapAndSettle(tester, 'day_${wd}_open');
      }
      await tapAndSettle(tester, 'setupPublish');

      expect(find.text(fr.hoursAllClosed), findsOneWidget);
      expect(pros.calls, isEmpty);
    });

    testWidgets('a flagged day blocks publishing with a message', (
      tester,
    ) async {
      final pros = FakeProRepository(profile: barberProfile(hours: false));
      await pumpSetup(
        tester,
        account: proAccount(),
        pros: pros,
        location: '/pro/setup/hours',
        timeAnswers: [_t(9)],
      );
      await tapAndSettle(tester, 'day_6_closes');
      expect(find.text(fr.hoursErrorSameTimes), findsOneWidget);
      await tapAndSettle(tester, 'setupPublish');

      expect(find.text(fr.hoursFixErrors), findsOneWidget);
      expect(pros.calls, isEmpty);
    });
  });
}
