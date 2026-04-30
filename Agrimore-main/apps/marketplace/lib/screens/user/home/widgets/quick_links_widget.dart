import 'package:flutter/material.dart';
import '../../../../../app/routes.dart';
import '../../../../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class QuickLinksWidget extends StatelessWidget {
  const QuickLinksWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickLink(
            context,
            icon: Icons.bolt,
            label: 'Flash Sale',
            route: AppRoutes.flashSale,
            color: Colors.amber,
            isDark: isDark,
          ),
          _buildQuickLink(
            context,
            icon: Icons.card_giftcard,
            label: 'Rewards',
            route: AppRoutes.rewards,
            color: Colors.purpleAccent,
            isDark: isDark,
          ),
          _buildQuickLink(
            context,
            icon: Icons.local_offer,
            label: 'Offers',
            route: AppRoutes.offers,
            color: Colors.redAccent,
            isDark: isDark,
          ),
          _buildQuickLink(
            context,
            icon: Icons.account_balance_wallet,
            label: 'Wallet',
            route: AppRoutes.wallet,
            color: Colors.blueAccent,
            isDark: isDark,
          ),
          _buildQuickLink(
            context,
            icon: Icons.groups_rounded,
            label: 'Group Order',
            route: AppRoutes.referral,
            color: Colors.deepOrange,
            isDark: isDark,
          ),
          _buildQuickLink(
            context,
            icon: Icons.auto_awesome,
            label: 'AI Chef',
            route: AppRoutes.aiChat,
            color: Colors.deepPurple,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLink(BuildContext context, {required IconData icon, required String label, required String route, required Color color, required bool isDark}) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
