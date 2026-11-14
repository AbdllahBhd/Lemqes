import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system', () async {
    final container = _container();
    await container.read(themeModeProvider.notifier).loaded;
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('setMode persists and a fresh container reads it back', () async {
    final first = _container();
    await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(first.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');

    final fresh = _container();
    await fresh.read(themeModeProvider.notifier).loaded;
    expect(fresh.read(themeModeProvider), ThemeMode.dark);
  });

  test('an unknown stored value falls back to system', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final container = _container();
    await container.read(themeModeProvider.notifier).loaded;
    expect(container.read(themeModeProvider), ThemeMode.system);
  });
}
