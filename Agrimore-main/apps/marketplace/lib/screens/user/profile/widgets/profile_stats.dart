import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/order_provider.dart';
import '../../../../providers/wishlist_provider.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderProvider, WishlistProvider>(
      builder: (context, orderProvider, wishlistProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.shopping_bag_outlined,
                value: orderProvider.orders.length.toString(),
                label: 'Orders',
                color: AppColors.primary,
              ),
              _buildDivider(),
              _buildStatItem(
                icon: Icons.favorite_outline,
                value: wishlistProvider.itemCount.toString(),
                label: 'Wishlist',
                color: AppColors.error,
              ),
              _buildDivider(),
              _buildStatItem(
                icon: Icons.star_outline,
                value: '0',
                label: 'Reviews',
                color: AppColors.warning,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 60,
      width: 1,
      color: AppColors.divider,
    );
  }
}
