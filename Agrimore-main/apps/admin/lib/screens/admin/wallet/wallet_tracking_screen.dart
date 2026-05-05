import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class WalletTrackingScreen extends StatelessWidget {
  const WalletTrackingScreen({Key? key}) : super(key: key);

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Wallet Top-Up Tracking'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('wallet_transactions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load wallet activity',
              subtitle: snapshot.error.toString(),
            );
          }

          final topups = (snapshot.data?.docs ?? [])
              .map((doc) => WalletTransactionModel.fromFirestore(doc))
              .where(
                (txn) =>
                    txn.type == TransactionType.credit &&
                    txn.amount > 0 &&
                    (txn.source == TransactionSource.topup ||
                        txn.metadata?['sourceKey'] == 'wallet_topup'),
              )
              .toList();

          if (topups.isEmpty) {
            return const _MessageState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No wallet top-ups yet',
              subtitle: 'Customer wallet credits will appear here instantly.',
            );
          }

          return FutureBuilder<_WalletTrackingData>(
            future: _buildTrackingData(topups),
            builder: (context, dataSnapshot) {
              if (!dataSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = dataSnapshot.data!;
              return RefreshIndicator(
                onRefresh: () async {},
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSummaryCards(data),
                    const SizedBox(height: 20),
                    _buildTransactionsTable(context, data),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<_WalletTrackingData> _buildTrackingData(
    List<WalletTransactionModel> transactions,
  ) async {
    final userIds = transactions.map((txn) => txn.userId).toSet();
    final users = <String, Map<String, dynamic>>{};
    final wallets = <String, WalletModel>{};

    await Future.wait(
      userIds.map((userId) async {
        final results = await Future.wait([
          _firestore.collection('users').doc(userId).get(),
          _firestore.collection('wallets').doc(userId).get(),
        ]);

        final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
        final walletDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;

        users[userId] = userDoc.data() ?? {};
        if (walletDoc.exists) {
          wallets[userId] = WalletModel.fromFirestore(walletDoc);
        }
      }),
    );

    return _WalletTrackingData(
      transactions: transactions,
      users: users,
      wallets: wallets,
    );
  }

  Widget _buildSummaryCards(_WalletTrackingData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        final cards = [
          _SummaryCard(
            icon: Icons.payments_rounded,
            label: 'Total Added',
            value: _formatMoney(data.totalAdded),
            color: const Color(0xFF16A34A),
          ),
          _SummaryCard(
            icon: Icons.receipt_long_rounded,
            label: 'Top-Up Count',
            value: data.transactions.length.toString(),
            color: const Color(0xFF2563EB),
          ),
          _SummaryCard(
            icon: Icons.group_rounded,
            label: 'Customers',
            value: data.users.length.toString(),
            color: const Color(0xFFF97316),
          ),
          _SummaryCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Current Balance',
            value: _formatMoney(data.totalCurrentBalance),
            color: const Color(0xFF7C3AED),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTransactionsTable(
    BuildContext context,
    _WalletTrackingData data,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Text(
              'Customer Wallet Top-Up History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStatePropertyAll(
                AppColors.primary.withOpacity(0.08),
              ),
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('User Name')),
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Date & Time')),
                DataColumn(label: Text('Total Balance')),
                DataColumn(label: Text('Total Added')),
                DataColumn(label: Text('Payment Ref')),
                DataColumn(label: Text('Status')),
              ],
              rows: data.transactions.map((txn) {
                final user = data.users[txn.userId] ?? {};
                final wallet = data.wallets[txn.userId];
                final userName = _userName(user, txn.userId);
                final userTotalAdded = data.totalAddedByUser[txn.userId] ?? 0;

                return DataRow(
                  cells: [
                    DataCell(Text(userName)),
                    DataCell(SelectableText(_shortId(txn.userId))),
                    DataCell(
                      Text(
                        _formatMoney(txn.amount),
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDateTime(txn.createdAt))),
                    DataCell(
                      Text(_formatMoney(wallet?.balance ?? txn.balanceAfter)),
                    ),
                    DataCell(Text(_formatMoney(userTotalAdded))),
                    DataCell(SelectableText(txn.referenceId ?? '-')),
                    const DataCell(_StatusPill(label: 'Success')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static String _userName(Map<String, dynamic> user, String userId) {
    final name = (user['name'] ?? user['displayName'] ?? user['fullName'])
        ?.toString()
        .trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return 'User ${_shortId(userId)}';
  }

  static String _shortId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 6)}...${id.substring(id.length - 4)}';
  }

  static String _formatMoney(double value) => 'Rs ${value.toStringAsFixed(0)}';

  static String _formatDateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}

class _WalletTrackingData {
  final List<WalletTransactionModel> transactions;
  final Map<String, Map<String, dynamic>> users;
  final Map<String, WalletModel> wallets;

  _WalletTrackingData({
    required this.transactions,
    required this.users,
    required this.wallets,
  });

  double get totalAdded => transactions.fold(0, (sum, txn) => sum + txn.amount);

  double get totalCurrentBalance =>
      wallets.values.fold(0, (sum, wallet) => sum + wallet.balance);

  Map<String, double> get totalAddedByUser {
    final totals = <String, double>{};
    for (final txn in transactions) {
      totals[txn.userId] = (totals[txn.userId] ?? 0) + txn.amount;
    }
    return totals;
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF166534),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
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
