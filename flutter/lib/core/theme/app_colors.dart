import 'package:flutter/material.dart';

/// App Color Palette
/// 
/// Aurora Theme - Semantic color tokens matching the web app design system.
/// Deep cosmic background with aurora-inspired accents.
class AppColors {
  AppColors._();

  // ============= Light Theme Colors (Aurora Light) =============
  
  /// Background color - light aurora
  static const Color background = Color(0xFFF3F6FA); // hsl(220, 25%, 97%)
  
  /// Foreground/text color
  static const Color foreground = Color(0xFF242E3F); // hsl(230, 25%, 18%)
  
  /// Card background - subtle aurora tint
  static const Color card = Color(0xFFF5F8FC); // hsl(210, 30%, 98%)
  static const Color cardForeground = Color(0xFF242E3F);
  
  /// Popover background
  static const Color popover = Color(0xFFFFFFFF);
  static const Color popoverForeground = Color(0xFF242E3F);
  
  /// Primary - Aurora Teal/Cyan
  static const Color primary = Color(0xFF1BA39C); // hsl(174, 72%, 40%)
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color primaryGlow = Color(0xFF2DD4C8); // hsl(174, 80%, 55%)
  
  /// Secondary - Aurora Purple
  static const Color secondary = Color(0xFFECE5F5); // hsl(270, 50%, 94%)
  static const Color secondaryForeground = Color(0xFF5B3593); // hsl(270, 60%, 35%)
  
  /// Muted colors - soft aurora grey
  static const Color muted = Color(0xFFEDF0F4); // hsl(220, 20%, 94%)
  static const Color mutedForeground = Color(0xFF6B7789); // hsl(220, 15%, 45%)
  
  /// Accent - Aurora Green
  static const Color accent = Color(0xFF1FA874); // hsl(160, 70%, 42%)
  static const Color accentForeground = Color(0xFFFFFFFF);
  
  /// Destructive/error color
  static const Color destructive = Color(0xFFEF4444); // hsl(0, 72%, 51%)
  static const Color destructiveForeground = Color(0xFFFFFFFF);
  
  /// Border color
  static const Color border = Color(0xFFDBE1E9); // hsl(220, 20%, 88%)
  
  /// Input border color
  static const Color input = Color(0xFFE4E9F0); // hsl(220, 20%, 92%)
  
  /// Focus ring color
  static const Color ring = Color(0xFF1BA39C);

  // ============= Dark Theme Colors (Aurora Dark) =============
  
  /// Background - Deep cosmic night sky
  static const Color backgroundDark = Color(0xFF111827); // hsl(230, 35%, 8%)
  
  /// Foreground - Light aurora text
  static const Color foregroundDark = Color(0xFFECF5F9); // hsl(200, 50%, 95%)
  
  /// Card with aurora glow
  static const Color cardDark = Color(0xFF1E293B); // hsl(230, 30%, 12%)
  static const Color cardForegroundDark = Color(0xFFECF5F9);
  
  /// Primary - Aurora Teal glowing
  static const Color primaryDark = Color(0xFF2DD4C8); // hsl(174, 72%, 50%)
  static const Color primaryForegroundDark = Color(0xFF111827);
  static const Color primaryGlowDark = Color(0xFF5EEAD4); // hsl(174, 80%, 60%)
  
  /// Secondary - Aurora Purple dark
  static const Color secondaryDark = Color(0xFF2D2055); // hsl(270, 45%, 20%)
  static const Color secondaryForegroundDark = Color(0xFFD8B4FE); // hsl(270, 60%, 80%)
  
  /// Muted - Deep cosmic grey
  static const Color mutedDark = Color(0xFF242E3F); // hsl(230, 25%, 18%)
  static const Color mutedForegroundDark = Color(0xFF94A3B8); // hsl(220, 20%, 65%)
  
  /// Accent - Aurora Green dark
  static const Color accentDark = Color(0xFF22C55E); // hsl(160, 70%, 45%)
  static const Color accentForegroundDark = Color(0xFF111827);
  
  /// Destructive dark
  static const Color destructiveDark = Color(0xFFDC2626);
  static const Color destructiveForegroundDark = Color(0xFFF8FAFC);
  
  /// Border dark
  static const Color borderDark = Color(0xFF334155); // hsl(230, 25%, 20%)
  static const Color inputDark = Color(0xFF242E3F);
  static const Color ringDark = Color(0xFF2DD4C8);

  // ============= Semantic Colors =============
  
  /// Success color - follows theme's accent
  static const Color success = Color(0xFF22C55E);
  static const Color successForeground = Color(0xFFFFFFFF);
  
  /// Warning color
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningForeground = Color(0xFFFFFFFF);
  
  /// Info color - follows theme's primary
  static const Color info = Color(0xFF1BA39C);
  static const Color infoForeground = Color(0xFFFFFFFF);

  // ============= Status Colors =============
  
  /// Online status - uses accent/success
  static const Color online = Color(0xFF22C55E);
  
  /// Offline status
  static const Color offline = Color(0xFF94A3B8);
  
  /// Away status
  static const Color away = Color(0xFFF59E0B);
  
  /// Busy status
  static const Color busy = Color(0xFFF59E0B);

  // ============= Gender Colors =============
  
  /// Male color
  static const Color male = Color(0xFF3B82F6);
  
  /// Female color
  static const Color female = Color(0xFFEC4899);

  // ============= Gradients =============
  
  /// Primary Aurora gradient - uses theme primary colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1BA39C), Color(0xFF22C55E)], // Primary to Accent
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Aurora gradient (animated background)
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [
      Color(0xFF2DD4C8), // Teal
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero gradient - light mode
  static const LinearGradient heroGradientLight = LinearGradient(
    colors: [Color(0xFFF3F6FA), Color(0xFFE0F2F1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Hero gradient - dark mode
  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF1A1D3A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // ============= Theme-aware color getters =============
  // These return the appropriate color based on brightness
  
  static Color getSuccess(Brightness brightness) => success;
  static Color getWarning(Brightness brightness) => warning;
  static Color getInfo(Brightness brightness) => brightness == Brightness.dark ? primaryDark : primary;
  static Color getOnline(Brightness brightness) => online;
  static Color getOffline(Brightness brightness) => offline;
  static Color getBusy(Brightness brightness) => busy;
}
