import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Phase ADMR-80.
///
/// A READ-ONLY admin investigation surface over the seller/rider/employee
/// payout paths (functions/src/admin/financeReconciliation.ts), calling
/// `financeReconciliationScan` on demand. Deliberately has no "fix" action
/// of any kind — every finding here is something for a human to read and
/// decide about, following the record ids it names, never something this
/// screen resolves itself.
class FinanceReconciliationScreen extends StatefulWidget {
  const FinanceReconciliationScreen({super.key});

  @override
  State<FinanceReconciliationScreen> createState() => _FinanceReconciliationScreenState();
}

class _FinanceReconciliationScreenState extends State<FinanceReconciliationScreen> {
  Future<Map<String, dynamic>>? _scan;
  String? _actorFilter; // null = all

  static String _kindLabel(String kind) => switch (kind) {
        'withdrawal_payout_status_mismatch' => 'Withdrawal/payout status mismatch',
        'paid_missing_reference' => 'Paid with no reference on file',
        'withdrawal_amount_mismatch' => 'Withdrawal amount does not match its payouts',
        'missing_destination_snapshot' => 'No destination on file at all',
        'payout_status_drift' => 'A payout drifted status outside its withdrawal',
        _ => kind,
      };

  Future<Map<String, dynamic>> _runScan() async {
    final result = await FirebaseFunctions.instance.httpsCallable('financeReconciliationScan').call<Map<String, dynamic>>();
    return result.data;
  }

  void _scanNow() => setState(() => _scan = _runScan());

  @override
  void initState() {
    super.initState();
    _scanNow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Finance Reconciliation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(onPressed: _scanNow, icon: const Icon(Icons.refresh), tooltip: 'Re-scan')],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _scan,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Scan failed: ${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _scanNow, child: const Text('Try again')),
                ]),
              ),
            );
          }
          final data = snap.data!;
          final findings = (data['findings'] as List? ?? const []).cast<Map<String, dynamic>>();
          final scanned = (data['scanned'] as Map?)?.cast<String, dynamic>() ?? const {};
          final observedAt = data['observedAt'] is num ? DateTime.fromMillisecondsSinceEpoch((data['observedAt'] as num).toInt()) : null;
          final visible = _actorFilter == null ? findings : findings.where((f) => f['actorType'] == _actorFilter).toList();

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Read-only — no action here changes anything. Follow a finding\'s record id to investigate '
                  'or act elsewhere. A finding reflects what was true at the moment of this scan, not necessarily now.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (observedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Scanned ${observedAt.toLocal()} · seller withdrawals: ${scanned['sellerWithdrawals'] ?? 0} · '
                      'paid rider statements: ${scanned['riderPayouts'] ?? 0} · paid associate payouts: ${scanned['employeePayouts'] ?? 0}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('All'), selected: _actorFilter == null, onSelected: (_) => setState(() => _actorFilter = null)),
                  ChoiceChip(label: const Text('Seller'), selected: _actorFilter == 'seller', onSelected: (_) => setState(() => _actorFilter = 'seller')),
                  ChoiceChip(label: const Text('Rider'), selected: _actorFilter == 'rider', onSelected: (_) => setState(() => _actorFilter = 'rider')),
                  ChoiceChip(label: const Text('Associate'), selected: _actorFilter == 'employee', onSelected: (_) => setState(() => _actorFilter = 'employee')),
                ]),
              ]),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                          const SizedBox(height: 12),
                          Text(findings.isEmpty ? 'No findings' : 'No findings for this filter',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final f = visible[index];
                        final actorType = (f['actorType'] ?? '').toString();
                        final amount = (f['amountRupees'] as num?)?.toDouble() ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text(actorType.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade800)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_kindLabel((f['kind'] ?? '').toString()),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                                Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 6),
                              Text((f['summary'] ?? '').toString(), style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              SelectableText('record: ${f['recordId']} · actor: ${f['actorId']}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
