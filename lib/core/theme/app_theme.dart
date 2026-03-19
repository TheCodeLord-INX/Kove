import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const double kFloatingIslandNavClearance = 120;

class AppColors {
  static const Color kiwiGreen = KoveColors.kiwiGreen;
  static const Color obsidianBlack = KoveColors.obsidianBlack;
  static const Color pureWhite = KoveColors.pureWhite;
  static const Color offWhite = KoveColors.offWhite;
  static const Color success = KoveColors.success;
  static const Color danger = KoveColors.danger;
  static const Color amber = KoveColors.amber;
  static const Color neobrutalistBorder = KoveColors.neobrutalistBorder;
  
  // Legacy aliases for existing code
  static const Color successGreen = KoveColors.success;
  static const Color dangerRed = KoveColors.danger;
  static const Color navyPrimary = KoveColors.obsidianBlack;
  static const Color accentBlue = KoveColors.kiwiGreen;
  static const Color textPrimary = KoveColors.obsidianBlack;
  static const Color textSecondary = Color(0xFF64748B);
  static const Color surfaceWhite = KoveColors.pureWhite;
}

/// KOVE Design Tokens - Neobrutalist-Lite x Glassmorphism
class KoveColors {
  KoveColors._();

  // ── Kiwi Palette ────────────────────────────────
  static const Color kiwiGreen = Color(0xFF98C95F); // Vibrant Kiwi Green
  static const Color obsidianBlack = Color(0xFF0F172A); // Deep Obsidian
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAFC);
  
  // ── Status Colors ───────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);
  
  // ── Border & Outline ────────────────────────────
  static const Color neobrutalistBorder = Color(0xFF000000);
  static const Color glassBorderLight = Color(0x33000000);
  static const Color glassBorderDark = Color(0x33FFFFFF);
}

class KoveTheme {
  KoveTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = KoveColors.kiwiGreen;
    final backgroundColor = isDark ? KoveColors.obsidianBlack : KoveColors.pureWhite;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : KoveColors.offWhite;
    final textColor = isDark ? Colors.white : KoveColors.obsidianBlack;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        surface: surfaceColor,
        onSurface: textColor,
        outline: KoveColors.neobrutalistBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: isDark ? Colors.white10 : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KoveColors.neobrutalistBorder, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: KoveColors.obsidianBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: KoveColors.neobrutalistBorder, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
        ),
        // Monospaced utility for readings
        labelLarge: GoogleFonts.jetBrainsMono(
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class KoveDecorations {
  static BoxDecoration glass({
    required bool isDark,
    double blur = 10,
    double opacity = 0.1,
    double borderRadius = 16,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder 
          ? Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1)
          : null,
    );
  }

  static BoxDecoration neobrutalist({
    required Color color,
    double borderRadius = 16,
    double shadowOffset = 4,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: KoveColors.neobrutalistBorder, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: KoveColors.neobrutalistBorder,
          offset: Offset(shadowOffset, shadowOffset),
          blurRadius: 0,
        ),
      ],
    );
  }
}
