import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final brand = Brand.fromJson(await rootBundle.loadString('assets/brand/brand.json'));
  runApp(LetterApp(brand: brand));
}

class LetterApp extends StatelessWidget {
  const LetterApp({super.key, required this.brand});

  final Brand brand;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: brand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: brand.primary)),
      home: SplashScreen(brand: brand),
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
            Text(brand.name, style: TextStyle(color: brand.accent, fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
