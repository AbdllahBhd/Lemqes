import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/core/time/country_clock.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/shared/widgets/hours_table.dart';
import 'package:lemqes/shared/widgets/photo_tile.dart';
import 'package:lemqes/shared/widgets/price_text.dart';
import 'package:material_ui/material_ui.dart';

Widget host(
  Widget child, {
  Locale locale = const Locale('fr'),
  double textScale = 1,
}) => MaterialApp(
  theme: lemqesTheme(Brightness.light),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appDelegates,
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: c!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

DayHours day(int wd, String o, String c, {String? bs, String? be}) {
  TimeOfDay t(String s) => TimeOfDay(
    hour: int.parse(s.split(':')[0]),
    minute: int.parse(s.split(':')[1]),
  );
  return DayHours(
    weekday: wd,
    opens: t(o),
    closes: t(c),
    breakStart: bs == null ? null : t(bs),
    breakEnd: be == null ? null : t(be),
  );
}

// Monday..Friday open, Saturday past midnight, Sunday missing.
final week = [
  for (var d = 1; d <= 5; d++)
    day(
      d,
      '09:00',
      '19:00',
      bs: d == 3 ? '13:00' : null,
      be: d == 3 ? '14:00' : null,
    ),
  day(6, '14:00', '01:00'),
];

void main() {
  group('HoursTable', () {
    testWidgets('shows Fermé for a missing day and the past-midnight range', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(HoursTable(week: week, clock: () => DateTime(2026, 11, 18))),
      );
      expect(find.text('Fermé'), findsOneWidget); // Sunday
      expect(find.text('14:00 – 01:00'), findsOneWidget);
      expect(find.text('13:00 – 14:00'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('reads each day as one item: name, then its hours', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(HoursTable(week: week, clock: () => DateTime(2026, 11, 14))),
      );
      expect(
        tester.getSemantics(find.text('Mercredi')),
        matchesSemantics(
          label: 'Mercredi\n09:00 – 19:00\nPause\n13:00 – 14:00',
        ),
      );
      handle.dispose();
    });

    testWidgets('lists Saturday first', (tester) async {
      await tester.pumpWidget(
        host(HoursTable(week: week, clock: () => DateTime(2026, 11, 18))),
      );
      final names = [
        'Samedi',
        'Dimanche',
        'Lundi',
        'Mardi',
        'Mercredi',
        'Jeudi',
        'Vendredi',
      ];
      final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
      expect([...ys]..sort(), ys);
    });

    testWidgets('highlights today from the injected clock', (tester) async {
      // 2026-11-14 is a Saturday.
      await tester.pumpWidget(
        host(HoursTable(week: week, clock: () => DateTime(2026, 11, 14))),
      );
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.byKey(const Key('today_6')), findsOneWidget);
      expect(find.byKey(const Key('today_1')), findsNothing);
    });

    testWidgets('highlights the country weekday, not the device one', (
      tester,
    ) async {
      // 23:30 UTC on Saturday 2026-11-14 is 18:30 Saturday for a device in
      // UTC-5 but already Sunday 00:30 in Algiers.
      final utc = DateTime.utc(2026, 11, 14, 23, 30);
      await tester.pumpWidget(
        host(
          HoursTable(
            week: week,
            clock: () => countryNow('Africa/Algiers', utc),
          ),
        ),
      );
      expect(find.byKey(const Key('today_7')), findsOneWidget);
      expect(find.byKey(const Key('today_6')), findsNothing);
    });
  });

  group('PriceText', () {
    testWidgets('uses Latin digits and DA under ar', (tester) async {
      await tester.pumpWidget(
        host(const PriceText(1500), locale: const Locale('ar')),
      );
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, matches(RegExp(r'^1\D?500 DA$')));
      expect(text, isNot(contains(RegExp(r'[٠-٩]'))));
    });

    testWidgets('is left-to-right inside RTL', (tester) async {
      await tester.pumpWidget(
        host(const PriceText(800), locale: const Locale('ar')),
      );
      expect(
        Directionality.of(tester.element(find.text('800 DA'))),
        TextDirection.ltr,
      );
    });
  });

  group('PhotoTile', () {
    testWidgets('a failed image shows the unavailable state, 1:1', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 160,
            child: PhotoTile(url: 'http://x.test/a.jpg'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photoError')), findsOneWidget);
      expect(tester.getSize(find.byType(PhotoTile)), const Size(160, 160));
    });

    testWidgets('remove button is 48 dp and fires onRemove', (tester) async {
      var removed = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 160,
            child: PhotoTile(
              url: 'http://x.test/a.jpg',
              onRemove: () => removed++,
            ),
          ),
        ),
      );
      final btn = find.byKey(const Key('photoRemove'));
      final size = tester.getSize(btn);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(btn);
      expect(removed, 1);
    });

    testWidgets('no remove button without onRemove', (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 160,
            child: PhotoTile(url: 'http://x.test/a.jpg'),
          ),
        ),
      );
      expect(find.byKey(const Key('photoRemove')), findsNothing);
    });
  });

  for (final locale in [const Locale('fr'), const Locale('ar')]) {
    testWidgets('200 % text, ${locale.languageCode}: no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              HoursTable(week: week, clock: () => DateTime(2026, 11, 18)),
              const PriceText(125000),
              SizedBox(
                width: 120,
                child: PhotoTile(url: 'http://x.test/a.jpg', onRemove: () {}),
              ),
            ],
          ),
          locale: locale,
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
