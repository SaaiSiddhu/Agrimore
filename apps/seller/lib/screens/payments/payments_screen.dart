import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'wallet.dart';
import 'statements.dart';

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
      } else if (e.status == 'pending' || e.status == 'requested') {
        // SELLER-WALLET-1: money in a withdrawal not yet paid is still owed.
        pending += e.net;
      }
    }
    return PayoutSummary(pending: pending, paid30d: paid30, paidAll: paidAll);
  }

  final double pending;
  final double paid30d;
  final double paidAll;
}

/// P-01 Payments (boards 19-01, 19-02, 19-07; SELLER-MONEY-1): the wallet
/// balance with Withdraw, the payout account on file (always masked; add or
/// change it for an admin to verify), what has been paid, and the
/// settlements. SELLER-WALLET-1 (owner 2026-09-24) replaced the brief's
/// read-only "no wallet" scope (decision D11, revised).
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, this.entries, this.payoutDetails, this.wallet});

  /// Injected in tests; otherwise streamed from Firestore.
  final List<PayoutEntry>? entries;
  final Map<String, dynamic>? payoutDetails;
  final WalletSource? wallet;

  static const int limit = 200;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  int _attempt = 0;
  WalletSource? _wallet;

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
    if (_wallet == null && widget.entries == null) {
      final uid = context.read<SellerAuthProvider>().currentUser?.uid;
      if (uid != null) _wallet = FirebaseWalletSource(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final injected = widget.entries;
    final uid = injected == null ? context.read<SellerAuthProvider>().currentUser?.uid : null;
    Widget body;
    if (injected != null) {
      body = PaymentsBody(entries: injected, payoutDetails: widget.payoutDetails, wallet: _wallet);
    } else if (uid == null) {
      body = const SizedBox.shrink();
    } else {
      body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey(_attempt),
        stream: FirebaseFirestore.instance
            .collection('seller_payouts')
            .where('sellerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(PaymentsScreen.limit)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return SellerErrorState(title: l10n.paymentsLoadFailed, onRetry: () => setState(() => _attempt++));
          }
          if (!snap.hasData) return SellerSkeletonList(label: l10n.dsLoading, thumbnail: false);
          final list = snap.data!.docs.map((d) => PayoutEntry.fromMap(d.id, d.data())).toList();
          // Streamed so an admin approving a bank/UPI change shows at once.
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('seller_payout_details').doc(uid).snapshots(),
            builder: (context, details) => PaymentsBody(entries: list, payoutDetails: details.data?.data(), wallet: _wallet),
          );
        },
      );
    }
    return Scaffold(appBar: SellerAppBar.root(context, title: l10n.paymentsTitle), body: body);
  }
}

/// Masked account line: "SBI · •••• 9012" or "UPI · ka•••••@bank".
String payoutAccountLine(AppLocalizations l10n, Map<String, dynamic> details) => details['payoutMethod'] == 'upi'
    ? l10n.payoutAccountUpi(SellerFormat.maskUpi((details['upiId'] ?? '').toString()))
    : l10n.payoutAccountBank(
        (details['bankName'] ?? '').toString(),
        SellerFormat.maskAccount((details['accountNumber'] ?? '').toString()),
      );

/// Status badge of a settlement: Pending (clock, amber) / Paid (check, green).
Widget settlementBadge(AppLocalizations l10n, PayoutEntry e) => e.isPaid
    ? SellerStatusBadge(label: l10n.payoutPaid, tone: SellerTone.success, icon: SellerIcons.success)
    : e.status == 'requested'
        ? SellerStatusBadge(label: l10n.payoutInWithdrawal, tone: SellerTone.info, icon: SellerIcons.bank)
        : SellerStatusBadge(label: l10n.payoutPending, tone: SellerTone.warning, icon: SellerIcons.pending);

/// One settlement row: order, date (paid date once paid), amount, status.
class SettlementRow extends StatelessWidget {
  const SettlementRow({super.key, required this.entry});
  final PayoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final e = entry;
    final date = e.isPaid && e.paidAt != null
        ? l10n.paymentsPaidOn(SellerFormat.date(e.paidAt!))
        : (e.createdAt == null ? null : SellerFormat.date(e.createdAt!));
    return SellerListRow(
      icon: SellerIcons.orders,
      title: l10n.paymentsForOrder(e.orderNumber),
      subtitle: date,
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(SellerFormat.money(e.net), style: text.titleSmall!.tabular),
        const SizedBox(height: SellerSpace.s4),
        settlementBadge(l10n, e),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettlementDetailScreen(entry: e))),
    );
  }
}

