import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF90CAF9);
  static const Color accent = Color(0xFFF57C00);

  // Light theme
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightOnSurface = Color(0xFF1A1A2E);

  static const Color fosaGreen = Color(0xFF00695C);
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkOnSurface = Color(0xFFE6EDF3);

  // ── Loan category colors (semantic, theme-aware via extension) ────────────
  // BOSA loans — deep blue (trust, savings)
  static const Color loanBosa = Color(0xFF1565C0);
  // Salary advances — teal (FOSA brand)
  static const Color loanSalary = Color(0xFF00695C);
  // Special products — deep purple (premium)
  static const Color loanSpecial = Color(0xFF6A1B9A);
  // Loan history — amber/orange (records)
  static const Color loanHistory = Color(0xFFE65100);
  // Repayments — green (positive action)
  static const Color loanRepayment = Color(0xFF2E7D32);

  // ── Status colors ─────────────────────────────────────────────────────────
  static const Color statusPending = Color(0xFFF57C00);
  static const Color statusApproved = Color(0xFF1565C0);
  static const Color statusDisbursed = Color(0xFF2E7D32);
  static const Color statusRejected = Color(0xFFC62828);
  static const Color statusRepaid = Color(0xFF00695C);
  static const Color statusDefaulted = Color(0xFFBF360C);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.lightSurface,
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightOnSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: AppColors.darkSurface,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkOnSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  // Keep for any legacy references
  static ThemeData get theme => light;
}
