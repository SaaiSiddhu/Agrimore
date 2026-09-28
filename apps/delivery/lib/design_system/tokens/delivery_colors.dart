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

/// The AgriMore Delivery Partner colour tokens (Phases 01, 02, 03, 14, DLVHOME1).
///
/// OWNER_DECISION 2026-09-28 (`docs/design-system/DELIVERY_HOME_REDESIGN_2026-09-28.md`):
/// monochrome foundations -- light mode is white with black foreground and
/// primary actions, dark mode is black with white foreground and primary
/// actions. Burnt Orange (`#C2410C` light / `#FDBA74` dark) is no longer the
/// dominant [primary]/[brand] colour; it survives unchanged as the separate
/// [accent] family, used only where the app deliberately wants the brand
/// mark (e.g. the Home app bar's emergency icon), never as the default fill
/// for buttons, chips, badges, selected states, or the nav bar. Supersedes
/// the Phase 01-03 "Primary brand is Burnt Orange" direction for [primary]
/// itself; [accent] carries that palette forward unchanged.
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
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
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

  // Primary actions (DLVHOME1: monochrome -- black-on-white light, white-on-black dark)
  final Color primary;
  final Color onPrimary;
  final Color primaryStrong;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primarySubtle;

  // Restrained brand accent (DLVHOME1: the former dominant primary, Burnt
  // Orange, kept verbatim but demoted to occasional deliberate use only).
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

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

  /// Light palette (DLVHOME1, 2026-09-28): true-white foundation `#FFFFFF`,
  /// near-black `#171717` as the primary/foreground colour, neutral greys for
  /// secondary surfaces/borders/disabled/secondary text. Burnt orange
  /// `#C2410C` survives only as [accent] (unchanged from the former primary).
  static const DeliveryColors light = DeliveryColors(
    isDark: false,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    sunken: Color(0xFFF5F5F5),
    primary: Color(0xFF171717),
    onPrimary: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFF000000),
    primaryContainer: Color(0xFFF0F0F0),
    onPrimaryContainer: Color(0xFF171717),
    primarySubtle: Color(0xFFFAFAFA),
    accent: Color(0xFFC2410C),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFFEDD5),
    onAccentContainer: Color(0xFF7C2D12),
    amber: Color(0xFFEA580C),
    textPrimary: Color(0xFF171717),
    textSecondary: Color(0xFF525252),
    textTertiary: Color(0xFF737373),
    border: Color(0xFFE5E5E5),
    controlBorder: Color(0xFFD4D4D4),
    divider: Color(0xFFEDEDED),
    disabledFill: Color(0xFFF0F0F0),
    disabledText: Color(0xFFA3A3A3),
    focus: Color(0xFF171717),
    focusOnFill: Color(0xFF171717),
    focusOnDanger: Color(0xFF171717),
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
    toast: Color(0xFF171717),
    onToast: Color(0xFFFFFFFF),
    toastSuccess: Color(0xFF86EFAC),
    toastDanger: Color(0xFFFCA5A5),
    scrim: Color(0x80000000),
  );

  /// Dark palette (DLVHOME1, 2026-09-28): true-black foundation `#000000`,
  /// near-white `#F5F5F5` as the primary/foreground colour, neutral greys for
  /// secondary surfaces/borders/disabled/secondary text. Burnt orange
  /// `#FDBA74` survives only as [accent] (unchanged from the former primary).
  static const DeliveryColors dark = DeliveryColors(
    isDark: true,
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    raised: Color(0xFF1A1A1A),
    sunken: Color(0xFF000000),
    primary: Color(0xFFF5F5F5),
    onPrimary: Color(0xFF0A0A0A),
    primaryStrong: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF262626),
    onPrimaryContainer: Color(0xFFF5F5F5),
    primarySubtle: Color(0xFF1A1A1A),
    accent: Color(0xFFFDBA74),
    onAccent: Color(0xFF2B1206),
    accentContainer: Color(0xFF431E0E),
    onAccentContainer: Color(0xFFFFEDD5),
    amber: Color(0xFFFB923C),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA3A3A3),
    textTertiary: Color(0xFF737373),
    border: Color(0xFF2E2E2E),
    controlBorder: Color(0xFF404040),
    divider: Color(0xFF262626),
    disabledFill: Color(0xFF1F1F1F),
    disabledText: Color(0xFF595959),
    focus: Color(0xFFF5F5F5),
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
    toast: Color(0xFF262626),
    onToast: Color(0xFFF5F5F5),
    toastSuccess: Color(0xFF86EFAC),
    toastDanger: Color(0xFFFCA5A5),
    scrim: Color(0xB3000000),
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
