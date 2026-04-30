// lib/screens/shell/seller_shell.dart
// Bottom navigation shell for the seller app — 5 tabs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../home/dashboard_screen.dart';
import '../products/seller_products_screen.dart';
import '../orders/seller_orders_screen.dart';
import '../earnings/seller_earnings_screen.dart';
import '../profile/seller_profile_screen.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../providers/seller_order_provider.dart';

class SellerShell extends StatefulWidget {
  const SellerShell({super.key});

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SellerProductsScreen(),
    SellerOrdersScreen(),
    SellerEarningsScreen(),
    SellerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSellerData());
  }

  void _loadSellerData() {
    final auth = context.read<SellerAuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    context.read<SellerProductProvider>().loadSellerProducts(uid);
    context.read<SellerOrderProvider>().loadSellerOrders(uid);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF2D7D3C);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.inventory_2_rounded, 'Products'),
                _buildNavItemWithBadge(2, Icons.receipt_long_rounded, 'Orders'),
                _buildNavItem(3, Icons.account_balance_wallet_rounded, 'Earnings'),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final accentColor = const Color(0xFF2D7D3C);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? accentColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? accentColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(int index, IconData icon, String label) {
    return Consumer<SellerOrderProvider>(
      builder: (context, orderProvider, child) {
        final badgeCount = orderProvider.pendingOrders;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildNavItem(index, icon, label),
            if (badgeCount > 0)
              Positioned(
                top: 0,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount > 9 ? '9+' : badgeCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
