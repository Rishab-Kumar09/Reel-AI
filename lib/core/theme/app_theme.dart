import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color errorColor = Color(0xFFCF6679);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xB3FFFFFF); // 70% white

  // Text Styles
  static final TextStyle headlineLarge = GoogleFonts.roboto(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.25,
  );

  static final TextStyle headlineMedium = GoogleFonts.roboto(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.25,
  );

  static final TextStyle headlineSmall = GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.25,
  );

  static final TextStyle titleLarge = GoogleFonts.roboto(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static final TextStyle titleMedium = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static final TextStyle titleSmall = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static final TextStyle bodyLarge = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static final TextStyle bodyMedium = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static final TextStyle bodySmall = GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Colors.white,
      background: Colors.grey[100]!,
      error: errorColor,
    ),
    scaffoldBackgroundColor: Colors.grey[100],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      titleTextStyle: titleLarge.copyWith(color: Colors.black),
    ),
    textTheme: TextTheme(
      headlineLarge: headlineLarge.copyWith(color: Colors.black),
      headlineMedium: headlineMedium.copyWith(color: Colors.black),
      headlineSmall: headlineSmall.copyWith(color: Colors.black),
      titleLarge: titleLarge.copyWith(color: Colors.black),
      titleMedium: titleMedium.copyWith(color: Colors.black),
      titleSmall: titleSmall.copyWith(color: Colors.black),
      bodyLarge: bodyLarge.copyWith(color: Colors.black87),
      bodyMedium: bodyMedium.copyWith(color: Colors.black87),
      bodySmall: bodySmall.copyWith(color: Colors.black87),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      background: backgroundColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: titleLarge.copyWith(color: Colors.white),
    ),
    textTheme: TextTheme(
      headlineLarge: headlineLarge.copyWith(color: Colors.white),
      headlineMedium: headlineMedium.copyWith(color: Colors.white),
      headlineSmall: headlineSmall.copyWith(color: Colors.white),
      titleLarge: titleLarge.copyWith(color: Colors.white),
      titleMedium: titleMedium.copyWith(color: Colors.white),
      titleSmall: titleSmall.copyWith(color: Colors.white),
      bodyLarge: bodyLarge.copyWith(color: Colors.white70),
      bodyMedium: bodyMedium.copyWith(color: Colors.white70),
      bodySmall: bodySmall.copyWith(color: Colors.white70),
    ),
  );
}
