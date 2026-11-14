import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/config/env.dart';

void main() {
  test('assertConfigured throws when the dart-defines are empty', () {
    expect(
      Env.assertConfigured,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Missing SUPABASE_URL / SUPABASE_ANON_KEY: run with '
              '--dart-define-from-file=env/local.json',
        ),
      ),
    );
  });
}
