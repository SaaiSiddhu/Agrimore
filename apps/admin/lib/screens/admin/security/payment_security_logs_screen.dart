// lib/screens/admin/security/payment_security_logs_screen.dart
//
// ADMR-49 — payment_security_logs (functions/src/customer/payment.ts's/
// wallet.ts's own signature-mismatch handling) is a real, already-live,
// already admin-read-permitted (firestore.rules) collection with no admin
// screen reading it at all. Read-only visibility, newest first; nothing
// here changes what gets written or when, or what happens on a mismatch.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class PaymentSecurityLogsScreen extends StatelessWidget {
  // ADMR-49: an injectable Firestore instance, same pattern ADMR-48 just
  // established for OrderProvider -- defaults to the real
  // FirebaseFirestore.instance in production (main.dart's own navigation
  // to this screen never passes one), overridable in tests with a seeded
  // FakeFirebaseFirestore so this brand-new screen is testWidgets-testable
  // from day one, not another screen sharing the documented constraint.
  PaymentSecurityLogsScreen({super.key, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Security Logs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('payment_security_logs')
            .orderBy('flaggedAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Payment security logs: ${snap.error}');
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load security logs. Check your connection and reopen this page.'),
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
                child: Text('No payment signature mismatches recorded.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final record = PaymentSecurityLogRecord.fromMap(docs[i].data(), docs[i].id);
              return _LogCard(record: record);
            },
          );
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.record});
  final PaymentSecurityLogRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.error, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.typeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ],
            ),
            if (record.flaggedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                AgFormat.dateTime(record.flaggedAt!),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Text('Payment ID: ${record.paymentId}'),
            Text('Order ID: ${record.orderId}'),
            if (record.uid != null && record.uid!.isNotEmpty) Text('User: ${record.uid}'),
            const SizedBox(height: 4),
            Text(
              'Received signature length: ${record.receivedSignatureLength}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
