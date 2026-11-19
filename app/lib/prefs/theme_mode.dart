import 'package:material_ui/material_ui.dart';

/// The app-wide theme mode. `main.dart` listens to it; `PrefsController` sets it from
/// `/me/prefs` after sign-in and whenever the user changes the setting.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);
