import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de cor do Naipe. Ajuste aqui para mudar a paleta do app inteiro.
class AppColors {
  // Surfaces (claro)
  static const canvas = Color(0xFFF7F5FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0ECF8);
  static const hairline = Color(0xFFDDD4EF);

  // Marca (roxo)
  static const primary = Color(0xFF6B4EFF);
  static const primaryDeep = Color(0xFF4A2FD4);
  static const primarySoft = Color(0xFFECE6FF);

  // Texto
  static const ink = Color(0xFF1A1428);
  static const muted = Color(0xFF6E6680);

  // Face da carta (papel físico — independente do chrome do app)
  static const paper = Color(0xFFFFFCF8);
  static const paperShadow = Color(0xFF3D2F5C);
  static const paperBorder = Color(0xFFB8A8D9);
  static const parchment = Color(0xFFF3EEF9);

  // Mesa / preview
  static const table = Color(0xFFE8E2F4);

  // Feedback
  static const danger = Color(0xFFD4655C);
  static const success = Color(0xFF2F9E75);
  static const warning = Color(0xFFE0A257);

  // Aliases usados pelas telas (apontam para os tokens acima)
  static const gold = primary;
  static const goldDeep = paperBorder;
  static const cream = ink;
  static const mist = muted;
  static const inkElevated = surface;
  static const inkSoft = surfaceMuted;
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryDeep,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
    );

    final display = GoogleFonts.frauncesTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    final body = GoogleFonts.sourceSans3TextTheme(display);

    return base.copyWith(
      textTheme: body.copyWith(
        displaySmall: GoogleFonts.fraunces(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyMedium: GoogleFonts.sourceSans3(
          fontSize: 15,
          height: 1.35,
          color: AppColors.ink,
        ),
        labelLarge: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      dividerColor: AppColors.hairline,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.sourceSans3(color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primarySoft,
        checkmarkColor: AppColors.primaryDeep,
        labelStyle: GoogleFonts.sourceSans3(color: AppColors.ink),
        side: const BorderSide(color: AppColors.hairline),
      ),
    );
  }
}
