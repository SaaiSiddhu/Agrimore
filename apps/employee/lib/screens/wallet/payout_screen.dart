import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  // Phase 20: this stream previously had NO limit — an unbounded realtime
  // listener on a collection that only grows with an associate's payout
  // history is a real, avoidable cost (locked decision 6), the same defect
  // shape 16C-W4 fixed for wallet_transactions and Phase 19 fixed for
  // orders. Mirrors both of their _pageSize fields exactly.
  int _pageSize = 20;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static String _formatMoney(double value) => 'Rs ${value.toStringAsFixed(0)}';

  Future<void> _submitRequest() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('requestEmployeePayout');
      await callable.call({'amount': amount});

      if (mounted) {
        _amountController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout requested successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to request payout'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request payout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(title: const Text('Request Payout')),
      body: uid == null
          ? Center(
              child: Text(
                'Associate session unavailable',
                style: TextStyle(color: tokens.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request a Payout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The requested amount is deducted from your wallet immediately.',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Submit Request'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Payout History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHistory(uid, tokens),
              ],
            ),
    );
  }

  Widget _buildHistory(String uid, SalesAssociateTokens tokens) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employee_payouts')
          .where('employeeId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: ${snap.error}',
              style: TextStyle(color: tokens.textSecondary),
            ),
          );
        }
        if (!snap.hasData) {
          return Column(
            children: List.generate(
              3,
              (index) => Container(
                height: 64,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.divider),
                ),
              ),
            ),
          );
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No payout requests yet',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          );
        }

        final reachedPageLimit = docs.length >= _pageSize;

        return Column(
          children: [
            ...docs.map((doc) {
              final d = doc.data();
              final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final status = (d['status'] ?? 'requested').toString().toLowerCase();
              final isPaid = status == 'paid';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: tokens.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: tokens.divider),
                ),
                child: ListTile(
                  title: Text(
                    _formatMoney(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? tokens.successBg : tokens.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isPaid ? tokens.successFg : tokens.warningFg,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (reachedPageLimit) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _pageSize += 20),
                  child: const Text('Load more'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
