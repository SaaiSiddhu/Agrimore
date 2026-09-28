// ADMR-86 — the "exact financial record" step of the reconciliation
// investigation workflow (bounded scan -> confirmed finding -> exact
// financial record -> actor/order context -> recheck -> linked support
// case -> return to scan). Read-only, by design and by construction: this
// file contains no write to seller_withdrawals/seller_payouts/rider_payouts/
// employee_payouts anywhere. Paying/settling stays exclusively on
// seller_payouts_screen.dart and the rider/associate payout screens, which
// this screen only links out to — resolving an investigation never changes
// a balance, payout, refund or stock state.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../sellers/seller_wallet_admin.dart' show resolveSellerWithdrawalDestination, sellerPayoutDestinationText;
import '../support/support_case_constants.dart';

class FinancialRecordDetailScreen extends StatefulWidget {
  const FinancialRecordDetailScreen({
    super.key,
    required this.type,
    required this.recordId,
    this.findingKind,
    this.findingActorType,
    this.findingDetail,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore;

  /// One of kLinkRecordCollection's three financial keys:
  /// seller_withdrawal / rider_payout / employee_payout.
  final String type;
  final String recordId;

  /// Set only when this screen was opened from a specific reconciliation
  /// finding — enough to call financeReconciliationRecheckFinding for
  /// exactly that finding. Null when opened any other way (e.g. a linked-
  /// record chip on a support case): recheck is not offered then, since
  /// there is no specific finding to re-derive against.
  final String? findingKind;
  final String? findingActorType;
  final Map<String, dynamic>? findingDetail;

  /// Injectable for tests (mirrors SupportCaseDetailScreen's own
  /// convention) — defaults to the real instance in the running app.
  final FirebaseFirestore? _firestore;

  @override
  State<FinancialRecordDetailScreen> createState() => _FinancialRecordDetailScreenState();
}

class _FinancialRecordDetailScreenState extends State<FinancialRecordDetailScreen> {
  FirebaseFirestore get _db => widget._firestore ?? FirebaseFirestore.instance;

  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _data;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _children = const [];

  bool _rechecking = false;
  Map<String, dynamic>? _recheckResult;

  String get _collection => kLinkRecordCollection[widget.type] ?? '';

  String get _actorIdField => switch (widget.type) {
        'seller_withdrawal' => 'sellerId',
        'rider_payout' => 'riderId',
        'employee_payout' => 'employeeId',
        _ => '',
      };

  String get _actorLinkType => switch (widget.type) {
        'seller_withdrawal' => 'seller',
        'rider_payout' => 'rider',
        'employee_payout' => 'associate',
        _ => '',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snap = await _db.collection(_collection).doc(widget.recordId).get();
      if (!snap.exists) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _data = null;
        });
        return;
      }
      final data = snap.data()!;
      final children = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      if (widget.type == 'seller_withdrawal') {
        final ids = (data['payoutIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        // Firestore whereIn caps at 30 per query — sellerWallet.ts's own
        // MAX_PAYOUTS_PER_WITHDRAWAL is 400, so this pages through in
        // chunks rather than silently truncating a large withdrawal.
        for (var i = 0; i < ids.length; i += 30) {
          final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
          if (chunk.isEmpty) continue;
          final q = await _db.collection('seller_payouts').where(FieldPath.documentId, whereIn: chunk).get();
          children.addAll(q.docs);
        }
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _children = children;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Financial record load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load this record. Check your connection and try again.";
      });
    }
  }

  Future<void> _recheck() async {
    if (widget.findingKind == null || widget.findingActorType == null) return;
    setState(() => _rechecking = true);
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('financeReconciliationRecheckFinding')
          .call<Map<String, dynamic>>({
        'kind': widget.findingKind,
        'actorType': widget.findingActorType,
        'recordId': widget.recordId,
        'detail': widget.findingDetail ?? const {},
      });
      if (!mounted) return;
      setState(() {
        _recheckResult = Map<String, dynamic>.from(res.data);
        _rechecking = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _rechecking = false);
      SnackbarHelper.showError(context, e.message ?? "Couldn't recheck this finding.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _rechecking = false);
      SnackbarHelper.showError(context, "Couldn't recheck this finding.");
    }
  }

  void _openActor() {
    final actorId = (_data?[_actorIdField] ?? '').toString();
    if (actorId.isEmpty) return;
    context.push(linkRecordRoute(_actorLinkType, actorId));
  }

  Future<void> _raiseCase() async {
    final actorId = (_data?[_actorIdField] ?? '').toString();
    if (actorId.isEmpty) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _RaiseFinancialCaseDialog(
        actorType: _actorLinkType,
        actorId: actorId,
        linkType: widget.type,
        recordId: widget.recordId,
      ),
    );
    if (created == true && mounted) {
      SnackbarHelper.showSuccess(context, 'Case created and linked to this record');
      setState(() {}); // refresh the linked-cases section below
    }
  }

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(linkRecordTypeLabel(widget.type)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Reload')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _messageState(Icons.error_outline, Colors.red, _loadError!, onRetry: _load)
              : _data == null
                  ? _messageState(Icons.search_off, Colors.grey, 'This record no longer exists.')
                  : _content(context),
    );
  }

  Widget _messageState(IconData icon, Color color, String text, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ]),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final d = _data!;
    final status = (d['status'] ?? '').toString();
    final amount = widget.type == 'seller_withdrawal'
        ? _num(d['amountPaise']) / 100
        : widget.type == 'rider_payout'
            ? _num(d['amountPaise']) / 100
            : _num(d['amount']);
    final reference = (d['paymentReference'] ?? '').toString();
    final actorId = (d[_actorIdField] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(AgFormat.rupees(amount),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                Chip(label: Text(status.isEmpty ? 'unknown' : status), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 8),
              SelectableText('record id: ${widget.recordId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              SelectableText('actor id: $actorId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (reference.isNotEmpty) Text('Reference: $reference', style: const TextStyle(fontSize: 13)),
              if (widget.type == 'seller_withdrawal') ...[
                const SizedBox(height: 6),
                Text(sellerPayoutDestinationText(resolveSellerWithdrawalDestination(d)),
                    style: const TextStyle(fontSize: 13)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (actorId.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _openActor,
              icon: const Icon(Icons.person_outline),
              label: Text('Open ${linkRecordTypeLabel(_actorLinkType).toLowerCase()}'),
            ),
          if (actorId.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _raiseCase,
              icon: const Icon(Icons.support_agent),
              label: const Text('Raise a case about this'),
            ),
        ]),
        if (widget.findingKind != null) ...[
          const SizedBox(height: 16),
          _recheckCard(),
        ],
        if (widget.type == 'seller_withdrawal' && _children.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Constituent payout rows (${_children.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          for (final c in _children) _payoutRowTile(c),
        ],
        const SizedBox(height: 16),
        Text('Linked support cases', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        _linkedCases(),
      ],
    );
  }

  Widget _payoutRowTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final p = doc.data();
    final net = _num(p['netAmount'] ?? p['amount']);
    final status = (p['status'] ?? '').toString();
    final order = (p['orderNumber'] ?? p['orderId'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        dense: true,
        title: Text('${AgFormat.rupees(net)} · $status'),
        subtitle: Text('id ${doc.id}${order.isEmpty ? '' : ' · order $order'}', style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _recheckCard() {
    return Card(
      color: Colors.blue.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Recheck this finding',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade900)),
            ),
            FilledButton(
              onPressed: _rechecking ? null : _recheck,
              child: _rechecking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Recheck'),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Re-derives this exact finding fresh, live, right now — never changes any balance, payout, refund or stock state.',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
          ),
          if (_recheckResult != null) ...[
            const SizedBox(height: 8),
            _recheckOutcome(_recheckResult!),
          ],
        ]),
      ),
    );
  }

  Widget _recheckOutcome(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString();
    return switch (kind) {
      'confirmed' => Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          const Expanded(child: Text('Still confirmed — this finding reproduces right now.', style: TextStyle(fontSize: 12))),
        ]),
      'resolved' => Row(children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 6),
          const Expanded(child: Text('Resolved — this no longer reproduces.', style: TextStyle(fontSize: 12))),
        ]),
      'not_found' => Row(children: [
          Icon(Icons.help_outline, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          const Expanded(child: Text('The underlying record could not be found.', style: TextStyle(fontSize: 12))),
        ]),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _linkedCases() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _db
          .collection('support_cases')
          .where('linkedRecords', arrayContains: {'type': widget.type, 'id': widget.recordId})
          .get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
        }
        if (snap.hasError) {
          return const Text('Could not load linked cases.', style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Text('No support case is linked to this record yet.', style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        return Column(children: [
          for (final doc in docs)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                onTap: () => context.push('/support/${doc.id}'),
                title: Text((doc.data()['title'] ?? '(untitled)').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(supportCaseStatusLabel((doc.data()['status'] ?? 'open').toString())),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ]);
      },
    );
  }
}

