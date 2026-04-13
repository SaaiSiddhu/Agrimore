import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // ============================================
  // DISPLAY STYLES - Hero text for landing pages
  // ============================================
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
    height: 1.3,
  );
  
  // Dark theme variants
  static const TextStyle displayLargeDark = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle displayMediumDark = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle displaySmallDark = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
    letterSpacing: -0.25,
    height: 1.3,
  );
  
  // ============================================
  // HEADLINE STYLES - Section headers
  // ============================================
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  // Dark theme variants
  static const TextStyle headlineLargeDark = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.3,
  );
  
  static const TextStyle headlineMediumDark = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.3,
  );
  
  static const TextStyle headlineSmallDark = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.4,
  );
  
  // ============================================
  // TITLE STYLES - Card titles, list items
  // ============================================
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  // Dark theme variants
  static const TextStyle titleLargeDark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.5,
  );
  
  static const TextStyle titleMediumDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.5,
  );
  
  static const TextStyle titleSmallDark = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.5,
  );
  
  // ============================================
  // BODY STYLES - Main content text
  // ============================================
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  
  // Dark theme variants
  static const TextStyle bodyLargeDark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
    height: 1.5,
  );
  
  static const TextStyle bodyMediumDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
    height: 1.5,
  );
  
  static const TextStyle bodySmallDark = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textLightSecondary,
    height: 1.5,
  );
  
  // ============================================
  // LABEL STYLES - Form labels, captions
  // ============================================
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
  
  // Dark theme variants
  static const TextStyle labelLargeDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
    letterSpacing: 0.1,
  );
  
  static const TextStyle labelMediumDark = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textLightSecondary,
    letterSpacing: 0.5,
  );
  
  static const TextStyle labelSmallDark = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textLightSecondary,
    letterSpacing: 0.5,
  );
  
  // ============================================
  // BUTTON STYLES
  // ============================================
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.75,
    color: AppColors.textLight,
  );
  
  // ============================================
  // PRICE STYLES - E-commerce specific
  // ============================================
  static const TextStyle priceLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    height: 1.2,
  );
  
  static const TextStyle priceMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    height: 1.3,
  );
  
  static const TextStyle priceSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.4,
  );
  
  static const TextStyle priceStrikethrough = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    decoration: TextDecoration.lineThrough,
    decorationThickness: 2,
  );
  
  // Dark theme price variants
  static const TextStyle priceLargeDark = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryLight,
    height: 1.2,
  );
  
  static const TextStyle priceMediumDark = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryLight,
    height: 1.3,
  );
  
  static const TextStyle priceSmallDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryLight,
    height: 1.4,
  );
  
  static const TextStyle priceStrikethroughDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textLightSecondary,
    decoration: TextDecoration.lineThrough,
    decorationThickness: 2,
  );
  
  // ============================================
  // STATUS & SPECIAL STYLES
  // ============================================
  
  // Success styles
  static const TextStyle success = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.success,
  );
  
  static const TextStyle successBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.success,
  );
  
  // Error styles
  static const TextStyle error = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.error,
  );
  
  static const TextStyle errorBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.error,
  );
  
  static const TextStyle errorSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.error,
  );
  
  // Warning styles
  static const TextStyle warning = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.warning,
  );
  
  static const TextStyle warningBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.warning,
  );
  
  // Info styles
  static const TextStyle info = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.info,
  );
  
  static const TextStyle infoBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.info,
  );
  
  // ============================================
  // DISCOUNT & BADGE STYLES
  // ============================================
  static const TextStyle discount = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.discountText,
    letterSpacing: 0.5,
  );
  
  static const TextStyle discountLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.discountText,
    letterSpacing: 0.5,
  );
  
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    letterSpacing: 0.5,
  );
  
  // ============================================
  // SPECIALIZED STYLES
  // ============================================
  
  // AppBar title
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );
  
  static const TextStyle appBarTitleDark = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    letterSpacing: 0,
  );
  
  // Tab bar
  static const TextStyle tabBar = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  // Chip text
  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
  );
  
  // Dialog title
  static const TextStyle dialogTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle dialogTitleDark = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );
  
  // Input text
  static const TextStyle input = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle inputDark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );
  
  // Hint text
  static const TextStyle hint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
  );
  
  static const TextStyle hintDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textLightHint,
  );
  
  // Link text
  static const TextStyle link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
  );
  
  static const TextStyle linkDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryLight,
    decoration: TextDecoration.underline,
  );
  
  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  static const TextStyle captionDark = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textLightSecondary,
    height: 1.4,
  );
  
  // Overline (labels above content)
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );
  
  static const TextStyle overlineDark = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textLightSecondary,
    letterSpacing: 1.5,
  );
  
  // ============================================
  // ORDER STATUS STYLES
  // ============================================
  static const TextStyle orderStatus = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static const TextStyle orderStatusLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Get text style based on theme brightness
  static TextStyle getDisplayLarge(bool isDark) {
    return isDark ? displayLargeDark : displayLarge;
  }
  
  static TextStyle getDisplayMedium(bool isDark) {
    return isDark ? displayMediumDark : displayMedium;
  }
  
  static TextStyle getDisplaySmall(bool isDark) {
    return isDark ? displaySmallDark : displaySmall;
  }
  
  static TextStyle getHeadlineLarge(bool isDark) {
    return isDark ? headlineLargeDark : headlineLarge;
  }
  
  static TextStyle getHeadlineMedium(bool isDark) {
    return isDark ? headlineMediumDark : headlineMedium;
  }
  
  static TextStyle getHeadlineSmall(bool isDark) {
    return isDark ? headlineSmallDark : headlineSmall;
  }
  
  static TextStyle getTitleLarge(bool isDark) {
    return isDark ? titleLargeDark : titleLarge;
  }
  
  static TextStyle getTitleMedium(bool isDark) {
    return isDark ? titleMediumDark : titleMedium;
  }
  
  static TextStyle getTitleSmall(bool isDark) {
    return isDark ? titleSmallDark : titleSmall;
  }
  
  static TextStyle getBodyLarge(bool isDark) {
    return isDark ? bodyLargeDark : bodyLarge;
  }
  
  static TextStyle getBodyMedium(bool isDark) {
    return isDark ? bodyMediumDark : bodyMedium;
  }
  
  static TextStyle getBodySmall(bool isDark) {
    return isDark ? bodySmallDark : bodySmall;
  }
  
  static TextStyle getPriceLarge(bool isDark) {
    return isDark ? priceLargeDark : priceLarge;
  }
  
  static TextStyle getPriceMedium(bool isDark) {
    return isDark ? priceMediumDark : priceMedium;
  }
  
  static TextStyle getPriceSmall(bool isDark) {
    return isDark ? priceSmallDark : priceSmall;
  }
  
  static TextStyle getPriceStrikethrough(bool isDark) {
    return isDark ? priceStrikethroughDark : priceStrikethrough;
  }
  
  /// Get order status text style with color
  static TextStyle getOrderStatusStyle(String status, {bool large = false}) {
    final color = AppColors.getOrderStatusColor(status);
    return large 
        ? orderStatusLarge.copyWith(color: color)
        : orderStatus.copyWith(color: color);
  }
  
  /// Apply custom color to any style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }
  
  /// Apply custom font size to any style
  static TextStyle withFontSize(TextStyle style, double fontSize) {
    return style.copyWith(fontSize: fontSize);
  }
  
  /// Apply bold weight to any style
  static TextStyle toBold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.bold);
  }
  
  /// Apply italic to any style
  static TextStyle toItalic(TextStyle style) {
    return style.copyWith(fontStyle: FontStyle.italic);
  }
  
  /// Apply underline to any style
  static TextStyle withUnderline(TextStyle style) {
    return style.copyWith(decoration: TextDecoration.underline);
  }
  
  /// Scale font size based on device
  static TextStyle scale(TextStyle style, double scaleFactor) {
    return style.copyWith(
      fontSize: (style.fontSize ?? 14) * scaleFactor,
    );
  }
  
  /// Get responsive text style based on screen width
  static TextStyle responsive(
    TextStyle mobile,
    TextStyle tablet,
    TextStyle desktop,
    double screenWidth,
  ) {
    if (screenWidth >= 1100) return desktop;
    if (screenWidth >= 650) return tablet;
    return mobile;
  }
}
