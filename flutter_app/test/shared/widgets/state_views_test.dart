import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';
import 'package:lemqes/shared/widgets/state_views.dart';

Widget _host(Widget child) => MaterialApp(
  theme: lemqesTheme(Brightness.light),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('ErrorView retry tap calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        ErrorView(
          message: 'No connection',
          retryLabel: 'Retry',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.text('No connection'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('EmptyView renders title, body and its action', (tester) async {
    await tester.pumpWidget(
      _host(
        EmptyView(
          title: 'Nothing yet',
          body: 'Bookings appear here.',
          action: TextButton(onPressed: () {}, child: const Text('Explore')),
        ),
      ),
    );

    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Bookings appear here.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Explore'), findsOneWidget);
  });

  testWidgets('LoadingView shows a labelled progress indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const LoadingView(label: 'Loading')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('EmptyView shows its icon', (tester) async {
    await tester.pumpWidget(
      _host(const EmptyView(icon: Icons.storefront_outlined, title: 'Soon')),
    );
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });
}
