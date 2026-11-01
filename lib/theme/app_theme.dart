import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central place for every color / gradient / text style used across the app.
/// Keeping it here means the whole app stays visually consistent and easy
/// to re-theme later.
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF0A0A0A);
  static const Color charcoal = Color(0xFF161616);
  static const Color charcoalLight = Color(0xFF1F1F1F);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF6D989);
  static const Color goldDark = Color(0xFFA8791E);

  static const Color cream = Color(0xFFF7F1E6);
  static const Color creamDark = Color(0xFFEDE3CE);

  static const Color pink = Color(0xFFE0559A);
  static const Color pinkDark = Color(0xFFC23E7E);

  static const Color textMuted = Color(0xFFB9AE99);
  static const Color success = Color(0xFF3DDC84);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDark, gold, goldLight, gold],
  );

  static const LinearGradient goldGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold, goldDark],
  );

  static const RadialGradient blackVignette = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 1.2,
    colors: [Color(0xFF1C1C1C), black],
  );
}

class AppText {
  AppText._();

  static TextStyle heading = GoogleFonts.playfairDisplay(
    color: AppColors.cream,
    fontWeight: FontWeight.w600,
  );

  static TextStyle brand = GoogleFonts.playfairDisplay(
    color: AppColors.cream,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle body = GoogleFonts.poppins(
    color: AppColors.cream,
    fontWeight: FontWeight.w400,
  );

  static TextStyle bodyMuted = GoogleFonts.poppins(
    color: AppColors.textMuted,
    fontWeight: FontWeight.w400,
  );

  static TextStyle goldLabel = GoogleFonts.poppins(
    color: AppColors.gold,
    fontWeight: FontWeight.w500,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.black,
      primaryColor: AppColors.gold,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.pink,
        surface: AppColors.charcoal,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    );
  }
}
