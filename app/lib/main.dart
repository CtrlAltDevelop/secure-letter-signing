import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/l10n/app_locale.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/prefs/theme_mode.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/home_screen.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/no_scrollbar_behavior.dart';
import 'package:letter_signing/theme/widgets.dart';

import 'brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final brand = Brand.fromJson(
    await rootBundle.loadString('assets/brand/brand.json'),
  );
  final auth = AuthController(
    ApiClient(baseUrl: brand.resolvedApiUrl(), store: const SecureTokenStore()),
  );
  runApp(LetterApp(brand: brand, auth: auth));
}

class LetterApp extends StatefulWidget {
  const LetterApp({super.key, required this.brand, required this.auth});

  final Brand brand;
  final AuthController auth;

  @override
  State<LetterApp> createState() => _LetterAppState();
}

class _LetterAppState extends State<LetterApp> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      await widget.auth.restore();
    } on Exception {
      // Offline or server down at launch: fall through to the sign-in screen.
    }
    if (mounted) {
      setState(() {
        _restoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => _app(auth, mode),
    );
  }

  Widget _app(AuthController auth, ThemeMode mode) {
    return MaterialApp(
      title: widget.brand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(widget.brand),
      darkTheme: AppTheme.dark(widget.brand),
      themeMode: mode,
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      scrollBehavior: const NoScrollbarBehavior(),
      home: _restoring
          ? SplashScreen(brand: widget.brand)
          : ListenableBuilder(
              listenable: auth,
              builder: (context, _) => auth.user == null
                  ? LoginScreen(auth: auth)
                  : HomeScreen(auth: auth),
            ),
    );
  }
}

/// Shown while the saved session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.brand});

  final Brand brand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brand.dark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 96),
            const SizedBox(height: 20),
            Text(
              brand.name,
              style: TextStyle(
                color: brand.accent,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: brand.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
