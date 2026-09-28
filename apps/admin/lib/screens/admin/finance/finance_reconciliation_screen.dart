import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../support/support_case_constants.dart';

/// Every kind financeReconciliation.ts's own ReconciliationFindingKind
/// union can produce, in plain language. Pure and top-level (not a State
/// method) so it is directly unit-testable without pumping a widget.
String financeFindingKindLabel(String kind) => switch (kind) {
      'withdrawal_payout_status_mismatch' => 'Withdrawal/payout status mismatch',
      'paid_missing_reference' => 'Paid with no reference on file',
      'withdrawal_amount_mismatch' => 'Withdrawal amount does not match its payouts',
      'missing_destination_snapshot' => 'No destination on file at all',
      'payout_status_drift' => 'A payout drifted status outside its withdrawal',
      'malformed_amount' => 'A payout row has no valid amount',
      'payout_ownership_mismatch' => 'A payout row no longer points back at its withdrawal',
      _ => kind,
    };

String financeCoverageLine(String label, Map<String, dynamic>? c) {
  if (c == null) return '$label: not scanned';
  final inspected = c['inspected'] ?? 0;
  final statuses = ((c['statusesCovered'] as List?) ?? const []).join('/');
  final total = c['totalInStatuses'];
  final truncated = c['truncated'] == true;
  final totalText = total == null ? '' : (truncated ? ' of $total — more exist, not all inspected' : ' of $total');
  return '$label: $inspected$totalText ($statuses)';
}

/// The exact financial record a finding is about, and the link type it
/// must be navigated/linked as (one of kLinkRecordCollection's financial
/// keys). Null when there is nowhere sound to navigate. Pure and
/// top-level for the same reason as financeFindingKindLabel above — this
/// mapping is the single most consequential piece of new logic in this
/// phase (a wrong answer silently sends an admin to the WRONG record), so
/// it is unit-tested directly, exhaustively, for every real finding kind.
///
/// malformed_amount and payout_ownership_mismatch have their OWN recordId
/// pointing at a CHILD seller_payouts row, not the withdrawal — navigation
/// goes to the PARENT withdrawal instead (via the finding's own
/// detail.withdrawalId/expectedWithdrawalId), which shows that same child
/// row in context among its siblings, rather than inventing a fourth,
/// isolated single-row link type.
({String type, String id})? financeFindingNavigationTarget(Map<String, dynamic> f) {
  final actorType = (f['actorType'] ?? '').toString();
  final kind = (f['kind'] ?? '').toString();
  final recordId = (f['recordId'] ?? '').toString();
  if (recordId.isEmpty) return null;
  if (actorType == 'seller') {
    if (kind == 'malformed_amount' || kind == 'payout_ownership_mismatch') {
      final detail = (f['detail'] as Map?)?.cast<String, dynamic>() ?? const {};
      final wId = (detail['withdrawalId'] ?? detail['expectedWithdrawalId'] ?? '').toString();
      return wId.isEmpty ? null : (type: 'seller_withdrawal', id: wId);
    }
    return (type: 'seller_withdrawal', id: recordId);
  }
  if (actorType == 'rider') return (type: 'rider_payout', id: recordId);
  if (actorType == 'employee') return (type: 'employee_payout', id: recordId);
  return null;
}

/// Phase ADMR-80, cursor continuation + investigation navigation ADMR-86.
///
/// A READ-ONLY admin investigation surface over the seller/rider/employee
/// payout paths (functions/src/admin/financeReconciliation.ts), calling
/// `financeReconciliationScan` on demand. Deliberately has no "fix" action
/// of any kind — every finding here is something for a human to read and
/// decide about. Tapping a finding now navigates to the exact underlying
/// record (FinancialRecordDetailScreen) instead of showing only a
/// plain-text record/actor id.
class FinanceReconciliationScreen extends StatefulWidget {
  const FinanceReconciliationScreen({super.key});

  @override
  State<FinanceReconciliationScreen> createState() => _FinanceReconciliationScreenState();
}

