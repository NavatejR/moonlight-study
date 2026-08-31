import 'package:flutter/material.dart';

import 'colors.dart';

/// Moonlight Study design tokens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double radius = 20;
  static const double radiusLg = 28;
}

/// Theme entrypoint for the whole app. Uses [CoffeeColors].
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: CoffeeColors.caramel,
      onPrimary: CoffeeColors.paper,
      secondary: CoffeeColors.sage,
      onSecondary: Colors.white,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: isLight ? CoffeeColors.paper : CoffeeColors.espresso,
      onSurface: isLight ? CoffeeColors.espresso : CoffeeColors.foam,
      surfaceContainerHighest:
          isLight ? CoffeeColors.latte : CoffeeColors.mocha,
      onSurfaceVariant: isLight ? CoffeeColors.cacao : const Color(0xFFC3AE97),
      outline: isLight ? const Color(0xFFD8C6AF) : const Color(0xFF4A3826),
      outlineVariant: isLight ? CoffeeColors.latte : CoffeeColors.mocha,
      shadow: Colors.black38,
      scrim: Colors.black54,
      inverseSurface: isLight ? CoffeeColors.espresso : CoffeeColors.foam,
      onInverseSurface: isLight ? CoffeeColors.foam : CoffeeColors.espresso,
      inversePrimary: CoffeeColors.amber,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? CoffeeColors.crema : CoffeeColors.warmDark,
      fontFamily: 'WorkSans',
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? CoffeeColors.paper : CoffeeColors.espresso,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: const BorderSide(color: CoffeeColors.caramel, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CoffeeColors.espresso,
          foregroundColor: CoffeeColors.foam,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor:
            isLight ? CoffeeColors.paper : CoffeeColors.espresso,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CoffeeColors.espresso,
        foregroundColor: CoffeeColors.foam,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? CoffeeColors.paper : CoffeeColors.espresso,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}