import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import 'rider_money_admin.dart';

/// Phase DLV-4B: rider money for the delivery team, on top of DLV-4A
/// (functions/src/delivery/riderMoney.ts).
///  - Statements: weekly rider_payouts; firestore.rules allow exactly one
///    admin write — pending → paid with a UTR (the seller payouts rule).
///  - Cash: riders holding COD cash; record a deposit (recordRiderCashDeposit).
///  - Payout details: riders' bank/UPI change requests (reviewRiderBankChange).
///  - Pay rates: settings/rider_pay, bounded as the server bounds them.
class RiderPayoutsScreen extends StatelessWidget {
  const RiderPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rider Payouts'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Statements'),
              Tab(text: 'Cash with riders'),
              Tab(text: 'Payout details'),
              Tab(text: 'Pay rates'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_StatementsTab(), _CashTab(), _BankChangesTab(), _RatesTab()],
        ),
      ),
    );
  }
}

final FirebaseFirestore _db = FirebaseFirestore.instance;
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Rider profiles, fetched once per rider (names and payout details).
final Map<String, Map<String, dynamic>?> _riders = {};
Future<Map<String, dynamic>?> _rider(String id) async {
  if (_riders.containsKey(id)) return _riders[id];
  try {
    _riders[id] = (await _db.collection('delivery_partners').doc(id).get()).data();
  } catch (e) {
    debugPrint('Rider lookup failed for $id: $e');
    _riders[id] = null;
  }
  return _riders[id];
}

String _riderName(Map<String, dynamic>? r, String id) =>
    (r?['name'] as String?)?.trim().isNotEmpty == true ? r!['name'] as String : 'Rider ${id.substring(0, id.length < 6 ? id.length : 6)}';

String _destination(Map<String, dynamic>? r) {
  final acct = (r?['bankAccountNumber'] as String?) ?? '';
  final upi = (r?['upiId'] as String?) ?? '';
  final parts = <String>[
    if (acct.isNotEmpty) '${AgFormat.maskAccount(acct)} · ${r?['ifscCode'] ?? ''}',
    if (upi.isNotEmpty) 'UPI $upi',
  ];
  return parts.isEmpty ? 'No payout details' : parts.join(' · ');
}

String _copyText(Map<String, dynamic>? r) {
  final acct = (r?['bankAccountNumber'] as String?) ?? '';
  if (acct.isNotEmpty) return '${r?['accountHolderName'] ?? ''} $acct ${r?['ifscCode'] ?? ''}'.trim();
  return (r?['upiId'] as String?) ?? '';
}

