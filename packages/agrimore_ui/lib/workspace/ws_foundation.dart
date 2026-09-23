// ignore_for_file: public_member_api_docs

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../themes/sales_associate_tokens.dart';

/// Brand-neutral foundation of the AgriMore Workspace design system — the
/// system shared by the Sales Associate (blue) and Seller (teal) apps.
///
/// Source of truth: `docs/design-system/SELLER_APP_CANONICAL_ADR.md` §5.
/// Every value that already exists in [SaTokens] is REFERENCED from it, not
/// copied, so the Sales Associate board stays the single source for the
/// shared foundation. Values marked "new" were added by phase UI-TEAL-0.
///
/// Screens never use literals: spacing, radii, sizes, type, motion,
/// elevation and breakpoints come from these classes, colours from
/// `context.ws` ([WorkspaceTokens]).

/// 4-pt spacing scale.
abstract final class WsSpace {
  WsSpace._();
  static const double s2 = 2; // new
  static const double s4 = SaTokens.space4;
  static const double s8 = SaTokens.space8;
  static const double s12 = SaTokens.space12;
  static const double s16 = SaTokens.space16;
  static const double s20 = 20; // new
  static const double s24 = SaTokens.space24;
  static const double s32 = SaTokens.space32;
  static const double s40 = 40; // new
  static const double s48 = SaTokens.space48;
  static const double s64 = 64; // new

  /// Horizontal page padding per layout class.
  static const double page = SaTokens.pagePadding;
  static const double pageTablet = 24; // new
  static const double pageDesktop = 32; // new
}

/// Corner radii.
abstract final class WsRadius {
  WsRadius._();
  static const double small = 8; // new — badges, thumbnails
  static const double input = SaTokens.radiusInput;
  static const double card = SaTokens.radiusCard;
  static const double sheet = SaTokens.radiusBottomSheet;
  static const double pill = 999; // new
}

/// Component and layout sizes.
abstract final class WsSize {
  WsSize._();
  static const double hairline = 1; // new
  static const double focusRing = 2; // new
  static const double outline = 1.5; // outlined-button border (as SA)
  static const double controlHeight = SaTokens.controlHeight;
  static const double controlHeightCompact = 40; // new
  static const double minTouchTarget = SaTokens.minTouchTarget;
  static const double chipHeight = 32; // new
  static const double avatarSm = 32; // new
  static const double avatarMd = 40; // new
  static const double avatarLg = 64; // new
  static const double thumbSm = 48; // new
  static const double thumbMd = 64; // new
  static const double thumbLg = 96; // new
  static const double bottomBarHeight = 64; // new
  static const double railWidth = 88; // new
  static const double railWidthExpanded = 256; // new
  static const double contentMaxWidth = 1280; // new
  static const double formMaxWidth = 560; // new
}

/// Icon sizes.
abstract final class WsIconSize {
  WsIconSize._();
  static const double supporting = SaTokens.iconSupporting;
  static const double control = SaTokens.iconControl;
  static const double nav = SaTokens.iconNav;
  static const double feature = 32; // new
  static const double empty = 48; // new
}

/// Type scale — the six Sales Associate levels plus three the seller UX needs.
/// Font: Inter, bundled in `agrimore_ui` (see [fontFamily]).
abstract final class WsType {
  WsType._();

  /// Bundled Inter, namespaced by the package that declares it.
  static const String fontFamily = 'packages/agrimore_ui/Inter';

  static const double fsDisplayHero = 40; // new
  static const double lhDisplayHero = 48; // new
  static const double fsDisplayAmount = SaTokens.fsDisplayAmount;
  static const double lhDisplayAmount = SaTokens.lhDisplayAmount;
  static const double fsScreenTitle = SaTokens.fsScreenTitle;
  static const double lhScreenTitle = SaTokens.lhScreenTitle;
  static const double fsSectionHeading = SaTokens.fsSectionHeading;
  static const double lhSectionHeading = SaTokens.lhSectionHeading;
  static const double fsTitleSmall = 16; // new
  static const double lhTitleSmall = 24; // new
  static const double fsBody = SaTokens.fsBody;
  static const double lhBody = SaTokens.lhBody;
  static const double fsLabel = SaTokens.fsLabel;
  static const double lhLabel = SaTokens.lhLabel;
  static const double fsCaption = SaTokens.fsCaption;
  static const double lhCaption = SaTokens.lhCaption;
  static const double fsMicro = 11; // new
  static const double lhMicro = 16; // new

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static const double trackingDisplay = -0.5;
  static const double trackingTitle = -0.25;
  static const double trackingMicro = 0.4; // new — uppercase overlines

  /// Money, quantities, counts and IDs align in columns and do not jitter
  /// while updating.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}

/// Motion. Collapse to [instant] when `MediaQuery.disableAnimations` is set.
abstract final class WsMotion {
  WsMotion._();
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration emphasized = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 480);

  static const Curve curveStandard = Cubic(0.2, 0, 0, 1);
  static const Curve curveEnter = Cubic(0, 0, 0, 1);
  static const Curve curveExit = Cubic(0.3, 0, 1, 1);
}

/// Opacity steps for states and scrims.
abstract final class WsOpacity {
  WsOpacity._();
  static const double disabled = 0.38;
  static const double hover = 0.08;
  static const double pressed = 0.12;
  static const double scrim = 0.48;
  static const double scrimDark = 0.64;
  static const double focusRingLight = 0.40;
  static const double focusRingDark = 0.50;
}

/// Shadows. Cards stay flat with a divider border (level 0); shadows are
/// for sticky bars, menus and sheets in LIGHT mode only — dark mode uses
/// surface steps instead.
/// Shadow ink is slate-900 (`#0F172A`) at 6 / 8 / 12 %.
abstract final class WsElevation {
  WsElevation._();

  static const List<BoxShadow> level0 = <BoxShadow>[];
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 3),
  ];
  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x140F172A), offset: Offset(0, 4), blurRadius: 12),
  ];
  static const List<BoxShadow> level3 = [
    BoxShadow(color: Color(0x1F0F172A), offset: Offset(0, 12), blurRadius: 32),
  ];
}

/// Layout breakpoints (logical px of the window width).
abstract final class WsBreakpoints {
  WsBreakpoints._();
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
}

/// The layout class of a width, per [WsBreakpoints].
enum WsLayout { compact, medium, expanded, large }

WsLayout wsLayoutFor(double width) {
  if (width >= WsBreakpoints.large) return WsLayout.large;
  if (width >= WsBreakpoints.expanded) return WsLayout.expanded;
  if (width >= WsBreakpoints.medium) return WsLayout.medium;
  return WsLayout.compact;
}
