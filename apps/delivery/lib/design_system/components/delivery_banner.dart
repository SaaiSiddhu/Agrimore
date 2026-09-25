import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_button.dart';

/// Semantic alert banner with icon, title, body, and optional action button.
class DeliveryBanner extends StatelessWidget {
  const DeliveryBanner({
    super.key,
    this.title,
    this.body,
    this.tone = DeliveryTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.dense = false,
  });

  final String? title;
  final String? body;
  final DeliveryTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool dense;

  IconData get _defaultIcon => switch (tone) {
        DeliveryTone.brand => DeliveryIcons.bike,
        DeliveryTone.success => DeliveryIcons.verified,
        DeliveryTone.warning => DeliveryIcons.warning,
        DeliveryTone.danger => DeliveryIcons.danger,
        DeliveryTone.info => DeliveryIcons.info,
        DeliveryTone.neutral => DeliveryIcons.info,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = c.tone(tone);
    final hasTitle = title != null && title!.isNotEmpty;
    final hasBody = body != null && body!.isNotEmpty;

    return Semantics(
      container: true,
      liveRegion: tone == DeliveryTone.danger || tone == DeliveryTone.warning,
      child: Container(
        padding: EdgeInsets.all(dense ? DeliverySpace.md : DeliverySpace.lg),
        decoration: BoxDecoration(
          color: pair.container,
          borderRadius: DeliveryRadius.rMd,
          border: Border.all(color: pair.border, width: DeliverySize.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: pair.solid.withValues(alpha: 0.14),
                    borderRadius: DeliveryRadius.rSm,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon ?? _defaultIcon,
                    size: DeliveryIconSize.md,
                    color: pair.icon,
                  ),
                ),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle)
                        Text(
                          title!,
                          style: t.titleSmall.copyWith(color: pair.onContainer),
                        ),
                      if (hasTitle && hasBody)
                        const SizedBox(height: DeliverySpace.xxs),
                      if (hasBody)
                        Text(
                          body!,
                          style: (hasTitle ? t.bodySmall : t.bodyMedium)
                              .copyWith(color: pair.onContainer),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: DeliverySpace.sm),
                  trailing!,
                ],
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DeliverySpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: DeliveryButton.secondary(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  size: DeliveryButtonSize.sm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
