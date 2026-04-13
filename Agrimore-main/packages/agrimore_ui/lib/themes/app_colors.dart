import 'package:flutter/material.dart';

class AppColors {
  // ============================================
  // PRIMARY COLORS - Unique Emerald-Jade Green
  // ============================================
  static const Color primary = Color(0xFF0D9B5C); // Emerald Green
  static const Color primaryLight = Color(0xFF12B76A); // Bright Emerald
  static const Color primaryDark = Color(0xFF06804A); // Jade Green
  static const Color primaryLighter = Color(0xFF32D583); // Mint Emerald
  static const Color primaryDarker = Color(0xFF05603A); // Deep Jade
  
  // ============================================
  // SECONDARY COLORS - Earthy tones
  // ============================================
  static const Color secondary = Color(0xFFFF6F00); // Orange
  static const Color secondaryLight = Color(0xFFFF8F00);
  static const Color secondaryDark = Color(0xFFE65100);
  static const Color secondaryLighter = Color(0xFFFFB74D);
  
  // ============================================
  // ACCENT COLORS
  // ============================================
  static const Color accent = Color(0xFFFFC107); // Amber
  static const Color accentLight = Color(0xFFFFD54F);
  static const Color accentDark = Color(0xFFFFA000);
  
  // ============================================
  // BACKGROUND COLORS - Light Theme
  // ============================================
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF0F0F0);
  // Card background colors for UI components
  static const Color cardBackground = Color(0xFFFFFFFF); // Light card background
  static const Color cardBackgroundDark = Color(0xFF2C2C2C); // Dark card background
  
  // ✅ NEW - Added for home screen compatibility
  static const Color lightGrey = Color(0xFFF5F5F5); // Same as background
  static const Color white = Color(0xFFFFFFFF); // Explicit white
  
  // ============================================
  // BACKGROUND COLORS - Dark Theme
  // ============================================
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceDarkVariant = Color(0xFF2C2C2C);
  static const Color surfaceDarkContainer = Color(0xFF252525);
  static const Color surfaceDarkElevated = Color(0xFF2A2A2A);
  
  // ============================================
  // AUTH SCREEN COLORS - Login/Signup specific
  // ============================================
  static const Color authBackgroundLight = Color(0xFFE6F7ED); // Mint green (updated)
  static const Color authBackgroundDark = Color(0xFF0D3D2B); // Deep emerald-black
  static const Color authFormPanelDark = Color(0xFF0F0F0F); // Near black
  static const Color authInputBorder = Color(0xFFE0E0E0); // Input border light
  static const Color authInputBackground = Color(0xFFFAFAFA); // Input bg light
  
  // Auth branding gradient (updated to emerald)
  static const LinearGradient authBrandingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06804A), Color(0xFF0D9B5C), Color(0xFF12B76A)],
  );
  
  // Auth mobile gradient
  static LinearGradient authMobileGradientLight = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE6F7ED), Color(0xFFFFFFFF)],
  );
  
  static LinearGradient authMobileGradientDark = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D3D2B), Color(0xFF0F0F0F)],
  );
  
  // ============================================
  // TEXT COLORS - Light Theme
  // ============================================
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textDisabled = Color(0xFFE0E0E0);
  
  // ✅ NEW - Added for home screen compatibility
  static const Color grey = Color(0xFF9E9E9E); // Same as textTertiary
  
  // ============================================
  // TEXT COLORS - Dark Theme
  // ============================================
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textLightSecondary = Color(0xFFB0B0B0);
  static const Color textLightTertiary = Color(0xFF808080);
  static const Color textLightHint = Color(0xFF606060);
  static const Color textLightDisabled = Color(0xFF404040);
  
  // ============================================
  // STATUS COLORS
  // ============================================
  static const Color success = Color(0xFF0D9B5C); // Updated to match primary
  static const Color successLight = Color(0xFF32D583);
  static const Color successDark = Color(0xFF06804A);
  
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorDark = Color(0xFFD32F2F);
  
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color warningDark = Color(0xFFFFA000);
  
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF1976D2);
  
  // ============================================
  // BORDER & DIVIDER COLORS
  // ============================================
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFEEEEEE);
  static const Color borderDark = Color(0xFFBDBDBD);
  
  static const Color divider = Color(0xFFBDBDBD);
  static const Color dividerLight = Color(0xFFE0E0E0);
  
  // Dark theme borders
  static const Color borderDarkTheme = Color(0xFF3A3A3A);
  static const Color dividerDarkTheme = Color(0xFF2A2A2A);
  
  // ============================================
  // GRADIENT COLORS (Updated to Emerald-Jade)
  // ============================================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D9B5C), Color(0xFF12B76A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFF0D9B5C), Color(0xFF06804A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Dark theme gradients (Updated)
  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF12B76A), Color(0xFF32D583)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradientDark = LinearGradient(
    colors: [backgroundDark, surfaceDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // ============================================
  // SHADOW COLORS
  // ============================================
  static const Color shadowLight = Color(0x1A000000); // 10% opacity
  static const Color shadowMedium = Color(0x33000000); // 20% opacity
  static const Color shadowDark = Color(0x4D000000); // 30% opacity
  static const Color shadowExtraDark = Color(0x66000000); // 40% opacity
  
  // Dark theme shadows
  static const Color shadowDarkTheme = Color(0x80000000); // 50% opacity
  
  // ============================================
  // ORDER STATUS COLORS
  // ============================================
  static const Color pending = Color(0xFFFFC107); // Yellow
  static const Color confirmed = Color(0xFF2196F3); // Blue
  static const Color processing = Color(0xFF9C27B0); // Purple
  static const Color shipped = Color(0xFF00BCD4); // Cyan
  static const Color outForDelivery = Color(0xFFFF9800); // Orange
  static const Color delivered = Color(0xFF0D9B5C); // Emerald Green (updated)
  static const Color cancelled = Color(0xFFF44336); // Red
  static const Color returned = Color(0xFF795548); // Brown
  static const Color refunded = Color(0xFF607D8B); // Blue Grey
  
  // ============================================
  // RATING COLORS
  // ============================================
  static const Color ratingActive = Color(0xFFFFC107);
  static const Color ratingInactive = Color(0xFFE0E0E0);
  static const Color ratingActiveDark = Color(0xFFFFD54F);
  static const Color ratingInactiveDark = Color(0xFF404040);
  
  // ============================================
  // DISCOUNT & BADGE COLORS
  // ============================================
  static const Color discountBg = Color(0xFFFF5252);
  static const Color discountText = Color(0xFFFFFFFF);
  static const Color discountBgDark = Color(0xFFE53935);
  
  static const Color badgeNew = Color(0xFF0D9B5C); // Updated to emerald
  static const Color badgeSale = Color(0xFFFF5252);
  static const Color badgeFeatured = Color(0xFFFF9800);
  static const Color badgeOutOfStock = Color(0xFF9E9E9E);
  
  // ============================================
  // SPECIAL UI COLORS
  // ============================================
  static const Color favorite = Color(0xFFE91E63); // Pink for wishlist
  static const Color cart = Color(0xFFFF6F00); // Orange for cart
  static const Color notification = Color(0xFFF44336); // Red for notifications
  
  // Stock status
  static const Color inStock = Color(0xFF0D9B5C); // Updated to emerald
  static const Color lowStock = Color(0xFFFF9800);
  static const Color outOfStock = Color(0xFFF44336);
  
  // Payment method colors
  static const Color cod = Color(0xFF0D9B5C); // Updated to emerald
  static const Color online = Color(0xFF2196F3);
  static const Color wallet = Color(0xFF9C27B0);
  
  // ============================================
  // OVERLAY COLORS
  // ============================================
  static const Color overlay = Color(0x80000000); // 50% black
  static const Color overlayLight = Color(0x40000000); // 25% black
  static const Color overlayDark = Color(0xB3000000); // 70% black
  
  // ============================================
  // SHIMMER COLORS (for loading states)
  // ============================================
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  
  static const Color shimmerBaseDark = Color(0xFF2A2A2A);
  static const Color shimmerHighlightDark = Color(0xFF3A3A3A);
  
  // ============================================
  // CATEGORY COLORS (for visual variety)
  // ============================================
  static const List<Color> categoryColors = [
    Color(0xFF0D9B5C), // Emerald (updated)
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Get text color based on background brightness
  static Color getTextColorForBackground(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? textLight : textPrimary;
  }
  
  /// Get order status color
  static Color getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return pending;
      case 'confirmed':
        return confirmed;
      case 'processing':
        return processing;
      case 'shipped':
        return shipped;
      case 'outfordelivery':
      case 'out_for_delivery':
        return outForDelivery;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      case 'returned':
        return returned;
      case 'refunded':
        return refunded;
      default:
        return textSecondary;
    }
  }
  
  /// Get stock status color
  static Color getStockStatusColor(int stock, {int lowStockThreshold = 10}) {
    if (stock <= 0) return outOfStock;
    if (stock <= lowStockThreshold) return lowStock;
    return inStock;
  }
  
  /// Get random category color
  static Color getRandomCategoryColor(int index) {
    return categoryColors[index % categoryColors.length];
  }
  
  /// Apply opacity to color
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  /// Lighten a color
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
  
  /// Darken a color
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
