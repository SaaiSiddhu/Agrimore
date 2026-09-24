import 'package:flutter/painting.dart';

/// Spacing, sizes, radii and layout of the seller design system
/// (boards 02 "design tokens" and 04 "responsive layouts"; decisions D3).
///
/// These are the only numbers a seller screen uses for layout.

/// 4-pt spacing scale.
abstract final class SellerSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  /// Horizontal page inset: 16 on phones, 24 from the medium breakpoint (board 04).
  static const double page = 16;
  static const double pageWide = 24;

  /// Inner padding of cards.
  static const double card = 16;

  /// Gap between page sections.
  static const double section = 24;
}

/// Corner radii (board 02: 4 · 8 · 12 · 16 · full).
abstract final class SellerRadius {
  static const double xs = 4;

  /// Buttons, fields, segmented controls, small tiles, thumbnails.
  static const double control = 8;
  static const double card = 12;
  static const double dialog = 16;
  static const double sheet = 20;
  static const double pill = 999;
}

/// Component sizes.
abstract final class SellerSize {
  static const double hairline = 1;

  /// Resting border of outlined buttons.
  static const double outline = 1.5;

  /// Focused border of fields, cards, rows, chips, nav items (same outline, heavier).
  static const double focus = 2;

  /// Focused border of buttons.
  static const double focusStrong = 3;

  /// Standard control height and the minimum touch target (board 02: 48 × 48).
  static const double control = 48;
  static const double controlCompact = 40;
  static const double touchTarget = 48;
  static const double fab = 56;
  static const double chip = 36;

  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
  static const double avatarXl = 72;

  static const double thumbSm = 40;
  static const double thumbMd = 56;
  static const double thumbLg = 72;
  static const double thumbXl = 88;

  /// Bottom navigation bar content height (labels always shown).
  static const double navBar = 64;
  static const double navIndicatorWidth = 56;
  static const double navIndicatorHeight = 32;
  static const double rail = 88;

  /// Width of the list pane in list + detail layouts.
  static const double listPane = 380;

  /// Readable content widths (board 04).
  static const double formMaxWidth = 640;
  static const double contentMaxWidth = 1200;

  static const double progressTrack = 8;
  static const double chartHeight = 180;
  static const double sparklineHeight = 40;
  static const double scoreRing = 120;
  static const double scoreRingSmall = 48;
  static const double ringStroke = 10;
  static const double dot = 8;
  static const double handle = 4;
  static const double handleWidth = 36;
  static const double illustration = 120;

  /// Storefront logo (88) and how far it overlaps the cover (half of it).
  /// Height of the sign-in landscape (board 16-01).
  static const double farmScene = 140;

  static const double storefrontLogo = 88;
  static const double storefrontLogoOverlap = 44;
}

/// Icon sizes (board 06: 16 / 20 / 24 / 32).
abstract final class SellerIconSize {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Opacity steps (board 02).
abstract final class SellerOpacity {
  static const double disabled = 0.38;
  static const double secondary = 0.6;
  static const double hover = 0.06;
  static const double pressed = 0.12;
  static const double selection = 0.3;
}

/// Shadows — light mode only; dark mode uses tonal surface steps (board 02:
/// raised 0/2/8 @ 8 %, overlay 0/8/24 @ 12 %, tint #134E4A).
abstract final class SellerElevation {
  static const List<BoxShadow> none = <BoxShadow>[];
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x14134E4A), offset: Offset(0, 2), blurRadius: 8),
  ];
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x1F134E4A), offset: Offset(0, 8), blurRadius: 24),
  ];
}

/// Window-width breakpoints (board 04: compact < 600, medium 600–839, expanded ≥ 840).
abstract final class SellerBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
}

enum SellerLayout { compact, medium, expanded, large }

SellerLayout sellerLayoutFor(double width) {
  if (width >= SellerBreakpoints.large) return SellerLayout.large;
  if (width >= SellerBreakpoints.expanded) return SellerLayout.expanded;
  if (width >= SellerBreakpoints.medium) return SellerLayout.medium;
  return SellerLayout.compact;
}
