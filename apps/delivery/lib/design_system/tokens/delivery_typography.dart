import 'package:flutter/material.dart';

import 'delivery_colors.dart';

/// Delivery Partner typography scale (Phases 02, 05).
/// Uses bundled Inter 4.1 (`assets/fonts/Inter-*.ttf`) with tabular numerals
/// (`tnum`) for money, distances, timers, OTP boxes, and order IDs.
class DeliveryType {
  const DeliveryType(this._c);

  final DeliveryColors _c;

  static const String fontFamily = 'Inter';

  /// Tabular numerals prevent jitter in live countdowns, distances, and rupees.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle _s(
    double size,
    double height,
    FontWeight weight,
    Color color, {
    double? tracking,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color,
        letterSpacing: tracking,
      );

  TextStyle get displayLarge => _s(32, 40, bold, _c.textPrimary, tracking: -0.5);
  TextStyle get displayMedium =>
      _s(40, 48, bold, _c.textPrimary, tracking: -0.5);
  TextStyle get displaySmall =>
      _s(28, 36, bold, _c.textPrimary, tracking: -0.25);
  TextStyle get headlineLarge =>
      _s(28, 36, bold, _c.textPrimary, tracking: -0.25);
  TextStyle get headlineMedium =>
      _s(24, 32, semibold, _c.textPrimary, tracking: -0.25);
  TextStyle get headlineSmall => _s(22, 28, semibold, _c.textPrimary);
  TextStyle get titleLarge => _s(20, 28, semibold, _c.textPrimary);
  TextStyle get titleMedium => _s(18, 24, semibold, _c.textPrimary);
  TextStyle get titleSmall => _s(16, 24, semibold, _c.textPrimary);
  TextStyle get bodyLarge => _s(16, 24, regular, _c.textPrimary);
  TextStyle get bodyMedium => _s(14, 20, regular, _c.textSecondary);
  TextStyle get bodySmall => _s(12, 16, regular, _c.textSecondary);
  TextStyle get labelLarge => _s(14, 20, semibold, _c.textPrimary);
  TextStyle get labelMedium => _s(12, 16, semibold, _c.textSecondary);
  TextStyle get labelSmall =>
      _s(11, 16, semibold, _c.textSecondary, tracking: 0.4);
  TextStyle get caption => _s(12, 16, medium, _c.textSecondary);
  TextStyle get overline =>
      _s(11, 16, bold, _c.textSecondary, tracking: 0.6);

  static TextTheme textTheme(DeliveryColors c) {
    final t = DeliveryType(c);
    return TextTheme(
      displayLarge: t.displayLarge,
      displayMedium: t.displayMedium,
      displaySmall: t.displaySmall,
      headlineLarge: t.headlineLarge,
      headlineMedium: t.headlineMedium,
      headlineSmall: t.headlineSmall,
      titleLarge: t.titleLarge,
      titleMedium: t.titleMedium,
      titleSmall: t.titleSmall,
      bodyLarge: t.bodyLarge,
      bodyMedium: t.bodyMedium,
      bodySmall: t.bodySmall,
      labelLarge: t.labelLarge,
      labelMedium: t.labelMedium,
      labelSmall: t.labelSmall,
    );
  }
}

extension DeliveryTextContext on BuildContext {
  /// Non-null [DeliveryType] scale bound to active [DeliveryColors].
  DeliveryType get text => DeliveryType(colors);
}

extension DeliveryTextStyleX on TextStyle {
  /// Applies tabular numerals (`tnum`) for ₹ amounts, distances, timers, and IDs.
  TextStyle get tabular => copyWith(fontFeatures: DeliveryType.tabular);
}