class _RaiseFinancialCaseDialog extends StatefulWidget {
  const _RaiseFinancialCaseDialog({
    required this.actorType,
    required this.actorId,
    required this.linkType,
    required this.recordId,
  });

  final String actorType;
  final String actorId;
  final String linkType;
  final String recordId;

  @override
  State<_RaiseFinancialCaseDialog> createState() => _RaiseFinancialCaseDialogState();
}

class _RaiseFinancialCaseDialogState extends State<_RaiseFinancialCaseDialog> {
  final _titleController = TextEditingController();
  String _category = 'payment_issue';
  bool _busy = false;
  String? _error;
  final _requestIds = SupportRequestIdTracker();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final requestId = _requestIds.forPayload(
      (title, _category, widget.actorType, widget.actorId, widget.linkType, widget.recordId),
    );
    try {
      await FirebaseFunctions.instance.httpsCallable('createSupportCase').call<Map<String, dynamic>>({
        'title': title,
        'category': _category,
        'primaryActor': {'type': widget.actorType, 'id': widget.actorId},
        'initialLink': {'type': widget.linkType, 'id': widget.recordId},
        'requestId': requestId,
      });
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Could not create that case.');
    } catch (e) {
      setState(() => _error = 'Could not create that case.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Raise a case about this record'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'payment_issue', child: Text('Payment issue')),
                DropdownMenuItem(value: 'account_issue', child: Text('Account issue')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 4),
            Text(
              'This case will be created and linked to this exact ${linkRecordTypeLabel(widget.linkType).toLowerCase()} — nothing about the record itself changes.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
