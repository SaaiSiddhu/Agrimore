import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../order_stage.dart';

/// Reasons a seller can give (keys match REJECT_REASONS in
/// functions/src/seller/sellerTransitionOrder.ts).
const List<String> kOrderReasons = [
  'out_of_stock',
  'cannot_deliver_area',
  'price_error',
  'shop_closed',
  'other',
];

String orderReasonLabel(AppLocalizations l10n, String key) => switch (key) {
      'out_of_stock' => l10n.reasonOutOfStock,
      'cannot_deliver_area' => l10n.reasonCannotDeliver,
      'price_error' => l10n.reasonPriceError,
      'shop_closed' => l10n.reasonShopClosed,
      _ => l10n.reasonOther,
    };

/// Result of the reason sheet.
@immutable
class OrderReasonChoice {
  const OrderReasonChoice(this.reason, this.note);
  final String reason;
  final String note;
}

/// O-03 Reject / cancel sheet (board 17-06): order summary, a required
/// reason, an optional note, the consequence spelled out, [Keep order] and a
/// destructive confirm. [isCancel] = the order was already accepted.
Future<OrderReasonChoice?> showOrderReasonSheet(
  BuildContext context, {
  OrderModel? order,
  required bool isCancel,
  required bool prepaid,
}) {
  return showModalBottomSheet<OrderReasonChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OrderReasonSheet(order: order, isCancel: isCancel, prepaid: prepaid),
  );
}

class _OrderReasonSheet extends StatefulWidget {
  const _OrderReasonSheet({required this.order, required this.isCancel, required this.prepaid});
  final OrderModel? order;
  final bool isCancel;
  final bool prepaid;

  @override
  State<_OrderReasonSheet> createState() => _OrderReasonSheetState();
}

class _OrderReasonSheetState extends State<_OrderReasonSheet> {
  static const int _maxNote = 300;
  String? _reason;
  bool _showError = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_reason == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(OrderReasonChoice(_reason!, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final o = widget.order;
    return SellerSheetFrame(
      title: widget.isCancel ? l10n.cancelOrderTitle : l10n.rejectOrderTitle,
      subtitle: l10n.reasonPrompt,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (o != null) ...[
            SellerCard(
              tone: SellerCardTone.sunken,
              child: Row(children: [
                const SellerIconTile(icon: SellerIcons.orders),
                const SizedBox(width: SellerSpace.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.orderNumberTitle(o.orderNumber), style: text.titleSmall),
                    Text(o.deliveryAddress.name.isEmpty ? l10n.ordersCustomer : o.deliveryAddress.name, style: text.bodyMedium),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(SellerFormat.money(o.total), style: text.titleSmall!.tabular),
                  Text(isPrepaid(o) ? l10n.ordersPrepaid : l10n.ordersCod, style: text.bodyMedium),
                ]),
              ]),
            ),
            const SizedBox(height: SellerSpace.s16),
          ],
          Semantics(
            container: true,
            label: l10n.reasonPrompt,
            child: Column(children: [
              for (final r in kOrderReasons)
                SellerChoiceRow<String>(
                  value: r,
                  groupValue: _reason,
                  title: orderReasonLabel(l10n, r),
                  onChanged: (v) => setState(() {
                    _reason = v;
                    _showError = false;
                  }),
                ),
            ]),
          ),
          if (_showError) SellerFieldMessage(message: l10n.orderReasonRequired),
          const SizedBox(height: SellerSpace.s12),
          SellerTextField(label: l10n.reasonNoteLabel, controller: _note, maxLength: _maxNote, maxLines: 3, minLines: 2),
          const SizedBox(height: SellerSpace.s12),
          SellerBanner(
            tone: SellerTone.danger,
            message: widget.prepaid ? l10n.rejectConsequencePrepaid : l10n.rejectConsequence,
          ),
        ],
      ),
      footer: SellerButtonBar(children: [
        SellerButton.secondary(label: l10n.keepOrder, onPressed: () => Navigator.of(context).pop()),
        SellerButton.danger(label: widget.isCancel ? l10n.cancelOrderCta : l10n.rejectOrderCta, onPressed: _confirm),
      ]),
    );
  }
}
