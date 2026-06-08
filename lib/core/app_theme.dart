import 'package:flutter/material.dart';

/// Olympus Gate visual identity — gold, marble white and storm blue.
class AppColors {
  AppColors._();

  static const Color gold = Color(0xFFE9B949);
  static const Color goldLight = Color(0xFFF6D873);
  static const Color goldDark = Color(0xFFB07D1E);
  static const Color stormBlue = Color(0xFF2E7DD1);
  static const Color skyBlue = Color(0xFF5FC4F5);
  static const Color marble = Color(0xFFF3F4F8);
  static const Color nightTop = Color(0xFF1B1430);
  static const Color nightBottom = Color(0xFF0B1A33);
  static const Color danger = Color(0xFFE0533D);
  static const Color heart = Color(0xFFE43B5A);
}

class AppTheme {
  AppTheme._();

  static const String displayFont = 'serif';

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.nightBottom,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.stormBlue,
        surface: AppColors.nightTop,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }

  /// Classical display text style used for headers.
  static TextStyle title(
    double size, {
    Color color = AppColors.goldLight,
    FontWeight weight = FontWeight.w900,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 1.5,
      height: 1.05,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
      ],
    );
  }

  static TextStyle body(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.3,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
      ],
    );
  }

  /// Reusable background gradient for menus.
  static const LinearGradient menuGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.nightTop, AppColors.nightBottom, Color(0xFF06101F)],
    stops: [0.0, 0.55, 1.0],
  );
}
