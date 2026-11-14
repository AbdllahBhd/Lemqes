import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/shared_preferences_provider.dart';
import 'gen/app_localizations.dart';
import 'intl_locale.dart';

const supportedLocales = [
  Locale('ar'),
  Locale('fr'),
  Locale('en'),
  Locale('kab'),
];

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// First device language we support, else Arabic.
Locale resolveInitialLocale(List<Locale> deviceLocales) {
  for (final device in deviceLocales) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == device.languageCode) return supported;
    }
  }
  return const Locale('ar');
}

/// The stored language, else the device's, else Arabic.
Locale localeFromPrefs(SharedPreferences prefs) =>
    LocaleController._parse(prefs.getString(LocaleController.prefsKey)) ??
    resolveInitialLocale(PlatformDispatcher.instance.locales);

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// The user's language choice, persisted on the device.
class LocaleController extends Notifier<Locale> {
  static const String prefsKey = 'locale';

  @override
  Locale build() {
    final locale = localeFromPrefs(ref.watch(sharedPreferencesProvider));
    Intl.defaultLocale = intlLocaleFor(locale);
    return locale;
  }

  Future<void> setLocale(Locale locale) async {
    await ensureDateFormatting(locale);
    state = locale;
    Intl.defaultLocale = intlLocaleFor(locale);
    await ref
        .read(sharedPreferencesProvider)
        .setString(prefsKey, locale.languageCode);
  }

  static Locale? _parse(String? value) {
    for (final locale in supportedLocales) {
      if (locale.languageCode == value) return locale;
    }
    return null;
  }
}
