import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// The user's light / dark / system choice, persisted on the device.
class ThemeModeController extends Notifier<ThemeMode> {
  static const String prefsKey = 'theme_mode';

  /// Completes once the stored choice (if any) has been applied.
  late Future<void> loaded;

  bool _chosenThisSession = false;

  @override
  ThemeMode build() {
    _chosenThisSession = false;
    loaded = _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _parse(prefs.getString(prefsKey));
    // A choice made while prefs were loading wins over the stored one.
    if (!ref.mounted || _chosenThisSession || stored == null) return;
    state = stored;
  }

  Future<void> setMode(ThemeMode mode) async {
    _chosenThisSession = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
  }

  static ThemeMode? _parse(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
