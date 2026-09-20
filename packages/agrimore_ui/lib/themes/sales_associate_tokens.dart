// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

/// Sales Associate canonical design token set.
///
/// All values are **light-theme** and come from the canonical reference boards
/// (apps/employee/assets/Canonical/).  Do not modify these values without a
/// corresponding board update — they are the single source of truth for the
/// Sales Associate app's visual identity.
///
/// **Isolation guarantee**: no value here changes [AppColors.primary] or any
/// other shared constant.  These constants are consumed only by
/// [SalesAssociateTheme] and the [SalesAssociateTokens] extension — other
/// apps are not affected.
abstract final class SaTokens {
  SaTokens._();

  // ──────────────────────────────────────────────────────────────────────────
  // Primary palette
  // ──────────────────────────────────────────────────────────────────────────

  /// Actions & selection — #2563EB.
  static const Color primary = Color(0xFF2563EB);

  /// Pressed / active state — #1D4ED8.
  static const Color primaryPressed = Color(0xFF1D4ED8);

  /// Info surface / subtle background — #EFF6FF.
  static const Color primarySubtle = Color(0xFFEFF6FF);

  // ──────────────────────────────────────────────────────────────────────────
  // Neutral foundations
  // ──────────────────────────────────────────────────────────────────────────

  /// Page background — #F8FAFC.
  static const Color pageBackground = Color(0xFFF8FAFC);

  /// Card / surface — #FFFFFF.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text — #0F172A.
  static const Color textPrimary = Color(0xFF0F172A);

  /// Secondary text — #475569.
  static const Color textSecondary = Color(0xFF475569);

  /// Subtle divider — #E2E8F0.
  static const Color divider = Color(0xFFE2E8F0);

  /// Input / control boundary — #64748B.
  static const Color inputBorder = Color(0xFF64748B);

  // ──────────────────────────────────────────────────────────────────────────
  // Semantic accents
  // ──────────────────────────────────────────────────────────────────────────

  /// Success foreground — #15803D.
  static const Color successFg = Color(0xFF15803D);

  /// Success surface — #F0FDF4.
  static const Color successBg = Color(0xFFF0FDF4);

  /// Warning foreground — #B45309.
  static const Color warningFg = Color(0xFFB45309);

  /// Warning surface — #FFFBEB.
  static const Color warningBg = Color(0xFFFFFBEB);

  /// Error foreground — #B91C1C.
  static const Color errorFg = Color(0xFFB91C1C);

  /// Error surface — #FEF2F2.
  static const Color errorBg = Color(0xFFFEF2F2);

  // ──────────────────────────────────────────────────────────────────────────
  // Disabled state (derived — not in the board, needed for components)
  // ──────────────────────────────────────────────────────────────────────────

  /// Disabled container colour — same as divider.
  static const Color disabledContainer = Color(0xFFE2E8F0);

  /// Disabled content (foreground on disabled container).
  static const Color disabledContent = Color(0xFF94A3B8);

  // ──────────────────────────────────────────────────────────────────────────
  // Dark mode foundations (slate-900 / slate-800 scale)
  // ──────────────────────────────────────────────────────────────────────────

  /// Dark page background — #0F172A (slate-900).
  static const Color darkPageBackground = Color(0xFF0F172A);

  /// Dark card / surface — #1E293B (slate-800).
  static const Color darkSurface = Color(0xFF1E293B);

  /// Dark elevated surface — #334155 (slate-700).
  static const Color darkSurfaceElevated = Color(0xFF334155);

  /// Dark primary text — #F8FAFC (slate-50).
  static const Color darkTextPrimary = Color(0xFFF8FAFC);

  /// Dark secondary text — #94A3B8 (slate-400).
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  /// Dark divider — #334155 (slate-700).
  static const Color darkDivider = Color(0xFF334155);

  /// Dark input / control boundary — #475569 (slate-600).
  static const Color darkInputBorder = Color(0xFF475569);

  /// Dark primary subtle container — #172554 (blue-950).
  static const Color darkPrimarySubtle = Color(0xFF172554);

