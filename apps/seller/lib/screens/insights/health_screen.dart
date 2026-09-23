import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

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

/// H-05 Account health (ADR §10.2, SELLER-HOME-1c): an overall score from
/// transparent inputs — each with its value, target and how to improve.
/// Inputs without enough data are left out, not counted as zero.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key, required this.inputs});
  final List<HealthScore> inputs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final score = overallHealth(inputs);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.healthTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s16),
              child: score == null
                  ? Text(l10n.healthNotEnoughData, style: text.bodyMedium)
                  : Row(children: [
                      HealthRing(score: score),
                      const SizedBox(width: WsSpace.s16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l10n.healthBand(bandOf(score)), style: text.titleMedium),
                          Text(l10n.healthExplainer, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                        ]),
                      ),
                    ]),
            ),
          ),
          const SizedBox(height: WsSpace.s12),
          for (final s in inputs)
            Card(
              margin: const EdgeInsets.only(bottom: WsSpace.s8),
              child: Padding(
                padding: const EdgeInsets.all(WsSpace.s16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(s.meetsTarget ? AgIcons.success : AgIcons.warning, color: s.meetsTarget ? t.successFg : t.warningFg),
                    const SizedBox(width: WsSpace.s8),
                    Expanded(child: Text(l10n.healthLabel(s.input), style: text.titleSmall)),
                    Text(l10n.healthValue(s), style: text.titleSmall!.copyWith(fontFeatures: WsType.tabularFigures)),
                  ]),
                  const SizedBox(height: WsSpace.s4),
                  Text(l10n.healthTarget(s), style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  if (!s.meetsTarget) ...[
                    const SizedBox(height: WsSpace.s8),
                    Text(l10n.healthTip(s.input), style: text.bodyMedium),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// `WsScoreRing` (ADR §7).
class HealthRing extends StatelessWidget {
  const HealthRing({super.key, required this.score, this.size = WsSize.avatarLg});
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final band = bandOf(score);
    final color = switch (band) {
      HealthBand.good => t.successFg,
      HealthBand.fair => t.warningFg,
      HealthBand.poor => t.errorFg,
    };
    return Semantics(
      label: AppLocalizations.of(context).healthScoreLabel(score),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(value: score / 100, color: color, backgroundColor: t.surfaceSunken, strokeWidth: WsSpace.s4),
          ),
          Text(AgFormat.count(score), style: context.wsText.titleMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
        ]),
      ),
    );
  }
}
