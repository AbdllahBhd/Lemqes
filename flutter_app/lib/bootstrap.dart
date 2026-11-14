import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/l10n/intl_locale.dart';
import 'core/l10n/locale_controller.dart';
import 'core/storage/shared_preferences_provider.dart';

/// Starts Supabase and loads the preferences the first frame reads; shared by
/// `main` and the integration test so both run the same wiring.
Future<SharedPreferences> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  final prefs = await SharedPreferences.getInstance();
  await ensureDateFormatting(localeFromPrefs(prefs));
  return prefs;
}

/// The app with its preloaded preferences.
Widget lemqesRoot(SharedPreferences prefs) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: const LemqesApp(),
);
