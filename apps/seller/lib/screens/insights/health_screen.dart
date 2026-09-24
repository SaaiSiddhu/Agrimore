import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import 'insights_rules.dart';

/// Copy for one health input.
extension HealthCopy on AppLocalizations {
  String healthLabel(HealthInput i) => switch (i) {
        HealthInput.fulfilment => healthFulfilment,
        HealthInput.cancellations => healthCancellations,
        HealthInput.rating => healthRating,
        HealthInput.listings => healthListings,
        HealthInput.quotes => healthQuotes,
      };

  String healthTip(HealthInput i) => switch (i) {
        HealthInput.fulfilment => healthTipFulfilment,
        HealthInput.cancellations => healthTipCancellations,
        HealthInput.rating => healthTipRating,
        HealthInput.listings => healthTipListings,
        HealthInput.quotes => healthTipQuotes,
      };

  String healthBand(HealthBand b) => switch (b) {
        HealthBand.good => healthGood,
        HealthBand.fair => healthFair,
        HealthBand.poor => healthPoor,
      };

  String healthValue(HealthScore s) =>
      s.input == HealthInput.rating ? s.value.toStringAsFixed(1) : '${(s.value * 100).round()}%';

  String healthTarget(HealthScore s) => s.input == HealthInput.rating
      ? healthTargetAtLeast(s.target.toStringAsFixed(1))
      : s.input == HealthInput.cancellations
          ? healthTargetAtMost('${(s.target * 100).round()}%')
          : healthTargetAtLeast('${(s.target * 100).round()}%');
}

/// Band → tone and icon (word + colour + shape, board 21-08).
(SellerTone, IconData) healthBandStyle(HealthBand b) => switch (b) {
      HealthBand.good => (SellerTone.success, SellerIcons.success),
      HealthBand.fair => (SellerTone.warning, SellerIcons.warning),
      HealthBand.poor => (SellerTone.danger, SellerIcons.error),
    };

/// H-05 Account health (board 21-08, SELLER-HOME-1c): an overall score from
/// transparent inputs — each with its value, target and how to improve.
/// Inputs without enough data are left out, not counted as zero.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key, required this.inputs});
  final List<HealthScore> inputs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final score = overallHealth(inputs);
    final band = score == null ? null : bandOf(score);
    final style = band == null ? null : healthBandStyle(band);
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.healthTitle, subtitle: l10n.healthLast30),
      body: SellerPage(
        gap: SellerSpace.s16,
        children: [
          SellerCard(
            child: Column(children: [
              SellerScoreRing(score: score, tone: style?.$1 ?? SellerTone.neutral),
              const SizedBox(height: SellerSpace.s12),
              if (band != null) SellerStatusBadge(label: l10n.healthBand(band), tone: style!.$1, icon: style.$2, large: true),
              const SizedBox(height: SellerSpace.s8),
              Text(score == null ? l10n.healthNotEnoughData : l10n.healthExplainer, style: text.bodyMedium, textAlign: TextAlign.center),
            ]),
          ),
          if (inputs.isNotEmpty) ...[
            SellerSectionHeader(title: l10n.healthMeasures),
            SellerMenuGroup(children: [
              for (final s in inputs)
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.all(SellerSpace.s12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SellerIconTile(icon: s.meetsTarget ? SellerIcons.success : SellerIcons.warning, tone: s.meetsTarget ? SellerTone.success : SellerTone.warning, circle: true),
                      const SizedBox(width: SellerSpace.s12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: Text(l10n.healthLabel(s.input), style: text.titleSmall)),
                            Text(l10n.healthValue(s), style: text.titleSmall!.tabular),
                          ]),
                          Text(l10n.healthTarget(s), style: text.bodyMedium),
                          if (!s.meetsTarget) ...[
                            const SizedBox(height: SellerSpace.s4),
                            Text(l10n.healthTip(s.input), style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}
