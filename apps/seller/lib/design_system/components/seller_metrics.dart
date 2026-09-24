import 'package:flutter/material.dart';

import '../icons/seller_icons.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_card.dart';

/// Direction of a change between periods.
enum SellerTrend { up, down, flat, none }

/// "↑ +25%" / "↓ −25%" / "– 0%" / nothing to compare (board 21-03). Arrow +
/// sign + text carry the meaning; colour only reinforces it.
class SellerDelta extends StatelessWidget {
  const SellerDelta({super.key, required this.trend, required this.label, this.goodWhenUp = true, this.pill = false});

  final SellerTrend trend;
  final String label;

  /// For costs such as cancellations, "down" is the good direction.
  final bool goodWhenUp;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final good = trend == SellerTrend.flat || trend == SellerTrend.none
        ? null
        : (trend == SellerTrend.up) == goodWhenUp;
    final tone = good == null ? SellerTone.neutral : (good ? SellerTone.success : SellerTone.danger);
    final pair = c.tone(tone);
    final icon = switch (trend) {
      SellerTrend.up => SellerIcons.trendUp,
      SellerTrend.down => SellerIcons.trendDown,
      SellerTrend.flat => SellerIcons.flat,
      SellerTrend.none => SellerIcons.info,
    };
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: SellerIconSize.sm, color: pair.foreground)),
        const SizedBox(width: SellerSpace.s4),
        Flexible(child: Text(label, style: context.text.labelLarge!.copyWith(color: pair.foreground).tabular)),
      ],
    );
    if (!pill) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8, vertical: SellerSpace.s4),
      decoration: BoxDecoration(color: pair.container, borderRadius: BorderRadius.circular(SellerRadius.pill)),
      child: row,
    );
  }
}

/// KPI card (boards 11, 21-01): label (+ info button), value, change vs the
/// previous period, context line, optional sparkline. Values wrap — they are
/// never shrunk to fit (brief §5).
class SellerMetricCard extends StatelessWidget {
  const SellerMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.caption,
    this.icon,
    this.onInfo,
    this.infoLabel,
    this.chart,
    this.onTap,
    this.tone = SellerCardTone.surface,
    this.large = false,
  });

  final String label;
  final String value;
  final Widget? delta;
  final String? caption;
  final IconData? icon;
  final VoidCallback? onInfo;
  final String? infoLabel;
  final Widget? chart;
  final VoidCallback? onTap;
  final SellerCardTone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return SellerCard(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.all(SellerSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(child: Icon(icon, size: SellerIconSize.md, color: c.primary)),
                const SizedBox(width: SellerSpace.s8),
              ],
              Expanded(child: Text(label, style: text.labelLarge!.copyWith(color: c.textSecondary))),
              if (onInfo != null)
                SizedBox(
                  width: SellerSize.touchTarget,
                  height: SellerSpace.s32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: infoLabel,
                    onPressed: onInfo,
                    icon: Icon(SellerIcons.info, size: SellerIconSize.md, color: c.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SellerSpace.s4),
          Text(value, style: (large ? text.displayLarge : text.headlineMedium)!.tabular),
          if (delta != null) ...[const SizedBox(height: SellerSpace.s4), delta!],
          if (caption != null) ...[
            const SizedBox(height: SellerSpace.s2),
            Text(caption!, style: text.bodySmall),
          ],
          if (chart != null) ...[const SizedBox(height: SellerSpace.s8), chart!],
        ],
      ),
    );
  }
}

/// One line of a money breakdown.
@immutable
class SellerMoneyLine {
  const SellerMoneyLine(this.label, this.amount, {this.tone, this.note});
  final String label;

  /// Pre-formatted amount (the caller decides precision; server numbers only).
  final String amount;
  final SellerTone? tone;
  final String? note;
}

/// Line items → total (boards 11, 17-04, 19-03/04, 19-05): tabular figures,
/// deductions shown with their own sign, the total emphasised.
class SellerMoneyBreakdown extends StatelessWidget {
  const SellerMoneyBreakdown({
    super.key,
    required this.lines,
    required this.totalLabel,
    required this.total,
    this.totalTone,
    this.footnote,
    this.after = const [],
  });

  final List<SellerMoneyLine> lines;
  final String totalLabel;
  final String total;
  final SellerTone? totalTone;
  final String? footnote;

  /// Lines under the total (e.g. Paid / Pending of a statement).
  final List<SellerMoneyLine> after;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    Widget line(SellerMoneyLine l, {bool strong = false}) {
      final color = l.tone == null ? null : c.tone(l.tone!).foreground;
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SellerSpace.s6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.label, style: strong ? text.titleMedium : text.bodyLarge!.copyWith(color: c.textSecondary)),
                  if (l.note != null) Text(l.note!, style: text.bodySmall),
                ]),
              ),
              const SizedBox(width: SellerSpace.s12),
              Text(
                l.amount,
                textAlign: TextAlign.end,
                style: (strong ? text.titleLarge : text.bodyLarge)!.copyWith(color: color).tabular,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in lines) line(l),
        const Padding(padding: EdgeInsets.symmetric(vertical: SellerSpace.s4), child: Divider()),
        line(SellerMoneyLine(totalLabel, total, tone: totalTone), strong: true),
        for (final l in after) line(l),
        if (footnote != null) ...[
          const SizedBox(height: SellerSpace.s8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(child: Icon(SellerIcons.info, size: SellerIconSize.sm, color: c.textSecondary)),
            const SizedBox(width: SellerSpace.s6),
            Expanded(child: Text(footnote!, style: text.bodySmall)),
          ]),
        ],
      ],
    );
  }
}

/// Big amount on a tinted hero card: "To be paid ₹551" (boards 19-01, 19-04).
class SellerAmountHero extends StatelessWidget {
  const SellerAmountHero({super.key, required this.label, required this.amount, this.caption, this.badge, this.icon});

  final String label;
  final String amount;
  final String? caption;
  final Widget? badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return SellerCard(
      tone: SellerCardTone.mint,
      padding: const EdgeInsets.all(SellerSpace.s20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelLarge!.copyWith(color: c.textPrimary)),
                const SizedBox(height: SellerSpace.s4),
                Text(amount, style: text.displayLarge!.copyWith(color: c.textPrimary).tabular),
                if (caption != null) ...[
                  const SizedBox(height: SellerSpace.s4),
                  Text(caption!, style: text.bodyMedium!.copyWith(color: c.textPrimary)),
                ],
              ],
            ),
          ),
          if (badge != null) badge!,
          if (badge == null && icon != null)
            SellerIconTile(icon: icon!, tone: SellerTone.warning, circle: true, size: SellerSize.avatarMd),
        ],
      ),
    );
  }
}
