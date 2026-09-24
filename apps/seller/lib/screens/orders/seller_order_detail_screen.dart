import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_order_provider.dart';
import 'order_stage.dart';
import 'seller_orders_screen.dart';
import 'widgets/order_invoice_card.dart';
import 'widgets/order_reason_sheet.dart';

/// O-02 Order detail (boards 17-02…17-05): where the order is, who and
/// what, money, invoice, and exactly the next step the server allows. The
/// order follows the live list, so a stage change shows up here without
/// leaving the screen (decision D10). [embedded] = the right-hand pane of
/// the tablet list + detail layout (no back arrow).
class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({super.key, required this.order, this.embedded = false});
  final OrderModel order;
  final bool embedded;

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  bool _busy = false;

  String _errorCopy(AppLocalizations l10n, OrderActionError? error) => switch (error) {
        OrderActionError.unpaid => l10n.orderUnpaid,
        OrderActionError.alreadyMoved => l10n.orderAlreadyMoved,
        _ => l10n.orderActionFailed,
      };

  Future<void> _run(Future<bool> Function(SellerOrderProvider p) action, String success) async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final provider = context.read<SellerOrderProvider>();
    final ok = await action(provider);
    if (!mounted) return;
    setState(() => _busy = false);
    final l10n = AppLocalizations.of(context);
    SellerToast.show(context, ok ? success : _errorCopy(l10n, provider.lastActionError),
        tone: ok ? SellerToastTone.success : SellerToastTone.danger);
  }

  Future<void> _rejectOrCancel(OrderModel o) async {
    final l10n = AppLocalizations.of(context);
    final isCancel = orderStageOf(o.orderStatus) != OrderStage.toAccept;
    final choice = await showOrderReasonSheet(context, order: o, isCancel: isCancel, prepaid: isPrepaid(o));
    if (choice == null || !mounted) return;
    await _run(
      (p) => isCancel
          ? p.cancelOrder(o.id, reason: choice.reason, note: choice.note)
          : p.rejectOrder(o.id, reason: choice.reason, note: choice.note),
      isCancel ? l10n.orderCancelled : l10n.orderRejected,
    );
  }

  /// Calls and texts go through the phone's own apps; the number itself is
  /// never shown in full (decision D9).
  Future<void> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('Launch failed: $e');
    }
  }

  List<SellerTimelineStep> _timeline(AppLocalizations l10n, OrderModel o, OrderStage stage) {
    const flow = [OrderStage.toAccept, OrderStage.toPack, OrderStage.packing, OrderStage.ready, OrderStage.outForDelivery, OrderStage.delivered];
    final titles = [l10n.stepPlaced, l10n.stepAccepted, l10n.stepPacking, l10n.stepReady, l10n.stageOutForDelivery, l10n.stageDelivered];
    final at = flow.indexOf(stage);
    return [
      for (var i = 0; i < flow.length; i++)
        SellerTimelineStep(
          title: titles[i],
          // Delivered is complete; otherwise the stage reached is current.
          state: stage == OrderStage.delivered || i < at
              ? SellerStepState.done
              : (i == at ? SellerStepState.current : SellerStepState.upcoming),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    // Live copy of the order from the provider's stream.
    final o = context.watch<SellerOrderProvider>().allOrders.where((x) => x.id == widget.order.id).firstOrNull ?? widget.order;
    final stage = orderStageOf(o.orderStatus);
    final (tone, stageIcon) = orderStageStyle(stage);
    final phone = o.deliveryAddress.phone;
    final prepaid = isPrepaid(o);
    final action = nextSellerAction(stage);
    final units = o.items.fold<int>(0, (n, i) => n + i.quantity);

    Widget section(String title, IconData icon, List<Widget> children, {Widget? trailing}) => SellerCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, size: SellerIconSize.md, color: c.primary),
              const SizedBox(width: SellerSpace.s8),
              Expanded(child: Semantics(header: true, child: Text(title, style: text.titleSmall))),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: SellerSpace.s8),
            ...children,
          ]),
        );

    final stageBlock = SellerCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SellerIconTile(icon: stageIcon, tone: tone),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.stageLabel(stage), style: text.titleMedium),
              Text(l10n.orderPlacedAt(SellerFormat.dateTime(o.createdAt)), style: text.bodyMedium),
              Text(l10n.stageGuide(stage), style: text.bodyMedium!.copyWith(color: c.textPrimary)),
            ]),
          ),
        ]),
        if (stage != OrderStage.cancelled && stage != OrderStage.other) ...[
          const SizedBox(height: SellerSpace.s16),
          SellerTimeline(steps: _timeline(l10n, o, stage), dense: true, showCurrentPill: false),
        ],
      ]),
    );

    final customer = section(l10n.orderCustomer, SellerIcons.user, [
      SellerKeyValueRow(label: l10n.orderName, value: o.deliveryAddress.name.isEmpty ? l10n.ordersCustomer : o.deliveryAddress.name),
      if (phone.isNotEmpty)
        SellerKeyValueRow(
          label: l10n.orderPhoneLabel,
          valueWidget: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(SellerFormat.maskPhone(phone), style: text.bodyLarge!.tabular, textAlign: TextAlign.end)),
            SellerIconButton(
              icon: SellerIcons.phone,
              label: l10n.orderCall,
              color: c.primary,
              onPressed: () => _launch(Uri(scheme: 'tel', path: phone)),
            ),
          ]),
        ),
      SellerKeyValueRow(
        label: l10n.orderAddress,
        icon: SellerIcons.location,
        value: o.deliveryAddress.fullAddress.isEmpty ? l10n.orderNoAddress : o.deliveryAddress.fullAddress,
      ),
      if (o.deliverySlot != null && o.deliverySlot!.isNotEmpty)
        SellerKeyValueRow(label: l10n.orderSlot, icon: SellerIcons.clock, value: o.deliverySlot),
      SellerKeyValueRow(
        label: l10n.orderNote,
        icon: SellerIcons.document,
        value: (o.notes ?? '').trim().isEmpty ? l10n.orderNoNote : o.notes!.trim(),
      ),
    ]);

    final items = section(l10n.orderItemsHeader(units), SellerIcons.orders, [
      for (final i in o.items)
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SellerSpace.s6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SellerImage(url: i.productImage, size: SellerSize.thumbMd),
              const SizedBox(width: SellerSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.productName, style: text.titleSmall),
                  if (i.variant != null && i.variant!.isNotEmpty) Text(l10n.variantsOrderLine(i.variant!), style: text.bodyMedium),
                  Text(l10n.orderLineQty(SellerFormat.count(i.quantity), SellerFormat.money(i.price)), style: text.bodyMedium!.tabular),
                ]),
              ),
              const SizedBox(width: SellerSpace.s8),
              Text(SellerFormat.money(i.price * i.quantity), style: text.titleSmall!.tabular),
            ]),
          ),
        ),
      const SizedBox(height: SellerSpace.s4),
      Row(children: [
        Icon(SellerIcons.info, size: SellerIconSize.sm, color: c.textSecondary),
        const SizedBox(width: SellerSpace.s6),
        Expanded(child: Text(l10n.orderItemsReadOnly, style: text.bodySmall)),
      ]),
    ]);

    final payment = section(l10n.orderPayment, SellerIcons.payments, [
      SellerListRow(
        title: prepaid ? l10n.ordersPrepaid : l10n.ordersCod,
        subtitle: prepaid ? l10n.orderPrepaidDetail : l10n.orderCodDetail,
        icon: prepaid ? SellerIcons.card : SellerIcons.cash,
        showChevron: false,
      ),
      SellerMoneyBreakdown(
        lines: [
          SellerMoneyLine(l10n.invoiceSubtotal, SellerFormat.money(o.subtotal)),
          if (o.discount > 0) SellerMoneyLine(l10n.invoiceDiscount, SellerFormat.money(-o.discount), tone: SellerTone.success),
          SellerMoneyLine(l10n.invoiceDelivery, SellerFormat.money(o.deliveryCharge)),
          if (o.tax > 0) SellerMoneyLine(l10n.orderTax, SellerFormat.money(o.tax)),
        ],
        totalLabel: l10n.invoiceTotal,
        total: SellerFormat.money(o.total),
        footnote: l10n.orderTotalSeparate,
      ),
    ]);

    final footer = action == null
        ? null
        : SellerButtonBar(children: [
            SellerButton.dangerOutline(
              label: stage == OrderStage.toAccept ? l10n.orderReject : l10n.orderCancel,
              icon: SellerIcons.delete,
              onPressed: _busy ? null : () => _rejectOrCancel(o),
            ),
            SellerButton(
              label: switch (action) {
                'accept' => l10n.orderAccept,
                'pack' => l10n.orderStartPacking,
                _ => l10n.orderMarkReady,
              },
              icon: switch (action) {
                'accept' => SellerIcons.check,
                'pack' => SellerIcons.packing,
                _ => SellerIcons.delivery,
              },
              loading: _busy,
              loadingLabel: l10n.saving,
              onPressed: () => switch (action) {
                'accept' => _run((p) => p.acceptOrder(o.id), l10n.orderAccepted),
                'pack' => _run((p) => p.markPacking(o.id), l10n.orderPacking),
                _ => _run((p) => p.markReadyForPickup(o.id), l10n.orderReady),
              },
            ),
          ]);

    return Scaffold(
      appBar: SellerAppBar.detail(
        context,
        title: l10n.orderNumberTitle(o.orderNumber),
        status: SellerStatusBadge(label: prepaid ? l10n.ordersPrepaid : l10n.ordersCod, tone: SellerTone.brand),
        showBack: !widget.embedded,
        actions: [
          if (phone.isNotEmpty) ...[
            SellerIconButton(icon: SellerIcons.phone, label: l10n.orderCall, onPressed: () => _launch(Uri(scheme: 'tel', path: phone))),
            SellerIconButton(
              icon: SellerIcons.message,
              label: l10n.orderChat,
              onPressed: () => _launch(Uri(scheme: 'sms', path: phone, queryParameters: {'body': l10n.orderMessageBody(o.orderNumber)})),
            ),
          ],
        ],
      ),
      body: SellerPage(
        gap: SellerSpace.s12,
        footer: footer,
        children: [
          stageBlock,
          customer,
          items,
          payment,
          OrderInvoiceCard(orderId: o.id, orderStatus: o.orderStatus),
        ],
      ),
    );
  }
}
