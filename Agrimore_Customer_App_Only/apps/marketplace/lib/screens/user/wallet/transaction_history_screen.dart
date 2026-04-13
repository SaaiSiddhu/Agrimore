import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/wallet_provider.dart';
import '../../../providers/theme_provider.dart';
import 'widgets/transaction_tile.dart';

/// Transaction history screen with filtering
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _filter = 'all'; // all, credit, debit

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.loadTransactions(limit: 50);
  }

  List<WalletTransactionModel> _getFilteredTransactions(List<WalletTransactionModel> transactions) {
    if (_filter == 'all') return transactions;
    return transactions.where((t) {
      if (_filter == 'credit') return t.type == TransactionType.credit;
      if (_filter == 'debit') return t.type == TransactionType.debit;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transaction History',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all', isDark, accentColor),
                const SizedBox(width: 10),
                _buildFilterChip('Credits', 'credit', isDark, const Color(0xFF4CAF50)),
                const SizedBox(width: 10),
                _buildFilterChip('Debits', 'debit', isDark, const Color(0xFFE53935)),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: Consumer<WalletProvider>(
              builder: (context, walletProvider, _) {
                if (walletProvider.isLoadingTransactions) {
                  return Center(
                    child: CircularProgressIndicator(color: accentColor),
                  );
                }

                final filtered = _getFilteredTransactions(walletProvider.transactions);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = _groupByDate(filtered);

                return RefreshIndicator(
                  onRefresh: _loadTransactions,
                  color: accentColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final date = grouped.keys.elementAt(index);
                      final transactions = grouped[date]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              date,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: transactions.map((txn) {
                                return TransactionTile(transaction: txn, isDark: isDark);
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark, Color color) {
    final isSelected = _filter == value;
    
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Map<String, List<WalletTransactionModel>> _groupByDate(List<WalletTransactionModel> transactions) {
    final Map<String, List<WalletTransactionModel>> grouped = {};
    
    for (final txn in transactions) {
      final dateKey = txn.formattedDate;
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(txn);
    }
    
    return grouped;
  }
}
