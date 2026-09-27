// lib/screens/admin/delivery/rider_cash_ledger_screen.dart
//
// ADMR-52 — rider_cash_ledger (functions/src/delivery/riderMoney.ts's own
// "every change to cashHeld") is a real, already-live, already
// admin-read-permitted (firestore.rules) collection with no admin screen
// reading it at all. rider_payouts_screen.dart already shows a rider's
// CURRENT cashHeld and already lets admin record a deposit against it, but
// has no way to show WHY that balance is what it is. Read-only visibility,
// newest first; nothing here changes what gets written or when.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class RiderCashLedgerScreen extends StatelessWidget {
  // ADMR-52: an injectable Firestore instance, same pattern ADMR-48/49/51
  // established -- defaults to the real FirebaseFirestore.instance,
  // overridable in tests so this screen is testWidgets-testable from day
  // one.
  RiderCashLedgerScreen({super.key, required this.riderId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String riderId;
  final FirebaseFirestore _firestore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Ledger'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('rider_cash_ledger')
            .where('riderId', isEqualTo: riderId)
            .orderBy('at', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Rider cash ledger: ${snap.error}');
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load the cash ledger. Check your connection and reopen this page.'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No cash ledger entries yet for this rider.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final entry = RiderCashLedgerEntry.fromMap(docs[i].data(), docs[i].id);
              return _LedgerCard(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.entry});
  final RiderCashLedgerEntry entry;

  IconData get _icon => switch (entry.type) {
        'cash_collected' => Icons.local_shipping_outlined,
        'deposit' => Icons.savings_outlined,
        'netted_against_payout' => Icons.receipt_long_outlined,
        _ => Icons.receipt_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.typeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                Text(
                  AgFormat.rupees(entry.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            if (entry.at != null) ...[
              const SizedBox(height: 4),
              Text(
                AgFormat.dateTime(entry.at!),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
            if (entry.orderId != null) ...[
              const SizedBox(height: 6),
              Text('Order: ${entry.orderId}'),
            ],
            if (entry.reference != null) ...[
              const SizedBox(height: 6),
              Text('Reference: ${entry.reference}'),
            ],
            if (entry.recordedBy != null)
              Text(
                'Recorded by: ${entry.recordedBy}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            if (entry.statementId != null) ...[
              const SizedBox(height: 6),
              Text('Statement: ${entry.statementId}'),
            ],
          ],
        ),
      ),
    );
  }
}
