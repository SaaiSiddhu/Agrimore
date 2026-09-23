import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';

/// One settlement row from `seller_payouts` (written by the server when an
/// order is delivered; marked paid by an admin with a UTR reference).
@immutable
class PayoutEntry {
  const PayoutEntry({
    required this.id,
    required this.orderNumber,
    required this.gross,
    required this.commission,
    required this.net,
    required this.status,
    this.createdAt,
    this.paidAt,
    this.reference,
  });

  factory PayoutEntry.fromMap(String id, Map<String, dynamic> d) {
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    DateTime? t(Object? v) => v is Timestamp ? v.toDate() : null;
    return PayoutEntry(
      id: id,
      orderNumber: (d['orderNumber'] ?? d['orderId'] ?? '').toString(),
      gross: n(d['grossAmount']),
      commission: n(d['commissionAmount']),
      net: n(d['netAmount'] ?? d['amount']),
      status: (d['status'] ?? 'pending').toString(),
      createdAt: t(d['createdAt']),
      paidAt: t(d['paidAt']),
      reference: d['paymentReference'] as String?,
    );
  }

  final String id;
  final String orderNumber;
  final double gross;
  final double commission;
  final double net;
  final String status;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? reference;

  bool get isPaid => status == 'paid';
}

/// Totals shown on P-01. Pure — unit-tested.
@immutable
class PayoutSummary {
  const PayoutSummary({required this.pending, required this.paid30d, required this.paidAll});

  factory PayoutSummary.of(List<PayoutEntry> entries, DateTime now) {
    const window = Duration(days: 30);
    double pending = 0, paid30 = 0, paidAll = 0;
    for (final e in entries) {
      if (e.isPaid) {
        paidAll += e.net;
        final at = e.paidAt ?? e.createdAt;
        if (at != null && now.difference(at) <= window) paid30 += e.net;
      } else if (e.status == 'pending') {
        pending += e.net;
      }
    }
    return PayoutSummary(pending: pending, paid30d: paid30, paidAll: paidAll);
  }

  final double pending;
  final double paid30d;
  final double paidAll;
}

/// P-01 Payments (ADR §10.5, SELLER-MONEY-1): what the seller is owed and has
/// been paid, the payout account on file (masked), and every settlement.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key, this.entries, this.payoutDetails});

  /// Injected in tests; otherwise streamed from Firestore.
  final List<PayoutEntry>? entries;
  final Map<String, dynamic>? payoutDetails;

  static const int _limit = 200;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final injected = entries;
    final uid = injected == null ? context.read<SellerAuthProvider>().currentUser?.uid : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentsTitle), automaticallyImplyLeading: false),
      body: injected != null
          ? _PaymentsBody(entries: injected, payoutDetails: payoutDetails)
          : uid == null
              ? const SizedBox.shrink()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('seller_payouts')
                      .where('sellerId', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .limit(_limit)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(WsSpace.page),
                        child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.paymentsLoadFailed),
                      );
                    }
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final list = snap.data!.docs.map((d) => PayoutEntry.fromMap(d.id, d.data())).toList();
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('seller_payout_details').doc(uid).get(),
                      builder: (context, details) =>
                          _PaymentsBody(entries: list, payoutDetails: details.data?.data()),
                    );
                  },
                ),
    );
  }
}

class _PaymentsBody extends StatelessWidget {
  const _PaymentsBody({required this.entries, this.payoutDetails});
  final List<PayoutEntry> entries;
  final Map<String, dynamic>? payoutDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final summary = PayoutSummary.of(entries, DateTime.now());

