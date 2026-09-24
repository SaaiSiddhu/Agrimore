import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../invoice_screen.dart';

/// Order statuses an invoice can be issued for (mirrors INVOICEABLE in
/// functions/src/seller/sellerInvoice.ts).
const Set<String> kInvoiceableStatuses = {
  'confirmed', 'processing', 'ready_for_pickup', 'delivery_accepted', 'arrived_at_store',
  'picked_up', 'out_for_delivery', 'shipped', 'delivered', 'completed',
};

/// O-02 "Documents" block: generate the invoice once the order is accepted,
/// then open it. Issuing goes through the issueSellerInvoice callable.
class OrderInvoiceCard extends StatefulWidget {
  const OrderInvoiceCard({
    super.key,
    required this.orderId,
    required this.orderStatus,
    this.invoiceId,
    this.invoiceNumber,
  });

  final String orderId;
  final String orderStatus;
  final String? invoiceId;
  final String? invoiceNumber;

  @override
  State<OrderInvoiceCard> createState() => _OrderInvoiceCardState();
}

class _OrderInvoiceCardState extends State<OrderInvoiceCard> {
  bool _busy = false;
  bool _failed = false;
  String? _invoiceId;
  String? _invoiceNumber;

  @override
  void initState() {
    super.initState();
    _invoiceId = widget.invoiceId;
    _invoiceNumber = widget.invoiceNumber;
    if (_invoiceId == null) _loadExisting();
  }

  /// An invoice issued earlier is linked on the order (server-written).
  Future<void> _loadExisting() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      final id = snap.data()?['invoiceId'] as String?;
      if (id != null && mounted) {
        setState(() {
          _invoiceId = id;
          _invoiceNumber = snap.data()?['invoiceNumber'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Invoice lookup failed: $e');
    }
  }

  Future<void> _issue() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('issueSellerInvoice')
          .call<Map<String, dynamic>>({'orderId': widget.orderId});
      setState(() {
        _invoiceId = res.data['invoiceId'] as String?;
        _invoiceNumber = res.data['invoiceNumber'] as String?;
      });
      _open();
    } catch (e) {
      debugPrint('Invoice issue failed: $e');
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open() {
    final id = _invoiceId;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InvoiceScreen(invoiceId: id)));
  }

  Future<void> _copy() async {
    final number = _invoiceNumber;
    if (number == null) return;
    await Clipboard.setData(ClipboardData(text: number));
    if (mounted) SellerToast.show(context, AppLocalizations.of(context).invoiceNumberCopied, tone: SellerToastTone.success);
  }

  /// Board 17-07: before — "Invoice / Generate an invoice for this order."
  /// [Generate invoice]; after — the number with a copy button and
  /// [View invoice].
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final issued = _invoiceId != null;
    if (!issued && !kInvoiceableStatuses.contains(widget.orderStatus.toLowerCase())) {
      return const SizedBox.shrink();
    }
    return SellerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SellerIconTile(icon: SellerIcons.invoice),
              const SizedBox(width: SellerSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.invoiceTitle, style: text.titleSmall),
                  if (issued && _invoiceNumber != null)
                    Text(_invoiceNumber!, style: text.bodyLarge!.tabular)
                  else if (!issued)
                    Text(l10n.invoiceGeneratePrompt, style: text.bodyMedium),
                ]),
              ),
              if (issued && _invoiceNumber != null)
                SellerIconButton(icon: SellerIcons.copy, label: l10n.copyInvoiceNumber, onPressed: _copy),
            ],
          ),
          if (_failed) ...[
            const SizedBox(height: SellerSpace.s8),
            SellerBanner(tone: SellerTone.danger, message: l10n.invoiceIssueFailed),
          ],
          const SizedBox(height: SellerSpace.s12),
          if (issued)
            SellerButton(label: l10n.viewInvoice, icon: SellerIcons.document, expand: true, onPressed: _open)
          else
            SellerButton.secondary(
              label: l10n.generateInvoice,
              icon: SellerIcons.invoice,
              expand: true,
              loading: _busy,
              loadingLabel: l10n.generatingInvoice,
              onPressed: _issue,
            ),
        ],
      ),
    );
  }
}
