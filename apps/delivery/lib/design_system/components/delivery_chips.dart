import 'package:flutter/material.dart';

import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_badge.dart';
import 'delivery_states.dart';

/// Item descriptor for [DeliveryChipRow] and [DeliverySegmented].
class DeliveryChipItem<T> {
  const DeliveryChipItem({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int? count;
  final Key? key;
}

typedef DeliverySegmentOption<T> = DeliveryChipItem<T>;

/// Horizontally scrollable filter chip bar with optional counts and 48dp hit
/// targets.
class DeliveryChipRow<T> extends StatelessWidget {
  const DeliveryChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: DeliverySpace.lg),
    this.fullWidth = false,
  });

  final List<DeliveryChipItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: DeliverySpace.sm),
            _buildChip(context, c, t, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    DeliveryColors c,
    DeliveryType t,
    DeliveryChipItem<T> item,
  ) {
    final isSelected = item.value == selected;
    return DeliveryInteractive(
      key: item.key,
      onTap: () => onSelected(item.value),
      borderRadius: DeliveryRadius.rFull,
      semanticButton: true,
      semanticLabel: item.label,
      builder: (
        context, {
        required hovered,
        required pressed,
        required focused,
        required enabled,
      }) =>
          ConstrainedBox(
        constraints: const BoxConstraints(minHeight: DeliverySize.chipHeight),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DeliverySpace.lg,
            vertical: DeliverySpace.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? c.brand : c.surface,
            borderRadius: DeliveryRadius.rFull,
            border: Border.all(
              color: isSelected ? c.brand : c.borderStrong,
              width: DeliverySize.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: DeliveryIconSize.sm,
                  color: isSelected ? c.onBrand : c.textSecondary,
                ),
                const SizedBox(width: DeliverySpace.xs),
              ],
              Text(
                item.label,
                style: t.labelMedium.copyWith(
                  color: isSelected ? c.onBrand : c.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (item.count != null) ...[
                const SizedBox(width: DeliverySpace.xs),
                DeliveryCountPill(
                  count: item.count!,
                  selected: isSelected,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width segmented control (e.g. Appearance: System / Light / Dark).
class DeliverySegmented<T> extends StatelessWidget {
  const DeliverySegmented({
    super.key,
    List<DeliveryChipItem<T>>? items,
    List<DeliveryChipItem<T>>? options,
    required this.selected,
    required this.onSelected,
    this.fullWidth = true,
  }) : items = items ?? options ?? const [];

  final List<DeliveryChipItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Container(
      padding: const EdgeInsets.all(DeliverySpace.xxs),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: DeliveryRadius.rMd,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: DeliveryInteractive(
                key: item.key,
                onTap: () => onSelected(item.value),
                borderRadius: DeliveryRadius.rSm,
                semanticButton: true,
                semanticLabel: item.label,
                builder: (
                  context, {
                  required hovered,
                  required pressed,
                  required focused,
                  required enabled,
                }) {
                  final active = item.value == selected;
                  return Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DeliverySpace.sm,
                      vertical: DeliverySpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: active ? c.surface : Colors.transparent,
                      borderRadius: DeliveryRadius.rSm,
                      border: active
                          ? Border.all(color: c.brandBorder)
                          : null,
                      boxShadow: active
                          ? DeliveryElevation.card(c.shadow)
                          : const <BoxShadow>[],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: DeliveryIconSize.sm,
                            color: active ? c.brand : c.textSecondary,
                          ),
                          const SizedBox(width: DeliverySpace.xs),
                        ],
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium.copyWith(
                              color: active ? c.textPrimary : c.textSecondary,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
