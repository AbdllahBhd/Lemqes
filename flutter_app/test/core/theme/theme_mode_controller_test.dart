import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
import 'package:lemqes/core/theme/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system', () async {
    final container = await _container();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('setMode persists and a fresh container reads it back', () async {
    final first = await _container();
    await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(first.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');

    final fresh = await _container();
    expect(fresh.read(themeModeProvider), ThemeMode.dark);
  });

  test('a saved mode is the first state, with no async restore', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final container = await _container();
    final states = <ThemeMode>[];
    container.listen(
      themeModeProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    await pumpEventQueue();
    expect(states, [ThemeMode.dark]);
  });

  test('an unknown stored value falls back to system', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final container = await _container();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });
}
