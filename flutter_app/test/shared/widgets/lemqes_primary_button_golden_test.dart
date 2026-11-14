import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/shared/widgets/lemqes_primary_button.dart';

import 'golden_host.dart';

const _labels = {'fr': 'Je suis en route', 'ar': 'استدعاء التالية'};
const _states = ['enabled', 'pressed', 'disabled', 'loading', 'focused'];

Widget _sheet(String label) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final state in _states) ...[
          LemqesPrimaryButton(
            key: ValueKey(state),
            label: label,
            icon: Icons.directions_walk,
            loading: state == 'loading',
            onPressed: state == 'disabled' ? null : () {},
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}

void main() {
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final v in goldenVariants) {
    testWidgets('LemqesPrimaryButton states ${goldenName(v)}', (tester) async {
      tester.view.physicalSize = const Size(320, 400) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      // flutter_test flattens shadows by default; the soft shadow is the design.
      // Restored in `finally`, not addTearDown: the binding checks painting
      // debug vars before tear-downs run.
      debugDisableShadows = false;
      try {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        const key = ValueKey('sheet');

        await tester.pumpWidget(
          goldenHost(
            v,
            key: key,
            child: _sheet(_labels[v.locale.languageCode]!),
          ),
        );

        Focus.of(
          tester.element(
            find.descendant(
              of: find.byKey(const ValueKey('focused')),
              matching: find.byType(Text),
            ),
          ),
        ).requestFocus();
        final press = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('pressed'))),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'goldens/lemqes_primary_button_${goldenName(v)}.png',
          ),
        );
        await press.up();
        await tester.pump();
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  testWidgets('is at least 48 dp tall and calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      goldenHost(
        goldenVariants.first,
        key: const ValueKey('host'),
        child: LemqesPrimaryButton(label: 'Go', onPressed: () => taps++),
      ),
    );

    expect(
      tester.getSize(find.byType(LemqesPrimaryButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testWidgets('loading keeps the label and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      goldenHost(
        goldenVariants.first,
        key: const ValueKey('host'),
        child: LemqesPrimaryButton(
          label: 'Go',
          icon: Icons.check,
          loading: true,
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.text('Go'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(taps, 0);
  });

  testWidgets('is disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(
      goldenHost(
        goldenVariants.first,
        key: const ValueKey('host'),
        child: const LemqesPrimaryButton(label: 'Go', onPressed: null),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
