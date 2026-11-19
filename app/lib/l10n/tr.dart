import 'package:letter_signing/l10n/app_locale.dart';
import 'package:letter_signing/l10n/app_localizations.dart';

/// Context-free access to the app strings (the app is Persian-only), for
/// validators, constants and helpers that have no BuildContext.
AppLocalizations get tr => lookupAppLocalizations(appLocale);
