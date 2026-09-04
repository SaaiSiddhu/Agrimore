import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Lists `employee_payouts` documents (mirrors `seller_payouts`' shape per
/// Phase 1). Nothing writes to this collection yet — commission is currently
/// paid directly into `wallets`/`wallet_transactions` by
/// `payEmployeeCommissionOnDelivery`. This screen is deploy-ready ahead of
/// Phase 4 (the employee app), which is expected to introduce a payout-
/// request flow that populates it.
class EmployeePayoutsScreen extends StatelessWidget {
  const EmployeePayoutsScreen({Key? key}) : super(key: key);

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _markPaid(BuildContext context, String payoutId) async {
    try {
      await _firestore.collection('employee_payouts').doc(payoutId).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Payout marked as paid');
      }
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  static double _amountOf(Map<String, dynamic> d) {
    final raw = d['amount'] ?? d['netAmount'] ?? d['commissionAmount'] ?? d['grossAmount'];
    return (raw as num?)?.toDouble() ?? 0.0;
  }

  static String _formatMoney(double value) => 'Rs ${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Employee Payouts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('employee_payouts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load employee payouts',
              subtitle: snapshot.error.toString(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const _MessageState(
              icon: Icons.payments_outlined,
              title: 'No employee payouts yet',
              subtitle:
                  'Payout requests will appear here once the employee app is live.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final status = (d['status'] ?? 'pending').toString();
              final amount = _amountOf(d);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatMoney(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Employee: ${d['employeeId'] ?? '-'}',
                              style: TextStyle(
                                  color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'paid'
                              ? Colors.green.shade50
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: status == 'paid'
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      if (status != 'paid') ...[
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => _markPaid(context, doc.id),
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700),
                          child: const Text('Mark Paid'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
