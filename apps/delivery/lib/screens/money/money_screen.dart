// lib/screens/money/money_screen.dart
//
// The rider's earnings as the server records them (DLV-4A/4B, DLV-M1): this
// week's pay order by order, today's total, cash in hand from COD orders
// against the COD cash limit, weekly statements (each opens its detail), and
// the payout details with a change request that admin approves (D-DLV-BANK).
// DLV-M1: Workspace tokens and lib/l10n strings; amounts are exact paise.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import 'statement_screen.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, required this.riderId});
  final String riderId;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  late final RiderMoneyService _money = RiderMoneyService(widget.riderId);
  late final Stream<List<RiderEarning>> _earnings = _money.unsettledEarnings();
  late final Stream<RiderAccount> _account = _money.account();
  late final Stream<List<RiderPayout>> _payouts = _money.payouts();
  late final Stream<BankChangeRequest?> _bankChange = _money.latestBankChange();
  late final Stream<({String? maskedAccount, String? ifsc, String? upiId, String? holder})> _details =
      _money.payoutDetails();
  late final Future<double?> _cashLimit = RiderMoneyService.codCashLimit();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.moneyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, WsSpace.s32),
        children: [
          StreamBuilder<List<RiderEarning>>(
            stream: _earnings,
            builder: (context, snap) {
              if (snap.hasError) return _ErrorLine(text: l.moneyLoadError);
              final list = snap.data ?? const <RiderEarning>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Summary(
                    week: sumRupees(list.map((e) => e.total)),
                    today: earnedSince(list, istDayStart(DateTime.now())),
                    orders: list.length,
                    loading: !snap.hasData,
                  ),
                  const SizedBox(height: WsSpace.s12),
                  _CashCard(account: _account, limit: _cashLimit),
                  const SizedBox(height: WsSpace.s20),
                  _Heading(text: l.moneyThisWeek, trailing: list.isEmpty ? null : l.moneyDeliveries(list.length)),
                  if (snap.hasData && list.isEmpty) _Muted(text: l.moneyNoDeliveriesYet),
                  for (final e in list) EarningTile(earning: e),
                ],
              );
            },
          ),
          const SizedBox(height: WsSpace.s20),
          _Heading(text: l.moneyStatementsTitle),
          StreamBuilder<List<RiderPayout>>(
            stream: _payouts,
            builder: (context, snap) {
              if (snap.hasError) return _ErrorLine(text: l.moneyStatementsError);
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(WsSpace.s12), child: LinearProgressIndicator());
              }
              if (snap.data!.isEmpty) return _Muted(text: l.moneyStatementsEmpty);
              return Column(children: [
                for (final p in snap.data!)
                  _PayoutTile(
                    payout: p,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => StatementScreen(
                            payout: p, load: (after) => _money.statementLines(p.id, after: after)))),
                  ),
              ]);
            },
          ),
          const SizedBox(height: WsSpace.s20),
          _Heading(text: l.payoutDetailsTitle),
          _PayoutDetails(details: _details, bankChange: _bankChange, account: _account, onChange: _openChangeForm),
        ],
      ),
    );
  }

  Future<void> _openChangeForm() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _BankChangeForm(),
    );
    if (sent == true && mounted) {
      WsToast.show(context, AppLocalizations.of(context).bankChangeSent, tone: WsToastTone.success);
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.week, required this.today, required this.orders, required this.loading});
  final double week;
  final double today;
  final int orders;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final on = t.onPrimary;
    String amount(double v) => loading ? l.moneyAmountLoading : AgFormat.rupees(v);
    return Container(
      padding: const EdgeInsets.all(WsSpace.s16),
      decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(WsRadius.card)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.moneyThisWeek, style: text.labelLarge?.copyWith(color: on)),
                const SizedBox(height: WsSpace.s4),
                Text(amount(week), style: text.headlineMedium?.copyWith(color: on)),
                Text([l.moneyDeliveries(orders), l.moneyPaidMondays].join(' · '), style: text.bodySmall?.copyWith(color: on)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(l.moneyToday, style: text.labelLarge?.copyWith(color: on)),
              const SizedBox(height: WsSpace.s4),
              Text(amount(today), style: text.titleLarge?.copyWith(color: on)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.account, required this.limit});
  final Stream<RiderAccount> account;
  final Future<double?> limit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return StreamBuilder<RiderAccount>(
      stream: account,
      builder: (context, snap) => FutureBuilder<double?>(
        future: limit,
        builder: (context, lim) {
          final cash = snap.data?.cashHeld ?? 0;
          final holding = cash > 0;
          final max = lim.data;
          final over = max != null && cash >= max;
          final notes = <String>[
            holding ? l.moneyCashHint : l.moneyCashNoneHint,
            if (max != null) over ? l.moneyCashOverLimit(AgFormat.rupees(max)) : l.moneyCashUnderLimit(AgFormat.rupees(max)),
          ];
          return Container(
            padding: const EdgeInsets.all(WsSpace.s12),
            decoration: BoxDecoration(
              color: over ? t.warningBg : t.surface,
              borderRadius: BorderRadius.circular(WsRadius.card),
              border: Border.all(color: over ? t.warningFg : t.divider, width: WsSize.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(over ? AgIcons.warning : AgIcons.wallet, color: over ? t.warningFg : t.textSecondary),
                const SizedBox(width: WsSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holding ? l.moneyCashHeld(AgFormat.rupees(cash)) : l.moneyCashNone, style: text.titleSmall),
                      const SizedBox(height: WsSpace.s4),
                      Text(notes.join(' '), style: text.bodySmall?.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One delivered order's pay (also used by the statement screen).
class EarningTile extends StatelessWidget {
  const EarningTile({super.key, required this.earning});
  final RiderEarning earning;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final e = earning;
    final when = e.createdAt?.toLocal();
    final lines = [
      earningBreakdown(l, e),
      if (e.codCollected > 0) l.moneyLineCash(AgFormat.rupees(e.codCollected)),
      if (when != null) AgFormat.dateTime(when),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: WsSpace.s8),
      child: ListTile(
        title: Text(l.moneyEarningTitle(e.orderNumber ?? e.orderId), style: text.titleSmall),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 2,
        trailing: Text(AgFormat.rupees(e.total), style: text.titleMedium),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout, required this.onTap});
  final RiderPayout payout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final p = payout;
    final stage = payoutStage(p);
    final color = switch (stage) {
      PayoutStage.paid => t.successFg,
      PayoutStage.heldForReview || PayoutStage.heldNoDetails => t.warningFg,
      _ => t.textSecondary,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: WsSpace.s8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(WsSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(payoutTitle(l, p), style: text.titleSmall)),
                Text(AgFormat.rupees(p.amount), style: text.titleMedium),
                Icon(AgIcons.chevronRight, size: WsIconSize.supporting, color: t.textTertiary),
              ]),
              const SizedBox(height: WsSpace.s4),
              Text(
                [
                  l.moneyDeliveries(p.orderCount),
                  l.moneyStatementEarned(AgFormat.rupees(p.earned)),
                  if (p.netted > 0) l.moneyStatementCashOff(AgFormat.rupees(p.netted)),
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: WsSpace.s8),
              Row(children: [
                Icon(stage == PayoutStage.paid ? AgIcons.success : AgIcons.clock,
                    size: WsIconSize.supporting, color: color),
                const SizedBox(width: WsSpace.s8),
                Expanded(child: Text(payoutStageText(l, p), style: text.labelMedium?.copyWith(color: color))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutDetails extends StatelessWidget {
  const _PayoutDetails({required this.details, required this.bankChange, required this.account, required this.onChange});
  final Stream<({String? maskedAccount, String? ifsc, String? upiId, String? holder})> details;
  final Stream<BankChangeRequest?> bankChange;
  final Stream<RiderAccount> account;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return StreamBuilder<({String? maskedAccount, String? ifsc, String? upiId, String? holder})>(
      stream: details,
      builder: (context, snap) {
        final d = snap.data;
        final lines = <String>[
          if (d?.maskedAccount != null)
            d!.ifsc == null ? l.payoutDetailsBank(d.maskedAccount!) : l.payoutDetailsBankIfsc(d.maskedAccount!, d.ifsc!),
          if (d?.upiId != null) l.payoutDetailsUpi(d!.upiId!),
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lines.isEmpty ? l.payoutDetailsNone : lines.join('\n'), style: text.bodyMedium),
                StreamBuilder<BankChangeRequest?>(
                  stream: bankChange,
                  builder: (context, req) {
                    final r = req.data;
                    final note = switch (r?.status) {
                      'pending' => l.bankChangeReviewing,
                      'rejected' => (r!.rejectionReason ?? '').isEmpty
                          ? l.bankChangeRejectedNoReason
                          : l.bankChangeRejected(r.rejectionReason!),
                      _ => null,
                    };
                    if (note == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: WsSpace.s8),
                      child: Text(note,
                          style: text.bodySmall?.copyWith(color: r!.status == 'rejected' ? t.errorFg : t.warningFg)),
                    );
                  },
                ),
                const SizedBox(height: WsSpace.s12),
                StreamBuilder<RiderAccount>(
                  stream: account,
                  builder: (context, acc) {
                    final pending = acc.data?.bankChangePending != null;
                    return OutlinedButton.icon(
                      onPressed: pending ? null : onChange,
                      icon: const Icon(AgIcons.edit, size: WsIconSize.supporting),
                      label: Text(pending ? l.bankChangeWaiting : l.bankChangeButton),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: WsSpace.s8),
      child: Row(children: [
        Expanded(child: Text(text, style: theme.titleMedium)),
        if (trailing != null) Text(trailing!, style: theme.bodySmall?.copyWith(color: context.ws.textSecondary)),
      ]),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: WsSpace.s8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.ws.textSecondary)),
      );
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(WsSpace.s12),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.ws.errorFg)),
      );
}

class _BankChangeForm extends StatefulWidget {
  const _BankChangeForm();
  @override
  State<_BankChangeForm> createState() => _BankChangeFormState();
}

class _BankChangeFormState extends State<_BankChangeForm> {
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _account, _ifsc, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final problem = bankFormProblem(name: _name.text, account: _account.text, ifsc: _ifsc.text, upi: _upi.text);
    if (problem != null) {
      setState(() => _error = bankProblemText(l, problem));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await RiderMoneyService.requestBankChange(
        name: _name.text, account: _account.text, ifsc: _ifsc.text, upi: _upi.text);
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _sending = false;
        _error = bankFailureText(l, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          WsSpace.page, 0, WsSpace.page, MediaQuery.of(context).viewInsets.bottom + WsSpace.s20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.bankFormTitle, style: text.titleLarge),
            const SizedBox(height: WsSpace.s4),
            Text(l.bankFormIntro, style: text.bodySmall),
            const SizedBox(height: WsSpace.s16),
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.bankFormHolder)),
            const SizedBox(height: WsSpace.s8),
            TextField(
                controller: _account,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.bankFormAccount)),
            const SizedBox(height: WsSpace.s8),
            TextField(
                controller: _ifsc,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l.bankFormIfsc)),
            const SizedBox(height: WsSpace.s12),
            Text(l.bankFormOr, textAlign: TextAlign.center, style: text.bodySmall),
            const SizedBox(height: WsSpace.s8),
            TextField(
                controller: _upi,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l.bankFormUpi)),
            if (_error != null) ...[
              const SizedBox(height: WsSpace.s12),
              Text(_error!, style: text.bodyMedium?.copyWith(color: context.ws.errorFg)),
            ],
            const SizedBox(height: WsSpace.s16),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox.square(
                      dimension: WsIconSize.control, child: CircularProgressIndicator(strokeWidth: WsSize.focusRing))
                  : Text(l.bankFormSend),
            ),
          ],
        ),
      ),
    );
  }
}
