import 'package:flutter/material.dart';

import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_states.dart';

enum DeliveryCardVariant { standard, muted, brand, outlined, elevated }

/// Surface container for Delivery sections, orders, route stops, and settings.
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DeliverySpace.lg),
    this.margin = EdgeInsets.zero,
    this.variant = DeliveryCardVariant.standard,
    this.tone,
    this.onTap,
    this.semanticLabel,
    this.borderRadius = DeliveryRadius.rLg,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final DeliveryCardVariant variant;
  final DeliveryTone? tone;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final BorderRadius borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pair = tone != null ? c.tone(tone!) : null;

    final (Color bg, Color borderColor, List<BoxShadow> shadows) =
        switch (variant) {
      DeliveryCardVariant.standard => (
          pair?.container ?? c.surface,
          pair?.border ?? c.border,
          DeliveryElevation.card(c.shadow),
        ),
      DeliveryCardVariant.muted => (
          pair?.container ?? c.surfaceMuted,
          pair?.border ?? c.border,
          const <BoxShadow>[],
        ),
      DeliveryCardVariant.brand => (
          c.brandContainer,
          c.brandBorder,
          DeliveryElevation.card(c.shadow),
        ),
      DeliveryCardVariant.outlined => (
          c.surface,
          pair?.border ?? c.borderStrong,
          const <BoxShadow>[],
        ),
      DeliveryCardVariant.elevated => (
          c.surfaceElevated,
          c.border,
          DeliveryElevation.raised(c.shadow),
        ),
    };

    Widget buildSurface({
      bool hovered = false,
      bool pressed = false,
    }) {
      final effectiveBorder =
          hovered || pressed ? c.brandBorder : borderColor;
      return Container(
        margin: margin,
        clipBehavior: clipBehavior,
        decoration: BoxDecoration(
          color: pressed
              ? Color.alphaBlend(
                  c.brand.withValues(alpha: DeliveryOpacity.hover),
                  bg,
                )
              : bg,
          borderRadius: borderRadius,
          border: Border.all(
            color: effectiveBorder,
            width: DeliverySize.stroke,
          ),
          boxShadow: shadows,
        ),
        padding: padding,
        child: child,
      );
    }

    if (onTap == null) {
      return buildSurface();
    }

    return DeliveryInteractive(
      onTap: onTap,
      borderRadius: borderRadius,
      semanticButton: true,
      semanticLabel: semanticLabel,
      builder: (context, {required hovered, required pressed, required focused, required enabled}) =>
          buildSurface(hovered: hovered, pressed: pressed),
    );
  }
}

/// Section header with title, optional subtitle, and trailing action.
class DeliverySectionHeader extends StatelessWidget {
  const DeliverySectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: DeliverySpace.md),
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: t.overline.copyWith(color: c.brand),
                  ),
                  const SizedBox(height: DeliverySpace.xxs),
                ],
                Text(title, style: t.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: DeliverySpace.xxs),
                  Text(
                    subtitle!,
                    style: t.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DeliverySpace.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
