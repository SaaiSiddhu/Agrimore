import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_states.dart';

/// Rider avatar or Monogram badge.
class DeliveryAvatar extends StatelessWidget {
  const DeliveryAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = DeliverySize.avatarMd,
    this.verified = false,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool verified;

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'R';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.brandContainer,
            shape: BoxShape.circle,
            border: Border.all(color: c.brandBorder, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: t.titleMedium.copyWith(
              color: c.onBrandContainer,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: c.success.solid,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                DeliveryIcons.check,
                size: size * 0.22,
                color: c.success.onSolid,
              ),
            ),
          ),
      ],
    );
  }
}

/// Interactive or static list row with leading icon/avatar, title, subtitle,
/// and trailing slot.
class DeliveryListTile extends StatelessWidget {
  const DeliveryListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.tone,
    this.onTap,
    this.showChevron = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DeliverySpace.md,
      vertical: DeliverySpace.md,
    ),
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? leading;
  final Widget? trailing;
  final DeliveryTone? tone;
  final VoidCallback? onTap;
  final bool showChevron;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = tone != null ? c.tone(tone!) : null;

    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: DeliverySpace.md),
          ] else if (leadingIcon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pair?.container ?? c.surfaceMuted,
                borderRadius: DeliveryRadius.rMd,
              ),
              alignment: Alignment.center,
              child: Icon(
                leadingIcon,
                size: DeliveryIconSize.md,
                color: pair?.icon ?? c.textPrimary,
              ),
            ),
            const SizedBox(width: DeliverySpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleSmall.copyWith(
                    color: pair != null && tone == DeliveryTone.danger
                        ? pair.onContainer
                        : c.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: t.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DeliverySpace.sm),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: DeliverySpace.xs),
            Icon(
              DeliveryIcons.chevronRight,
              size: DeliveryIconSize.md,
              color: c.iconMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return DeliveryInteractive(
      onTap: onTap,
      borderRadius: DeliveryRadius.rMd,
      semanticButton: true,
      builder: (
        context, {
        required hovered,
        required pressed,
        required focused,
        required enabled,
      }) =>
          row,
    );
  }
}

/// Key/value metadata row that stacks gracefully at 200% text scale.
class DeliveryKeyValueRow extends StatelessWidget {
  const DeliveryKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.tabular = false,
    this.emphasized = false,
    this.valueTone,
  });

  final String label;
  final String value;
  final bool tabular;
  final bool emphasized;
  final DeliveryTone? valueTone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = valueTone != null ? c.tone(valueTone!) : null;
    final labelStyle =
        emphasized ? t.titleSmall : t.bodyMedium.copyWith(color: c.textSecondary);
    final baseValueStyle = emphasized ? t.titleMedium : t.labelLarge;
    final valueStyle = (tabular ? baseValueStyle.tabular : baseValueStyle)
        .copyWith(color: pair?.onContainer ?? c.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DeliverySpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: labelStyle),
          ),
          const SizedBox(width: DeliverySpace.md),
          Flexible(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
