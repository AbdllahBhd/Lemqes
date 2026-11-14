import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/lemqes_tokens.dart';
import 'package:lemqes/shared/widgets/lagoon_header_band.dart';

import 'golden_host.dart';

const _copy = {
  'fr': (place: 'Kouba, Alger', search: 'Rechercher un salon ou un service'),
  'ar': (place: 'القبة، الجزائر', search: 'ابحث عن صالون أو خدمة'),
};

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: LemqesShape.cardShadow,
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                hint,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  for (final v in goldenVariants) {
    testWidgets('LagoonHeaderBand ${goldenName(v)}', (tester) async {
      tester.view.physicalSize = const Size(390, 200) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      // flutter_test flattens shadows by default; the soft shadow is the design.
      debugDisableShadows = false;
      final copy = _copy[v.locale.languageCode]!;
      const key = ValueKey('band');

      await tester.pumpWidget(
        goldenHost(
          v,
          key: key,
          child: SizedBox(
            height: 200,
            child: Builder(
              builder: (context) => LagoonHeaderBand(
                overlap: _SearchField(hint: copy.search),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 36, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'LEMQES',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 18 * 0.16,
                            ),
                      ),
                      const Spacer(),
                      const Icon(Icons.place_outlined, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        copy.place,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/lagoon_header_band_${goldenName(v)}.png'),
      );
      debugDisableShadows = true;
    });
  }

  testWidgets('overlap straddles the band edge', (tester) async {
    const band = Key('band');
    const overlap = Key('overlap');
    await tester.pumpWidget(
      goldenHost(
        goldenVariants.first,
        key: band,
        child: const LagoonHeaderBand(
          height: 150,
          overlap: SizedBox(key: overlap, height: 48, width: 200),
          child: SizedBox.shrink(),
        ),
      ),
    );

    final bandTop = tester.getTopLeft(find.byKey(band)).dy;
    final overlapRect = tester.getRect(find.byKey(overlap));
    expect(overlapRect.top - bandTop, lessThan(150));
    expect(overlapRect.bottom - bandTop, greaterThan(150));
    expect(tester.getSize(find.byKey(band)).height, overlapRect.bottom);
  });
}
