// lib/screens/home/active_work_states.dart
//
// Phase DLV-C1 — the dashboard's states around active work: loading, a
// failed read, several active orders at once, and data shown from the
// device cache. Workspace tokens and ARB copy only.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../data/rider_work.dart';
import '../../l10n/app_localizations.dart';

class ActiveWorkLoading extends StatelessWidget {
  const ActiveWorkLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: AppLocalizations.of(context).activeWorkLoading,
          child: const CircularProgressIndicator(),
        ),
      );
}

String riderDataErrorText(AppLocalizations l, RiderDataError e) => switch (e) {
      RiderDataError.permission => l.activeWorkErrorPermission,
      RiderDataError.offline => l.activeWorkErrorOffline,
      RiderDataError.unknown => l.activeWorkErrorUnknown,
    };

class ActiveWorkError extends StatelessWidget {
  const ActiveWorkError({super.key, required this.error, required this.onRetry});

  final RiderDataError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(error == RiderDataError.offline ? AgIcons.offline : AgIcons.error,
                size: WsIconSize.empty, color: t.textTertiary),
            const SizedBox(height: WsSpace.s12),
            Text(riderDataErrorText(l10n, error),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: WsSpace.s16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(AgIcons.refresh),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// More than one order is assigned to this rider at once. Each can be
/// opened; none is picked for the rider.
class MultipleActiveOrders extends StatelessWidget {
  const MultipleActiveOrders({super.key, required this.orders, required this.onOpen});

  final List<OrderModel> orders;
  final void Function(OrderModel order) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(WsSpace.page),
      children: [
        Container(
          padding: const EdgeInsets.all(WsSpace.s16),
          decoration: BoxDecoration(color: t.warningBg, borderRadius: BorderRadius.circular(WsRadius.card)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(AgIcons.warning, color: t.warningFg, size: WsIconSize.control),
                const SizedBox(width: WsSpace.s8),
                Expanded(
                  child: Text(l10n.activeWorkMultipleTitle(orders.length),
                      style: text.titleMedium?.copyWith(color: t.warningFg)),
                ),
              ]),
              const SizedBox(height: WsSpace.s8),
              Text(l10n.activeWorkMultipleBody, style: text.bodyMedium?.copyWith(color: t.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: WsSpace.s16),
        for (final o in orders) ...[
          FilledButton.tonalIcon(
            onPressed: () => onOpen(o),
            icon: const Icon(AgIcons.delivery),
            label: Text(l10n.activeWorkOpen(o.orderNumber)),
          ),
          const SizedBox(height: WsSpace.s8),
        ],
      ],
    );
  }
}

/// The orders on screen came from the device cache or a failed refresh.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: t.infoBg,
        padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s8),
        child: Row(children: [
          Icon(AgIcons.offline, color: t.infoFg, size: WsIconSize.supporting),
          const SizedBox(width: WsSpace.s8),
          Expanded(
            child: Text(AppLocalizations.of(context).activeWorkOffline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.infoFg)),
          ),
        ]),
      ),
    );
  }
}
