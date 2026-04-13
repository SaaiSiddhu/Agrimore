import 'package:flutter/material.dart';

/// Admin-specific color palette with blue theme
class AdminColors {
  // ============================================
  // PRIMARY COLORS - Blue theme for admin
  // ============================================
  static const Color primary = Color(0xFF1976D2); // Blue
  static const Color primaryLight = Color(0xFF2196F3); // Light Blue
  static const Color primaryDark = Color(0xFF1565C0); // Dark Blue
  static const Color primaryLighter = Color(0xFF64B5F6); // Extra Light Blue
  static const Color primaryDarker = Color(0xFF0D47A1); // Extra Dark Blue
  
  // ============================================
  // SECONDARY COLORS - Complementary tones
  // ============================================
  static const Color secondary = Color(0xFF00ACC1); // Cyan
  static const Color secondaryLight = Color(0xFF26C6DA);
  static const Color secondaryDark = Color(0xFF00838F);
  static const Color secondaryLighter = Color(0xFF80DEEA);
  
  // ============================================
  // ACCENT COLORS
  // ============================================
  static const Color accent = Color(0xFFFF9800); // Amber
  static const Color accentLight = Color(0xFFFFB74D);
  static const Color accentDark = Color(0xFFF57C00);
  
  // ============================================
  // BACKGROUND COLORS - Light Theme
  // ============================================
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF0F2F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF1E2A3A);
  
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  
  // ============================================
  // BACKGROUND COLORS - Dark Theme
  // ============================================
  static const Color backgroundDark = Color(0xFF0F1419);
  static const Color surfaceDark = Color(0xFF1A2332);
  static const Color surfaceDarkVariant = Color(0xFF243447);
  static const Color surfaceDarkContainer = Color(0xFF1E2A3A);
  static const Color surfaceDarkElevated = Color(0xFF2A3A4D);
  
  // ============================================
  // TEXT COLORS - Light Theme
  // ============================================
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textDisabled = Color(0xFFE0E0E0);
  
  static const Color grey = Color(0xFF9E9E9E);
  
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
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);
  
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);
  
  // ============================================
  // BORDER & DIVIDER COLORS
  // ============================================
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFFD1D5DB);
  
  static const Color divider = Color(0xFFE5E7EB);
  static const Color dividerLight = Color(0xFFF3F4F6);
  
  static const Color borderDarkTheme = Color(0xFF374151);
  static const Color dividerDarkTheme = Color(0xFF1F2937);
  
  // ============================================
  // GRADIENT COLORS
  // ============================================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient sidebarGradient = LinearGradient(
    colors: [Color(0xFF0F1419), Color(0xFF1A2332)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // ============================================
  // SHADOW COLORS
  // ============================================
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);
  static const Color shadowExtraDark = Color(0x66000000);
  static const Color shadowDarkTheme = Color(0x80000000);
  
  // ============================================
  // ADMIN-SPECIFIC STATUS COLORS
  // ============================================
  static const Color pending = Color(0xFFFBBF24);
  static const Color confirmed = Color(0xFF3B82F6);
  static const Color processing = Color(0xFF8B5CF6);
  static const Color shipped = Color(0xFF06B6D4);
  static const Color outForDelivery = Color(0xFFF97316);
  static const Color delivered = Color(0xFF10B981);
  static const Color cancelled = Color(0xFFEF4444);
  static const Color returned = Color(0xFF78716C);
  static const Color refunded = Color(0xFF64748B);
  
  // ============================================
  // RATING COLORS
  // ============================================
  static const Color ratingActive = Color(0xFFFBBF24);
  static const Color ratingInactive = Color(0xFFE5E7EB);
  
  // ============================================
  // BADGE COLORS
  // ============================================
  static const Color badgeNew = Color(0xFF10B981);
  static const Color badgeSale = Color(0xFFEF4444);
  static const Color badgeFeatured = Color(0xFFF59E0B);
  static const Color badgeOutOfStock = Color(0xFF9CA3AF);
  
  // ============================================
  // SPECIAL UI COLORS
  // ============================================
  static const Color favorite = Color(0xFFEC4899);
  static const Color cart = Color(0xFFF97316);
  static const Color notification = Color(0xFFEF4444);
  
  static const Color inStock = Color(0xFF10B981);
  static const Color lowStock = Color(0xFFF59E0B);
  static const Color outOfStock = Color(0xFFEF4444);
  
  // ============================================
  // OVERLAY COLORS
  // ============================================
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  static const Color overlayDark = Color(0xB3000000);
  
  // ============================================
  // SHIMMER COLORS
  // ============================================
  static const Color shimmerBase = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF9FAFB);
  static const Color shimmerBaseDark = Color(0xFF374151);
  static const Color shimmerHighlightDark = Color(0xFF4B5563);
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  static Color getTextColorForBackground(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? textLight : textPrimary;
  }
  
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
  
  static Color getStockStatusColor(int stock, {int lowStockThreshold = 10}) {
    if (stock <= 0) return outOfStock;
    if (stock <= lowStockThreshold) return lowStock;
    return inStock;
  }
}
