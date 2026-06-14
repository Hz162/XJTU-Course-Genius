import 'package:flutter/material.dart';

// ── Palette ──
const primaryColor = Color(0xFF4F6EF7);
const primaryLight = Color(0xFF818CF8);
const primarySoft = Color(0xFFEEF2FF);
const logoBlue = Color(0xFF7DB5D6);
const logoBlueLight = Color(0xFFB8D9ED);

const successColor = Color(0xFF22C55E);
const warningColor = Color(0xFFF59E0B);
const dangerColor = Color(0xFFEF4444);

const accentPink = Color(0xFFEC4899);
const accentPurple = Color(0xFF8B5CF6);
const accentTeal = Color(0xFF14B8A6);

const bgColor = Color(0xFFF1F5F9);
const surfaceColor = Colors.white;
const surfaceSecondary = Color(0xFFF8FAFC);

// ── Text ──
const textPrimary = Color(0xFF1E293B);
const textSecondary = Color(0xFF64748B);
const textMuted = Color(0xFF94A3B8);

// ── Border ──
const borderColor = Color(0xFFE2E8F0);
const borderLight = Color(0xFFF1F5F9);

// ── Radii ──
const double radiusSm = 6;
const double radiusMd = 10;
const double radiusLg = 14;
const double radiusXl = 18;

// ── Shadows ──
List<BoxShadow> shadowSm(Color color) => [
      BoxShadow(color: color.withAlpha(12), blurRadius: 4, offset: const Offset(0, 1)),
    ];
List<BoxShadow> shadowMd(Color color) => [
      BoxShadow(color: color.withAlpha(18), blurRadius: 12, offset: const Offset(0, 4)),
    ];
List<BoxShadow> shadowLg(Color color) => [
      BoxShadow(color: color.withAlpha(24), blurRadius: 24, offset: const Offset(0, 8)),
    ];

// ── Gradients ──
const Gradient primaryGradient = LinearGradient(
  colors: [primaryColor, primaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const Gradient accentGradient = LinearGradient(
  colors: [accentPurple, accentPink],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Accent color map (course type → color) ──
const _accentPalette = [
  primaryColor, successColor, warningColor,
  accentPurple, accentTeal, accentPink,
  Color(0xFFE67E22), Color(0xFF1ABC9C), Color(0xFFE74C3C),
  Color(0xFF3498DB), Color(0xFF2ECC71), Color(0xFF9B59B6),
];

Color accentForType(String type) {
  if (type.isEmpty) return textMuted;
  // Known course query types — fixed colors for consistency
  switch (type) {
    case 'TJKC': return primaryColor;
    case 'FANKC': return successColor;
    case 'FAWKC': return warningColor;
    case 'XGXK': return accentPurple;
    case 'TYKC': return accentTeal;
  }
  // Hash unknown types (numeric courseType, etc.) to a palette color
  int hash = 0;
  for (int i = 0; i < type.length; i++) {
    hash = (hash * 31 + type.codeUnitAt(i)) & 0x7fffffff;
  }
  return _accentPalette[hash % _accentPalette.length];
}

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'NotoSansSC',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 0.5,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        ),
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: 'NotoSansSC',
        ),
        elevation: 8,
        shadowColor: Color(0x20000000),
      ),
    );
