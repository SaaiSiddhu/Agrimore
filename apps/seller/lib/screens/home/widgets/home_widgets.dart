import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
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

/// "Needs you now" (boards 03, 11): one clear action per row, most urgent
/// first; an explicit all-clear card instead of an empty one.
class ActionQueueCard extends StatelessWidget {
  const ActionQueueCard({super.key, required this.items});
  final List<ActionItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      return SellerCard(
        child: Row(children: [
          const SellerIconTile(icon: SellerIcons.success, tone: SellerTone.success),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.homeAllCaughtUp, style: context.text.titleSmall),
              Text(l10n.homeAllCaughtUpBody, style: context.text.bodyMedium),
            ]),
          ),
        ]),
      );
    }
    return SellerMenuGroup(children: [
      for (final item in items)
        SellerListRow(
          title: item.label,
          subtitle: item.detail,
          icon: item.icon,
          iconTone: switch (item.tone) {
            ActionTone.urgent => SellerTone.warning,
            ActionTone.attention => SellerTone.warning,
            ActionTone.neutral => SellerTone.brand,
          },
          onTap: item.onTap,
        ),
    ]);
  }
}
