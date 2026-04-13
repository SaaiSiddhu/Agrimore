import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/wallet_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../app/routes.dart';
import 'widgets/wallet_balance_card.dart';
import 'widgets/transaction_tile.dart';

/// Main wallet dashboard screen
class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.loadWallet();
    await walletProvider.loadTransactions(limit: 5);
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
          'Wallet',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          if (walletProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: accentColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  WalletBalanceCard(
                    balance: walletProvider.balance,
                    coins: walletProvider.coins,
                    isDark: isDark,
                    onAddMoney: () => _navigateTo(AppRoutes.addMoney),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(isDark, cardColor, accentColor),

                  const SizedBox(height: 28),

                  // Recent Transactions
                  _buildRecentTransactions(walletProvider, isDark, cardColor, accentColor),

                  const SizedBox(height: 28),

                  // Referral Card
                  if (walletProvider.isReferralEnabled)
                    _buildReferralCard(walletProvider, isDark, cardColor, accentColor),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, Color cardColor, Color accentColor) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.add_circle_outline,
            label: 'Add Money',
            color: accentColor,
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.addMoney),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'History',
            color: Colors.orange,
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.transactionHistory),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.card_giftcard,
            label: 'Refer',
            color: Colors.purple,
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.referral),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
    WalletProvider walletProvider,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => _navigateTo(AppRoutes.transactionHistory),
              child: Text(
                'View All',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (walletProvider.transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
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
              children: walletProvider.transactions.map((txn) {
                return TransactionTile(transaction: txn, isDark: isDark);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildReferralCard(
    WalletProvider walletProvider,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Refer & Earn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share your code and earn ${walletProvider.config.referrerBonus} coins for every friend who signs up!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _navigateTo(AppRoutes.referral);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Share Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route);
  }
}
