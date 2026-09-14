import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const ink = Color(0xFF121418);
  static const inkElevated = Color(0xFF1C2129);
  static const inkSoft = Color(0xFF252B36);
  static const hairline = Color(0xFF3A4254);
  static const gold = Color(0xFFD4B06A);
  static const goldDeep = Color(0xFF9A7030);
  static const paper = Color(0xFFF3E6C8);
  static const paperShadow = Color(0xFF2A2114);
  static const parchment = Color(0xFFE7D3A2);
  static const mist = Color(0xFF9AA3B5);
  static const cream = Color(0xFFF7F1E3);
  static const danger = Color(0xFFD4655C);
  static const success = Color(0xFF6FBF9A);
  static const warning = Color(0xFFE0A257);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.ink,
        secondary: AppColors.parchment,
        surface: AppColors.inkElevated,
        onSurface: AppColors.cream,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.ink,
    );

    final display = GoogleFonts.frauncesTextTheme(base.textTheme).apply(
      bodyColor: AppColors.cream,
      displayColor: AppColors.paper,
    );
    final body = GoogleFonts.sourceSans3TextTheme(display);

    return base.copyWith(
      textTheme: body.copyWith(
        displaySmall: GoogleFonts.fraunces(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: AppColors.paper,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.paper,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.paper,
        ),
        titleMedium: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.cream,
        ),
        bodyMedium: GoogleFonts.sourceSans3(
          fontSize: 15,
          height: 1.35,
          color: AppColors.cream,
        ),
        labelLarge: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.paper,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.inkElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.ink,
      ),
      dividerColor: AppColors.hairline,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inkSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkSoft,
        contentTextStyle: GoogleFonts.sourceSans3(color: AppColors.cream),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.inkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkElevated,
        showDragHandle: true,
      ),
    );
  }
}