    Widget metric(String label, double value, {bool primary = false}) => Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.bodyMedium),
                  const SizedBox(height: WsSpace.s4),
                  Text(
                    AgFormat.rupeesWhole(value),
                    style: (primary ? text.headlineMedium : text.titleMedium)!
                        .copyWith(fontFeatures: WsType.tabularFigures, color: primary ? t.primary : null),
                  ),
                ],
              ),
            ),
        );

    final details = payoutDetails;
    final String account = details == null
        ? l10n.payoutAccountMissing
        : details['payoutMethod'] == 'upi'
            ? l10n.payoutAccountUpi((details['upiId'] ?? '').toString())
            : l10n.payoutAccountBank(
                (details['bankName'] ?? '').toString(),
                AgFormat.maskAccount((details['accountNumber'] ?? '').toString()),
              );

    return ListView(
      padding: const EdgeInsets.all(WsSpace.page),
      children: [
        metric(l10n.paymentsPending, summary.pending, primary: true),
        Row(children: [
          Expanded(child: metric(l10n.paymentsPaid30d, summary.paid30d)),
          const SizedBox(width: WsSpace.s12),
          Expanded(child: metric(l10n.paymentsPaidAll, summary.paidAll)),
        ]),
        const SizedBox(height: WsSpace.s12),
        Card(
          child: ListTile(
            leading: Icon(AgIcons.bank, color: details == null ? t.warningFg : t.primary),
            title: Text(l10n.payoutAccountTitle, style: text.titleSmall),
            subtitle: Text(account),
          ),
        ),
        if (details == null) ...[
          const SizedBox(height: WsSpace.s8),
          SaInfoBanner(variant: SaBannerVariant.warning, message: l10n.payoutAccountMissingHelp),
        ],
        const SizedBox(height: WsSpace.s24),
        Text(l10n.paymentsHistory, style: text.titleMedium),
        const SizedBox(height: WsSpace.s8),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: WsSpace.s32),
            child: Column(
              children: [
                Icon(AgIcons.wallet, size: WsIconSize.empty, color: t.textTertiary),
                const SizedBox(height: WsSpace.s12),
                Text(l10n.paymentsEmpty, style: text.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          )
        else
          for (final e in entries)
            Card(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettlementDetailScreen(entry: e)),
                ),
                title: Text(l10n.paymentsForOrder(e.orderNumber), style: text.titleSmall),
                subtitle: Text(e.createdAt == null ? '' : AgFormat.date(e.createdAt!), style: text.bodySmall),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(AgFormat.rupees(e.net),
                        style: text.titleSmall!.copyWith(fontFeatures: WsType.tabularFigures)),
                    Text(
                      e.isPaid ? l10n.payoutPaid : l10n.payoutPending,
                      style: text.labelMedium!.copyWith(color: e.isPaid ? t.successFg : t.warningFg),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// P-03 Settlement detail: what the order earned, what AgriMore kept, what
/// was paid and the bank reference.
class SettlementDetailScreen extends StatelessWidget {
  const SettlementDetailScreen({super.key, required this.entry});
  final PayoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    Widget row(String label, String value, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
          child: Row(children: [
            Expanded(child: Text(label, style: strong ? text.titleSmall : text.bodyMedium)),
            Text(value,
                style: (strong ? text.titleMedium : text.bodyLarge)!
                    .copyWith(fontFeatures: WsType.tabularFigures, color: color)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.paymentsForOrder(entry.orderNumber)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WsTimeline(steps: [
                    WsTimelineStep(
                      title: l10n.settlementCreated,
                      caption: entry.createdAt == null ? null : AgFormat.dateTime(entry.createdAt!),
                      state: WsTimelineState.done,
                    ),
                    WsTimelineStep(
                      title: l10n.settlementPaid,
                      caption: entry.paidAt == null ? null : AgFormat.dateTime(entry.paidAt!),
                      state: entry.isPaid ? WsTimelineState.done : WsTimelineState.current,
                    ),
                  ]),
                  const Divider(height: WsSpace.s32),
                  row(l10n.settlementGross, AgFormat.rupees(entry.gross)),
                  row(l10n.settlementCommission, AgFormat.rupees(-entry.commission), color: t.textSecondary),
                  const Divider(height: WsSpace.s16),
                  row(l10n.settlementNet, AgFormat.rupees(entry.net), strong: true),
                  if (entry.reference != null && entry.reference!.isNotEmpty)
                    row(l10n.settlementReference, entry.reference!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
