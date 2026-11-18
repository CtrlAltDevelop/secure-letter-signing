import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/api/auth_controller.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/screens/home_screen.dart';

import 'brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final brand = Brand.fromJson(
    await rootBundle.loadString('assets/brand/brand.json'),
  );
  final auth = AuthController(
    ApiClient(baseUrl: brand.apiUrl, store: const SecureTokenStore()),
  );
  try {
    await auth.restore();
  } on Exception {
    // Offline or server down at launch: fall through to the sign-in screen.
  }
  runApp(LetterApp(brand: brand, auth: auth));
}

class LetterApp extends StatelessWidget {
  const LetterApp({super.key, required this.brand, required this.auth});

  final Brand brand;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: brand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand.primary),
      ),
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => auth.user == null
            ? LoginScreen(auth: auth)
            : HomeScreen(auth: auth),
      ),
    );
  }
}

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
            SvgPicture.asset('assets/brand/logo.svg', width: 96, height: 96),
            const SizedBox(height: 16),
            Text(
              brand.name,
              style: TextStyle(color: brand.accent, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
