import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Helper colors that match the new light AppTheme so old widgets stay consistent.
class AppColors {
  AppColors._();

  // ── Brand / Gradient ──────────────────────────────────────
  static const primary = Color(0xFF6B73FF); // main brand color
  static const gradA = Color(0xFF667EEA);   // gradient start
  static const gradB = Color(0xFF764BA2);   // gradient middle
  static const gradC = Color(0xFF6B73FF);   // gradient end

  // Keep old names used in widgets BUT now using light-theme values
  static const blueBright = primary;

  // Light surfaces – NO MORE DARK BACKGROUND
  static const blueDeepest = Color(0xFFF3F4FF); // scaffold bg light
  static const blueDark    = Color(0xFFFFFFFF); // cards / surfaces
  static const blueMid     = Color(0xFFF9FAFF); // inputs / tiles / subtle panels

  // Text colors
  static const textDark  = Color(0xFF111827); // primary text on light bg
  static const textLight = Color(0xFFF9FAFF); // text on gradients / colored chips
  static const textMuted = Color(0xFF6B7280); // secondary text / hints

  // Borders, dividers
  static const border = Color(0xFFE5E7EB);

  // Status colors
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFFBBF24);
  static const danger  = Color(0xFFEF4444);

  // Same gradient you use in DashboardAppBar
  static LinearGradient get primaryGradient => AppTheme.primaryGradient;

  // Shadow base (use withOpacity(0.3) as glow)
  static const shadowBase = primary;

  static Color? get textPrimary => null;
}
