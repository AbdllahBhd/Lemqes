import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/gen/app_localizations.dart';
import 'core/l10n/kab_fallback_delegates.dart';
import 'core/l10n/locale_controller.dart';
import 'core/theme/lemqes_theme.dart';
import 'core/theme/theme_mode_controller.dart';

const appDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  kabMaterialDelegate,
  kabCupertinoDelegate,
  kabWidgetsDelegate,
  ...GlobalMaterialLocalizations.delegates,
];

class LemqesApp extends ConsumerWidget {
  const LemqesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LEMQES',
      theme: lemqesTheme(Brightness.light),
      darkTheme: lemqesTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: appDelegates,
      supportedLocales: supportedLocales,
      home: const Scaffold(body: Center(child: Text('LEMQES'))),
    );
  }
}
