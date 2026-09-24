import 'package:flutter/material.dart';

/// Every colour role a seller screen may use — the seller app's own palette
/// (docs/seller-redesign/decisions.md D0, D1; boards 01–03).
///
/// Read it with `context.colors`. Screens never write a colour literal: if a
/// role is missing, it is added here first.
///
/// Contrast (asserted in test/design_system/seller_colors_test.dart): every
/// text role ≥ 4.5:1 on the surfaces it is used on, control boundaries and
/// focus borders ≥ 3:1.
@immutable
class SellerColors extends ThemeExtension<SellerColors> {
  const SellerColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.sunken,
    required this.primary,
    required this.onPrimary,
    required this.primaryStrong,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primarySubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.controlBorder,
    required this.disabledFill,
    required this.disabledText,
    required this.scrim,
    required this.focus,
    required this.focusOnFill,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.dangerFill,
    required this.onDangerFill,
    required this.focusOnDanger,
    required this.info,
    required this.infoContainer,
    required this.toast,
    required this.onToast,
    required this.toastSuccess,
    required this.toastDanger,
    required this.leaf,
    required this.chart,
  });

  final Brightness brightness;

  // Surfaces, from back to front.
  /// Page background ("canvas").
  final Color canvas;
  final Color surface;

  /// Raised surfaces (menus, sheets in dark mode). Dark mode uses tonal steps,
  /// not shadows.
  final Color raised;

  /// Search fields, skeletons, image placeholders.
  final Color sunken;

  // Brand.
  final Color primary;
  final Color onPrimary;

  /// Pressed state and the deep-teal brand ink.
  final Color primaryStrong;

  /// Mint: selected nav item, selected chips, tonal buttons, hero tiles.
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Tinted cards and informational surfaces.
  final Color primarySubtle;

  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Decorative borders and dividers (cards, lists).
  final Color border;

  /// Boundaries that identify a control (fields, checkboxes, off switches) — ≥ 3:1.
  final Color controlBorder;

  final Color disabledFill;
  final Color disabledText;
  final Color scrim;

  /// Keyboard focus: the control's own outline, heavier, in this colour.
  final Color focus;

  /// Keyboard focus on a filled control (e.g. a primary button), where [focus]
  /// would disappear into the fill.
  final Color focusOnFill;

  // Status — foreground and its container.
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;

  /// Fill of destructive buttons and its label colour.
  final Color dangerFill;
  final Color onDangerFill;

  /// Keyboard focus stroke on a [dangerFill] control.
  final Color focusOnDanger;
  final Color info;
  final Color infoContainer;

  // Toast (transient message) — its own inverse pair so status icons stay legible.
  final Color toast;
  final Color onToast;
  final Color toastSuccess;
  final Color toastDanger;

  /// Second leaf of the brand mark.
  final Color leaf;

  /// Ordered chart series; series 1 is always the brand.
  final List<Color> chart;

  bool get isDark => brightness == Brightness.dark;

  static const SellerColors light = SellerColors(
    brightness: Brightness.light,
    canvas: Color(0xFFF5F8F7),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    sunken: Color(0xFFEDF3F1),
    primary: Color(0xFF0F766E), // 5.47:1 with white
    onPrimary: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFF134E4A),
    primaryContainer: Color(0xFFDDF3EA), // mint
    onPrimaryContainer: Color(0xFF0F766E), // 4.71:1 on mint
    primarySubtle: Color(0xFFEEF8F4),
    textPrimary: Color(0xFF142D2A),
    textSecondary: Color(0xFF526660),
    textTertiary: Color(0xFF5A6E68),
    border: Color(0xFFD8E3DF),
    controlBorder: Color(0xFF7C8F89), // 3.42:1 on white, 3.20:1 on canvas
    disabledFill: Color(0xFFE3EAE7),
    disabledText: Color(0xFF8A9B96),
    scrim: Color(0x660B1513),
    focus: Color(0xFF0F766E),
    focusOnFill: Color(0xFF06100E), // 3.53:1 on the teal fill, 19.3:1 on white
    success: Color(0xFF15803D),
    successContainer: Color(0xFFEEF8F1),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFDF3E3),
    danger: Color(0xFFB91C1C),
    dangerContainer: Color(0xFFFDECEC),
    dangerFill: Color(0xFFB91C1C),
    onDangerFill: Color(0xFFFFFFFF), // 6.47:1
    focusOnDanger: Color(0xFF000000), // 3.25:1 on the red fill
    info: Color(0xFF1D4ED8),
    infoContainer: Color(0xFFEAF0FD),
    toast: Color(0xFF134E4A),
    onToast: Color(0xFFFFFFFF),
    toastSuccess: Color(0xFF86EFAC),
    toastDanger: Color(0xFFFCA5A5),
    leaf: Color(0xFF15803D),
    chart: [
      Color(0xFF0F766E),
      Color(0xFF2563EB),
      Color(0xFFB45309),
      Color(0xFF7C3AED),
      Color(0xFFBE123C),
      Color(0xFF475569),
    ],
  );

  static const SellerColors dark = SellerColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF050908), // near-black
    surface: Color(0xFF0B1513), // teal-black
    raised: Color(0xFF12221E),
    sunken: Color(0xFF08100E),
    primary: Color(0xFF5EEAD4), // dark accent
    onPrimary: Color(0xFF042F2E), // 9.78:1
    primaryStrong: Color(0xFF2DD4BF),
    primaryContainer: Color(0xFF134E4A),
    onPrimaryContainer: Color(0xFF5EEAD4), // 6.41:1
    primarySubtle: Color(0xFF0D2622),
    textPrimary: Color(0xFFECFDF5),
    textSecondary: Color(0xFFA3B8B0),
    textTertiary: Color(0xFF8FA69E),
    border: Color(0xFF29433A),
    controlBorder: Color(0xFF5F7D74), // 4.13:1 on the surface
    disabledFill: Color(0xFF1A2B27),
    disabledText: Color(0xFF5E7169),
    scrim: Color(0xA3000000),
    focus: Color(0xFF5EEAD4),
    focusOnFill: Color(0xFF0F766E), // 3.70:1 on the fill, 3.66:1 on the page
    success: Color(0xFF86EFAC),
    successContainer: Color(0xFF0E2A1B),
    warning: Color(0xFFFCD34D),
    warningContainer: Color(0xFF2C2108),
    danger: Color(0xFFFCA5A5),
    dangerContainer: Color(0xFF321515),
    dangerFill: Color(0xFFDC2626),
    onDangerFill: Color(0xFFFFFFFF), // 4.83:1
    focusOnDanger: Color(0xFFECFDF5), // 4.6:1 on the red fill
    info: Color(0xFF93C5FD),
    infoContainer: Color(0xFF0F1E38),
    toast: Color(0xFF1C332E),
    onToast: Color(0xFFECFDF5),
    toastSuccess: Color(0xFF86EFAC),
    toastDanger: Color(0xFFFCA5A5),
    leaf: Color(0xFF86EFAC),
    chart: [
      Color(0xFF5EEAD4),
      Color(0xFF60A5FA),
      Color(0xFFFBBF24),
      Color(0xFFA78BFA),
      Color(0xFFFB7185),
      Color(0xFF94A3B8),
    ],
  );

  @override
  SellerColors copyWith({Brightness? brightness}) => brightness == null || brightness == this.brightness
      ? this
      : (brightness == Brightness.dark ? dark : light);

  @override
  SellerColors lerp(SellerColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SellerColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      sunken: l(sunken, other.sunken),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      primarySubtle: l(primarySubtle, other.primarySubtle),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      border: l(border, other.border),
      controlBorder: l(controlBorder, other.controlBorder),
      disabledFill: l(disabledFill, other.disabledFill),
      disabledText: l(disabledText, other.disabledText),
      scrim: l(scrim, other.scrim),
      focus: l(focus, other.focus),
      focusOnFill: l(focusOnFill, other.focusOnFill),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      dangerFill: l(dangerFill, other.dangerFill),
      onDangerFill: l(onDangerFill, other.onDangerFill),
      focusOnDanger: l(focusOnDanger, other.focusOnDanger),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
      toast: l(toast, other.toast),
      onToast: l(onToast, other.onToast),
      toastSuccess: l(toastSuccess, other.toastSuccess),
      toastDanger: l(toastDanger, other.toastDanger),
      leaf: l(leaf, other.leaf),
      chart: [
        for (var i = 0; i < chart.length; i++) i < other.chart.length ? l(chart[i], other.chart[i]) : chart[i],
      ],
    );
  }
}

/// The tone of a status: drives colour AND the icon that repeats its meaning
/// (never colour alone — board 24-06).
enum SellerTone { neutral, brand, success, warning, danger, info }

/// Foreground / container pair for a [SellerTone].
@immutable
class SellerTonePair {
  const SellerTonePair(this.foreground, this.container);
  final Color foreground;
  final Color container;
}

extension SellerColorsTones on SellerColors {
  SellerTonePair tone(SellerTone tone) => switch (tone) {
        SellerTone.neutral => SellerTonePair(textSecondary, sunken),
        SellerTone.brand => SellerTonePair(onPrimaryContainer, primaryContainer),
        SellerTone.success => SellerTonePair(success, successContainer),
        SellerTone.warning => SellerTonePair(warning, warningContainer),
        SellerTone.danger => SellerTonePair(danger, dangerContainer),
        SellerTone.info => SellerTonePair(info, infoContainer),
      };
}

extension SellerColorsContext on BuildContext {
  /// The active seller palette (light or dark).
  SellerColors get colors {
    final theme = Theme.of(this);
    return theme.extension<SellerColors>() ??
        (theme.brightness == Brightness.dark ? SellerColors.dark : SellerColors.light);
  }
}
