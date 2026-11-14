import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart' show appDelegates;
import 'package:lemqes/core/l10n/gen/app_localizations.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/features/geo/data/geo_models.dart';
import 'package:lemqes/features/geo/data/geo_providers.dart';
import 'package:lemqes/features/geo/presentation/locality_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'geo_fixture.dart';

Future<void> pumpPicker(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  double textScale = 1,
  Size size = const Size(390, 844),
  String? regionCode,
  int? localityId,
  required void Function(String, int) onChanged,
  Future<List<Region>> Function()? regions,
  Future<List<Locality>> Function(String)? localities,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final seed = loadSeed();
  await tester.pumpWidget(
    ProviderScope(
      // Silent backoff retries would hide the failure this test pins.
      retry: (_, _) => null,
      overrides: [
        regionsProvider.overrideWith(
          (ref, c) => regions != null ? regions() : Future.value(seed.regions),
        ),
        localitiesProvider.overrideWith(
          (ref, k) => localities != null
              ? localities(k.regionCode)
              : Future.value([
                  for (final l in seed.localities)
                    if (l.regionCode == k.regionCode) l,
                ]),
        ),
      ],
      child: MaterialApp(
        theme: lemqesTheme(Brightness.light),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LocalityPicker(
              country: 'DZ',
              regionCode: regionCode,
              localityId: localityId,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openRegions(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pickRegion')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"bou saada" (accents ignored) finds region 68', (tester) async {
    await pumpPicker(tester, onChanged: (_, _) {});
    await openRegions(tester);
    await tester.enterText(find.byKey(const Key('pickerSearch')), 'bou saada');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('option_68')), findsOneWidget);
    expect(find.byKey(const Key('option_01')), findsNothing);
  });

  testWidgets('an exact Arabic substring of region 68 finds it', (
    tester,
  ) async {
    await pumpPicker(tester, locale: const Locale('ar'), onChanged: (_, _) {});
    await openRegions(tester);
    await tester.enterText(find.byKey(const Key('pickerSearch')), 'سعادة');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('option_68')), findsOneWidget);
  });

  testWidgets('region then commune reports both', (tester) async {
    final calls = <(String, int)>[];
    await pumpPicker(tester, onChanged: (r, id) => calls.add((r, id)));
    await openRegions(tester);
    await tester.enterText(find.byKey(const Key('pickerSearch')), 'bou saada');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('option_68')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty, reason: 'a region alone is not a locality');

    // The commune sheet follows the region choice.
    await tester.tap(find.byKey(const Key('option_2820')));
    await tester.pumpAndSettle();
    expect(calls, [('68', 2820)]);
  });

  testWidgets('rows show the code left-to-right and are at least 48 dp', (
    tester,
  ) async {
    await pumpPicker(tester, locale: const Locale('ar'), onChanged: (_, _) {});
    await openRegions(tester);
    final row = find.byKey(const Key('option_01'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(find.descendant(of: row, matching: find.text('01')), findsOneWidget);
  });

  testWidgets('the commune field is disabled until a wilaya is chosen', (
    tester,
  ) async {
    await pumpPicker(tester, onChanged: (_, _) {});
    await tester.tap(find.byKey(const Key('pickLocality')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pickerSearch')), findsNothing);
    expect(find.text('Choisissez d\'abord la wilaya'), findsOneWidget);
  });

  testWidgets('shows the chosen wilaya and commune names', (tester) async {
    await pumpPicker(
      tester,
      regionCode: '68',
      localityId: 2820,
      onChanged: (_, _) {},
    );
    expect(find.text('Bou Saâda'), findsOneWidget);
    expect(find.text('Bou Saada'), findsOneWidget);
  });

  testWidgets('empty search shows the empty state', (tester) async {
    await pumpPicker(tester, onChanged: (_, _) {});
    await openRegions(tester);
    await tester.enterText(find.byKey(const Key('pickerSearch')), 'zzzzzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);
  });

  testWidgets('a failed load shows retry, and retry reloads', (tester) async {
    var fail = true;
    await pumpPicker(
      tester,
      onChanged: (_, _) {},
      regions: () async {
        if (fail) throw Exception('offline');
        return [
          const Region(
            countryCode: 'DZ',
            code: '16',
            nameAr: 'الجزائر',
            nameFr: 'Alger',
          ),
        ];
      },
    );
    await tester.tap(find.byKey(const Key('pickRegion')));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('option_16')), findsOneWidget);
  });

  testWidgets('a pending load shows the loading state', (tester) async {
    final never = Completer<List<Region>>().future;
    await pumpPicker(tester, onChanged: (_, _) {}, regions: () => never);
    await tester.tap(find.byKey(const Key('pickRegion')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  for (final locale in [const Locale('fr'), const Locale('ar')]) {
    testWidgets('200 % text, ${locale.languageCode}: no overflow', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        locale: locale,
        textScale: 2,
        size: const Size(360, 640),
        regionCode: '68',
        localityId: 2820,
        onChanged: (_, _) {},
      );
      expect(tester.takeException(), isNull);
      await openRegions(tester);
      await tester.enterText(
        find.byKey(const Key('pickerSearch')),
        'bou saada',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('option_68')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
