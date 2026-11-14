import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/app.dart';
import 'package:lemqes/core/supabase/supabase_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  testWidgets('LemqesApp renders a MaterialApp', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
        ],
        child: const LemqesApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
