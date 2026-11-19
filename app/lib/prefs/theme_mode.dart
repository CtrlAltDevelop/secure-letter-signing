import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// The app-wide theme mode. `main.dart` listens to it; `PrefsController` sets it from
/// `/me/prefs` after sign-in and whenever the user changes the setting.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);

/// The signed-in user's dashboard background image (null = none). `main.dart` paints it
/// behind every screen; `PrefsController` sets it after sign-in and on change.
final ValueNotifier<Uint8List?> appBackground = ValueNotifier(null);

/// How opaque screens stay over the background image (readability).
const double backgroundScrimOpacity = 0.9;
