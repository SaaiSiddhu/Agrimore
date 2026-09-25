import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

/// Approved AgriMore Delivery Partner icon tile (`app_icon_delivery_orange.png`)
/// with graceful vector fallback if asset loading is unavailable in unit tests.
class DeliveryBrandMark extends StatelessWidget {
  const DeliveryBrandMark({
    super.key,
    this.size = 44,
    this.borderRadius,
  });

  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius =
        borderRadius ?? BorderRadius.circular((size * 0.24).clamp(10, 22));
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.brand,
        borderRadius: radius,
        boxShadow: DeliveryElevation.card(c.shadow),
      ),
      child: Image.asset(
        'assets/images/delivery_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(
            DeliveryIcons.bike,
            color: c.onBrand,
            size: size * 0.56,
          ),
        ),
      ),
    );
  }
}

/// Lockup combining [DeliveryBrandMark] with the AgriMore Delivery wordmark
/// and "DELIVERY PARTNER" role pill.
class DeliveryLogo extends StatelessWidget {
  const DeliveryLogo({
    super.key,
    this.markSize = 48,
    this.title = 'AgriMore',
    this.badge = 'DELIVERY PARTNER',
    this.subtitle,
  });

  final double markSize;
  final String title;
  final String badge;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final showSubtitle =
        subtitle != null &&
        subtitle!.trim().isNotEmpty &&
        subtitle!.trim().toLowerCase() != badge.trim().toLowerCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DeliveryBrandMark(size: markSize),
        const SizedBox(width: DeliverySpace.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: DeliverySpace.sm,
                runSpacing: DeliverySpace.xxs,
                children: [
                  Text(
                    title,
                    style: t.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DeliverySpace.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.brandContainer,
                      borderRadius: DeliveryRadius.rFull,
                      border: Border.all(color: c.brandBorder),
                    ),
                    child: Text(
                      badge,
                      style: t.overline.copyWith(
                        color: c.onBrandContainer,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom warm burnt-orange hero artwork for Auth, Onboarding, and Shift state
/// headers. Draws a scenic farm-to-door route ribbon, warm sun disc, and crisp
/// delivery rider emblem.
class DeliveryHeroIllustration extends StatelessWidget {
  const DeliveryHeroIllustration({
    super.key,
    this.height = 136,
    this.icon = DeliveryIcons.bike,
    this.badgeLabel,
    this.title,
    this.subtitle,
  });

  final double height;
  final IconData icon;
  final String? badgeLabel;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final resolvedBadge = badgeLabel ??
        ((title == null && subtitle == null)
            ? 'FARM TO DOOR • PARTNER'
            : null);
    final resolvedTitle =
        title ??
        (subtitle == null ? 'Deliver fresh produce across your city' : null);
    final resolvedSubtitle =
        subtitle ??
        (title == null
            ? 'Clear routes, transparent trip pay, and weekly bank payouts.'
            : null);

    return Container(
      constraints: BoxConstraints(minHeight: height),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.isDark
              ? const [Color(0xFF3A1A0B), Color(0xFF231610)]
              : const [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
        ),
        borderRadius: DeliveryRadius.rXl,
        border: Border.all(color: c.brandBorder),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HeroRouteArtworkPainter(
                accent: c.brand,
                secondary: c.brandBorder,
                isDark: c.isDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DeliverySpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (resolvedBadge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DeliverySpace.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface.withValues(alpha: 0.9),
                            borderRadius: DeliveryRadius.rFull,
                            border: Border.all(color: c.brandBorder),
                          ),
                          child: Text(
                            resolvedBadge.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.overline.copyWith(
                              color: c.onBrandContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: DeliverySpace.xs),
                      ],
                      if (resolvedTitle != null)
                        Text(
                          resolvedTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium.copyWith(
                            color: c.onBrandContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (resolvedSubtitle != null) ...[
                        const SizedBox(height: DeliverySpace.xxs),
                        Text(
                          resolvedSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall.copyWith(
                            color: c.onBrandContainer.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DeliverySpace.md),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.brand,
                    borderRadius: DeliveryRadius.rLg,
                    boxShadow: DeliveryElevation.raised(c.shadow),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: DeliveryIconSize.xl,
                    color: c.onBrand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRouteArtworkPainter extends CustomPainter {
  _HeroRouteArtworkPainter({
    required this.accent,
    required this.secondary,
    required this.isDark,
  });

  final Color accent;
  final Color secondary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final sunPaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.16 : 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.22),
      size.height * 0.55,
      sunPaint,
    );

    final hillPaint = Paint()
      ..color = secondary.withValues(alpha: isDark ? 0.22 : 0.35)
      ..style = PaintingStyle.fill;
    final hillPath = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.62,
        size.width * 0.62,
        size.height * 0.84,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.96,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    final routePaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final routePath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.88)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.54,
        size.width * 0.55,
        size.height * 0.92,
        size.width * 0.82,
        size.height * 0.48,
      );
    canvas.drawPath(routePath, routePaint);
  }

  @override
  bool shouldRepaint(covariant _HeroRouteArtworkPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.isDark != isDark;
}

/// Custom vector vehicle silhouette for the 6 rider vehicle classes in
/// Registration Step 2 & Profile (`bike`, `scooter`, `ev`, `bicycle`,
/// `three_wheeler`, `car_van`).
class DeliveryVehicleIllustration extends StatelessWidget {
  const DeliveryVehicleIllustration({
    super.key,
    required this.vehicleType,
    this.selected = false,
    this.size = 44,
  });

  final String vehicleType;
  final bool selected;
  final double size;

  IconData get _icon => switch (vehicleType) {
        'bicycle' => DeliveryIcons.bicycle,
        'three_wheeler' || 'auto' => DeliveryIcons.truck,
        'car' || 'van' || 'car_van' => DeliveryIcons.car,
        'ev' || 'electric' => DeliveryIcons.zap,
        _ => DeliveryIcons.bike,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = selected ? c.brand : c.surfaceMuted;
    final fg = selected ? c.onBrand : c.onBrandContainer;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DeliveryRadius.rMd,
        border: Border.all(
          color: selected ? c.brand : c.border,
          width: DeliverySize.stroke,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(_icon, size: size * 0.52, color: fg),
    );
  }
}

enum DeliveryIllustrationKind {
  empty,
  emptyHistory,
  offline,
  kycReview,
  kycRejected,
  orderComplete,
  warning,
  error,
}

/// Soft geometric badge illustration for empty, offline, waiting, and KYC
/// verification states.
class DeliveryIllustration extends StatelessWidget {
  const DeliveryIllustration({
    super.key,
    this.icon,
    this.kind,
    DeliveryTone? tone,
    this.size = 76,
    this.secondaryIcon,
  }) : _tone = tone;

  final IconData? icon;
  final DeliveryIllustrationKind? kind;
  final DeliveryTone? _tone;
  final double size;
  final IconData? secondaryIcon;

  IconData get _effectiveIcon =>
      icon ??
      switch (kind) {
        DeliveryIllustrationKind.emptyHistory => DeliveryIcons.history,
        DeliveryIllustrationKind.offline => DeliveryIcons.offline,
        DeliveryIllustrationKind.kycReview => DeliveryIcons.hourglass,
        DeliveryIllustrationKind.kycRejected => DeliveryIcons.documentWarning,
        DeliveryIllustrationKind.orderComplete => DeliveryIcons.checkCircle,
        DeliveryIllustrationKind.warning => DeliveryIcons.warning,
        DeliveryIllustrationKind.error => DeliveryIcons.danger,
        _ => DeliveryIcons.package,
      };

  DeliveryTone get _effectiveTone =>
      _tone ??
      switch (kind) {
        DeliveryIllustrationKind.kycReview ||
        DeliveryIllustrationKind.warning =>
          DeliveryTone.warning,
        DeliveryIllustrationKind.kycRejected ||
        DeliveryIllustrationKind.error =>
          DeliveryTone.danger,
        DeliveryIllustrationKind.orderComplete => DeliveryTone.success,
        DeliveryIllustrationKind.empty ||
        DeliveryIllustrationKind.emptyHistory ||
        DeliveryIllustrationKind.offline =>
          DeliveryTone.neutral,
        null => DeliveryTone.brand,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pair = c.tone(_effectiveTone);
    return SizedBox(
      width: size + 16,
      height: size + 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: pair.container,
              shape: BoxShape.circle,
              border: Border.all(
                color: pair.border,
                width: DeliverySize.strokeStrong,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              _effectiveIcon,
              size: size * 0.44,
              color: pair.icon,
            ),
          ),
          if (secondaryIcon != null)
            Positioned(
              right: 2,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: pair.solid,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  secondaryIcon,
                  size: 14,
                  color: pair.onSolid,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Canonical 6-vehicle taxonomy for Registration Step 2 & Profile (Phase 16).
enum DeliveryVehicleKind {
  bicycle('bicycle'),
  motorcycle('bike'),
  scooter('scooter'),
  evTwoWheeler('ev'),
  autoThreeWheeler('three_wheeler'),
  miniTruck('van');

  const DeliveryVehicleKind(this.wire);
  final String wire;
}

class DeliveryVehicleOption {
  const DeliveryVehicleOption({
    required this.kind,
    required this.label,
    this.subtitle,
  });

  final DeliveryVehicleKind kind;
  final String label;
  final String? subtitle;
}

/// Visual 2-column selector grid for the 6 vehicle classes in Registration Step 2.
class DeliveryVehicleSelector extends StatelessWidget {
  const DeliveryVehicleSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.options,
  });

  final DeliveryVehicleKind selected;
  final ValueChanged<DeliveryVehicleKind> onSelected;
  final List<DeliveryVehicleOption> options;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 290;
        final tileWidth = twoCol
            ? (constraints.maxWidth - DeliverySpace.sm) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: DeliverySpace.sm,
          runSpacing: DeliverySpace.sm,
          children: [
            for (final opt in options)
              SizedBox(
                width: tileWidth,
                child: Material(
                  color: opt.kind == selected ? c.brandContainer : c.surface,
                  borderRadius: DeliveryRadius.rLg,
                  child: InkWell(
                    borderRadius: DeliveryRadius.rLg,
                    onTap: () => onSelected(opt.kind),
                    child: Container(
                      padding: const EdgeInsets.all(DeliverySpace.md),
                      decoration: BoxDecoration(
                        borderRadius: DeliveryRadius.rLg,
                        border: Border.all(
                          color: opt.kind == selected ? c.brand : c.border,
                          width: opt.kind == selected
                              ? DeliverySize.strokeStrong
                              : DeliverySize.stroke,
                        ),
                      ),
                      child: Row(
                        children: [
                          DeliveryVehicleIllustration(
                            vehicleType: opt.kind.wire,
                            selected: opt.kind == selected,
                            size: 40,
                          ),
                          const SizedBox(width: DeliverySpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  opt.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.labelMedium.copyWith(
                                    color: opt.kind == selected
                                        ? c.onBrandContainer
                                        : c.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (opt.subtitle != null)
                                  Text(
                                    opt.subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(
                                      color: opt.kind == selected
                                          ? c.onBrandContainer
                                              .withValues(alpha: 0.85)
                                          : c.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Top environment ribbon shown only when non-production or seeded test data
/// is active.
class DeliveryTestDataRibbon extends StatelessWidget {
  const DeliveryTestDataRibbon({
    super.key,
    required this.label,
    this.visible = false,
  });

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final c = context.colors;
    final t = context.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.md,
        vertical: DeliverySpace.xxs,
      ),
      color: c.warning.container,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            DeliveryIcons.flask,
            size: DeliveryIconSize.xs,
            color: c.warning.icon,
          ),
          const SizedBox(width: DeliverySpace.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.overline.copyWith(color: c.warning.onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
