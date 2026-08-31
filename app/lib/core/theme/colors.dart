import 'package:flutter/material.dart';

/// Moonlight Study — coffee + lofi color palette.
///
/// Inspired by slow mornings: espresso, crema, caramel, and sage.
class CoffeeColors {
  CoffeeColors._();

  // Cream / paper base
  static const Color crema = Color(0xFFF7F0E6);
  static const Color paper = Color(0xFFFFFBF5);
  static const Color latte = Color(0xFFEBDDC9);

  // Espresso family (text / dark surfaces)
  static const Color espresso = Color(0xFF2E2014);
  static const Color mocha = Color(0xFF4A3826);
  static const Color cacao = Color(0xFF6F5A44);

  // Accents
  static const Color caramel = Color(0xFFC08A55);
  static const Color amber = Color(0xFFE0A96D);
  static const Color coffee = Color(0xFF9C6F44);
  static const Color sage = Color(0xFF8FA57F);
  static const Color moss = Color(0xFF5F7254);

  // Warm neutrals
  static const Color warmDark = Color(0xFF241A11);
  static const Color foam = Color(0xFFF4EDE2);

  // Vibe accents
  static const Color vinyl = Color(0xFF17130F);
  static const Color vinylLabel = Color(0xFFC79A6B);
}

/// Convenience gradient used across cards and hero areas.
class CoffeeGradients {
  CoffeeGradients._();

  static const LinearGradient latteSunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBF5EA), Color(0xFFF0E3D0), Color(0xFFEAD9C2)],
  );

  static const LinearGradient espressoDusk = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A2A1B), Color(0xFF2E2014), Color(0xFF241A11)],
  );

  static const LinearGradient caramelGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0A96D), Color(0xFFC08A55), Color(0xFF9C6F44)],
  );

  static const LinearGradient mossGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9FB08F), Color(0xFF8FA57F), Color(0xFF5F7254)],
  );
}