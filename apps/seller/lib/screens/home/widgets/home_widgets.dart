import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

enum ActionTone { urgent, attention, neutral }

/// One row of the "Needs you now" queue.
@immutable
class ActionItem {
  const ActionItem({required this.icon, required this.label, this.detail, this.tone = ActionTone.neutral, required this.onTap});
  final IconData icon;
  final String label;
  final String? detail;
  final ActionTone tone;
  final VoidCallback onTap;
}

/// `WsActionQueueCard` (ADR §7): what needs the seller now, most urgent
/// first; an explicit all-clear state instead of an empty card.
class ActionQueueCard extends StatelessWidget {
  const ActionQueueCard({super.key, required this.items});
  final List<ActionItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    if (items.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(AgIcons.success, color: t.successFg),
          title: Text(l10n.homeAllCaughtUp, style: text.titleSmall),
          subtitle: Text(l10n.homeAllCaughtUpBody, style: text.bodySmall),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: WsSize.hairline),
          _row(context, items[i]),
        ],
      ]),
    );
  }

  Widget _row(BuildContext context, ActionItem item) {
    final t = context.ws;
    final text = context.wsText;
    final (Color fg, Color bg) = switch (item.tone) {
      ActionTone.urgent => (t.errorFg, t.errorBg),
      ActionTone.attention => (t.warningFg, t.warningBg),
      ActionTone.neutral => (t.primary, t.primarySubtle),
    };
    return ListTile(
      onTap: item.onTap,
      leading: Container(
        width: WsSize.avatarMd,
        height: WsSize.avatarMd,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(WsRadius.small)),
        child: Icon(item.icon, color: fg, size: WsIconSize.control),
      ),
      title: Text(item.label, style: text.titleSmall),
      subtitle: item.detail == null
          ? null
          : Text(item.detail!, style: text.bodySmall!.copyWith(color: item.tone == ActionTone.neutral ? t.textSecondary : fg)),
      trailing: Icon(AgIcons.chevronRight, color: t.textTertiary),
    );
  }
}

/// `WsKpiCard`: value, change vs the previous period (arrow + text, never
/// colour alone) and a sparkline.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.delta, this.deltaUp, this.series});
  final String label;
  final String value;
  final String? delta;

  /// Whether the change is an improvement; null = no comparison.
  final bool? deltaUp;
  final List<double>? series;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    final color = deltaUp == null ? t.textSecondary : (deltaUp! ? t.successFg : t.errorFg);
    final s = series;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: text.bodySmall!.copyWith(color: t.textSecondary)),
          const SizedBox(height: WsSpace.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.titleLarge!.copyWith(fontFeatures: WsType.tabularFigures)),
          ),
          if (delta != null) ...[
            const SizedBox(height: WsSpace.s2),
            Row(children: [
              if (deltaUp != null)
                Icon(deltaUp! ? AgIcons.trendUp : AgIcons.trendDown, size: WsIconSize.supporting, color: color),
              if (deltaUp != null) const SizedBox(width: WsSpace.s4),
              Flexible(
                child: Text(delta!, style: text.bodySmall!.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],
          if (s != null && s.length > 1) ...[
            const SizedBox(height: WsSpace.s8),
            SizedBox(
              height: WsSpace.s24,
              width: double.infinity,
              child: ExcludeSemantics(child: CustomPaint(painter: _SparklinePainter(s, t.primary))),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final dx = size.width / (values.length - 1);
    double y(double v) => max == 0 ? size.height : size.height - (v / max) * size.height;
    final path = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(dx * i, y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = WsSize.outline
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values || old.color != color;
}

/// Section overline with an optional count.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = context.wsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: WsSpace.s8),
      child: Row(children: [
        Expanded(child: Text(title, style: text.titleMedium)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
