import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      ..writeln(l10n.statementTotals(AgFormat.rupees(gross), AgFormat.rupees(commission), AgFormat.rupees(net)))
      ..writeln();
    for (final e in entries) {
      b.writeln(l10n.statementLine(
        e.createdAt == null ? '' : AgFormat.date(e.createdAt!),
        e.orderNumber,
        AgFormat.rupees(e.net),
        e.isPaid ? (e.reference ?? l10n.payoutPaid) : l10n.payoutPending,
      ));
    }
    return b.toString();
  }
}

String monthLabel(DateTime month) => AgFormat.monthYear(month);

class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key, required this.statement});
  final MonthlyStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final s = statement;
    final label = monthLabel(s.month);
    Widget row(String k, String v, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: WsSpace.s4),
          child: Row(children: [
            Expanded(child: Text(k, style: text.bodyMedium!.copyWith(color: t.textSecondary))),
            Text(v, style: (strong ? text.titleSmall : text.bodyMedium)!.copyWith(fontFeatures: WsType.tabularFigures)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.statementHeading(label)),
        actions: [
          IconButton(
            tooltip: l10n.statementCopy,
            icon: const Icon(AgIcons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: s.toText(l10n, label)));
              if (context.mounted) WsToast.show(context, l10n.statementCopied, tone: WsToastTone.success);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WsSpace.page),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s16),
              child: Column(children: [
                row(l10n.settlementGross, AgFormat.rupees(s.gross)),
                row(l10n.settlementCommission, AgFormat.rupees(-s.commission)),
                const Divider(height: WsSpace.s16),
                row(l10n.settlementNet, AgFormat.rupees(s.net), strong: true),
                row(l10n.payoutPaid, AgFormat.rupees(s.paid)),
                row(l10n.payoutPending, AgFormat.rupees(s.pending)),
              ]),
            ),
          ),
          const SizedBox(height: WsSpace.s16),
          for (final e in s.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.paymentsForOrder(e.orderNumber), style: text.bodyMedium),
              subtitle: Text(e.createdAt == null ? '' : AgFormat.date(e.createdAt!), style: text.bodySmall),
              trailing: Text(AgFormat.rupees(e.net), style: text.titleSmall!.copyWith(fontFeatures: WsType.tabularFigures)),
            ),
        ],
      ),
    );
  }
}
