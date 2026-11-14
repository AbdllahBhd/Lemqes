import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// The user's language choice, persisted on the device.
class LocaleController extends Notifier<Locale> {
  static const String prefsKey = 'locale';

  @override
  Locale build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    final locale =
        _parse(stored) ??
        resolveInitialLocale(PlatformDispatcher.instance.locales);
    Intl.defaultLocale = intlLocaleFor(locale);
    return locale;
  }

  Future<void> setLocale(Locale locale) async {
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
