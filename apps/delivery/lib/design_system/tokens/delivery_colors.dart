import 'package:flutter/material.dart';

/// Semantic tone used across badges, banners, icon tiles, and illustrations
/// (Phases 01–03, 11–14).
enum DeliveryTone { brand, neutral, success, warning, danger, info }

typedef DeliveryBannerTone = DeliveryTone;
typedef DeliveryBadgeTone = DeliveryTone;

/// A matched foreground + container + solid + border pair for a [DeliveryTone].
@immutable
class DeliveryTonePair {
  const DeliveryTonePair({
    required this.foreground,
    required this.container,
    Color? solid,
    Color? onSolid,
    Color? border,
    Color? icon,
  })  : _solid = solid,
        _onSolid = onSolid,
        _border = border,
        _icon = icon;

  final Color foreground;
  final Color container;
  final Color? _solid;
  final Color? _onSolid;
  final Color? _border;
  final Color? _icon;

  Color get text => foreground;
  Color get fg => foreground;
  Color get bg => container;
  Color get onContainer => foreground;
  Color get solid => _solid ?? foreground;
  Color get onSolid => _onSolid ?? const Color(0xFFFFFFFF);
  Color get border => _border ?? foreground.withValues(alpha: 0.28);
  Color get icon => _icon ?? foreground;
}

