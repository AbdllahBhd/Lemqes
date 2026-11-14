import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

const Locale _french = Locale('fr');

/// Flutter ships no Kabyle strings; these delegates make `kab` resolve to the
/// French framework strings (and LTR) instead of throwing.
class _KabMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _KabMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'kab';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_french);

  @override
  bool shouldReload(_KabMaterialDelegate old) => false;
}

class _KabCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KabCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'kab';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_french);

  @override
  bool shouldReload(_KabCupertinoDelegate old) => false;
}

class _KabWidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _KabWidgetsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'kab';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const DefaultWidgetsLocalizations());

  @override
  bool shouldReload(_KabWidgetsDelegate old) => false;
}

const LocalizationsDelegate<MaterialLocalizations> kabMaterialDelegate =
    _KabMaterialDelegate();
const LocalizationsDelegate<CupertinoLocalizations> kabCupertinoDelegate =
    _KabCupertinoDelegate();
const LocalizationsDelegate<WidgetsLocalizations> kabWidgetsDelegate =
    _KabWidgetsDelegate();
