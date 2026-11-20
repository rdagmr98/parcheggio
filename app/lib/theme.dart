import 'package:flutter/material.dart';

/// Palette e tipografia ispirate ai cockpit automotive (tema esclusivamente scuro).
abstract final class AppColors {
  static const Color bgObsidian = Color(0xFF07080A);
  static const Color mapCanvas = Color(0xFF0B0D11);
  static const Color glassBase = Color(0xFF12151B);
  static const Color glassElevated = Color(0xFF1A1E27);
  static const Color surfaceSubtle = Color(0xFF1F242E);

  /// Accento rosso Audi (#BB0A30) usato con parsimonia.
  static const Color audiRed = Color(0xFFBB0A30);
  static const Color audiRedDark = Color(0xFF8F0724);
  static const Color audiRedBright = Color(0xFFD91E45);

  /// Blu telemetrico per la posizione attuale dell'utente.
  static const Color userBlue = Color(0xFF3B9EFF);

  /// Ambra discreta da quadro strumenti per avvisi permessi.
  static const Color warningAmber = Color(0xFFE0A040);

  static const Color textPrimary = Color(0xFFF3F5F8);
  static const Color textSecondary = Color(0xFF9CA4B2);
  static const Color textMuted = Color(0xFF6B7382);

  static Color hairline([double alpha = 0.10]) =>
      Colors.white.withValues(alpha: alpha);
}

abstract final class AppTypography {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle microLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  static const TextStyle brandBadge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.8,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle heroDisplay = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.6,
    height: 1.12,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const TextStyle heroMetric = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const TextStyle titleLight = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.2,
    height: 1.22,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textMuted,
    fontFeatures: tabular,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgObsidian,
    canvasColor: AppColors.bgObsidian,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.audiRed,
      onPrimary: Colors.white,
      secondary: AppColors.userBlue,
      onSecondary: Colors.white,
      surface: AppColors.glassBase,
      onSurface: AppColors.textPrimary,
      error: AppColors.audiRedBright,
      onError: Colors.white,
    ),
    splashFactory: InkSparkle.splashFactory,
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.glassElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.hairline(0.12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.glassElevated,
      contentTextStyle: AppTypography.body.copyWith(
        color: AppColors.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.hairline(0.12)),
      ),
    ),
  );
}
