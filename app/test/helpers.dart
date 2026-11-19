import 'package:material_ui/material_ui.dart';
import 'package:letter_signing/l10n/app_locale.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

/// A Persian (RTL) app shell for widget tests.
Widget faApp(Widget home) => MaterialApp(
  locale: appLocale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: Scaffold(body: home),
);

/// A Persian (RTL) `MaterialApp` whose [home] brings its own Scaffold.
Widget faMaterial({required Widget home}) => MaterialApp(
  locale: appLocale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: home,
);
