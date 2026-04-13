import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class OrderStatsWidget extends StatelessWidget {
  final List<dynamic> orders;

  const OrderStatsWidget({Key? key, required this.orders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((o) => o.orderStatus.toLowerCase() == 'pending').length;
    final processing = orders.where((o) => o.orderStatus.toLowerCase() == 'processing').length;
    final shipped = orders.where((o) => o.orderStatus.toLowerCase() == 'shipped').length;
    final total = orders.fold<double>(0, (sum, order) => sum + order.total);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            label: 'Total Orders',
            value: orders.length.toString(),
            icon: Icons.shopping_cart_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: 'Pending',
            value: pending.toString(),
            icon: Icons.schedule_rounded,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            label: 'Revenue',
            value: '₹${(total / 1000).toStringAsFixed(1)}k',
            icon: Icons.trending_up_rounded,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
