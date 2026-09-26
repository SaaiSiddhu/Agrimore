// lib/screens/home/active_work_states.dart
//
// Phase DLV-C1 / Phase 18 — the dashboard's states around active work: loading,
// a failed read, several active orders at once, and data shown from the device
// cache. Delivery Design System tokens and ARB copy only.
import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:flutter/material.dart';

import '../../data/rider_work.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

class ActiveWorkLoading extends StatelessWidget {
  const ActiveWorkLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: AppLocalizations.of(context).activeWorkLoading,
          child: DeliveryLoadingState(
            label: AppLocalizations.of(context).activeWorkLoading,
          ),
        ),
      );
}

String riderDataErrorText(AppLocalizations l, RiderDataError e) => switch (e) {
      RiderDataError.permission => l.activeWorkErrorPermission,
      RiderDataError.offline => l.activeWorkErrorOffline,
      RiderDataError.unknown => l.activeWorkErrorUnknown,
    };

class ActiveWorkError extends StatelessWidget {
  const ActiveWorkError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final RiderDataError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DeliveryErrorState(
      title: riderDataErrorText(l10n, error),
      retryLabel: l10n.actionRetry,
      onRetry: onRetry,
    );
  }
}

/// More than one order is assigned to this rider at once. Each can be
/// opened; none is picked for the rider.
class MultipleActiveOrders extends StatelessWidget {
  const MultipleActiveOrders({
    super.key,
    required this.orders,
    required this.onOpen,
  });

  final List<OrderModel> orders;
  final void Function(OrderModel order) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shrink = !constraints.hasBoundedHeight;
        return ListView(
          shrinkWrap: shrink,
          physics: shrink ? const NeverScrollableScrollPhysics() : null,
          padding: shrink ? EdgeInsets.zero : const EdgeInsets.all(DeliverySpace.page),
          children: [
            DeliveryBanner(
              tone: DeliveryBannerTone.warning,
              title: l10n.activeWorkMultipleTitle(orders.length),
              body: l10n.activeWorkMultipleBody,
            ),
            const SizedBox(height: DeliverySpace.lg),
            for (final o in orders) ...[
              DeliveryButton.secondary(
                label: l10n.activeWorkOpen(o.orderNumber),
                icon: DeliveryIcons.activeOrder,
                onPressed: () => onOpen(o),
              ),
              const SizedBox(height: DeliverySpace.sm),
            ],
          ],
        );
      },
    );
  }
}

/// One active order, front and centre with a way to open it. Used by both
/// the dashboard (single active order) and the Deliveries tab (active work
/// above the history list) — phase DLVNAV1 extracted this out of what was
/// `_DashboardScreenState._buildActiveOrderCard` so both screens share it
/// instead of the Deliveries tab growing a second copy.
class ActiveOrderSummaryCard extends StatelessWidget {
  const ActiveOrderSummaryCard({
    super.key,
    required this.order,
    required this.onOpen,
  });

  final OrderModel order;
  final void Function(OrderModel order) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeliverySpace.page),
        child: DeliveryCard(
          variant: DeliveryCardVariant.brand,
          padding: const EdgeInsets.all(DeliverySpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: DeliverySize.avatarLg,
                    height: DeliverySize.avatarLg,
                    decoration: BoxDecoration(
                      color: c.brand,
                      borderRadius: DeliveryRadius.rMd,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      DeliveryIcons.rider,
                      color: c.onBrand,
                      size: DeliveryIconSize.lg,
                    ),
                  ),
                  const SizedBox(width: DeliverySpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.dashActiveTitle,
                          style: t.titleMedium.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          l.offerOrderNumber(order.orderNumber),
                          style: t.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DeliverySpace.xl),
              DeliveryButton.primary(
                label: l.dashViewDetails,
                icon: DeliveryIcons.chevronRight,
                onPressed: () => onOpen(order),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The orders on screen came from the device cache or a failed refresh.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DeliverySpace.page,
        vertical: DeliverySpace.xs,
      ),
      child: DeliveryBanner(
        tone: DeliveryBannerTone.info,
        icon: DeliveryIcons.offline,
        body: AppLocalizations.of(context).activeWorkOffline,
      ),
    );
  }
}
