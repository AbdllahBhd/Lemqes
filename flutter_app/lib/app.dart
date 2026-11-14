import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/lemqes_theme.dart';
import 'core/theme/theme_mode_controller.dart';

class LemqesApp extends ConsumerWidget {
  const LemqesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LEMQES',
      theme: lemqesTheme(Brightness.light),
      darkTheme: lemqesTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const Scaffold(body: Center(child: Text('LEMQES'))),
    );
  }
}
