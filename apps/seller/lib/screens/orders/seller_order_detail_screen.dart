import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_order_provider.dart';
import 'order_stage.dart';
import 'seller_orders_screen.dart';
import 'widgets/order_invoice_card.dart';
import 'widgets/order_reason_sheet.dart';

/// O-02 Order detail (ADR §10.3, SELLER-UI-1b): where the order is, who and
/// what, money, invoice, and exactly the next step the server allows.
class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({super.key, required this.order});
  final OrderModel order;

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
    WsToast.show(context, ok ? success : _errorCopy(l10n, provider.lastActionError),
        tone: ok ? WsToastTone.success : WsToastTone.error);
    if (ok) Navigator.of(context).maybePop();
  }

  Future<void> _rejectOrCancel(OrderModel o) async {
    final l10n = AppLocalizations.of(context);
    final isCancel = orderStageOf(o.orderStatus) != OrderStage.toAccept;
    final choice = await showOrderReasonSheet(context, isCancel: isCancel, prepaid: isPrepaid(o));
    if (choice == null || !mounted) return;
    await _run(
      (p) => isCancel
          ? p.cancelOrder(o.id, reason: choice.reason, note: choice.note)
          : p.rejectOrder(o.id, reason: choice.reason, note: choice.note),
      isCancel ? l10n.orderCancelled : l10n.orderRejected,
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _chat(OrderModel o) async {
    final l10n = AppLocalizations.of(context);
    final sellerId = o.sellerId ?? '';
    try {
      // DLV-K1: a thread's parties are fixed when it is made (firestore.rules
      // threads) — create it once; never rewrite it.
      final ref = FirebaseFirestore.instance.collection('threads').doc('${o.id}_seller_customer');
      if (!(await ref.get()).exists) {
        await ref.set({
          'orderId': o.id,
          'orderNumber': o.orderNumber,
          'customerId': o.userId,
          'sellerId': sellerId,
          'participantIds': [o.userId, sellerId].where((id) => id.isNotEmpty).toList(),
          'type': 'seller_customer',
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) WsToast.show(context, l10n.chatReady);
    } catch (e) {
      debugPrint('Chat thread failed: $e');
      if (mounted) WsToast.show(context, l10n.orderActionFailed, tone: WsToastTone.error);
    }
  }

  List<WsTimelineStep> _timeline(AppLocalizations l10n, OrderModel o, OrderStage stage) {
    const flow = [OrderStage.toAccept, OrderStage.toPack, OrderStage.packing, OrderStage.ready, OrderStage.outForDelivery, OrderStage.delivered];
    final titles = [l10n.stepPlaced, l10n.stepAccepted, l10n.stepPacking, l10n.stepReady, l10n.stageOutForDelivery, l10n.stageDelivered];
    final at = flow.indexOf(stage);
    return [
      for (var i = 0; i < flow.length; i++)
        WsTimelineStep(
          title: titles[i],
          caption: i == 0 ? AgFormat.dateTime(o.createdAt) : null,
          // The step reached is done; the next one is current.
          state: i <= at ? WsTimelineState.done : (i == at + 1 ? WsTimelineState.current : WsTimelineState.upcoming),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final o = widget.order;
    final stage = orderStageOf(o.orderStatus);
    final phone = o.deliveryAddress.phone;

    Widget card(String title, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: WsSpace.s12),
              ...children,
            ]),
          ),
        );

    Widget row(String label, String value, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(label, style: text.bodyMedium!.copyWith(color: t.textSecondary))),
            const SizedBox(width: WsSpace.s12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: (strong ? text.titleSmall : text.bodyMedium)!.copyWith(fontFeatures: WsType.tabularFigures, color: color)),
            ),
          ]),
        );

    final action = nextSellerAction(stage);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.paymentsForOrder(o.orderNumber)),
        actions: [
          IconButton(tooltip: l10n.orderCall, icon: const Icon(AgIcons.phone), onPressed: phone.isEmpty ? null : () => _call(phone)),
          IconButton(tooltip: l10n.orderChat, icon: const Icon(AgIcons.chat), onPressed: () => _chat(o)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(AgFormat.rupees(o.total), style: text.headlineMedium!.copyWith(fontFeatures: WsType.tabularFigures))),
                  OrderStagePill(stage: stage),
                ]),
                Text(isPrepaid(o) ? l10n.ordersPrepaid : l10n.ordersCod, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                if (stage != OrderStage.cancelled && stage != OrderStage.other) ...[
                  const SizedBox(height: WsSpace.s16),
                  WsTimeline(steps: _timeline(l10n, o, stage)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: WsSpace.s12),
          card(l10n.orderCustomer, [
            row(l10n.orderName, o.deliveryAddress.name.isEmpty ? l10n.ordersCustomer : o.deliveryAddress.name),
            if (phone.isNotEmpty) row(l10n.accountPhone, phone),
            row(l10n.orderAddress, o.deliveryAddress.fullAddress.isEmpty ? l10n.orderNoAddress : o.deliveryAddress.fullAddress),
            if (o.deliverySlot != null) row(l10n.orderSlot, o.deliverySlot!),
            if (o.notes != null && o.notes!.isNotEmpty) row(l10n.orderNote, o.notes!),
          ]),
          const SizedBox(height: WsSpace.s12),
          card(l10n.ordersItems(o.items.fold<int>(0, (n, i) => n + i.quantity)), [
            for (final i in o.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(WsRadius.small),
                    child: SizedBox.square(
                      dimension: WsSize.thumbSm,
                      child: i.productImage.isEmpty
                          ? ColoredBox(color: t.surfaceSunken, child: Icon(AgIcons.product, color: t.textTertiary))
                          : Image.network(i.productImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: t.surfaceSunken)),
                    ),
                  ),
                  const SizedBox(width: WsSpace.s12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.productName, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (i.variant != null && i.variant!.isNotEmpty)
                        Text(l10n.variantsOrderLine(i.variant!), style: text.labelMedium!.copyWith(color: t.primary)),
                      Text(l10n.quoteQtyAtPrice(AgFormat.count(i.quantity), AgFormat.rupees(i.price)),
                          style: text.bodySmall!.copyWith(color: t.textSecondary)),
                    ]),
                  ),
                  Text(AgFormat.rupees(i.price * i.quantity), style: text.bodyMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
                ]),
              ),
          ]),
          const SizedBox(height: WsSpace.s12),
          card(l10n.orderPayment, [
            row(l10n.invoiceSubtotal, AgFormat.rupees(o.subtotal)),
            if (o.discount > 0) row(l10n.invoiceDiscount, AgFormat.rupees(-o.discount), color: t.successFg),
            row(l10n.invoiceDelivery, AgFormat.rupees(o.deliveryCharge)),
            if (o.tax > 0) row(l10n.orderTax, AgFormat.rupees(o.tax)),
            const Divider(height: WsSpace.s16),
            row(l10n.invoiceTotal, AgFormat.rupees(o.total), strong: true),
          ]),
          const SizedBox(height: WsSpace.s12),
          OrderInvoiceCard(orderId: o.id, orderStatus: o.orderStatus),
          const SizedBox(height: WsSpace.s24),
        ],
      ),
      bottomNavigationBar: action == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, WsSpace.s12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _rejectOrCancel(o),
                      style: OutlinedButton.styleFrom(foregroundColor: t.errorFg),
                      child: Text(stage == OrderStage.toAccept ? l10n.orderReject : l10n.orderCancel),
                    ),
                  ),
                  const SizedBox(width: WsSpace.s12),
                  Expanded(
                    flex: 2,
                    child: SaLoadingButton(
                      isLoading: _busy,
                      text: switch (action) {
                        'accept' => l10n.orderAccept,
                        'pack' => l10n.orderStartPacking,
                        _ => l10n.orderMarkReady,
                      },
                      onPressed: _busy
                          ? null
                          : () => switch (action) {
                                'accept' => _run((p) => p.acceptOrder(o.id), l10n.orderAccepted),
                                'pack' => _run((p) => p.markPacking(o.id), l10n.orderPacking),
                                _ => _run((p) => p.markReadyForPickup(o.id), l10n.orderReady),
                              },
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}
