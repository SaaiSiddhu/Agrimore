import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../support/support_case_constants.dart';
import 'finance_reconciliation_models.dart';

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

/// The exact financial record a finding is about, and the link type it
/// must be navigated/linked as (one of kLinkRecordCollection's financial
/// keys). Null when there is nowhere sound to navigate. Pure and
/// top-level for the same reason as financeFindingKindLabel above — this
/// mapping is the single most consequential piece of new logic ADMR-86
/// added (a wrong answer silently sends an admin to the WRONG record), so
/// it is unit-tested directly, exhaustively, for every real finding kind.
///
/// malformed_amount and payout_ownership_mismatch have their OWN recordId
/// pointing at a CHILD seller_payouts row, not the withdrawal — navigation
/// goes to the PARENT withdrawal instead (via the finding's own
/// detail.withdrawalId/expectedWithdrawalId), which shows that same child
/// row in context among its siblings, rather than inventing a fourth,
/// isolated single-row link type.
({String type, String id})? financeFindingNavigationTarget(FinanceFinding f) {
  if (f.recordId.isEmpty) return null;
  if (f.actorType == 'seller') {
    if (f.kind == 'malformed_amount' || f.kind == 'payout_ownership_mismatch') {
      final wId = (f.detail['withdrawalId'] ?? f.detail['expectedWithdrawalId'] ?? '').toString();
      return wId.isEmpty ? null : (type: 'seller_withdrawal', id: wId);
    }
    return (type: 'seller_withdrawal', id: f.recordId);
  }
  if (f.actorType == 'rider') return (type: 'rider_payout', id: f.recordId);
  if (f.actorType == 'employee') return (type: 'employee_payout', id: f.recordId);
  return null;
}

/// Phase ADMR-80, cursor continuation + investigation navigation ADMR-86,
/// typed contract + request robustness ADMR-89.
///
/// A READ-ONLY admin investigation surface over the seller/rider/employee
/// payout paths (functions/src/admin/financeReconciliation.ts), calling
/// `financeReconciliationScan` on demand. Deliberately has no "fix" action
/// of any kind — every finding here is something for a human to read and
/// decide about. Tapping a finding now navigates to the exact underlying
/// record (FinancialRecordDetailScreen) instead of showing only a
/// plain-text record/actor id.
class FinanceReconciliationScreen extends StatefulWidget {
  const FinanceReconciliationScreen({super.key, FinanceReconciliationRepository? repository})
      : _repository = repository ?? const CallableFinanceReconciliationRepository();

  /// Injectable for tests — mirrors FinancialRecordDetailScreen's own
  /// already-established injection convention.
  final FinanceReconciliationRepository _repository;

  @override
  State<FinanceReconciliationScreen> createState() => _FinanceReconciliationScreenState();
}

class _FinanceReconciliationScreenState extends State<FinanceReconciliationScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  /// Keyed by each finding's own stable `id` and insertion-ordered (Dart's
  /// default Map preserves insertion order) — a page whose findings happen
  /// to repeat an id already held (should not happen after ADMR-88's own
  /// fix, but this is a cheap, correct defensive measure, not a load-bearing
  /// one) overwrites that entry IN PLACE rather than appending a visible
  /// duplicate.
  Map<String, FinanceFinding> _findingsById = {};
  ScanCoverage _coverage = ScanCoverage.empty;
  bool _incomplete = false;
  List<String> _incompleteReasons = const [];
  DateTime? _observedAt;
  Map<String, dynamic>? _nextCursor;
  bool _hasMore = false;
  String? _actorFilter; // null = all

  /// Incremented on every new request (a fresh scan OR a load-more). Each
  /// in-flight request captures its own value at the moment it starts; if
  /// the counter has moved on by the time it resolves, ITS result is stale
  /// and is discarded rather than applied — this is what stops a slow
  /// "load more" response from landing after a "re-scan" already reset the
  /// list, and what makes a double-tap harmless instead of corrupting.
  int _requestGeneration = 0;

  void _openFinding(FinanceFinding f) {
    final target = financeFindingNavigationTarget(f);
    if (target == null) return;
    context.push(
      linkRecordRoute(target.type, target.id),
      extra: {'kind': f.kind, 'actorType': f.actorType, 'detail': f.detail},
    );
  }

  void _applyPage(ScanPage page, {required bool reset}) {
    setState(() {
      if (reset) _findingsById = {};
      for (final f in page.findings) {
        _findingsById[f.id] = f;
      }
      _coverage = page.coverage;
      _incomplete = reset ? page.incomplete : (_incomplete || page.incomplete);
      _incompleteReasons = reset ? page.incompleteReasons : [..._incompleteReasons, ...page.incompleteReasons];
      _observedAt = page.observedAt ?? _observedAt;
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  String _operatorMessage(Object e) {
    if (e is MalformedScanResponseException) return e.message;
    return "Couldn't reach the server — check your connection and try again.";
  }

  Future<void> _scanFresh() async {
    final myGeneration = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget._repository.scan();
      if (myGeneration != _requestGeneration || !mounted) return; // superseded by a newer request
      _applyPage(page, reset: true);
    } catch (e) {
      if (myGeneration != _requestGeneration || !mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _loadingMore) return;
    final myGeneration = ++_requestGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await widget._repository.scan(cursor: _nextCursor);
      if (myGeneration != _requestGeneration || !mounted) return; // superseded by a newer request
      _applyPage(page, reset: false);
    } catch (e) {
      if (myGeneration != _requestGeneration || !mounted) return;
      setState(() => _loadingMore = false);
      SnackbarHelper.showError(context, _operatorMessage(e));
    }
  }

  @override
  void initState() {
    super.initState();
    _scanFresh();
  }

  @override
  Widget build(BuildContext context) {
    final findings = _findingsById.values.toList();
    final visible = _actorFilter == null ? findings : findings.where((f) => f.actorType == _actorFilter).toList();

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
                      Text('Scan failed: ${_operatorMessage(_error!)}', textAlign: TextAlign.center),
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
                            'Last checked ${_observedAt!.toLocal()} · ${findings.length} finding(s) loaded\n'
                            '${_coverage.sellerWithdrawals.line('Seller withdrawals')}\n'
                            '${_coverage.riderPayouts.line('Paid rider statements')}\n'
                            '${_coverage.employeePayouts.line('Paid associate payouts')}',
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
                                  findings.isEmpty
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
                                          child: Text(f.actorType.toUpperCase(),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade800)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(financeFindingKindLabel(f.kind),
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        ),
                                        Text('₹${f.amountRupees.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(f.summary, style: const TextStyle(fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Expanded(
                                          child: SelectableText('record: ${f.recordId} · actor: ${f.actorId}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                        ),
                                        if (f.confirmation == 'unconfirmed')
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
