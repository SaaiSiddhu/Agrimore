import 'package:flutter/material.dart';

import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_card.dart';

/// Compact KPI tile with tabular numeric value, label, and optional icon/caption.
class DeliveryMetricTile extends StatelessWidget {
  const DeliveryMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.tone = DeliveryTone.brand,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final DeliveryTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final pair = c.tone(tone);

    return DeliveryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DeliverySpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: pair.container,
                    borderRadius: DeliveryRadius.rSm,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: DeliveryIconSize.sm,
                    color: pair.icon,
                  ),
                ),
                const SizedBox(width: DeliverySpace.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: DeliverySpace.sm),
          Text(
            value,
            style: t.headlineMedium.tabular.copyWith(color: c.textPrimary),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: DeliverySpace.xxs),
            Text(
              caption!,
              style: t.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Line item descriptor for [DeliveryMoneyBreakdown].
class DeliveryMoneyLine {
  const DeliveryMoneyLine({
    required this.label,
    required this.amount,
    this.caption,
    this.isTotal = false,
    this.isDeduction = false,
    this.tone,
  });

  final String label;
  final String amount;
  final String? caption;
  final bool isTotal;
  final bool isDeduction;
  final DeliveryTone? tone;
}

/// Structured ledger card for Weekly Statements, Payout Breakdowns, and Order
/// Earnings. Uses tabular numerals on every currency figure.
class DeliveryMoneyBreakdown extends StatelessWidget {
  const DeliveryMoneyBreakdown({
    super.key,
    required this.lines,
    this.title,
    this.footer,
  });

  final List<DeliveryMoneyLine> lines;
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return DeliveryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: t.titleMedium),
            const SizedBox(height: DeliverySpace.md),
          ],
          for (var i = 0; i < lines.length; i++) ...[
            if (lines[i].isTotal && i > 0) ...[
              const SizedBox(height: DeliverySpace.xs),
              Divider(height: 1, color: c.border),
              const SizedBox(height: DeliverySpace.sm),
            ],
            _buildLine(c, t, lines[i]),
            if (i < lines.length - 1 && !lines[i + 1].isTotal)
              const SizedBox(height: DeliverySpace.sm),
          ],
          if (footer != null) ...[
            const SizedBox(height: DeliverySpace.md),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _buildLine(DeliveryColors c, DeliveryType t, DeliveryMoneyLine line) {
    final pair = line.tone != null ? c.tone(line.tone!) : null;
    final amountColor = pair?.onContainer ??
        (line.isDeduction
            ? c.warning.onContainer
            : line.isTotal
                ? c.brand
                : c.textPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                line.label,
                style: line.isTotal
                    ? t.titleMedium
                    : t.bodyMedium.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(width: DeliverySpace.md),
            Text(
              line.amount,
              style: (line.isTotal
                      ? t.titleLarge.tabular
                      : t.labelLarge.tabular)
                  .copyWith(color: amountColor),
            ),
          ],
        ),
        if (line.caption != null && line.caption!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            line.caption!,
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ],
    );
  }
}
