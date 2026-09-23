import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

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

/// O-03 Reject / cancel sheet (ADR §10.3): a required reason, an optional
/// note, the consequence spelled out, and a destructive confirm.
/// [isCancel] = the order was already accepted.
Future<OrderReasonChoice?> showOrderReasonSheet(
  BuildContext context, {
  required bool isCancel,
  required bool prepaid,
}) {
  return showModalBottomSheet<OrderReasonChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OrderReasonSheet(isCancel: isCancel, prepaid: prepaid),
  );
}

class _OrderReasonSheet extends StatefulWidget {
  const _OrderReasonSheet({required this.isCancel, required this.prepaid});
  final bool isCancel;
  final bool prepaid;

  @override
  State<_OrderReasonSheet> createState() => _OrderReasonSheetState();
}

class _OrderReasonSheetState extends State<_OrderReasonSheet> {
  static const int _maxNote = 300;
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.isCancel ? l10n.cancelOrderTitle : l10n.rejectOrderTitle, style: text.titleMedium),
              const SizedBox(height: WsSpace.s8),
              Text(l10n.reasonPrompt, style: text.bodyMedium),
              const SizedBox(height: WsSpace.s8),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in kOrderReasons)
                      RadioListTile<String>(
                        value: r,
                        contentPadding: EdgeInsets.zero,
                        title: Text(orderReasonLabel(l10n, r), style: text.bodyLarge),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _note,
                maxLength: _maxNote,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.reasonNoteLabel),
              ),
              const SizedBox(height: WsSpace.s8),
              SaInfoBanner(
                variant: SaBannerVariant.warning,
                message: widget.prepaid ? l10n.rejectConsequencePrepaid : l10n.rejectConsequence,
              ),
              const SizedBox(height: WsSpace.s16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.errorFg, foregroundColor: t.surface),
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop(OrderReasonChoice(_reason!, _note.text.trim())),
                child: Text(widget.isCancel ? l10n.cancelOrderCta : l10n.rejectOrderCta),
              ),
              const SizedBox(height: WsSpace.s8),
              SaLoadingButton(
                text: l10n.keepOrder,
                variant: SaButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