class _FinanceReconciliationScreenState extends State<FinanceReconciliationScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  List<Map<String, dynamic>> _findings = [];
  Map<String, dynamic> _coverage = const {};
  bool _incomplete = false;
  List<String> _incompleteReasons = const [];
  DateTime? _observedAt;
  Map<String, dynamic>? _nextCursor;
  bool _hasMore = false;
  String? _actorFilter; // null = all

  void _openFinding(Map<String, dynamic> f) {
    final target = financeFindingNavigationTarget(f);
    if (target == null) return;
    context.push(
      linkRecordRoute(target.type, target.id),
      extra: {'kind': f['kind'], 'actorType': f['actorType'], 'detail': f['detail']},
    );
  }

  void _applyResult(Map<String, dynamic> data, {required bool reset}) {
    final newFindings = (data['findings'] as List? ?? const []).cast<Map<String, dynamic>>();
    final newReasons = (data['incompleteReasons'] as List? ?? const []).cast<String>();
    setState(() {
      _findings = reset ? newFindings : [..._findings, ...newFindings];
      _coverage = (data['coverage'] as Map?)?.cast<String, dynamic>() ?? _coverage;
      _incomplete = reset ? data['incomplete'] == true : (_incomplete || data['incomplete'] == true);
      _incompleteReasons = reset ? newReasons : [..._incompleteReasons, ...newReasons];
      _observedAt = data['observedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch((data['observedAt'] as num).toInt())
          : _observedAt;
      _nextCursor = (data['nextCursor'] as Map?)?.cast<String, dynamic>();
      _hasMore = data['hasMore'] == true;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  Future<void> _scanFresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await FirebaseFunctions.instance.httpsCallable('financeReconciliationScan').call<Map<String, dynamic>>();
      _applyResult(Map<String, dynamic>.from(result.data as Map), reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('financeReconciliationScan')
          .call<Map<String, dynamic>>({'cursor': _nextCursor});
      _applyResult(Map<String, dynamic>.from(result.data as Map), reset: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      SnackbarHelper.showError(context, "Couldn't load more — check your connection and try again.");
    }
  }

  @override
  void initState() {
    super.initState();
    _scanFresh();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _actorFilter == null ? _findings : _findings.where((f) => f['actorType'] == _actorFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Finance Reconciliation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(onPressed: _scanFresh, icon: const Icon(Icons.refresh), tooltip: 'Re-scan')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 40, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Scan failed: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _scanFresh, child: const Text('Try again')),
                    ]),
                  ),
                )
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Read-only — no action here changes anything. Open a finding to investigate the exact '
                        'record, its actor and, where relevant, a support case. A finding reflects what was true '
                        'at the moment it was scanned or last rechecked, not necessarily now.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (_observedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Last checked ${_observedAt!.toLocal()} · ${_findings.length} finding(s) loaded\n'
                            '${financeCoverageLine('Seller withdrawals', _coverage['sellerWithdrawals'] as Map<String, dynamic>?)}\n'
                            '${financeCoverageLine('Paid rider statements', _coverage['riderPayouts'] as Map<String, dynamic>?)}\n'
                            '${financeCoverageLine('Paid associate payouts', _coverage['employeePayouts'] as Map<String, dynamic>?)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      if (_incomplete)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                              const SizedBox(width: 6),
                              Text('This scan did not finish', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.orange.shade900)),
                            ]),
                            for (final r in _incompleteReasons)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(r, style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
                              ),
                          ]),
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
                                Icon(_incomplete ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    size: 48, color: _incomplete ? Colors.orange : Colors.green),
                                const SizedBox(height: 12),
                                Text(
                                  _findings.isEmpty
                                      ? (_incomplete ? 'No findings in the scope this scan actually covered' : 'No findings')
                                      : 'No findings for this filter',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == visible.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                                  child: Center(
                                    child: _loadingMore
                                        ? const CircularProgressIndicator()
                                        : OutlinedButton(
                                            onPressed: _loadMore,
                                            child: const Text('Load older records'),
                                          ),
                                  ),
                                );
                              }
                              final f = visible[index];
                              final actorType = (f['actorType'] ?? '').toString();
                              final amount = (f['amountRupees'] as num?)?.toDouble() ?? 0;
                              final confirmation = (f['confirmation'] ?? '').toString();
                              final navigable = financeFindingNavigationTarget(f) != null;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: navigable ? () => _openFinding(f) : null,
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
                                          child: Text(financeFindingKindLabel((f['kind'] ?? '').toString()),
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        ),
                                        Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text((f['summary'] ?? '').toString(), style: const TextStyle(fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Expanded(
                                          child: SelectableText('record: ${f['recordId']} · actor: ${f['actorId']}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                        ),
                                        if (confirmation == 'unconfirmed')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                            child: const Text('not re-verified', style: TextStyle(fontSize: 10)),
                                          ),
                                        if (navigable) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
                                        ],
                                      ]),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ]),
    );
  }
}
