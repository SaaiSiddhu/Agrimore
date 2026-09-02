import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Read-only wallet view for the current employee — mirrors
/// apps/admin/lib/screens/admin/wallet/wallet_tracking_screen.dart's simple
/// StreamBuilder style. Employees don't need marketplace's full top-up/spend
/// WalletProvider (not a shared-package export anyway), just this view.
///
/// Phase 16C, Workstream 4: converted to StatefulWidget solely to hold the
/// page size for the transaction list — see _WalletScreenState._pageSize.
/// No balance calculation changed, and this screen still writes nothing.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // Phase 16C, Workstream 4: this stream previously had NO limit — an
  // unbounded realtime listener on a ledger collection that only ever
  // grows is a real, avoidable cost (locked decision 6), not a
  // hypothetical one. Starts at a sensible page size and grows on request
  // via "Load more" rather than fetching the whole history up front.
  int _pageSize = 20;

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
      // Phase 16C, Workstream 4: bounded by _pageSize (see field comment).
      // orderBy + limit rather than the previous unbounded .where(...)
      // stream — sorting client-side after an unbounded fetch was the old
      // shape; sorting server-side lets the limit actually bound the read.
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
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

        // Already ordered by the query itself (createdAt desc) — no
        // client-side re-sort needed.
        final transactions = snap.data!.docs
            .map((doc) => WalletTransactionModel.fromFirestore(doc))
            .toList();

        if (transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No transactions yet')),
          );
        }

        final reachedPageLimit = transactions.length >= _pageSize;

        return Column(
          children: [
            ...transactions.map((txn) => _TransactionTile(txn: txn)),
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

/// Phase 16C, Workstream 4 — a transaction row that says what it actually
/// was, sourced from the document's own fields (source, metadata.orderMode,
/// metadata.rateSource) rather than leaving the associate to guess from a
/// bare amount. `description` (the server's own human sentence, e.g.
/// "Commission on B2C order ORD-1234") stays as the primary line; the
/// source label and mode/rate details are ADDITIVE structure below it, not
/// a replacement for it.
class _TransactionTile extends StatelessWidget {
  final WalletTransactionModel txn;

  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final metadata = txn.metadata;
    final rawMode = metadata?['orderMode'];
    final modeLabel = rawMode == 'B2B'
        ? 'B2B'
        : rawMode == 'B2C'
            ? 'Retail'
            : null;
    final rateSource = metadata?['rateSource'];
    final rateLabel = rateSource == 'employee_override'
        ? 'Your custom commission rate'
        : rateSource == 'configured_mode_rate'
            ? 'Standard commission rate'
            : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(txn.icon, color: txn.color),
              title: Text(
                txn.description,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(txn.formattedDate),
              trailing: Text(
                txn.formattedAmount,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: txn.type == TransactionType.credit
                      ? const Color(0xFF15803D)
                      : Colors.red,
                ),
              ),
            ),
            // Structured detail chips — what kind of transaction this was,
            // which order it references (the wallet_transaction's own
            // orderId field; not a second Firestore read — this screen
            // does not open the order document itself, since that would be
            // a per-row read this collection was never designed to pay
            // for), and, for commission rows, which rate applied.
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Chip(label: txn.sourceLabel),
                  if (modeLabel != null) _Chip(label: modeLabel),
                  if (txn.orderId != null && txn.orderId!.isNotEmpty)
                    _Chip(label: 'Order ref: ${txn.orderId}'),
                  if (rateLabel != null) _Chip(label: rateLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
      ),
    );
  }
}
