// lib/screens/money/money_screen.dart
//
// Phase 27 — The rider's earnings as the server records them (DLV-4A/4B, DLV-M1):
// this week's pay order by order, today's total, cash in hand from COD orders
// against the COD cash limit, weekly statements (each opens its detail), and
// the payout details with a change request that admin approves (D-DLV-BANK).
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../money/money_text.dart';
import '../../money/rider_money.dart';
import 'statement_screen.dart';

/// A rider's payout destination, as far as the app may show it.
typedef PayoutDetails = ({
  String? maskedAccount,
  String? ifsc,
  String? upiId,
  String? holder,
});

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({
    super.key,
    required this.riderId,
    this.earningsSource,
    this.accountSource,
    this.payoutsSource,
    this.bankChangeSource,
    this.payoutDetailsSource,
    this.cashLimit,
  });
  final String riderId;

  /// Injectable in tests, the same seam DLV-S1 established for
  /// DashboardScreen: null keeps the real Firestore-backed defaults, so
  /// production behaviour is unchanged.
  final Stream<List<RiderEarning>> Function(String riderId)? earningsSource;
  final Stream<RiderAccount> Function(String riderId)? accountSource;
  final Stream<List<RiderPayout>> Function(String riderId)? payoutsSource;
  final Stream<BankChangeRequest?> Function(String riderId)? bankChangeSource;
  final Stream<PayoutDetails> Function(String riderId)? payoutDetailsSource;
  final Future<double?> Function()? cashLimit;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  late final RiderMoneyService _money = RiderMoneyService(widget.riderId);
  late final Stream<List<RiderEarning>> _earnings =
      widget.earningsSource?.call(widget.riderId) ?? _money.unsettledEarnings();
  late final Stream<RiderAccount> _account =
      widget.accountSource?.call(widget.riderId) ?? _money.account();
  late final Stream<List<RiderPayout>> _payouts =
      widget.payoutsSource?.call(widget.riderId) ?? _money.payouts();
  late final Stream<BankChangeRequest?> _bankChange =
      widget.bankChangeSource?.call(widget.riderId) ?? _money.latestBankChange();
  late final Stream<PayoutDetails> _details =
      widget.payoutDetailsSource?.call(widget.riderId) ?? _money.payoutDetails();
  late final Future<double?> _cashLimit =
      widget.cashLimit?.call() ?? RiderMoneyService.codCashLimit();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.moneyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DeliverySpace.page,
          DeliverySpace.sm,
          DeliverySpace.page,
          DeliverySpace.xxxl,
        ),
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
                  const SizedBox(height: DeliverySpace.md),
                  _CashCard(account: _account, limit: _cashLimit),
                  const SizedBox(height: DeliverySpace.xl),
                  _Heading(
                    text: l.moneyThisWeek,
                    trailing:
                        list.isEmpty ? null : l.moneyDeliveries(list.length),
                  ),
                  if (snap.hasData && list.isEmpty)
                    _Muted(text: l.moneyNoDeliveriesYet),
                  for (final e in list) EarningTile(earning: e),
                ],
              );
            },
          ),
          const SizedBox(height: DeliverySpace.xl),
          _Heading(text: l.moneyStatementsTitle),
          StreamBuilder<List<RiderPayout>>(
            stream: _payouts,
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorLine(text: l.moneyStatementsError);
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(DeliverySpace.md),
                  child: LinearProgressIndicator(),
                );
              }
              if (snap.data!.isEmpty) {
                return _Muted(text: l.moneyStatementsEmpty);
              }
              return Column(
                children: [
                  for (final p in snap.data!)
                    _PayoutTile(
                      payout: p,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StatementScreen(
                            payout: p,
                            load: (after) =>
                                _money.statementLines(p.id, after: after),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: DeliverySpace.xl),
          _Heading(text: l.payoutDetailsTitle),
          _PayoutDetails(
            details: _details,
            bankChange: _bankChange,
            account: _account,
            onChange: _openChangeForm,
          ),
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
      showDeliveryToast(
        context,
        message: AppLocalizations.of(context).bankChangeSent,
        tone: DeliveryBannerTone.success,
      );
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.week,
    required this.today,
    required this.orders,
    required this.loading,
  });
  final double week;
  final double today;
  final int orders;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final on = c.onBrand;
    String amount(double v) =>
        loading ? l.moneyAmountLoading : DeliveryFormat.rupees(v);
    return Container(
      padding: const EdgeInsets.all(DeliverySpace.lg),
      decoration: BoxDecoration(
        color: c.brand,
        borderRadius: DeliveryRadius.rMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.moneyThisWeek, style: t.labelLarge.copyWith(color: on)),
                const SizedBox(height: DeliverySpace.xxs),
                Text(
                  amount(week),
                  style: t.headlineMedium.copyWith(color: on),
                ),
                Text(
                  [l.moneyDeliveries(orders), l.moneyPaidMondays].join(' · '),
                  style: t.bodySmall.copyWith(color: on),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(l.moneyToday, style: t.labelLarge.copyWith(color: on)),
              const SizedBox(height: DeliverySpace.xxs),
              Text(amount(today), style: t.titleLarge.copyWith(color: on)),
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
    final c = context.colors;
    final t = context.text;
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
            if (max != null)
              over
                  ? l.moneyCashOverLimit(DeliveryFormat.rupees(max))
                  : l.moneyCashUnderLimit(DeliveryFormat.rupees(max)),
          ];
          return Container(
            padding: const EdgeInsets.all(DeliverySpace.md),
            decoration: BoxDecoration(
              color: over ? c.warning.container : c.surface,
              borderRadius: DeliveryRadius.rMd,
              border: Border.all(
                color: over ? c.warning.border : c.borderSubtle,
                width: DeliverySize.hairline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  over ? DeliveryIcons.warning : DeliveryIcons.wallet,
                  color: over ? c.warning.icon : c.textSecondary,
                ),
                const SizedBox(width: DeliverySpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holding
                            ? l.moneyCashHeld(DeliveryFormat.rupees(cash))
                            : l.moneyCashNone,
                        style: t.titleSmall.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: DeliverySpace.xxs),
                      Text(
                        notes.join(' '),
                        style: t.bodySmall.copyWith(color: c.textSecondary),
                      ),
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
  const EarningTile({super.key, required this.earning, this.highlighted = false});
  final RiderEarning earning;

  /// DLVH4: true for the one line matching the order a statement was opened
  /// FROM (e.g. from history's own "in a weekly statement" link) -- the
  /// mockup's own "Highlight or locate the originating delivery where
  /// practical." Every other caller (MoneyScreen's own plain list) leaves
  /// this false, unchanged.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final e = earning;
    final when = e.createdAt?.toLocal();
    final lines = [
      earningBreakdown(l, e),
      if (e.codCollected > 0)
        l.moneyLineCash(DeliveryFormat.rupees(e.codCollected)),
      if (when != null) DeliveryFormat.dateTime(when),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
      child: DeliveryCard(
        padding: EdgeInsets.zero,
        variant: highlighted ? DeliveryCardVariant.brand : DeliveryCardVariant.standard,
        child: ListTile(
          title: Text(
            l.moneyEarningTitle(e.orderNumber ?? e.orderId),
            style: t.titleSmall.copyWith(color: c.textPrimary),
          ),
          subtitle: Text(
            lines.join('\n'),
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
          isThreeLine: lines.length > 2,
          trailing: Text(
            DeliveryFormat.rupees(e.total),
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
        ),
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
    final c = context.colors;
    final t = context.text;
    final p = payout;
    final stage = payoutStage(p);
    final color = switch (stage) {
      PayoutStage.paid => c.success.text,
      PayoutStage.heldForReview || PayoutStage.heldNoDetails => c.warning.text,
      _ => c.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
      child: DeliveryCard(
        onTap: onTap,
        padding: const EdgeInsets.all(DeliverySpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payoutTitle(l, p),
                    style: t.titleSmall.copyWith(color: c.textPrimary),
                  ),
                ),
                Text(
                  DeliveryFormat.rupees(p.amount),
                  style: t.titleMedium.copyWith(color: c.textPrimary),
                ),
                Icon(
                  DeliveryIcons.chevronRight,
                  size: DeliveryIconSize.sm,
                  color: c.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: DeliverySpace.xxs),
            Text(
              [
                l.moneyDeliveries(p.orderCount),
                l.moneyStatementEarned(DeliveryFormat.rupees(p.earned)),
                if (p.netted > 0)
                  l.moneyStatementCashOff(DeliveryFormat.rupees(p.netted)),
              ].join(' · '),
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.sm),
            Row(
              children: [
                Icon(
                  stage == PayoutStage.paid
                      ? DeliveryIcons.checkCircle
                      : DeliveryIcons.clock,
                  size: DeliveryIconSize.sm,
                  color: color,
                ),
                const SizedBox(width: DeliverySpace.sm),
                Expanded(
                  child: Text(
                    payoutStageText(l, p),
                    style: t.labelMedium.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutDetails extends StatelessWidget {
  const _PayoutDetails({
    required this.details,
    required this.bankChange,
    required this.account,
    required this.onChange,
  });
  final Stream<
      ({
        String? maskedAccount,
        String? ifsc,
        String? upiId,
        String? holder,
      })> details;
  final Stream<BankChangeRequest?> bankChange;
  final Stream<RiderAccount> account;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return StreamBuilder<
        ({
          String? maskedAccount,
          String? ifsc,
          String? upiId,
          String? holder,
        })>(
      stream: details,
      builder: (context, snap) {
        final d = snap.data;
        final lines = <String>[
          if (d?.maskedAccount != null)
            d!.ifsc == null
                ? l.payoutDetailsBank(d.maskedAccount!)
                : l.payoutDetailsBankIfsc(d.maskedAccount!, d.ifsc!),
          if (d?.upiId != null) l.payoutDetailsUpi(d!.upiId!),
        ];
        return DeliveryCard(
          padding: const EdgeInsets.all(DeliverySpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lines.isEmpty ? l.payoutDetailsNone : lines.join('\n'),
                style: t.bodyMedium.copyWith(color: c.textPrimary),
              ),
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
                    padding: const EdgeInsets.only(top: DeliverySpace.sm),
                    child: Text(
                      note,
                      style: t.bodySmall.copyWith(
                        color: r!.status == 'rejected'
                            ? c.danger.text
                            : c.warning.text,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: DeliverySpace.md),
              StreamBuilder<RiderAccount>(
                stream: account,
                builder: (context, acc) {
                  final pending = acc.data?.bankChangePending != null;
                  return DeliveryButton.secondary(
                    label:
                        pending ? l.bankChangeWaiting : l.bankChangeButton,
                    icon: DeliveryIcons.edit,
                    onPressed: pending ? null : onChange,
                  );
                },
              ),
            ],
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
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: DeliverySpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: t.titleMedium.copyWith(color: c.textPrimary),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: DeliverySpace.sm),
        child: Text(
          text,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(DeliverySpace.md),
        child: Text(
          text,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.danger.text,
          ),
        ),
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
    final problem = bankFormProblem(
      name: _name.text,
      account: _account.text,
      ifsc: _ifsc.text,
      upi: _upi.text,
    );
    if (problem != null) {
      setState(() => _error = bankProblemText(l, problem));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await RiderMoneyService.requestBankChange(
      name: _name.text,
      account: _account.text,
      ifsc: _ifsc.text,
      upi: _upi.text,
    );
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
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DeliverySpace.page,
        0,
        DeliverySpace.page,
        MediaQuery.of(context).viewInsets.bottom + DeliverySpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.bankFormTitle,
              style: t.titleLarge.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: DeliverySpace.xxs),
            Text(
              l.bankFormIntro,
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.bankFormHolder),
            ),
            const SizedBox(height: DeliverySpace.sm),
            TextField(
              controller: _account,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.bankFormAccount),
            ),
            const SizedBox(height: DeliverySpace.sm),
            TextField(
              controller: _ifsc,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l.bankFormIfsc),
            ),
            const SizedBox(height: DeliverySpace.md),
            Text(
              l.bankFormOr,
              textAlign: TextAlign.center,
              style: t.bodySmall.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: DeliverySpace.sm),
            TextField(
              controller: _upi,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l.bankFormUpi),
            ),
            if (_error != null) ...[
              const SizedBox(height: DeliverySpace.md),
              Text(
                _error!,
                style: t.bodyMedium.copyWith(color: c.danger.text),
              ),
            ],
            const SizedBox(height: DeliverySpace.lg),
            DeliveryButton.primary(
              label: l.bankFormSend,
              isLoading: _sending,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
