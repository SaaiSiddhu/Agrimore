import 'package:flutter/material.dart';

import 'seller_colors.dart';

/// Seller type scale (boards 02 and 05; decisions D3). Inter is bundled with
/// the app (assets/fonts, SIL OFL 1.1) — no runtime font download.
abstract final class SellerType {
  static const String fontFamily = 'Inter';

  /// Money, quantities, counts and IDs line up and do not jitter.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Builds the text theme for a palette. Role → use:
  /// - displayLarge 32/40 bold — hero amounts
  /// - displayMedium 40/48 bold — score numbers
  /// - headlineMedium 24/32 semibold — root screen titles
  /// - titleLarge 20/28 semibold — detail titles, card titles
  /// - titleMedium 18/24 semibold — section headings
  /// - titleSmall 16/24 semibold — list-item titles, order numbers
  /// - bodyLarge 16/24 — body
  /// - bodyMedium 14/20 — secondary body (muted)
  /// - labelLarge 14/20 semibold — buttons, field labels, chips
  /// - bodySmall 12/16 — captions, helper text (muted)
  /// - labelMedium 12/16 semibold — badges
  /// - labelSmall 11/16 semibold, tracked — overlines, chart axes
  static TextTheme textTheme(SellerColors c) {
    TextStyle s(double size, double height, FontWeight weight, Color color, {double? tracking}) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          color: color,
          letterSpacing: tracking,
        );
    return TextTheme(
      displayLarge: s(32, 40, bold, c.textPrimary, tracking: -0.5),
      displayMedium: s(40, 48, bold, c.textPrimary, tracking: -0.5),
      displaySmall: s(28, 36, bold, c.textPrimary, tracking: -0.25),
      headlineLarge: s(28, 36, bold, c.textPrimary, tracking: -0.25),
      headlineMedium: s(24, 32, semibold, c.textPrimary, tracking: -0.25),
      headlineSmall: s(22, 28, semibold, c.textPrimary),
      titleLarge: s(20, 28, semibold, c.textPrimary),
      titleMedium: s(18, 24, semibold, c.textPrimary),
      titleSmall: s(16, 24, semibold, c.textPrimary),
      bodyLarge: s(16, 24, regular, c.textPrimary),
      bodyMedium: s(14, 20, regular, c.textSecondary),
      bodySmall: s(12, 16, regular, c.textSecondary),
      labelLarge: s(14, 20, semibold, c.textPrimary),
      labelMedium: s(12, 16, semibold, c.textSecondary),
      labelSmall: s(11, 16, semibold, c.textSecondary, tracking: 0.4),
    );
  }
}

extension SellerTextContext on BuildContext {
  /// The seller text theme.
  TextTheme get text => Theme.of(this).textTheme;
}

extension SellerTextStyleX on TextStyle {
  /// Tabular figures for money, quantities and IDs.
  TextStyle get tabular => copyWith(fontFeatures: SellerType.tabular);
}
