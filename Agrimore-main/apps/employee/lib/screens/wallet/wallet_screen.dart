import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Read-only wallet view for the current employee — mirrors
/// apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart's simple
/// StreamBuilder style. Employees don't need marketplace's full top-up/spend
/// WalletProvider (not a shared-package export anyway), just this view.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static String _formatMoney(double value) => 'Rs ${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Wallet')),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalanceCard(uid),
                const SizedBox(height: 20),
                const Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _buildTransactionsList(uid),
              ],
            ),
    );
  }

  Widget _buildBalanceCard(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        final lifetimeEarnings =
            (data?['lifetimeEarnings'] as num?)?.toDouble() ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMoney(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lifetime commission: ${_formatMoney(lifetimeEarnings)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsList(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final transactions = snap.data!.docs
            .map((doc) => WalletTransactionModel.fromFirestore(doc))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No transactions yet')),
          );
        }

        return Column(
          children: transactions.map((txn) {
            final isCredit = txn.type == TransactionType.credit;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(txn.icon, color: txn.color),
                title: Text(txn.description),
                subtitle: Text(txn.formattedDate),
                trailing: Text(
                  txn.formattedAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isCredit ? const Color(0xFF15803D) : Colors.red,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
