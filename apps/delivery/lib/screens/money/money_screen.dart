// lib/screens/money/money_screen.dart
//
// Phase DLV-4B — the rider's earnings as the server records them (DLV-4A):
// this week's pay order by order, today's total, cash in hand from COD
// orders, weekly statements with the paid reference, and the payout details
// with a change request that admin approves (D-DLV-BANK).
import 'package:flutter/material.dart';

import '../../money/rider_money.dart';

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
  late final Stream<({String? maskedAccount, String? ifsc, String? upiId, String? holder})> _details = _money.payoutDetails();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          StreamBuilder<List<RiderEarning>>(
            stream: _earnings,
            builder: (context, snap) {
              if (snap.hasError) return _error('Could not load your earnings. Check your connection.');
              final list = snap.data ?? const <RiderEarning>[];
              final week = list.fold(0.0, (s, e) => s + e.total);
              final today = earnedSince(list, istDayStart(DateTime.now()));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summary(cs, week: week, today: today, orders: list.length, loading: !snap.hasData),
                  const SizedBox(height: 12),
                  _cashCard(cs),
                  const SizedBox(height: 20),
                  _heading(cs, 'This week', list.isEmpty ? null : '${list.length} ${list.length == 1 ? 'delivery' : 'deliveries'}'),
                  if (snap.hasData && list.isEmpty)
                    _muted(cs, 'No deliveries yet this week. Pay for each delivery shows here as soon as it is delivered.'),
                  for (final e in list) _earningTile(cs, e),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _heading(cs, 'Weekly statements', null),
          StreamBuilder<List<RiderPayout>>(
            stream: _payouts,
            builder: (context, snap) {
              if (snap.hasError) return _error('Could not load statements.');
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
              if (snap.data!.isEmpty) {
                return _muted(cs, 'Your first statement is made on Monday for the week before. Pay is sent to your bank or UPI.');
              }
              return Column(children: [for (final p in snap.data!) _payoutTile(cs, p)]);
            },
          ),
          const SizedBox(height: 20),
          _heading(cs, 'Payout details', null),
          _payoutDetails(cs),
        ],
      ),
    );
  }

  Widget _summary(ColorScheme cs, {required double week, required double today, required int orders, required bool loading}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade500, Colors.green.shade700]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This week', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(loading ? '…' : rupees(week),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                Text('$orders ${orders == 1 ? 'delivery' : 'deliveries'} · paid every Monday',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Today', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(loading ? '…' : rupees(today),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cashCard(ColorScheme cs) {
    return StreamBuilder<RiderAccount>(
      stream: _account,
      builder: (context, snap) {
        final cash = snap.data?.cashHeld ?? 0;
        final holding = cash > 0.005;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: holding ? Colors.orange.shade50 : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: holding ? Colors.orange.shade200 : cs.outline.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.payments_rounded, color: holding ? Colors.orange.shade700 : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(holding ? 'Cash with you: ${rupees(cash)}' : 'No cash with you',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      holding
                          ? 'Cash from COD orders is taken off your Monday payout. Hand larger amounts to the Agrimore team — '
                              "while you hold too much cash you won't get cash-on-delivery orders."
                          : 'Cash you collect on COD orders shows here.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _earningTile(ColorScheme cs, RiderEarning e) {
    final parts = <String>[
      'Base ${rupees(e.basePay)}',
      // Two decimals: pay is worked out on the km as stored (4.05 km × ₹6 =
      // ₹24.30); "4.0 km ₹24.30" would not add up for the rider.
      if (e.km > 0) '${e.km.toStringAsFixed(2)} km ${rupees(e.distancePay)}',
      if (e.waitMinutes > 0) 'Waiting ${e.waitMinutes} min ${rupees(e.waitingPay)}',
    ];
    final when = e.createdAt?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Order #${e.orderNumber ?? e.orderId}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          parts.join(' · '),
          if (e.codCollected > 0) 'Collected ${rupees(e.codCollected)} cash',
          if (when != null) TimeOfDay.fromDateTime(when).format(context),
        ].join('\n')),
        isThreeLine: e.codCollected > 0 || when != null,
        trailing: Text(rupees(e.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  Widget _payoutTile(ColorScheme cs, RiderPayout p) {
    final paid = p.status == 'paid';
    final color = switch (p.status) {
      'paid' => Colors.green.shade700,
      'on_hold' => Colors.orange.shade800,
      _ => cs.onSurfaceVariant,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(payoutWeekLabel(p), style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(rupees(p.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${p.orderCount} ${p.orderCount == 1 ? 'delivery' : 'deliveries'} · earned ${rupees(p.earned)}'
              '${p.netted > 0 ? ' · cash taken off ${rupees(p.netted)}' : ''}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(paid ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(payoutStatusLabel(p), style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _payoutDetails(ColorScheme cs) {
    return StreamBuilder<({String? maskedAccount, String? ifsc, String? upiId, String? holder})>(
      stream: _details,
      builder: (context, snap) {
        final d = snap.data;
        final lines = <String>[
          if (d?.maskedAccount != null) 'Bank ${d!.maskedAccount}${d.ifsc == null ? '' : ' · ${d.ifsc}'}',
          if (d?.upiId != null) 'UPI ${d!.upiId}',
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lines.isEmpty ? 'No bank or UPI details yet — your pay will wait until you add them.' : lines.join('\n'),
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
                StreamBuilder<BankChangeRequest?>(
                  stream: _bankChange,
                  builder: (context, req) {
                    final r = req.data;
                    if (r == null) return const SizedBox.shrink();
                    final text = switch (r.status) {
                      'pending' => 'Your change is being checked by the Agrimore team.',
                      'rejected' => 'Your last change was not approved: ${r.rejectionReason ?? 'no reason given'}',
                      _ => null,
                    };
                    if (text == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(text,
                          style: TextStyle(
                              fontSize: 13, color: r.status == 'rejected' ? cs.error : Colors.orange.shade800)),
                    );
                  },
                ),
                const SizedBox(height: 10),
                StreamBuilder<RiderAccount>(
                  stream: _account,
                  builder: (context, acc) {
                    final pending = acc.data?.bankChangePending != null;
                    return OutlinedButton.icon(
                      onPressed: pending ? null : _openChangeForm,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(pending ? 'Change waiting for review' : 'Change payout details'),
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

  Future<void> _openChangeForm() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _BankChangeForm(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent. The Agrimore team will check it; your pay waits until then.')),
      );
    }
  }

  Widget _heading(ColorScheme cs, String text, String? trailing) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            if (trailing != null) Text(trailing, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      );

  Widget _muted(ColorScheme cs, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
      );

  Widget _error(String text) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await RiderMoneyService.requestBankChange(
        name: _name.text, account: _account.text, ifsc: _ifsc.text, upi: _upi.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Change payout details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('The Agrimore team checks every change before any money is sent to it.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: _name, textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Account holder name')),
            TextField(controller: _account, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bank account number')),
            TextField(controller: _ifsc, textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'IFSC')),
            const SizedBox(height: 12),
            const Text('and / or', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            TextField(controller: _upi, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'UPI ID (e.g. name@okaxis)')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send for review', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