class _RiderLine extends StatelessWidget {
  const _RiderLine(this.riderId, {this.showDestination = false});
  final String riderId;
  final bool showDestination;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _rider(riderId),
      builder: (context, snap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_riderName(snap.data, riderId), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (showDestination)
            Row(
              children: [
                Expanded(child: Text(_destination(snap.data), style: const TextStyle(fontSize: 12))),
                if (_copyText(snap.data).isNotEmpty)
                  IconButton(
                    tooltip: 'Copy payout details',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => Clipboard.setData(ClipboardData(text: _copyText(snap.data))),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Widget _message(String text) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));

// ── Statements ──

class _StatementsTab extends StatefulWidget {
  const _StatementsTab();
  @override
  State<_StatementsTab> createState() => _StatementsTabState();
}

class _StatementsTabState extends State<_StatementsTab> {
  String _status = 'pending';

  Future<void> _markPaid(String id, Map<String, dynamic> p) async {
    final ref = TextEditingController();
    final rider = await _rider((p['riderId'] ?? '').toString());
    var method = ((rider?['bankAccountNumber'] as String?) ?? '').isEmpty && ((rider?['upiId'] as String?) ?? '').isNotEmpty ? 'upi' : 'bank';
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Mark statement as paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AgFormat.rupees(_num(p['amount']))} to ${_riderName(rider, (p['riderId'] ?? '').toString())}'),
              const SizedBox(height: 4),
              Text(_destination(rider), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'bank', label: Text('Bank')), ButtonSegment(value: 'upi', label: Text('UPI'))],
                selected: {method},
                onSelectionChanged: (s) => setD(() => method = s.first),
              ),
              TextField(
                controller: ref,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'UTR / payment reference', helperText: 'Required — shown to the rider'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark paid')),
          ],
        ),
      ),
    );
    final reference = ref.text.trim();
    ref.dispose();
    if (confirmed != true || !mounted) return;
    final error = paymentReferenceError(reference);
    if (error != null) {
      SnackbarHelper.showError(context, error);
      return;
    }
    try {
      await _db.collection('rider_payouts').doc(id).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentReference': reference,
        'paidBy': FirebaseAuth.instance.currentUser?.uid,
        'payoutMethod': method, // rules accept bank | upi only
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) SnackbarHelper.showSuccess(context, 'Statement marked as paid');
    } catch (e) {
      debugPrint('Rider payout mark paid failed: $e');
      if (mounted) SnackbarHelper.showError(context, "Couldn't mark it paid. It may already be settled — refresh and try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('To pay')),
              ButtonSegment(value: 'on_hold', label: Text('On hold')),
              ButtonSegment(value: 'paid', label: Text('Paid')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Equality only (no composite index); newest first below.
            stream: _db.collection('rider_payouts').where('status', isEqualTo: _status).limit(300).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                debugPrint('Rider payouts load failed: ${snap.error}');
                return _message("Couldn't load statements. Check your connection and try again.");
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.toList()
                ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
                    .compareTo((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
              if (docs.isEmpty) {
                return _message(switch (_status) {
                  'pending' => 'Nothing to pay. Statements are made every Monday at 00:30.',
                  'on_hold' => 'No statements on hold.',
                  _ => 'No paid statements yet.',
                });
              }
              final total = docs.fold<double>(0, (a, d) => a + _num(d.data()['amount']));
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('${docs.length} statements · ${AgFormat.rupees(total)}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final d in docs) _tile(d.id, d.data()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(String id, Map<String, dynamic> p) {
    final riderId = (p['riderId'] ?? '').toString();
    final ref = (p['paymentReference'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RiderLine(riderId, showDestination: _status != 'paid')),
                Text(AgFormat.rupees(_num(p['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${p['weekKey'] ?? ''} · ${p['orderCount'] ?? 0} deliveries · earned ${AgFormat.rupees(_num(p['earned']))}'
                '${_num(p['netted']) > 0 ? ' · cash netted ${AgFormat.rupees(_num(p['netted']))}' : ''}',
                style: const TextStyle(fontSize: 12)),
            if (_status == 'on_hold')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(holdReasonLabel(p['holdReason'] as String?), style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
              ),
            if (_status == 'pending')
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => _markPaid(id, p), child: const Text('Mark paid')))
            else if (ref.isNotEmpty)
              Text('Ref $ref · ${p['payoutMethod'] ?? ''}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Cash with riders ──

class _CashTab extends StatelessWidget {
  const _CashTab();

  Future<void> _recordDeposit(BuildContext context, String riderId, double held) async {
    final amount = TextEditingController(text: held.toStringAsFixed(2));
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record cash deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Holding ${AgFormat.rupees(held)}'),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount received (₹)')),
            TextField(controller: ref, decoration: const InputDecoration(labelText: 'Receipt / reference')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
        ],
      ),
    );
    final value = double.tryParse(amount.text.trim());
    final reference = ref.text.trim();
    amount.dispose();
    ref.dispose();
    if (ok != true || !context.mounted) return;
    if (value == null || value <= 0) {
      SnackbarHelper.showError(context, 'Enter an amount greater than zero.');
      return;
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('recordRiderCashDeposit')
          .call<Map<String, dynamic>>({'riderId': riderId, 'amount': value, 'reference': reference});
      if (context.mounted) SnackbarHelper.showSuccess(context, 'Deposit recorded');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('recordRiderCashDeposit: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (context.mounted) SnackbarHelper.showError(context, riderMoneyRefusal(e.code, reason));
    } catch (e) {
      debugPrint('recordRiderCashDeposit: $e');
      if (context.mounted) SnackbarHelper.showError(context, riderMoneyRefusal('unknown', null));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('rider_accounts').where('cashHeld', isGreaterThan: 0).orderBy('cashHeld', descending: true).limit(300).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Rider cash load failed: ${snap.error}');
          return _message("Couldn't load cash. Check your connection and try again.");
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _message('No rider is holding COD cash.');
        final total = docs.fold<double>(0, (a, d) => a + _num(d.data()['cashHeld']));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${docs.length} riders holding ${AgFormat.rupees(total)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Cash is also taken off each rider\'s Monday statement automatically.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            for (final d in docs)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: _RiderLine(d.id),
                  subtitle: Text('Holding ${AgFormat.rupees(_num(d.data()['cashHeld']))}'),
                  trailing: OutlinedButton(
                    onPressed: () => _recordDeposit(context, d.id, _num(d.data()['cashHeld'])),
                    child: const Text('Record deposit'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Payout-detail changes ──

class _BankChangesTab extends StatelessWidget {
  const _BankChangesTab();

  Future<void> _review(BuildContext context, String requestId, bool approve) async {
    String? reason;
    if (!approve) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject change'),
          content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Reason (shown to the rider)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
          ],
        ),
      );
      reason = c.text.trim();
      c.dispose();
      if (ok != true) return;
    }
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('reviewRiderBankChange')
          .call<Map<String, dynamic>>({'requestId': requestId, 'approve': approve, if (reason != null) 'reason': reason});
      final released = (r.data['released'] as num?)?.toInt() ?? 0;
      if (context.mounted) {
        SnackbarHelper.showSuccess(context,
            '${approve ? 'Approved' : 'Rejected'}${released > 0 ? ' · $released held statement${released == 1 ? '' : 's'} released' : ''}');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('reviewRiderBankChange: ${e.code} ${e.details}');
      final why = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (context.mounted) SnackbarHelper.showError(context, riderMoneyRefusal(e.code, why));
    } catch (e) {
      debugPrint('reviewRiderBankChange: $e');
      if (context.mounted) SnackbarHelper.showError(context, riderMoneyRefusal('unknown', null));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('rider_bank_change_requests').where('status', isEqualTo: 'pending').limit(200).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Bank change requests load failed: ${snap.error}');
          return _message("Couldn't load requests. Check your connection and try again.");
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _message('No payout-detail changes waiting.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Check each change (e.g. the name matches the rider\'s KYC) before approving — '
                'approved details receive the rider\'s pay.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            for (final d in docs)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RiderLine((d.data()['riderId'] ?? '').toString(), showDestination: true),
                      const Divider(),
                      const Text('New details', style: TextStyle(fontWeight: FontWeight.w700)),
                      if (((d.data()['bankAccountNumber'] as String?) ?? '').isNotEmpty)
                        SelectableText('${d.data()['accountHolderName'] ?? ''}\n${d.data()['bankAccountNumber']} · ${d.data()['ifscCode'] ?? ''}'),
                      if (((d.data()['upiId'] as String?) ?? '').isNotEmpty) SelectableText('UPI ${d.data()['upiId']}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => _review(context, d.id, false), child: const Text('Reject')),
                          const SizedBox(width: 8),
                          FilledButton(onPressed: () => _review(context, d.id, true), child: const Text('Approve')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Pay rates ──

class _RatesTab extends StatefulWidget {
  const _RatesTab();
  @override
  State<_RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<_RatesTab> {
  final Map<String, TextEditingController> _c = {for (final f in riderPayFields) f.key: TextEditingController()};
  Map<String, Object?> _stored = const {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = (await _db.collection('settings').doc('rider_pay').get()).data() ?? {};
      _stored = d;
      for (final f in riderPayFields) {
        final v = effectiveRate(f.key, d[f.key]);
        _c[f.key]!.text = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
      }
    } catch (e) {
      debugPrint('Rider pay settings load failed: $e');
      if (mounted) SnackbarHelper.showError(context, "Couldn't load the current rates.");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final r = validateRates({for (final e in _c.entries) e.key: e.value.text});
    if (r.error != null) {
      SnackbarHelper.showError(context, r.error!);
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.collection('settings').doc('rider_pay').set({
        ...r.values!,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));
      _stored = r.values!;
      if (mounted) SnackbarHelper.showSuccess(context, 'Rates saved — new offers and deliveries use them');
    } catch (e) {
      debugPrint('Rider pay settings save failed: $e');
      if (mounted) SnackbarHelper.showError(context, "Couldn't save the rates. Try again.");
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Now: ${ratesSummary(_stored)}', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text('Pay per delivery = base + per km of the store → customer road distance + waiting beyond the free minutes. '
            'Changes apply to new offers and deliveries, not to pay already recorded.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        for (final f in riderPayFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _c[f.key],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${f.label} (${f.unit})',
                helperText: 'Between ${f.min.toStringAsFixed(0)} and ${f.max.toStringAsFixed(0)} · default ${f.defaultValue.toStringAsFixed(0)}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save rates'),
        ),
      ],
    );
  }
}
