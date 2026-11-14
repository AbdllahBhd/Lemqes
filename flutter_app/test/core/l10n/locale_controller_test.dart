import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemqes/core/l10n/locale_controller.dart';
import 'package:lemqes/core/storage/shared_preferences_provider.dart';
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

  test('setLocale persists and a fresh container reads it back', () async {
    final first = await _container();
    await first.read(localeProvider.notifier).setLocale(const Locale('kab'));
    expect(first.read(localeProvider), const Locale('kab'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'kab');

    final fresh = await _container();
    expect(fresh.read(localeProvider), const Locale('kab'));
  });

  test(
    'an unsupported stored value falls back to a supported locale',
    () async {
      SharedPreferences.setMockInitialValues({'locale': 'xx'});
      final container = await _container();
      expect(supportedLocales, contains(container.read(localeProvider)));
    },
  );
}
