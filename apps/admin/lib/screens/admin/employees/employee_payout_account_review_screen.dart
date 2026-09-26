// lib/screens/admin/employees/employee_payout_account_review_screen.dart
//
// Phase ADMR-5 — admin review of associate bank/UPI change requests
// (functions/src/employee/employeePayoutAccount.ts).
//
// Mirrors seller_wallet_admin.dart's SellerPayoutChangesTab almost exactly —
// the closest existing pattern for "review a pending payout-destination
// change" — and reuses that file's own sellerDestinationFull() to render the
// new details, since employee_payout_change_requests documents are written
// in the same field-naming shape (accountHolder/ifsc/upiId) that function
// already expects. Deliberately minimal: a list, masked details, two
// buttons — functional, not a new design exploration (uiux.md rule 1).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../sellers/seller_wallet_admin.dart' show sellerDestinationFull;

final FirebaseFirestore _db = FirebaseFirestore.instance;

/// Refusals from reviewEmployeePayoutChange, in admin words.
String _employeePayoutChangeRefusal(String code, String? reason) => switch (reason) {
      'not_pending' => 'This request has already been reviewed.',
      'not_found' => 'Not found — it may have been removed.',
      'reason_required' => 'Give a reason (3–200 characters) — the associate sees it.',
      _ => code == 'permission-denied'
          ? 'Only admins can do this.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not complete that. Please try again.',
    };

Future<void> _call(BuildContext context, String name, Map<String, dynamic> data, String done) async {
  try {
    await FirebaseFunctions.instance.httpsCallable(name).call<Map<String, dynamic>>(data);
    if (context.mounted) SnackbarHelper.showSuccess(context, done);
  } on FirebaseFunctionsException catch (e) {
    debugPrint('$name: ${e.code} ${e.details}');
    final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
    if (context.mounted) SnackbarHelper.showError(context, _employeePayoutChangeRefusal(e.code, reason));
  } catch (e) {
    debugPrint('$name: $e');
    if (context.mounted) SnackbarHelper.showError(context, _employeePayoutChangeRefusal('unknown', null));
  }
}

/// Renders the `previous` snapshot stored on a request — the OUTPUT shape of
/// functions/src/seller/sellerWallet.ts's payoutDestination() (`method` +
/// `accountLast4` for bank, or `method` + `upiId`), which is NOT the same
/// shape sellerDestinationFull() expects (`payoutMethod` + `accountNumber`,
/// the shape a payout_details/request document itself has). Reusing that
/// function for this field would silently render the bank template for
/// every previous destination, UPI included, since the key names don't match.
String _previousDestinationSummary(Map<String, dynamic>? d) {
  if (d == null) return 'No previous destination on file';
  if (d['method'] == 'upi') return 'UPI ${d['upiId'] ?? '—'}';
  final holder = (d['accountHolder'] ?? '').toString();
  return '${holder.isEmpty ? '' : '$holder\n'}${d['bankName'] ?? 'Bank'} · A/c ending ${d['accountLast4'] ?? '—'} · IFSC ${d['ifsc'] ?? '—'}';
}

Future<String?> _askReason(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reject change'),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Reason (shown to the associate)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
      ],
    ),
  );
  final reason = c.text.trim();
  c.dispose();
  return ok == true ? reason : null;
}

class EmployeePayoutAccountReviewScreen extends StatelessWidget {
  const EmployeePayoutAccountReviewScreen({super.key});

  Future<void> _review(BuildContext context, String requestId, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason(context);
      if (reason == null) return;
    }
    if (!context.mounted) return;
    await _call(
      context,
      'reviewEmployeePayoutChange',
      {'requestId': requestId, 'approve': approve, if (reason != null) 'reason': reason},
      approve ? 'Approved — payouts now go to the new details' : 'Rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Associate Bank/UPI Changes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('employee_payout_change_requests')
            .where('status', isEqualTo: 'pending')
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Employee payout changes load failed: ${snap.error}');
            return const Center(child: Text("Couldn't load requests. Check your connection and try again."));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No bank/UPI changes waiting.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Check each change (e.g. the account holder matches the associate's KYC) before approving — "
                'approved details receive the associate\'s payouts.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final d in docs) _RequestCard(doc: d, onReview: (approve) => _review(context, d.id, approve)),
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final ValueChanged<bool> onReview;

  const _RequestCard({required this.doc, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final employeeId = (data['employeeId'] ?? '').toString();
    final previous = data['previous'] as Map<String, dynamic>?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _db.collection('employees').doc(employeeId).get(),
              builder: (context, empSnap) {
                final name = empSnap.data?.data()?['name']?.toString() ?? employeeId;
                return Text(name, style: const TextStyle(fontWeight: FontWeight.w800));
              },
            ),
            const SizedBox(height: 4),
            const Divider(),
            if (previous != null) ...[
              const Text('Current details', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
              SelectableText(_previousDestinationSummary(previous), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
            ],
            const Text('New details', style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(sellerDestinationFull(data)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => onReview(false), child: const Text('Reject')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => onReview(true), child: const Text('Approve')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