class PaymentsBody extends StatelessWidget {
  const PaymentsBody({super.key, required this.entries, this.payoutDetails, this.wallet});
  final List<PayoutEntry> entries;
  final Map<String, dynamic>? payoutDetails;

  /// With a wallet the balance card, Withdraw and the payout-account actions
  /// replace the read-only "To be paid" tile and account card.
  final WalletSource? wallet;

  static const int _recent = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final summary = PayoutSummary.of(entries, DateTime.now());
    final statements = MonthlyStatement.of(entries);
    final details = payoutDetails;

    Widget tile(String label, double value, {bool hero = false}) => SellerCard(
          tone: hero ? SellerCardTone.mint : SellerCardTone.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.labelLarge!.copyWith(color: hero ? c.textPrimary : c.textSecondary)),
            const SizedBox(height: SellerSpace.s4),
            Text(SellerFormat.moneyWhole(value), style: (hero ? text.displayLarge : text.titleLarge)!.tabular),
            if (hero) ...[
              const SizedBox(height: SellerSpace.s4),
              Text(summary.pending == 0 ? l10n.paymentsEmptyTitle : l10n.paymentsPendingHelp, style: text.bodyMedium!.copyWith(color: c.textPrimary)),
            ],
          ]),
        );

    // Three tiles side by side when they fit (19-07); hero + two below
    // otherwise (19-01), so no amount is ever cut.
    final summaryBlock = LayoutBuilder(builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      if (box.maxWidth / scale >= 560) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tile(l10n.paymentsPending, summary.pending, hero: true)),
            const SizedBox(width: SellerSpace.s12),
            Expanded(child: tile(l10n.paymentsPaid30d, summary.paid30d)),
            const SizedBox(width: SellerSpace.s12),
            Expanded(child: tile(l10n.paymentsPaidAll, summary.paidAll)),
          ]),
        );
      }
      final pair = [tile(l10n.paymentsPaid30d, summary.paid30d), tile(l10n.paymentsPaidAll, summary.paidAll)];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile(l10n.paymentsPending, summary.pending, hero: true),
        const SizedBox(height: SellerSpace.s12),
        if (context.largeText) ...[pair[0], const SizedBox(height: SellerSpace.s12), pair[1]]
        else
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: pair[0]),
              const SizedBox(width: SellerSpace.s12),
              Expanded(child: pair[1]),
            ]),
          ),
      ]);
    });

    final account = details == null
        ? SellerCard(
            tone: SellerCardTone.sunken,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SellerIconTile(icon: SellerIcons.bank, tone: SellerTone.warning),
              const SizedBox(width: SellerSpace.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.payoutAccountMissing, style: text.titleSmall),
                  Text(l10n.payoutAccountMissingHelp, style: text.bodyMedium),
                ]),
              ),
            ]),
          )
        : SellerCard(
            child: MergeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SellerIconTile(icon: SellerIcons.bank),
                const SizedBox(width: SellerSpace.s12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.payoutAccountTitle, style: text.titleSmall),
                    Text(payoutAccountLine(l10n, details), style: text.bodyMedium!.copyWith(color: c.textPrimary).tabular),
                    Text(l10n.payoutAccountOnFile, style: text.bodyMedium),
                  ]),
                ),
              ]),
            ),
          );

    final w = wallet;
    final paidPair = IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: tile(l10n.paymentsPaid30d, summary.paid30d)),
        const SizedBox(width: SellerSpace.s12),
        Expanded(child: tile(l10n.paymentsPaidAll, summary.paidAll)),
      ]),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s8, context.pageInset, SellerSpace.s32),
      children: [
        if (w != null) ...[
          WalletSection(source: w, payoutDetails: details),
          const SizedBox(height: SellerSpace.s16),
          if (context.largeText) ...[
            tile(l10n.paymentsPaid30d, summary.paid30d),
            const SizedBox(height: SellerSpace.s12),
            tile(l10n.paymentsPaidAll, summary.paidAll),
          ] else
            paidPair,
        ] else ...[
          summaryBlock,
          const SizedBox(height: SellerSpace.s16),
          account,
        ],
        if (statements.isNotEmpty) ...[
          const SizedBox(height: SellerSpace.section),
          SellerSectionHeader(title: l10n.statementsTitle),
          SellerMenuGroup(children: [
            for (final s in statements)
              SellerListRow(
                icon: SellerIcons.document,
                title: monthLabel(s.month),
                subtitle: l10n.statementCount(s.entries.length),
                value: SellerFormat.money(s.net),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StatementScreen(statement: s))),
              ),
          ]),
        ],
        const SizedBox(height: SellerSpace.section),
        SellerSectionHeader(
          title: l10n.paymentsRecent,
          actionLabel: entries.length > _recent ? l10n.paymentsSeeAll : null,
          onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AllSettlementsScreen(entries: entries))),
        ),
        if (entries.isEmpty)
          SellerEmptyState(icon: SellerIcons.receipt, title: l10n.paymentsEmptyTitle, message: l10n.paymentsEmpty, compact: true)
        else
          SellerMenuGroup(children: [for (final e in entries.take(_recent)) SettlementRow(entry: e)]),
      ],
    );
  }
}

