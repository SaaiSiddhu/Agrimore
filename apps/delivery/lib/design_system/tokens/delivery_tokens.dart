import 'package:flutter/painting.dart';

/// 4 dp spatial scale for the Delivery Partner app (Phases 02, 04).
abstract final class DeliverySpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  // T-shirt aliases
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal screen inset on compact phones (< 600 dp).
  static const double page = 16;

  /// Horizontal screen inset on medium/expanded layouts (≥ 600 dp).
  static const double pageWide = 24;

  /// Default inner padding of a card.
  static const double card = 16;

  /// Vertical rhythm between major sections.
  static const double section = 20;
}

/// Corner radii (Phase 02).
abstract final class DeliveryRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double control = 8;
  static const double card = 12;
  static const double dialog = 16;
  static const double sheet = 20;
  static const double pill = 999;

  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(control));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(card));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius rFull = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Control dimensions, stroke widths, and responsive breakpoints (Phases 02, 04, 32).
abstract final class DeliverySize {
  // Borders & focus outlines
  static const double hairline = 1;
  static const double outline = 1.5;
  static const double focus = 2;
  static const double focusStrong = 3;

  static const double stroke = hairline;
  static const double strokeStrong = outline;
  static const double strokeFocus = focus;

  // Controls & touch targets (minimum 48 x 48 dp per Phase 32)
  static const double touchTarget = 48;
  static const double minTouch = touchTarget;
  static const double control = 48;
  static const double controlLarge = 52;
  static const double controlCompact = 40;
  static const double buttonSm = 40;
  static const double buttonMd = 48;
  static const double buttonLg = 52;
  static const double chip = 36;
  static const double chipHeight = 40;
  static const double dot = 8;
  static const double fab = 56;

  // Navigation
  static const double navBar = 64;
  static const double navIndicatorWidth = 56;
  static const double navIndicatorHeight = 32;
  static const double rail = 88;

  // Avatars, thumbnails & illustrations
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
  static const double avatarXl = 72;
  static const double thumbMd = 56;
  static const double thumbLg = 88;
  static const double illustration = 112;
  static const double heroScene = 136;
  static const double countdownRing = 128;
  static const double mapHeight = 220;

  // DLVHOME1: bounded preview heights for the active-work states
  // (loading/single/multiple/error) when shown inside HomeOperationsPanel's
  // scrollable list, where their own internal `Center` needs a finite
  // height to lay out correctly.
  static const double workPreviewCompact = 240;
  static const double workPreviewMedium = 280;
  static const double workPreviewLarge = 320;

  // Responsive layout bounds (Phase 04)
  static const double formMaxWidth = 560;
  static const double compactMax = 600;
  static const double mediumMax = 840;
  static const double listPane = 360;
}

/// Icon sizes on a 24 dp grid with 2 px stroke (Phases 02, 06).
abstract final class DeliveryIconSize {
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double hero = 48;
}

/// State overlay opacities (Phase 02).
abstract final class DeliveryOpacity {
  static const double hover = 0.06;
  static const double pressed = 0.12;
  static const double selection = 0.16;
  static const double disabled = 0.38;
}

/// Elevation levels (Phase 02: flat bordered cards in dark mode, subtle lift in light).
abstract final class DeliveryElevation {
  static const double flat = 0;
  static const double raisedLevel = 1;
  static const double floating = 3;
  static const double modal = 6;

  static List<BoxShadow> card(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> raised(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> stickyBottom(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ];
}

/// Responsive window classes & layout bounds (Phase 04).
enum DeliveryLayoutClass { compact, medium, expanded }

abstract final class DeliveryLayout {
  static const double compactMax = DeliverySize.compactMax;
  static const double mediumMax = DeliverySize.mediumMax;
  static const double contentMaxWidth = 640;
  static const double formMaxWidth = DeliverySize.formMaxWidth;
}

DeliveryLayoutClass deliveryLayoutFor(double width) {
  if (width < DeliverySize.compactMax) return DeliveryLayoutClass.compact;
  if (width < DeliverySize.mediumMax) return DeliveryLayoutClass.medium;
  return DeliveryLayoutClass.expanded;
}
