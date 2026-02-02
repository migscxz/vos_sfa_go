import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand / gradient colors (match DashboardAppBar + cards)
  static const _primary = Color(0xFF6B73FF);
  static const _gradA   = Color(0xFF667EEA);
  static const _gradB   = Color(0xFF764BA2);
  static const _gradC   = Color(0xFF6B73FF);

  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_gradA, _gradB, _gradC],
    stops: [0, .5, 1],
  );

  /// Single source of truth – LIGHT THEME ONLY
  static ThemeData _base() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: const Color(0xFF764BA2),
    );

    // Typography aligned with your dashboard (Inter-like)
    final text = GoogleFonts.interTextTheme().apply(
      bodyColor: const Color(0xFF111827),
      displayColor: const Color(0xFF020617),
    );

    // Global surfaces
    const scaffoldBg = Color(0xFFF3F4FF); // soft bluish background
    const cardColor = Colors.white;
    const tileColor = Colors.white;
    const inputFill = Colors.white;

    final chipBg = const Color(0xFFE5E7EB);
    final chipSide = BorderSide(
      color: const Color(0xFFCBD5F5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ── Scaffold / Overall background ───────────────────────
      scaffoldBackgroundColor: scaffoldBg,

      // ── Typography ──────────────────────────────────────────
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.25),
      ),

      // ── AppBar ──────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF111827),
      ),

      // ── Cards (match your white KPI cards) ─────────────────
      // Use CardThemeData as required by your Flutter version.
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        surfaceTintColor: Colors.transparent, // remove M3 overlay tint
      ),

      // ── ListTiles ───────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: tileColor,
        iconColor: colorScheme.primary,
      ),

      // ── Inputs (TextFields, etc.) ───────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),

      // ── Chips (filters, tags) ───────────────────────────────
      chipTheme: ChipThemeData(
        labelStyle: const TextStyle(fontSize: 12),
        side: chipSide,
        backgroundColor: chipBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // ── Buttons (primary actions) ───────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: Color(0xFF4B5563),
      ),
    );
  }

  // Expose light & dark, but both are the same LIGHT theme now
  static ThemeData get light => _base();
  static ThemeData get dark  => _base();
}

/// For existing code that calls buildAppTheme()
ThemeData buildAppTheme() => AppTheme.light;
