import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_ar.dart';
import 'package:lemqes/core/l10n/gen/app_localizations_fr.dart';
import 'package:lemqes/features/account/data/account.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:lemqes/features/pro/presentation/edit/service_editor.dart';
import 'package:material_ui/material_ui.dart';

import '../../../auth/presentation/harness.dart' show byKey, fieldText;
import '../pro_test_host.dart';

const _preset = ServicePreset(
  key: 'men_cut',
  space: Space.men,
  home: false,
  category: ServiceCategory.hair,
  nameAr: 'قصة شعر',
  nameFr: 'Coupe homme',
  nameEn: "Men's haircut",
  nameKab: 'Tukksa n uzar',
  defaultPriceDzd: 600,
  defaultDurationMin: 30,
  sort: 1,
);

const _categories = [ServiceCategory.hair, ServiceCategory.beard];

void main() {
  final fr = AppLocalizationsFr();
  final ar = AppLocalizationsAr();

  late List<ProServiceDraft> saved;
  late int removed;

  setUp(() {
    saved = [];
    removed = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    ServicePreset? preset,
    ProService? existing,
    Locale locale = const Locale('fr'),
  }) => pumpLocalized(
    tester,
    ServiceEditor(
      preset: preset,
      existing: existing,
      categories: _categories,
      onSaved: saved.add,
      onRemove: existing == null ? null : () => removed++,
    ),
    locale: locale,
  );

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(byKey('serviceSave'));
    await tester.tap(byKey('serviceSave'));
    await tester.pump();
  }

  Future<void> typePrice(WidgetTester tester, String text) =>
      tester.enterText(byKey('servicePriceField'), text);

  testWidgets('a preset opens with its price and duration', (tester) async {
    await pump(tester, preset: _preset);
    expect(find.text('Coupe homme'), findsOneWidget);
    expect(fieldText(tester, 'servicePriceField'), '600');
    expect(fieldText(tester, 'serviceDurationField'), '30');
    expect(byKey('serviceNameField'), findsNothing);

    await save(tester);
    final d = saved.single;
    expect(d.presetKey, 'men_cut');
    expect(d.customName, isNull);
    expect(d.category, ServiceCategory.hair);
    expect(d.priceDzd, 600);
    expect(d.durationMin, 30);
    expect(d.active, isTrue);
  });

  testWidgets('Eastern Arabic digits are saved and shown back in Latin', (
    tester,
  ) async {
    await pump(tester, preset: _preset, locale: const Locale('ar'));
    await typePrice(tester, '١٥٠٠');
    await tester.enterText(byKey('serviceDurationField'), '٤٥');
    await save(tester);

    expect(saved.single.priceDzd, 1500);
    expect(saved.single.durationMin, 45);
    expect(fieldText(tester, 'servicePriceField'), '1500');
    expect(fieldText(tester, 'serviceDurationField'), '45');
    expect(find.text(ar.servicePriceInvalid), findsNothing);
  });

  testWidgets('spaces between thousands are accepted', (tester) async {
    await pump(tester, preset: _preset);
    await typePrice(tester, '1 500');
    await save(tester);
    expect(saved.single.priceDzd, 1500);
  });

  testWidgets('a price of 0 is a free service, not an error', (tester) async {
    await pump(tester, preset: _preset);
    await typePrice(tester, '0');
    await save(tester);
    expect(saved.single.priceDzd, 0);
  });

  testWidgets('an empty price asks for one and saves nothing', (tester) async {
    await pump(tester, preset: _preset);
    await typePrice(tester, '');
    await save(tester);
    expect(find.text(fr.servicePriceRequired), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('a price over 200 000 DA is refused with the range', (
    tester,
  ) async {
    await pump(tester, preset: _preset);
    await typePrice(tester, '999999');
    await save(tester);
    expect(find.text(fr.servicePriceInvalid), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('a decimal price is refused', (tester) async {
    await pump(tester, preset: _preset);
    await typePrice(tester, '12.5');
    await save(tester);
    expect(find.text(fr.servicePriceInvalid), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('4 minutes is refused, 5 is accepted', (tester) async {
    await pump(tester, preset: _preset);
    await tester.enterText(byKey('serviceDurationField'), '4');
    await save(tester);
    expect(find.text(fr.serviceDurationInvalid), findsOneWidget);
    expect(saved, isEmpty);

    await tester.enterText(byKey('serviceDurationField'), '5');
    await save(tester);
    expect(find.text(fr.serviceDurationInvalid), findsNothing);
    expect(saved.single.durationMin, 5);
  });

  testWidgets('an empty duration asks for one', (tester) async {
    await pump(tester, preset: _preset);
    await tester.enterText(byKey('serviceDurationField'), '');
    await save(tester);
    expect(find.text(fr.serviceDurationRequired), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('a custom service needs a name and keeps its category', (
    tester,
  ) async {
    await pump(tester);
    expect(fieldText(tester, 'servicePriceField'), '');
    await typePrice(tester, '800');
    await tester.enterText(byKey('serviceDurationField'), '20');
    await save(tester);
    expect(find.text(fr.serviceNameRequired), findsOneWidget);
    expect(saved, isEmpty);

    await tester.enterText(byKey('serviceNameField'), '  Rasage à l’ancienne ');
    await tester.tap(byKey('category_beard'));
    await tester.pump();
    await save(tester);

    final d = saved.single;
    expect(d.presetKey, isNull);
    expect(d.customName, 'Rasage à l’ancienne');
    expect(d.category, ServiceCategory.beard);
    expect(d.priceDzd, 800);
    expect(d.durationMin, 20);
  });

  testWidgets('a one-letter custom name is refused', (tester) async {
    await pump(tester);
    await tester.enterText(byKey('serviceNameField'), 'A');
    await typePrice(tester, '800');
    await tester.enterText(byKey('serviceDurationField'), '20');
    await save(tester);
    expect(find.text(fr.serviceNameLength), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('editing keeps the id and can pause or remove the service', (
    tester,
  ) async {
    await pump(
      tester,
      preset: _preset,
      existing: const ProService(
        id: 's1',
        presetKey: 'men_cut',
        category: ServiceCategory.hair,
        priceDzd: 700,
        durationMin: 40,
      ),
    );
    expect(fieldText(tester, 'servicePriceField'), '700');
    await tester.ensureVisible(byKey('serviceActiveSwitch'));
    await tester.tap(byKey('serviceActiveSwitch'));
    await tester.pump();
    await save(tester);
    expect(saved.single.id, 's1');
    expect(saved.single.active, isFalse);

    await tester.ensureVisible(byKey('serviceRemove'));
    await tester.tap(byKey('serviceRemove'));
    await tester.pump();
    expect(removed, 1);
  });

  testWidgets('200 % text in Arabic does not overflow', (tester) async {
    await pumpLocalized(
      tester,
      ServiceEditor(categories: _categories, onSaved: saved.add),
      locale: const Locale('ar'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
