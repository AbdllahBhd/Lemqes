/// Build-time configuration, injected with `--dart-define-from-file=env/local.json`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The vector map style (OpenFreeMap); config, so a fallback source needs
  /// no code change. Empty: the map shows its "unavailable" background.
  static const mapStyleUrl = String.fromEnvironment('MAP_STYLE_URL');

  /// Fails fast with a fix-it message instead of an opaque Supabase error.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY: run with '
        '--dart-define-from-file=env/local.json',
      );
    }
  }
}
