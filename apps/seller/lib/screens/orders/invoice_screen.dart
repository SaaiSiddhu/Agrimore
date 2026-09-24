import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

/// O-04 Invoice (board 17-07): renders the immutable `invoices/{id}`
/// snapshot the issueSellerInvoice callable wrote. The document type (Bill
/// of Supply / Tax Invoice) and every tax line come from that server data.
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
      appBar: SellerAppBar.detail(context, title: l10n.invoiceTitle),
      body: injected != null
          ? _InvoiceBody(data: injected)
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const SellerLoadingView();
                final d = snap.data?.data();
                if (snap.hasError || d == null) return SellerErrorState(title: l10n.invoiceLoadFailed);
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
    final c = context.colors;
    final text = context.text;
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

    Widget party(String heading, String? name, String? address, {String? gstin}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: text.labelMedium),
            const SizedBox(height: SellerSpace.s4),
            if (name != null) Text(name, style: text.titleSmall),
            if (address != null) Text(address, style: text.bodyMedium),
            if (gstin != null) Text(l10n.invoiceGstin(gstin), style: text.bodyMedium!.tabular),
          ],
        );

    final from = party(l10n.invoiceFrom, seller['shopName'] as String?, seller['address'] as String?, gstin: seller['gstin'] as String?);
    final to = party(l10n.invoiceTo, buyer['name'] as String?, buyer['address'] as String?);

    return SellerPage(
      children: [
        SellerCard(
          padding: const EdgeInsets.all(SellerSpace.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(isTax ? l10n.docTaxInvoice : l10n.docBillOfSupply, style: text.headlineMedium)),
              const SizedBox(height: SellerSpace.s4),
              Row(children: [
                Expanded(child: Text(number, style: text.titleSmall!.copyWith(color: c.primary).tabular)),
                SellerIconButton(
                  icon: SellerIcons.copy,
                  label: l10n.copyInvoiceNumber,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: number));
                    if (context.mounted) SellerToast.show(context, l10n.invoiceNumberCopied, tone: SellerToastTone.success);
                  },
                ),
              ]),
              if (issuedAt != null) Text(l10n.invoiceIssued(SellerFormat.dateTime(issuedAt)), style: text.bodyMedium),
              Text(l10n.invoiceForOrder(data['orderNumber'] as String? ?? ''), style: text.bodyMedium),
              if (!isTax) ...[
                const SizedBox(height: SellerSpace.s12),
                SellerBanner(tone: SellerTone.info, message: l10n.billOfSupplyNote),
              ],
              const Divider(height: SellerSpace.s32),
              if (context.largeText) ...[from, const SizedBox(height: SellerSpace.s16), to]
              else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: from),
                  const SizedBox(width: SellerSpace.s16),
                  Expanded(child: to),
                ]),
              const Divider(height: SellerSpace.s32),
              for (final l in lines)
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: SellerSpace.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l['name'] as String? ?? '', style: text.titleSmall),
                              Text(
                                l10n.invoiceLineQty(SellerFormat.count(_n(l['quantity'])), SellerFormat.money(_n(l['unitPrice']))),
                                style: text.bodyMedium!.tabular,
                              ),
                              if (isTax)
                                Text(
                                  l10n.invoiceLineTax(l['hsnCode'] as String? ?? '', SellerFormat.count(_n(l['gstRate']))),
                                  style: text.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: SellerSpace.s8),
                        Text(SellerFormat.money(_n(l['amount'])), style: text.bodyLarge!.tabular),
                      ],
                    ),
                  ),
                ),
              const Divider(height: SellerSpace.s16),
              SellerMoneyBreakdown(
                lines: [
                  SellerMoneyLine(l10n.invoiceSubtotal, SellerFormat.money(_n(totals['subtotal']))),
                  if (_n(totals['discount']) > 0)
                    SellerMoneyLine(l10n.invoiceDiscount, SellerFormat.money(-_n(totals['discount'])), tone: SellerTone.success),
                  SellerMoneyLine(l10n.invoiceDelivery, SellerFormat.money(_n(totals['deliveryCharge']))),
                  if (isTax && cgst > 0) SellerMoneyLine(l10n.invoiceCgst, SellerFormat.money(cgst)),
                  if (isTax && sgst > 0) SellerMoneyLine(l10n.invoiceSgst, SellerFormat.money(sgst)),
                  if (isTax && igst > 0) SellerMoneyLine(l10n.invoiceIgst, SellerFormat.money(igst)),
                ],
                totalLabel: l10n.invoiceTotal,
                total: SellerFormat.money(_n(totals['total'])),
                footnote: isTax ? l10n.invoiceTaxIncluded : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
