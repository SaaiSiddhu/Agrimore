import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

/// Semantic status pill with optional leading dot or icon.
///
/// Never communicates state by colour alone — always pairs text + icon/dot +
/// border.
class DeliveryBadge extends StatelessWidget {
  const DeliveryBadge({
    super.key,
    required this.label,
    this.tone = DeliveryTone.neutral,
    this.icon,
    this.showDot = false,
    this.solid = false,
    this.tabular = false,
  });

  final String label;
  final DeliveryTone tone;
  final IconData? icon;
  final bool showDot;
  final bool solid;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = c.tone(tone);
    final bg = solid ? pair.solid : pair.container;
    final fg = solid ? pair.onSolid : pair.onContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.sm,
        vertical: DeliverySpace.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DeliveryRadius.rFull,
        border: Border.all(
          color: solid ? pair.solid : pair.border,
          width: DeliverySize.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: DeliveryIconSize.xs, color: fg),
            const SizedBox(width: DeliverySpace.xs),
          ] else if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: solid ? pair.onSolid : pair.solid,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DeliverySpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (tabular ? t.caption.tabular : t.caption).copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric count pill for tabs, filters, and unread counters.
class DeliveryCountPill extends StatelessWidget {
  const DeliveryCountPill({
    super.key,
    required this.count,
    this.selected = false,
    this.tone,
  });

  final int count;
  final bool selected;
  final DeliveryTone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = tone != null ? c.tone(tone!) : null;
    final bg = pair != null
        ? pair.container
        : (selected ? c.brand : c.surfaceMuted);
    final fg = pair != null
        ? pair.onContainer
        : (selected ? c.onBrand : c.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DeliveryRadius.rFull,
      ),
      child: Text(
        '$count',
        style: t.caption.tabular.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Circular SLA / offer countdown ring with tabular seconds display.
///
/// Automatically transitions from brand orange (`> 10s`) to warning amber
/// (`<= 10s`) to danger crimson (`<= 5s`).
class DeliveryCountdownRing extends StatelessWidget {
  const DeliveryCountdownRing({
    super.key,
    int? remainingSeconds,
    int? secondsLeft,
    this.totalSeconds = 30,
    this.fractionLeft,
    this.size = 68,
    String? caption,
    String? unitLabel,
    this.urgent,
  })  : remainingSeconds = remainingSeconds ?? secondsLeft ?? 0,
        caption = caption ?? unitLabel;

  final int remainingSeconds;
  final int totalSeconds;
  final double? fractionLeft;
  final double size;
  final String? caption;
  final bool? urgent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final clamped = remainingSeconds.clamp(0, totalSeconds);
    final progress = fractionLeft != null
        ? fractionLeft!.clamp(0.0, 1.0)
        : (totalSeconds > 0 ? clamped / totalSeconds : 0.0);

    final DeliveryTonePair pair;
    if (urgent == true || clamped <= 5) {
      pair = c.danger;
    } else if (clamped <= 10) {
      pair = c.warning;
    } else {
      pair = c.tone(DeliveryTone.brand);
    }

    return Semantics(
      label: '$clamped ${caption ?? 'seconds'}',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CountdownRingPainter(
            progress: progress,
            trackColor: pair.border.withValues(alpha: 0.45),
            ringColor: pair.solid,
            fillColor: pair.container,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${clamped}s',
                      style: t.titleMedium.tabular.copyWith(
                        color: pair.onContainer,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    if (caption != null)
                      Text(
                        caption!,
                        style: t.caption.copyWith(
                          color: pair.onContainer,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    required this.fillColor,
  });

  final double progress;
  final Color trackColor;
  final Color ringColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final bgPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.trackColor != trackColor;
}
