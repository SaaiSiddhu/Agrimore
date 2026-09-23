import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// O-04 Invoice (ADR §10.3, SELLER-ORDERS-2): renders the immutable
/// `invoices/{id}` snapshot the issueSellerInvoice callable wrote.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.invoiceId, this.data});

  final String invoiceId;

  /// Injected in tests; otherwise read from Firestore.
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final injected = data;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.invoiceTitle),
      ),
      body: injected != null
          ? _InvoiceBody(data: injected)
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = snap.data?.data();
                if (snap.hasError || d == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(WsSpace.page),
                      child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.invoiceLoadFailed),
                    ),
                  );
                }
                return _InvoiceBody(data: d);
              },
            ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.data});
  final Map<String, dynamic> data;

  num _n(Object? v) => v is num ? v : 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final isTax = data['docType'] == 'tax_invoice';
    final seller = (data['seller'] as Map?)?.cast<String, dynamic>() ?? const {};
    final buyer = (data['buyer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lines = ((data['lines'] as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    final issued = data['issuedAt'];
    final issuedAt = issued is Timestamp ? issued.toDate() : null;
    final number = data['invoiceNumber'] as String? ?? '';

    num sum(String k) => lines.fold<num>(0, (a, l) => a + _n(l[k]));
    final cgst = sum('cgst');
    final sgst = sum('sgst');
    final igst = sum('igst');

    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: strong ? text.titleSmall : text.bodyMedium)),
              Text(value,
                  style: (strong ? text.titleSmall : text.bodyLarge)!.copyWith(fontFeatures: WsType.tabularFigures)),
            ],
          ),
        );

    Widget party(String heading, String? name, String? address, {String? gstin}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading.toUpperCase(), style: text.labelSmall),
              const SizedBox(height: WsSpace.s4),
              if (name != null) Text(name, style: text.titleSmall),
              if (address != null) Text(address, style: text.bodySmall),
              if (gstin != null) Text(l10n.invoiceGstin(gstin), style: text.bodySmall),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(WsSpace.page),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isTax ? l10n.docTaxInvoice : l10n.docBillOfSupply, style: text.headlineMedium),
                const SizedBox(height: WsSpace.s4),
                Row(
                  children: [
                    Expanded(
                      child: Text(number,
                          style: text.titleSmall!.copyWith(color: t.primary, fontFeatures: WsType.tabularFigures)),
                    ),
                    IconButton(
                      tooltip: l10n.copyInvoiceNumber,
                      icon: const Icon(AgIcons.copy, size: WsIconSize.control),
                      onPressed: () => Clipboard.setData(ClipboardData(text: number)),
                    ),
                  ],
                ),
                if (issuedAt != null) Text(l10n.invoiceIssued(AgFormat.dateTime(issuedAt)), style: text.bodySmall),
                Text(l10n.invoiceForOrder(data['orderNumber'] as String? ?? ''), style: text.bodySmall),
                if (!isTax) ...[
                  const SizedBox(height: WsSpace.s12),
                  SaInfoBanner(variant: SaBannerVariant.info, message: l10n.billOfSupplyNote),
                ],
                const Divider(height: WsSpace.s32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    party(l10n.invoiceFrom, seller['shopName'] as String?, seller['address'] as String?,
                        gstin: seller['gstin'] as String?),
                    const SizedBox(width: WsSpace.s16),
                    party(l10n.invoiceTo, buyer['name'] as String?, buyer['address'] as String?),
                  ],
                ),
                const Divider(height: WsSpace.s32),
                for (final l in lines) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l['name'] as String? ?? '', style: text.titleSmall),
                            Text(
                              l10n.invoiceLineQty(AgFormat.count(_n(l['quantity'])), AgFormat.rupees(_n(l['unitPrice']))),
                              style: text.bodySmall,
                            ),
                            if (isTax)
                              Text(
                                l10n.invoiceLineTax(l['hsnCode'] as String? ?? '', AgFormat.count(_n(l['gstRate']))),
                                style: text.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Text(AgFormat.rupees(_n(l['amount'])),
                          style: text.bodyLarge!.copyWith(fontFeatures: WsType.tabularFigures)),
                    ],
                  ),
                  const SizedBox(height: WsSpace.s12),
                ],
                const Divider(height: WsSpace.s24),
                row(l10n.invoiceSubtotal, AgFormat.rupees(_n(totals['subtotal']))),
                if (_n(totals['discount']) > 0) row(l10n.invoiceDiscount, AgFormat.rupees(-_n(totals['discount']))),
                row(l10n.invoiceDelivery, AgFormat.rupees(_n(totals['deliveryCharge']))),
                if (isTax && cgst > 0) row(l10n.invoiceCgst, AgFormat.rupees(cgst)),
                if (isTax && sgst > 0) row(l10n.invoiceSgst, AgFormat.rupees(sgst)),
                if (isTax && igst > 0) row(l10n.invoiceIgst, AgFormat.rupees(igst)),
                const Divider(height: WsSpace.s24),
                row(l10n.invoiceTotal, AgFormat.rupees(_n(totals['total'])), strong: true),
                if (isTax) Text(l10n.invoiceTaxIncluded, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
