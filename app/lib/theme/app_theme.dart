import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/brand.dart';

/// Design tokens shared by every screen. Colours come from the brand (brand.json); state colours are fixed.
class Tokens {
  const Tokens._();
  static const ok = Color(0xFF4CD8B9);
  static const error = Color(0xFFD65959);
  static const warn = Color(0xFFCFA44B);
  static const radius = 16.0;
  static const radiusSmall = 12.0;
  static const gap = 16.0;
  static const maxContentWidth = 760.0;
}

/// The branded look: deep brand-dark surfaces with an accent, in light and dark variants.
class AppTheme {
  const AppTheme._();

  /// Vazirmatn (SIL OFL). TODO: bundle the TTF files under assets/fonts and declare them in
  /// pubspec; until then the platform's Persian fallback font is used.
  static const fontFamily = 'Vazirmatn';

  static ThemeData dark(Brand brand) {
    final surface = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.06),
      brand.dark,
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: Color.lerp(brand.primary, Colors.white, 0.18),
          onPrimary: Colors.white,
          secondary: brand.accent,
          onSecondary: brand.dark,
          tertiary: Tokens.ok,
          error: Tokens.error,
          surface: brand.dark,
          onSurface: const Color(0xFFE9EEF7),
          surfaceContainerLowest: brand.dark,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: Color.alphaBlend(
            Colors.white.withValues(alpha: 0.10),
            brand.dark,
          ),
          outlineVariant: Colors.white.withValues(alpha: 0.12),
        );
    return _build(scheme, brand);
  }

  static ThemeData light(Brand brand) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: brand.primary,
          secondary: brand.accent,
          tertiary: const Color(0xFF1E9E86),
          error: Tokens.error,
          surface: const Color(0xFFF6F7FB),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: const Color(0xFFEFF2F8),
        );
    return _build(scheme, brand);
  }

  static ThemeData _build(ColorScheme s, Brand brand) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSmall),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSmall),
      borderSide: BorderSide(color: s.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: s,
      scaffoldBackgroundColor: s.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: s.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: s.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radius),
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surfaceContainerLow,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: s.primary, width: 1.6),
        ),
        errorBorder: border.copyWith(borderSide: BorderSide(color: s.error)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: s.outlineVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
        backgroundColor: s.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: s.onSurface),
      ),
      listTileTheme: ListTileThemeData(shape: shape),
      dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: s.surfaceContainerLow,
        indicatorColor: s.primary.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: s.surfaceContainerLow,
        indicatorColor: s.primary.withValues(alpha: 0.2),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.secondary,
        foregroundColor: s.onSecondary,
        shape: shape,
      ),
    );
  }
}