/// Every settlement, newest first (gap: "all settlements list").
class AllSettlementsScreen extends StatelessWidget {
  const AllSettlementsScreen({super.key, required this.entries});
  final List<PayoutEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.paymentsAllTitle),
      body: SellerPage(children: [SellerMenuGroup(children: [for (final e in entries) SettlementRow(entry: e)])]),
    );
  }
}

/// P-03 Settlement detail (boards 19-03, 19-04): the amount, the recorded
/// events, the financials exactly as the settlement record has them, and the
/// payment reference with copy.
class SettlementDetailScreen extends StatelessWidget {
  const SettlementDetailScreen({super.key, required this.entry});
  final PayoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final e = entry;
    final reference = e.reference;
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.paymentsForOrder(e.orderNumber), status: settlementBadge(l10n, e)),
      body: SellerPage(
        gap: SellerSpace.s16,
        children: [
          SellerAmountHero(
            label: e.isPaid ? l10n.settlementReceived : l10n.settlementToReceive,
            amount: SellerFormat.money(e.net),
            caption: e.createdAt == null ? null : l10n.paymentsCreatedOn(SellerFormat.date(e.createdAt!)),
            icon: e.isPaid ? null : SellerIcons.pending,
          ),
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(l10n.settlementStatus, style: text.titleSmall)),
              const SizedBox(height: SellerSpace.s12),
              SellerTimeline(showCurrentPill: false, steps: [
                SellerTimelineStep(
                  title: l10n.settlementCreated,
                  subtitle: e.createdAt == null ? null : SellerFormat.dateTime(e.createdAt!),
                  state: SellerStepState.done,
                ),
                e.isPaid
                    ? SellerTimelineStep(
                        title: l10n.settlementPaid,
                        subtitle: e.paidAt == null ? null : SellerFormat.dateTime(e.paidAt!),
                        state: SellerStepState.done,
                      )
                    : SellerTimelineStep(title: l10n.settlementPaymentPending, subtitle: l10n.settlementAwaiting, state: SellerStepState.upcoming),
              ]),
            ]),
          ),
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(l10n.settlementFinancials, style: text.titleSmall)),
              SellerMoneyBreakdown(
                lines: [
                  SellerMoneyLine(l10n.settlementGross, SellerFormat.money(e.gross)),
                  SellerMoneyLine(l10n.settlementCommission, SellerFormat.money(-e.commission)),
                ],
                totalLabel: l10n.settlementNet,
                total: SellerFormat.money(e.net),
                totalTone: SellerTone.brand,
                footnote: l10n.settlementAmountsNote,
              ),
            ]),
          ),
          if (reference != null && reference.isNotEmpty)
            SellerCard(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.settlementReference, style: text.bodyMedium),
                    Text(reference, style: text.titleSmall!.tabular),
                  ]),
                ),
                SellerIconButton(
                  icon: SellerIcons.copy,
                  label: l10n.settlementCopyReference,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: reference));
                    if (context.mounted) SellerToast.show(context, l10n.settlementReferenceCopied, tone: SellerToastTone.success);
                  },
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
