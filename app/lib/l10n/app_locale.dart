import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/widgets.dart' show Locale, LocalizationsDelegate;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'package:letter_signing/l10n/app_localizations.dart';

/// The app is Persian (RTL) only for now.
const appLocale = Locale('fa');

/// Delegates for the app's strings plus the Material/Cupertino/Widgets ones from
/// `material_ui` / `cupertino_ui` (the generated list points at the deprecated
/// `flutter_localizations` Material delegates, which `material_ui` does not accept).
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
