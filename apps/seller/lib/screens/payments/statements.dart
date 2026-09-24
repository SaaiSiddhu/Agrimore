import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import 'payments_screen.dart';

/// P-05 monthly statement (ADR gap 30, SELLER-POLISH-1): settlements created
/// in one calendar month, with totals. Pure grouping — unit-tested.
@immutable
class MonthlyStatement {
  const MonthlyStatement({required this.month, required this.entries});
  final DateTime month; // first day of the month
  final List<PayoutEntry> entries;

  double get gross => entries.fold(0, (s, e) => s + e.gross);
  double get commission => entries.fold(0, (s, e) => s + e.commission);
  double get net => entries.fold(0, (s, e) => s + e.net);
  double get paid => entries.where((e) => e.isPaid).fold(0, (s, e) => s + e.net);
  double get pending => entries.where((e) => !e.isPaid).fold(0, (s, e) => s + e.net);

  /// Newest month first; entries without a date are left out.
  static List<MonthlyStatement> of(Iterable<PayoutEntry> entries) {
    final byMonth = <DateTime, List<PayoutEntry>>{};
    for (final e in entries) {
      final at = e.createdAt;
      if (at == null) continue;
      byMonth.putIfAbsent(DateTime(at.year, at.month), () => []).add(e);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final m in months) MonthlyStatement(month: m, entries: byMonth[m]!)];
  }

  /// Plain-text statement for sharing with an accountant.
  String toText(AppLocalizations l10n, String monthLabel) {
    final b = StringBuffer()
      ..writeln(l10n.statementHeading(monthLabel))
      ..writeln(l10n.statementTotals(SellerFormat.money(gross), SellerFormat.money(commission), SellerFormat.money(net)))
      ..writeln();
    for (final e in entries) {
      b.writeln(l10n.statementLine(
        e.createdAt == null ? '' : SellerFormat.date(e.createdAt!),
        e.orderNumber,
        SellerFormat.money(e.net),
        e.isPaid ? (e.reference ?? l10n.payoutPaid) : l10n.payoutPending,
      ));
    }
    return b.toString();
  }
}

String monthLabel(DateTime month) => SellerFormat.monthYear(month);

/// P-05 Monthly statement (board 19-05): summary, the month's orders and a
/// copy action for the seller's accountant.
class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key, required this.statement});
  final MonthlyStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final s = statement;
    final label = monthLabel(s.month);
    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: s.toText(l10n, label)));
      if (context.mounted) SellerToast.show(context, l10n.statementCopied, tone: SellerToastTone.success);
    }

    return Scaffold(
      appBar: SellerAppBar.detail(
        context,
        title: label,
        subtitle: l10n.statementSubtitle,
        actions: [SellerIconButton(icon: SellerIcons.copy, label: l10n.statementCopy, onPressed: copy)],
      ),
      body: SellerPage(
        gap: SellerSpace.s16,
        children: [
          Semantics(header: true, child: Text(l10n.statementHeading(label), style: text.titleMedium)),
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l10n.statementSummary, style: text.titleSmall),
              SellerMoneyBreakdown(
                lines: [
                  SellerMoneyLine(l10n.settlementGross, SellerFormat.money(s.gross)),
                  SellerMoneyLine(l10n.settlementCommission, SellerFormat.money(-s.commission)),
                ],
                totalLabel: l10n.settlementNet,
                total: SellerFormat.money(s.net),
                totalTone: SellerTone.brand,
                after: [
                  SellerMoneyLine(l10n.payoutPaid, SellerFormat.money(s.paid), tone: SellerTone.success),
                  SellerMoneyLine(l10n.payoutPending, SellerFormat.money(s.pending), tone: SellerTone.warning),
                ],
              ),
            ]),
          ),
          SellerSectionHeader(title: l10n.statementOrders, count: s.entries.length),
          SellerMenuGroup(children: [
            for (final e in s.entries)
              SellerListRow(
                icon: SellerIcons.document,
                title: l10n.paymentsForOrder(e.orderNumber),
                subtitle: e.createdAt == null ? null : l10n.paymentsCreatedOn(SellerFormat.date(e.createdAt!)),
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Text(SellerFormat.money(e.net), style: text.titleSmall!.tabular),
                  const SizedBox(height: SellerSpace.s4),
                  settlementBadge(l10n, e),
                ]),
              ),
          ]),
          SellerButton.tonal(label: l10n.statementCopy, icon: SellerIcons.copy, expand: true, onPressed: copy),
        ],
      ),
    );
  }
}
