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

  // ── Per-loan-type colors (each product gets a distinct gradient pair) ────────
  static const Map<String, List<Color>> loanTypeColors = {
    'normal':           [Color(0xFF1565C0), Color(0xFF1E88E5)], // blue
    'jumbo':            [Color(0xFF4A148C), Color(0xFF7B1FA2)], // deep purple
    'bima':             [Color(0xFF00695C), Color(0xFF00897B)], // teal
    'premier':          [Color(0xFF1A237E), Color(0xFF283593)], // indigo
    'super':            [Color(0xFF880E4F), Color(0xFFC2185B)], // pink
    'mega':             [Color(0xFF0D47A1), Color(0xFF1565C0)], // dark blue
    'refinancing':      [Color(0xFF004D40), Color(0xFF00695C)], // dark teal
    'emergency':        [Color(0xFFB71C1C), Color(0xFFD32F2F)], // red
    'school_fees':      [Color(0xFF1B5E20), Color(0xFF2E7D32)], // green
    'asset_financing':  [Color(0xFFE65100), Color(0xFFF57C00)], // orange
    'muslim':           [Color(0xFF33691E), Color(0xFF558B2F)], // light green
    'muslim_emergency': [Color(0xFF827717), Color(0xFFF9A825)], // amber
    'msasa':            [Color(0xFF006064), Color(0xFF00838F)], // cyan
    'fosa_flex':        [Color(0xFF01579B), Color(0xFF0277BD)], // light blue
    'fosa_golden':      [Color(0xFFF57F17), Color(0xFFFFA000)], // amber/gold
    'fosa_ultra':       [Color(0xFF4E342E), Color(0xFF6D4C41)], // brown
    'qcash':            [Color(0xFF311B92), Color(0xFF4527A0)], // deep purple
    'dividend_advance': [Color(0xFF1A237E), Color(0xFF3949AB)], // indigo
  };

  static List<Color> colorsForLoanType(String loanType) =>
      loanTypeColors[loanType] ?? [loanBosa, loanBosa.withAlpha(190)];

  // ── Active loan banner (dark navy — distinct from all category colors) ───────
  static const Color activeLoanBanner = Color(0xFF0D1B2A);
  static const Color activeLoanBannerEnd = Color(0xFF1B3A4B);
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