  /// Dark primary accent (high contrast on dark surfaces) — #3B82F6.
  static const Color darkPrimary = Color(0xFF3B82F6);

  /// Dark primary pressed — #60A5FA.
  static const Color darkPrimaryPressed = Color(0xFF60A5FA);

  /// Dark success foreground — #4ADE80.
  static const Color darkSuccessFg = Color(0xFF4ADE80);

  /// Dark success surface — #052E16.
  static const Color darkSuccessBg = Color(0xFF052E16);

  /// Dark warning foreground — #FBBF24.
  static const Color darkWarningFg = Color(0xFFFBBF24);

  /// Dark warning surface — #451A03.
  static const Color darkWarningBg = Color(0xFF451A03);

  /// Dark error foreground — #F87171.
  static const Color darkErrorFg = Color(0xFFF87171);

  /// Dark error surface — #450A0A.
  static const Color darkErrorBg = Color(0xFF450A0A);

  /// Dark disabled container — #334155.
  static const Color darkDisabledContainer = Color(0xFF334155);

  /// Dark disabled content — #64748B.
  static const Color darkDisabledContent = Color(0xFF64748B);

  // ──────────────────────────────────────────────────────────────────────────
  // Spacing scale (logical pixels)
  // ──────────────────────────────────────────────────────────────────────────

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ──────────────────────────────────────────────────────────────────────────
  // Layout constants
  // ──────────────────────────────────────────────────────────────────────────

  /// Horizontal page padding (20 px).
  static const double pagePadding = 20;

  /// Minimum interactive touch target (48 × 48).
  static const double minTouchTarget = 48;

  /// Standard control height (52 px).
  static const double controlHeight = 52;

  // ──────────────────────────────────────────────────────────────────────────
  // Shape / corner radii
  // ──────────────────────────────────────────────────────────────────────────

  /// Input fields and buttons — 12 px.
  static const double radiusInput = 12;

  /// Cards — 16 px.
  static const double radiusCard = 16;

  /// Bottom sheet top corners — 24 px.
  static const double radiusBottomSheet = 24;

  // ──────────────────────────────────────────────────────────────────────────
  // Typography scale
  // All sizes are logical pixels (sp-equivalent in Flutter's scalable sizing).
  // Font: Inter (google_fonts).  Weights use FontWeight constants.
  // ──────────────────────────────────────────────────────────────────────────

  /// Display amount — 32 sp / line height 40 / semibold (600).
  static const double fsDisplayAmount = 32;
  static const double lhDisplayAmount = 40;
  static const FontWeight fwDisplayAmount = FontWeight.w600;

  /// Screen title — 24 sp / 32 / semibold (600).
  static const double fsScreenTitle = 24;
  static const double lhScreenTitle = 32;
  static const FontWeight fwScreenTitle = FontWeight.w600;

  /// Section heading — 18 sp / 26 / semibold (600).
  static const double fsSectionHeading = 18;
  static const double lhSectionHeading = 26;
  static const FontWeight fwSectionHeading = FontWeight.w600;

  /// Body — 16 sp / 24 / regular (400).
  static const double fsBody = 16;
  static const double lhBody = 24;
  static const FontWeight fwBody = FontWeight.w400;

  /// Label / form label — 14 sp / 20 / medium (500).
  static const double fsLabel = 14;
  static const double lhLabel = 20;
  static const FontWeight fwLabel = FontWeight.w500;

  /// Caption — 12 sp / 18 / regular (400).
  static const double fsCaption = 12;
  static const double lhCaption = 18;
  static const FontWeight fwCaption = FontWeight.w400;

  // ──────────────────────────────────────────────────────────────────────────
  // Icon sizes (logical pixels)
  // ──────────────────────────────────────────────────────────────────────────

  /// Supporting icons (in-list, hints) — 16 px.
  static const double iconSupporting = 16;

  /// Control icons (buttons, inputs) — 20 px.
  static const double iconControl = 20;

  /// Navigation icons (bottom bar, primary nav) — 24 px.
  static const double iconNav = 24;
}