/// The AgriMore Delivery Partner colour tokens (Phases 01, 02, 03, 14).
///
/// Primary brand is Burnt Orange (`#C2410C` in light mode, `#FDBA74` in dark
/// mode), paired with warm cream/espresso neutrals (`#FFFAF5` / `#171210`).
/// Never uses green, teal, or blue as a brand colour.
@immutable
class DeliveryColors extends ThemeExtension<DeliveryColors> {
  const DeliveryColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.raised,
    required this.sunken,
    required this.primary,
    required this.onPrimary,
    required this.primaryStrong,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primarySubtle,
    required this.amber,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.controlBorder,
    required this.divider,
    required this.disabledFill,
    required this.disabledText,
    required this.focus,
    required this.focusOnFill,
    required this.focusOnDanger,
    required this.successColor,
    required this.successContainer,
    required this.warningColor,
    required this.warningContainer,
    required this.dangerColor,
    required this.dangerContainer,
    required this.dangerFill,
    required this.onDangerFill,
    required this.infoColor,
    required this.infoContainer,
    required this.toast,
    required this.onToast,
    required this.toastSuccess,
    required this.toastDanger,
    required this.scrim,
  });

  final bool isDark;

  // Surfaces
  final Color background;
  final Color surface;
  final Color raised;
  final Color sunken;

  // Brand (Burnt Orange)
  final Color primary;
  final Color onPrimary;
  final Color primaryStrong;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primarySubtle;
  final Color amber;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Borders & disabled
  final Color border;
  final Color controlBorder;
  final Color divider;
  final Color disabledFill;
  final Color disabledText;

  // Single-border focus tokens (Phase 32)
  final Color focus;
  final Color focusOnFill;
  final Color focusOnDanger;

  // Semantic statuses (paired with icon + text, never colour alone)
  final Color successColor;
  final Color successContainer;
  final Color warningColor;
  final Color warningContainer;
  final Color dangerColor;
  final Color dangerContainer;
  final Color dangerFill;
  final Color onDangerFill;
  final Color infoColor;
  final Color infoContainer;

  // Toasts & overlays
  final Color toast;
  final Color onToast;
  final Color toastSuccess;
  final Color toastDanger;
  final Color scrim;

  // Ergonomic aliases used across components and feature screens
  Color get brand => primary;
  Color get onBrand => onPrimary;
  Color get brandHover => primaryStrong;
  Color get brandPressed => primaryStrong;
  Color get brandContainer => primaryContainer;
  Color get onBrandContainer => onPrimaryContainer;
  Color get brandBorder => primary.withValues(alpha: isDark ? 0.45 : 0.32);
  Color get brandSubtle => primarySubtle;
  Color get surfaceMuted => sunken;
  Color get surfaceVariant => sunken;
  Color get surfaceElevated => raised;
  Color get borderStrong => controlBorder;
  Color get borderSubtle => divider;
  Color get onlineFg => successColor;
  Color get textDisabled => disabledText;
  Color get iconMuted => textTertiary;
  Color get focusRing => focus;
  Color get shadow => const Color(0xFF171210);

  /// The full-screen document/photo viewer's own backdrop + foreground --
  /// deliberately fixed regardless of [isDark] (a photo is shown against a
  /// dark surface with light text/icons either way, the same convention a
  /// system photo viewer uses), same category as [shadow] above.
  Color get mediaViewerBackground => Colors.black;
  Color get onMediaViewer => Colors.white;

  DeliveryTonePair get success => DeliveryTonePair(
        foreground: successColor,
        container: successContainer,
        solid: successColor,
        onSolid: isDark ? const Color(0xFF0A2012) : const Color(0xFFFFFFFF),
        border: successColor.withValues(alpha: 0.32),
      );

  DeliveryTonePair get warning => DeliveryTonePair(
        foreground: warningColor,
        container: warningContainer,
        solid: warningColor,
        onSolid: isDark ? const Color(0xFF231505) : const Color(0xFFFFFFFF),
        border: warningColor.withValues(alpha: 0.34),
      );

  DeliveryTonePair get danger => DeliveryTonePair(
        foreground: dangerColor,
        container: dangerContainer,
        solid: dangerFill,
        onSolid: onDangerFill,
        border: dangerColor.withValues(alpha: 0.34),
      );

  DeliveryTonePair get info => DeliveryTonePair(
        foreground: infoColor,
        container: infoContainer,
        solid: infoColor,
        onSolid: isDark ? const Color(0xFF0B192E) : const Color(0xFFFFFFFF),
        border: infoColor.withValues(alpha: 0.32),
      );

  DeliveryTonePair get neutral => DeliveryTonePair(
        foreground: textSecondary,
        container: sunken,
        solid: textSecondary,
        onSolid: surface,
        border: border,
      );

  /// Light palette (Phases 01–03): warm ivory background `#FFFAF5`, crisp white
  /// cards `#FFFFFF`, burnt orange `#C2410C` primary, deep espresso `#241A16` ink.
  static const DeliveryColors light = DeliveryColors(
    isDark: false,
    background: Color(0xFFFFFAF5),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    sunken: Color(0xFFF5EFEA),
    primary: Color(0xFFC2410C),
    onPrimary: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFF9A3412),
    primaryContainer: Color(0xFFFFEDD5),
    onPrimaryContainer: Color(0xFF7C2D12),
    primarySubtle: Color(0xFFFFF7ED),
    amber: Color(0xFFEA580C),
    textPrimary: Color(0xFF241A16),
    textSecondary: Color(0xFF5C4D46),
    textTertiary: Color(0xFF7A6A62),
    border: Color(0xFFE7DDD6),
    controlBorder: Color(0xFFCFC2B8),
    divider: Color(0xFFEFE6DF),
    disabledFill: Color(0xFFEDE5DF),
    disabledText: Color(0xFF94847B),
    focus: Color(0xFFC2410C),
    focusOnFill: Color(0xFF241A16),
    focusOnDanger: Color(0xFF241A16),
    successColor: Color(0xFF15803D),
    successContainer: Color(0xFFDCFCE7),
    warningColor: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    dangerColor: Color(0xFFB91C1C),
    dangerContainer: Color(0xFFFEE2E2),
    dangerFill: Color(0xFFB91C1C),
    onDangerFill: Color(0xFFFFFFFF),
    infoColor: Color(0xFF1D4ED8),
    infoContainer: Color(0xFFDBEAFE),
    toast: Color(0xFF241A16),
    onToast: Color(0xFFFFFAF5),
    toastSuccess: Color(0xFF86EFAC),
    toastDanger: Color(0xFFFCA5A5),
    scrim: Color(0x80171210),
  );

  /// Dark palette (Phases 03, 14): low-glare warm espresso `#171210` background,
  /// `#251C17` cards, luminous warm amber `#FDBA74` interactive accent with dark
  /// `#2B1206` text on filled controls.
  static const DeliveryColors dark = DeliveryColors(
    isDark: true,
    background: Color(0xFF171210),
    surface: Color(0xFF251C17),
    raised: Color(0xFF2E231D),
    sunken: Color(0xFF120E0C),
    primary: Color(0xFFFDBA74),
    onPrimary: Color(0xFF2B1206),
    primaryStrong: Color(0xFFEA580C),
    primaryContainer: Color(0xFF431E0E),
    onPrimaryContainer: Color(0xFFFFEDD5),
    primarySubtle: Color(0xFF261812),
    amber: Color(0xFFFB923C),
    textPrimary: Color(0xFFF7EFEA),
    textSecondary: Color(0xFFC9B9B0),
    textTertiary: Color(0xFF9A8980),
    border: Color(0xFF3B2E27),
    controlBorder: Color(0xFF57453C),
    divider: Color(0xFF332721),
    disabledFill: Color(0xFF2B211C),
    disabledText: Color(0xFF786860),
    focus: Color(0xFFFDBA74),
    focusOnFill: Color(0xFFFFFFFF),
    focusOnDanger: Color(0xFFFFFFFF),
    successColor: Color(0xFF86EFAC),
    successContainer: Color(0xFF132A1C),
    warningColor: Color(0xFFFCD34D),
    warningContainer: Color(0xFF33210B),
    dangerColor: Color(0xFFFCA5A5),
    dangerContainer: Color(0xFF361515),
    dangerFill: Color(0xFFDC2626),
    onDangerFill: Color(0xFFFFFFFF),
    infoColor: Color(0xFF93C5FD),
    infoContainer: Color(0xFF15233B),
    toast: Color(0xFF362922),
    onToast: Color(0xFFF7EFEA),
    toastSuccess: Color(0xFF86EFAC),
    toastDanger: Color(0xFFFCA5A5),
    scrim: Color(0xB30B0807),
  );

  /// Returns the matched foreground/container pair for [t].
  DeliveryTonePair tone(DeliveryTone t) => switch (t) {
        DeliveryTone.brand => DeliveryTonePair(
            foreground: onPrimaryContainer,
            container: primaryContainer,
            solid: primary,
            onSolid: onPrimary,
            border: brandBorder,
          ),
        DeliveryTone.neutral => neutral,
        DeliveryTone.success => success,
        DeliveryTone.warning => warning,
        DeliveryTone.danger => danger,
        DeliveryTone.info => info,
      };

  @override
  DeliveryColors copyWith({bool? isDark}) =>
      (isDark ?? this.isDark) ? dark : light;

  @override
  DeliveryColors lerp(ThemeExtension<DeliveryColors>? other, double t) {
    if (other is! DeliveryColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension DeliveryColorsContext on BuildContext {
  /// Active [DeliveryColors] from the surrounding [Theme].
  DeliveryColors get colors =>
      Theme.of(this).extension<DeliveryColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? DeliveryColors.dark
          : DeliveryColors.light);
}
