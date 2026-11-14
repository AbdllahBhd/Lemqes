import 'package:material_ui/material_ui.dart';
import 'package:lemqes/core/theme/lemqes_theme.dart';

/// One golden variant: a theme brightness and a locale with its direction.
typedef GoldenVariant = ({Brightness brightness, Locale locale});

const List<GoldenVariant> goldenVariants = [
  (brightness: Brightness.light, locale: Locale('fr')),
  (brightness: Brightness.light, locale: Locale('ar')),
  (brightness: Brightness.dark, locale: Locale('fr')),
  (brightness: Brightness.dark, locale: Locale('ar')),
];

String goldenName(GoldenVariant v) =>
    '${v.brightness == Brightness.dark ? 'dark' : 'light'}_${v.locale.languageCode}';

Widget goldenHost(GoldenVariant v, {required Key key, required Widget child}) {
  final rtl = v.locale.languageCode == 'ar';
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: lemqesTheme(v.brightness),
    home: Builder(
      builder: (context) => Localizations.override(
        context: context,
        locale: v.locale,
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: key,
                // Captured with the scaffold ground so dark goldens read true.
                child: Builder(
                  builder: (context) => ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
