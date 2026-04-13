import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/admin_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Provider.of<AdminProvider>(context, listen: false)
        .loadDashboardStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          final stats = adminProvider.dashboardStats;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(
                'Total Revenue',
                '₹${stats['revenue'].toStringAsFixed(2)}',
                Icons.attach_money,
                AppColors.success,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Orders',
                stats['orders'].toString(),
                Icons.shopping_cart,
                AppColors.info,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Products',
                stats['products'].toString(),
                Icons.inventory_2,
                AppColors.primary,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Users',
                stats['users'].toString(),
                Icons.people,
                AppColors.warning,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyMedium),
              Text(
                value,
                style: AppTextStyles.displaySmall.copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
