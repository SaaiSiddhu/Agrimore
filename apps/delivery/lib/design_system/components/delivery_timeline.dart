import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

enum DeliveryTimelineStepState { completed, active, upcoming, error }

class DeliveryTimelineStep {
  const DeliveryTimelineStep({
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.state = DeliveryTimelineStepState.upcoming,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final DeliveryTimelineStepState state;
}

/// Horizontal step indicator for multi-step registration and active order
/// progress (`0 .. totalSteps - 1`).
class DeliveryStepIndicator extends StatelessWidget {
  const DeliveryStepIndicator({
    super.key,
    required this.currentStep,
    required this.labels,
    this.onStepTap,
  });

  final int currentStep;
  final List<String> labels;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List<Widget>.generate(labels.length * 2 - 1, (idx) {
            if (idx.isOdd) {
              final stepBefore = idx ~/ 2;
              final done = stepBefore < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(
                    horizontal: DeliverySpace.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: done ? c.brand : c.border,
                    borderRadius: DeliveryRadius.rFull,
                  ),
                ),
              );
            }
            final step = idx ~/ 2;
            final isDone = step < currentStep;
            final isCurrent = step == currentStep;
            final bg = isDone
                ? c.success.solid
                : isCurrent
                    ? c.brand
                    : c.surfaceMuted;
            final fg = isDone
                ? c.success.onSolid
                : isCurrent
                    ? c.onBrand
                    : c.textTertiary;

            return GestureDetector(
              onTap: onStepTap != null && step <= currentStep
                  ? () => onStepTap!(step)
                  : null,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent
                        ? c.brand
                        : isDone
                            ? c.success.solid
                            : c.borderStrong,
                  ),
                ),
                alignment: Alignment.center,
                child: isDone
                    ? Icon(DeliveryIcons.check, size: 14, color: fg)
                    : Text(
                        '${step + 1}',
                        style: t.caption.tabular.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            );
          }),
        ),
        const SizedBox(height: DeliverySpace.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                labels[currentStep.clamp(0, labels.length - 1)],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelMedium.copyWith(color: c.brand),
              ),
            ),
            Text(
              '${currentStep + 1} / ${labels.length}',
              style: t.caption.tabular.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vertical timeline used for Pickup -> Drop route stops and KYC progress.
class DeliveryRouteTimeline extends StatelessWidget {
  const DeliveryRouteTimeline({
    super.key,
    required this.steps,
  });

  final List<DeliveryTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      _buildNode(c, steps[i], i),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: steps[i].state ==
                                    DeliveryTimelineStepState.completed
                                ? c.success.solid
                                : c.borderStrong,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < steps.length - 1 ? DeliverySpace.lg : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                steps[i].title,
                                style: t.titleSmall.copyWith(
                                  color: steps[i].state ==
                                          DeliveryTimelineStepState.upcoming
                                      ? c.textSecondary
                                      : c.textPrimary,
                                ),
                              ),
                              if (steps[i].subtitle != null &&
                                  steps[i].subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  steps[i].subtitle!,
                                  style: t.bodySmall.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (steps[i].trailing != null) ...[
                          const SizedBox(width: DeliverySpace.sm),
                          steps[i].trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNode(DeliveryColors c, DeliveryTimelineStep step, int index) {
    final (Color bg, Color fg, Color border, IconData defaultIcon) =
        switch (step.state) {
      DeliveryTimelineStepState.completed => (
          c.success.solid,
          c.success.onSolid,
          c.success.solid,
          DeliveryIcons.check,
        ),
      DeliveryTimelineStepState.active => (
          c.brand,
          c.onBrand,
          c.brand,
          index == 0 ? DeliveryIcons.pickup : DeliveryIcons.dropoff,
        ),
      DeliveryTimelineStepState.error => (
          c.danger.solid,
          c.danger.onSolid,
          c.danger.solid,
          DeliveryIcons.danger,
        ),
      DeliveryTimelineStepState.upcoming => (
          c.surfaceMuted,
          c.textSecondary,
          c.borderStrong,
          index == 0 ? DeliveryIcons.pickup : DeliveryIcons.dropoff,
        ),
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: DeliverySize.stroke),
      ),
      alignment: Alignment.center,
      child: Icon(step.icon ?? defaultIcon, size: 14, color: fg),
    );
  }
}

/// Stylized route map canvas header used on Incoming Offer and Active Order
/// screens to visualize pickup -> drop corridor, distance pill, and GPS status.
class DeliveryMapHeader extends StatelessWidget {
  const DeliveryMapHeader({
    super.key,
    required this.pickupLabel,
    required this.dropLabel,
    this.distanceLabel,
    this.statusBadge,
    this.height = 148,
  });

  final String pickupLabel;
  final String dropLabel;
  final String? distanceLabel;
  final Widget? statusBadge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF1F1916) : const Color(0xFFF6EFE7),
        borderRadius: DeliveryRadius.rLg,
        border: Border.all(color: c.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RouteCorridorMapPainter(
                gridColor: c.border.withValues(alpha: 0.65),
                routeColor: c.brand,
                pickupColor: c.brand,
                dropColor: c.success.solid,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DeliverySpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (distanceLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DeliverySpace.sm,
                          vertical: DeliverySpace.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.94),
                          borderRadius: DeliveryRadius.rFull,
                          border: Border.all(color: c.brandBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              DeliveryIcons.route,
                              size: DeliveryIconSize.xs,
                              color: c.brand,
                            ),
                            const SizedBox(width: DeliverySpace.xs),
                            Text(
                              distanceLabel!,
                              style: t.labelSmall.tabular.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (statusBadge != null) statusBadge!,
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _MapEndpointChip(
                        icon: DeliveryIcons.store,
                        toneColor: c.brand,
                        label: pickupLabel,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DeliverySpace.xs,
                      ),
                      child: Icon(
                        DeliveryIcons.forward,
                        size: DeliveryIconSize.sm,
                        color: c.brand,
                      ),
                    ),
                    Expanded(
                      child: _MapEndpointChip(
                        icon: DeliveryIcons.dropoff,
                        toneColor: c.success.solid,
                        label: dropLabel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapEndpointChip extends StatelessWidget {
  const _MapEndpointChip({
    required this.icon,
    required this.toneColor,
    required this.label,
  });

  final IconData icon;
  final Color toneColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.sm,
        vertical: DeliverySpace.xs,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        borderRadius: DeliveryRadius.rSm,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: DeliveryIconSize.xs, color: toneColor),
          const SizedBox(width: DeliverySpace.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCorridorMapPainter extends CustomPainter {
  _RouteCorridorMapPainter({
    required this.gridColor,
    required this.routeColor,
    required this.pickupColor,
    required this.dropColor,
  });

  final Color gridColor;
  final Color routeColor;
  final Color pickupColor;
  final Color dropColor;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i < 5; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }

    final start = Offset(size.width * 0.18, size.height * 0.56);
    final end = Offset(size.width * 0.82, size.height * 0.42);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.25,
        size.width * 0.58,
        size.height * 0.72,
        end.dx,
        end.dy,
      );

    final haloPaint = Paint()
      ..color = routeColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, haloPaint);

    final linePaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    canvas.drawCircle(start, 6, Paint()..color = pickupColor);
    canvas.drawCircle(end, 6, Paint()..color = dropColor);
  }

  @override
  bool shouldRepaint(covariant _RouteCorridorMapPainter oldDelegate) =>
      oldDelegate.routeColor != routeColor ||
      oldDelegate.gridColor != gridColor;
}
