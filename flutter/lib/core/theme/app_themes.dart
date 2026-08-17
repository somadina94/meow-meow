import 'package:flutter/material.dart';

/// Theme definition matching web app's ThemeContext
class AppThemeData {
  final String id;
  final String name;
  final String description;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  final Color primaryGlow;
  final Color primaryGlowDark;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.description,
    required this.lightScheme,
    required this.darkScheme,
    required this.primaryGlow,
    required this.primaryGlowDark,
  });
}

/// Helper to convert HSL string to Color
Color hslToColor(String hsl) {
  final parts = hsl.split(' ').map((s) => double.parse(s.replaceAll('%', ''))).toList();
  final h = parts[0] / 360;
  final s = parts[1] / 100;
  final l = parts[2] / 100;
  return HSLColor.fromAHSL(1.0, h * 360, s, l).toColor();
}

/// All 20 themes matching the web app
class AppThemes {
  AppThemes._();

  // ============= 1. Aurora Theme =============
  static final aurora = AppThemeData(
    id: 'aurora',
    name: 'Aurora',
    description: 'Cosmic teal with aurora glow',
    primaryGlow: hslToColor('174 80 55'),
    primaryGlowDark: hslToColor('174 80 60'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('220 25 97'),
      onSurface: hslToColor('230 25 18'),
      surfaceContainerHighest: hslToColor('210 30 98'),
      primary: hslToColor('174 72 40'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('270 50 94'),
      onSecondary: hslToColor('270 60 35'),
      tertiary: hslToColor('160 70 42'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('220 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('230 35 8'),
      onSurface: hslToColor('200 50 95'),
      surfaceContainerHighest: hslToColor('230 30 12'),
      primary: hslToColor('174 72 50'),
      onPrimary: hslToColor('230 35 8'),
      secondary: hslToColor('270 45 20'),
      onSecondary: hslToColor('270 60 80'),
      tertiary: hslToColor('160 70 45'),
      onTertiary: hslToColor('230 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('230 25 20'),
    ),
  );

  // ============= 2. Pink Theme =============
  static final pink = AppThemeData(
    id: 'pink',
    name: 'Rose Blossom',
    description: 'Soft pink with romantic vibes',
    primaryGlow: hslToColor('330 85 70'),
    primaryGlowDark: hslToColor('330 85 75'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('330 30 98'),
      onSurface: hslToColor('330 25 15'),
      surfaceContainerHighest: hslToColor('330 35 99'),
      primary: hslToColor('330 81 60'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('320 50 94'),
      onSecondary: hslToColor('320 60 35'),
      tertiary: hslToColor('340 75 55'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('330 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('330 30 8'),
      onSurface: hslToColor('330 50 95'),
      surfaceContainerHighest: hslToColor('330 25 12'),
      primary: hslToColor('330 81 65'),
      onPrimary: hslToColor('330 30 8'),
      secondary: hslToColor('320 45 20'),
      onSecondary: hslToColor('320 60 80'),
      tertiary: hslToColor('340 75 60'),
      onTertiary: hslToColor('330 30 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('330 25 20'),
    ),
  );

  // ============= 3. Ocean Theme =============
  static final ocean = AppThemeData(
    id: 'ocean',
    name: 'Ocean Blue',
    description: 'Deep ocean with calm waves',
    primaryGlow: hslToColor('210 95 60'),
    primaryGlowDark: hslToColor('210 95 65'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('210 30 98'),
      onSurface: hslToColor('210 25 15'),
      surfaceContainerHighest: hslToColor('210 35 99'),
      primary: hslToColor('210 90 50'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('200 50 94'),
      onSecondary: hslToColor('200 60 35'),
      tertiary: hslToColor('190 85 45'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('210 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('210 35 8'),
      onSurface: hslToColor('210 50 95'),
      surfaceContainerHighest: hslToColor('210 30 12'),
      primary: hslToColor('210 90 55'),
      onPrimary: hslToColor('210 35 8'),
      secondary: hslToColor('200 45 20'),
      onSecondary: hslToColor('200 60 80'),
      tertiary: hslToColor('190 85 50'),
      onTertiary: hslToColor('210 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('210 25 20'),
    ),
  );

  // ============= 4. Forest Theme =============
  static final forest = AppThemeData(
    id: 'forest',
    name: 'Forest Green',
    description: 'Natural green forest vibes',
    primaryGlow: hslToColor('142 80 55'),
    primaryGlowDark: hslToColor('142 80 60'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('140 30 98'),
      onSurface: hslToColor('140 25 12'),
      surfaceContainerHighest: hslToColor('140 35 99'),
      primary: hslToColor('142 71 45'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('140 50 94'),
      onSecondary: hslToColor('140 60 30'),
      tertiary: hslToColor('160 60 40'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('140 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('140 35 8'),
      onSurface: hslToColor('140 50 95'),
      surfaceContainerHighest: hslToColor('140 30 12'),
      primary: hslToColor('142 71 50'),
      onPrimary: hslToColor('140 35 8'),
      secondary: hslToColor('140 45 20'),
      onSecondary: hslToColor('140 60 80'),
      tertiary: hslToColor('160 60 45'),
      onTertiary: hslToColor('140 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('140 25 20'),
    ),
  );

  // ============= 5. Sunset Theme =============
  static final sunset = AppThemeData(
    id: 'sunset',
    name: 'Sunset Orange',
    description: 'Warm sunset glow',
    primaryGlow: hslToColor('25 100 63'),
    primaryGlowDark: hslToColor('25 100 68'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('30 30 98'),
      onSurface: hslToColor('25 25 15'),
      surfaceContainerHighest: hslToColor('30 35 99'),
      primary: hslToColor('25 95 53'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('30 50 94'),
      onSecondary: hslToColor('25 60 35'),
      tertiary: hslToColor('15 90 50'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('30 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('25 35 8'),
      onSurface: hslToColor('30 50 95'),
      surfaceContainerHighest: hslToColor('25 30 12'),
      primary: hslToColor('25 95 58'),
      onPrimary: hslToColor('25 35 8'),
      secondary: hslToColor('30 45 20'),
      onSecondary: hslToColor('30 60 80'),
      tertiary: hslToColor('15 90 55'),
      onTertiary: hslToColor('25 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('25 25 20'),
    ),
  );

  // ============= 6. Lavender Theme =============
  static final lavender = AppThemeData(
    id: 'lavender',
    name: 'Lavender Dream',
    description: 'Soft purple lavender fields',
    primaryGlow: hslToColor('270 75 70'),
    primaryGlowDark: hslToColor('270 75 75'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('270 30 98'),
      onSurface: hslToColor('270 25 15'),
      surfaceContainerHighest: hslToColor('270 35 99'),
      primary: hslToColor('270 65 60'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('270 50 94'),
      onSecondary: hslToColor('270 60 35'),
      tertiary: hslToColor('280 60 55'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('270 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('270 35 8'),
      onSurface: hslToColor('270 50 95'),
      surfaceContainerHighest: hslToColor('270 30 12'),
      primary: hslToColor('270 65 65'),
      onPrimary: hslToColor('270 35 8'),
      secondary: hslToColor('270 45 20'),
      onSecondary: hslToColor('270 60 80'),
      tertiary: hslToColor('280 60 60'),
      onTertiary: hslToColor('270 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('270 25 20'),
    ),
  );

  // ============= 7. Crimson Theme =============
  static final crimson = AppThemeData(
    id: 'crimson',
    name: 'Crimson Red',
    description: 'Bold crimson passion',
    primaryGlow: hslToColor('350 85 60'),
    primaryGlowDark: hslToColor('350 85 65'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('350 30 98'),
      onSurface: hslToColor('350 25 15'),
      surfaceContainerHighest: hslToColor('350 35 99'),
      primary: hslToColor('350 80 50'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('350 50 94'),
      onSecondary: hslToColor('350 60 35'),
      tertiary: hslToColor('0 75 55'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('350 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('350 35 8'),
      onSurface: hslToColor('350 50 95'),
      surfaceContainerHighest: hslToColor('350 30 12'),
      primary: hslToColor('350 80 55'),
      onPrimary: hslToColor('350 35 8'),
      secondary: hslToColor('350 45 20'),
      onSecondary: hslToColor('350 60 80'),
      tertiary: hslToColor('0 75 60'),
      onTertiary: hslToColor('350 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('350 25 20'),
    ),
  );

  // ============= 8. Gold Theme =============
  static final gold = AppThemeData(
    id: 'gold',
    name: 'Golden Amber',
    description: 'Luxurious gold and amber',
    primaryGlow: hslToColor('45 95 58'),
    primaryGlowDark: hslToColor('45 95 65'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('45 30 98'),
      onSurface: hslToColor('45 25 12'),
      surfaceContainerHighest: hslToColor('45 35 99'),
      primary: hslToColor('45 90 48'),
      onPrimary: hslToColor('45 25 10'),
      secondary: hslToColor('45 50 94'),
      onSecondary: hslToColor('45 60 30'),
      tertiary: hslToColor('38 85 50'),
      onTertiary: hslToColor('45 25 10'),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('45 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('45 35 8'),
      onSurface: hslToColor('45 50 95'),
      surfaceContainerHighest: hslToColor('45 30 12'),
      primary: hslToColor('45 90 55'),
      onPrimary: hslToColor('45 35 8'),
      secondary: hslToColor('45 45 20'),
      onSecondary: hslToColor('45 60 80'),
      tertiary: hslToColor('38 85 55'),
      onTertiary: hslToColor('45 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('45 25 20'),
    ),
  );

  // ============= 9. Mint Theme =============
  static final mint = AppThemeData(
    id: 'mint',
    name: 'Fresh Mint',
    description: 'Cool refreshing mint',
    primaryGlow: hslToColor('165 80 55'),
    primaryGlowDark: hslToColor('165 80 60'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('165 30 98'),
      onSurface: hslToColor('165 25 12'),
      surfaceContainerHighest: hslToColor('165 35 99'),
      primary: hslToColor('165 72 45'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('165 50 94'),
      onSecondary: hslToColor('165 60 30'),
      tertiary: hslToColor('155 65 42'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('165 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('165 35 8'),
      onSurface: hslToColor('165 50 95'),
      surfaceContainerHighest: hslToColor('165 30 12'),
      primary: hslToColor('165 72 50'),
      onPrimary: hslToColor('165 35 8'),
      secondary: hslToColor('165 45 20'),
      onSecondary: hslToColor('165 60 80'),
      tertiary: hslToColor('155 65 48'),
      onTertiary: hslToColor('165 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('165 25 20'),
    ),
  );

  // ============= 10. Slate Theme =============
  static final slate = AppThemeData(
    id: 'slate',
    name: 'Slate Gray',
    description: 'Modern neutral slate',
    primaryGlow: hslToColor('215 30 55'),
    primaryGlowDark: hslToColor('215 30 65'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('215 25 98'),
      onSurface: hslToColor('215 25 12'),
      surfaceContainerHighest: hslToColor('215 30 99'),
      primary: hslToColor('215 25 45'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('215 20 94'),
      onSecondary: hslToColor('215 25 35'),
      tertiary: hslToColor('220 20 50'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('215 15 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('215 30 8'),
      onSurface: hslToColor('215 20 95'),
      surfaceContainerHighest: hslToColor('215 25 12'),
      primary: hslToColor('215 25 55'),
      onPrimary: hslToColor('215 30 8'),
      secondary: hslToColor('215 20 20'),
      onSecondary: hslToColor('215 25 80'),
      tertiary: hslToColor('220 20 55'),
      onTertiary: hslToColor('215 30 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('215 20 20'),
    ),
  );

  // ============= 11. Cherry Theme =============
  static final cherry = AppThemeData(
    id: 'cherry',
    name: 'Cherry Blossom',
    description: 'Japanese cherry blossom',
    primaryGlow: hslToColor('340 85 75'),
    primaryGlowDark: hslToColor('340 85 80'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('340 30 98'),
      onSurface: hslToColor('340 25 15'),
      surfaceContainerHighest: hslToColor('340 35 99'),
      primary: hslToColor('340 80 65'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('340 50 94'),
      onSecondary: hslToColor('340 60 35'),
      tertiary: hslToColor('350 75 60'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('340 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('340 35 8'),
      onSurface: hslToColor('340 50 95'),
      surfaceContainerHighest: hslToColor('340 30 12'),
      primary: hslToColor('340 80 70'),
      onPrimary: hslToColor('340 35 8'),
      secondary: hslToColor('340 45 20'),
      onSecondary: hslToColor('340 60 80'),
      tertiary: hslToColor('350 75 65'),
      onTertiary: hslToColor('340 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('340 25 20'),
    ),
  );

  // ============= 12. Cobalt Theme =============
  static final cobalt = AppThemeData(
    id: 'cobalt',
    name: 'Cobalt Blue',
    description: 'Deep rich cobalt',
    primaryGlow: hslToColor('225 90 65'),
    primaryGlowDark: hslToColor('225 90 70'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('225 30 98'),
      onSurface: hslToColor('225 25 12'),
      surfaceContainerHighest: hslToColor('225 35 99'),
      primary: hslToColor('225 85 55'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('225 50 94'),
      onSecondary: hslToColor('225 60 35'),
      tertiary: hslToColor('230 80 50'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('225 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('225 35 8'),
      onSurface: hslToColor('225 50 95'),
      surfaceContainerHighest: hslToColor('225 30 12'),
      primary: hslToColor('225 85 60'),
      onPrimary: hslToColor('225 35 8'),
      secondary: hslToColor('225 45 20'),
      onSecondary: hslToColor('225 60 80'),
      tertiary: hslToColor('230 80 55'),
      onTertiary: hslToColor('225 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('225 25 20'),
    ),
  );

  // ============= 13. Coral Theme =============
  static final coral = AppThemeData(
    id: 'coral',
    name: 'Coral Reef',
    description: 'Vibrant coral tones',
    primaryGlow: hslToColor('16 90 70'),
    primaryGlowDark: hslToColor('16 90 75'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('16 30 98'),
      onSurface: hslToColor('16 25 15'),
      surfaceContainerHighest: hslToColor('16 35 99'),
      primary: hslToColor('16 85 60'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('16 50 94'),
      onSecondary: hslToColor('16 60 35'),
      tertiary: hslToColor('10 80 55'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('16 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('16 35 8'),
      onSurface: hslToColor('16 50 95'),
      surfaceContainerHighest: hslToColor('16 30 12'),
      primary: hslToColor('16 85 65'),
      onPrimary: hslToColor('16 35 8'),
      secondary: hslToColor('16 45 20'),
      onSecondary: hslToColor('16 60 80'),
      tertiary: hslToColor('10 80 60'),
      onTertiary: hslToColor('16 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('16 25 20'),
    ),
  );

  // ============= 14. Wine Theme =============
  static final wine = AppThemeData(
    id: 'wine',
    name: 'Wine Berry',
    description: 'Rich wine and berry',
    primaryGlow: hslToColor('310 70 55'),
    primaryGlowDark: hslToColor('310 70 65'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('310 30 98'),
      onSurface: hslToColor('310 25 12'),
      surfaceContainerHighest: hslToColor('310 35 99'),
      primary: hslToColor('310 60 45'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('310 50 94'),
      onSecondary: hslToColor('310 60 30'),
      tertiary: hslToColor('320 55 50'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('310 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('310 35 8'),
      onSurface: hslToColor('310 50 95'),
      surfaceContainerHighest: hslToColor('310 30 12'),
      primary: hslToColor('310 60 55'),
      onPrimary: hslToColor('310 35 8'),
      secondary: hslToColor('310 45 20'),
      onSecondary: hslToColor('310 60 80'),
      tertiary: hslToColor('320 55 55'),
      onTertiary: hslToColor('310 35 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('310 25 20'),
    ),
  );

  // ============= 15. Midnight Theme =============
  static final midnight = AppThemeData(
    id: 'midnight',
    name: 'Midnight Indigo',
    description: 'Deep midnight sky',
    primaryGlow: hslToColor('245 80 65'),
    primaryGlowDark: hslToColor('245 80 70'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('245 25 98'),
      onSurface: hslToColor('245 25 12'),
      surfaceContainerHighest: hslToColor('245 30 99'),
      primary: hslToColor('245 70 55'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('245 50 94'),
      onSecondary: hslToColor('245 60 35'),
      tertiary: hslToColor('255 65 50'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('245 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('245 35 6'),
      onSurface: hslToColor('245 50 95'),
      surfaceContainerHighest: hslToColor('245 30 10'),
      primary: hslToColor('245 70 60'),
      onPrimary: hslToColor('245 35 6'),
      secondary: hslToColor('245 45 18'),
      onSecondary: hslToColor('245 60 80'),
      tertiary: hslToColor('255 65 55'),
      onTertiary: hslToColor('245 35 6'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('245 25 18'),
    ),
  );

  // ============= 16. Peach Theme =============
  static final peach = AppThemeData(
    id: 'peach',
    name: 'Peach Blush',
    description: 'Soft warm peach',
    primaryGlow: hslToColor('20 90 75'),
    primaryGlowDark: hslToColor('20 90 80'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('20 35 98'),
      onSurface: hslToColor('20 25 15'),
      surfaceContainerHighest: hslToColor('20 40 99'),
      primary: hslToColor('20 85 65'),
      onPrimary: hslToColor('20 25 10'),
      secondary: hslToColor('20 50 94'),
      onSecondary: hslToColor('20 60 35'),
      tertiary: hslToColor('12 80 60'),
      onTertiary: hslToColor('20 25 10'),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('20 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('20 30 8'),
      onSurface: hslToColor('20 50 95'),
      surfaceContainerHighest: hslToColor('20 25 12'),
      primary: hslToColor('20 85 70'),
      onPrimary: hslToColor('20 30 8'),
      secondary: hslToColor('20 45 20'),
      onSecondary: hslToColor('20 60 80'),
      tertiary: hslToColor('12 80 65'),
      onTertiary: hslToColor('20 30 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('20 25 20'),
    ),
  );

  // ============= 17. Emerald Theme =============
  static final emerald = AppThemeData(
    id: 'emerald',
    name: 'Emerald Gem',
    description: 'Precious emerald green',
    primaryGlow: hslToColor('155 85 50'),
    primaryGlowDark: hslToColor('155 85 58'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('155 30 98'),
      onSurface: hslToColor('155 25 10'),
      surfaceContainerHighest: hslToColor('155 35 99'),
      primary: hslToColor('155 80 40'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('155 50 94'),
      onSecondary: hslToColor('155 60 28'),
      tertiary: hslToColor('145 75 38'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('155 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('155 35 6'),
      onSurface: hslToColor('155 50 95'),
      surfaceContainerHighest: hslToColor('155 30 10'),
      primary: hslToColor('155 80 48'),
      onPrimary: hslToColor('155 35 6'),
      secondary: hslToColor('155 45 18'),
      onSecondary: hslToColor('155 60 80'),
      tertiary: hslToColor('145 75 45'),
      onTertiary: hslToColor('155 35 6'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('155 25 18'),
    ),
  );

  // ============= 18. Sapphire Theme =============
  static final sapphire = AppThemeData(
    id: 'sapphire',
    name: 'Royal Sapphire',
    description: 'Royal blue sapphire',
    primaryGlow: hslToColor('220 90 60'),
    primaryGlowDark: hslToColor('220 90 68'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('220 30 98'),
      onSurface: hslToColor('220 25 12'),
      surfaceContainerHighest: hslToColor('220 35 99'),
      primary: hslToColor('220 85 50'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('220 50 94'),
      onSecondary: hslToColor('220 60 35'),
      tertiary: hslToColor('228 80 55'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('220 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('220 35 7'),
      onSurface: hslToColor('220 50 95'),
      surfaceContainerHighest: hslToColor('220 30 11'),
      primary: hslToColor('220 85 58'),
      onPrimary: hslToColor('220 35 7'),
      secondary: hslToColor('220 45 19'),
      onSecondary: hslToColor('220 60 80'),
      tertiary: hslToColor('228 80 60'),
      onTertiary: hslToColor('220 35 7'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('220 25 19'),
    ),
  );

  // ============= 19. Rose Theme =============
  static final rose = AppThemeData(
    id: 'rose',
    name: 'Rose Gold',
    description: 'Elegant rose gold',
    primaryGlow: hslToColor('345 80 70'),
    primaryGlowDark: hslToColor('345 80 75'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('345 30 98'),
      onSurface: hslToColor('345 25 15'),
      surfaceContainerHighest: hslToColor('345 35 99'),
      primary: hslToColor('345 75 60'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('345 50 94'),
      onSecondary: hslToColor('345 60 35'),
      tertiary: hslToColor('355 70 55'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('345 20 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('345 30 8'),
      onSurface: hslToColor('345 50 95'),
      surfaceContainerHighest: hslToColor('345 25 12'),
      primary: hslToColor('345 75 65'),
      onPrimary: hslToColor('345 30 8'),
      secondary: hslToColor('345 45 20'),
      onSecondary: hslToColor('345 60 80'),
      tertiary: hslToColor('355 70 60'),
      onTertiary: hslToColor('345 30 8'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('345 25 20'),
    ),
  );

  // ============= 20. Noir Theme =============
  static final noir = AppThemeData(
    id: 'noir',
    name: 'Noir Black',
    description: 'Elegant monochrome noir',
    primaryGlow: hslToColor('0 0 25'),
    primaryGlowDark: hslToColor('0 0 100'),
    lightScheme: ColorScheme.light(
      surface: hslToColor('0 0 98'),
      onSurface: hslToColor('0 0 10'),
      surfaceContainerHighest: const Color(0xFFFFFFFF),
      primary: hslToColor('0 0 15'),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: hslToColor('0 0 94'),
      onSecondary: hslToColor('0 0 25'),
      tertiary: hslToColor('0 0 25'),
      onTertiary: const Color(0xFFFFFFFF),
      error: hslToColor('0 72 51'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('0 0 88'),
    ),
    darkScheme: ColorScheme.dark(
      surface: hslToColor('0 0 5'),
      onSurface: hslToColor('0 0 95'),
      surfaceContainerHighest: hslToColor('0 0 8'),
      primary: hslToColor('0 0 95'),
      onPrimary: hslToColor('0 0 5'),
      secondary: hslToColor('0 0 15'),
      onSecondary: hslToColor('0 0 80'),
      tertiary: hslToColor('0 0 85'),
      onTertiary: hslToColor('0 0 5'),
      error: hslToColor('0 65 50'),
      onError: const Color(0xFFFFFFFF),
      outline: hslToColor('0 0 18'),
    ),
  );

  /// List of all available themes
  static final List<AppThemeData> all = [
    aurora,
    pink,
    ocean,
    forest,
    sunset,
    lavender,
    crimson,
    gold,
    mint,
    slate,
    cherry,
    cobalt,
    coral,
    wine,
    midnight,
    peach,
    emerald,
    sapphire,
    rose,
    noir,
  ];

  /// Get theme by ID
  static AppThemeData? getById(String id) {
    try {
      return all.firstWhere((theme) => theme.id == id);
    } catch (_) {
      return aurora; // Default fallback
    }
  }
}
