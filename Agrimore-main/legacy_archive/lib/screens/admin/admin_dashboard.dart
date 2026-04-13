// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../app/routes.dart';
import 'products/product_management_screen.dart';
import 'orders/order_management_screen.dart';
import 'users/user_management_screen.dart';
import 'analytics/analytics_screen.dart';
import 'coupon/coupon_management_screen.dart';
import 'products/add_product_screen.dart';
import 'banners/banner_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isRefreshing = true);
    await Provider.of<AdminProvider>(context, listen: false).loadDashboardStats();
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isRefreshing = false);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(authProvider),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: Consumer<AdminProvider>(
          builder: (context, adminProvider, _) {
            final stats = adminProvider.dashboardStats;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeBanner(authProvider),
                  const SizedBox(height: 28),
                  _buildAnimatedStats(stats, isMobile),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Quick Actions', Icons.flash_on_rounded),
                  const SizedBox(height: 16),
                  _buildQuickActions(isMobile),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Management Tools', Icons.dashboard_customize_rounded),
                  const SizedBox(height: 16),
                  _buildManagementGrid(isMobile),
                ],
              ).animate().fadeIn(duration: 400.ms),
            );
          },
        ),
      ),
    );
  }

  // 🌈 APP BAR
  AppBar _buildAppBar(AuthProvider authProvider) {
    return AppBar(
      elevation: 4,
      backgroundColor: AppColors.primary,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Text(
            DateFormat('EEEE, MMM d').format(DateTime.now()),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Text(
              authProvider.currentUser?.name.substring(0, 1).toUpperCase() ?? 'A',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 💫 WELCOME BANNER
  Widget _buildWelcomeBanner(AuthProvider authProvider) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E8AF6), Color(0xFF5DA7F2), Color(0xFF8AB4F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 42),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${authProvider.currentUser?.name.split(' ')[0] ?? 'Admin'} 👋',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Welcome back to Agrimore Control Center',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text('System Status: Stable',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).moveY(begin: 12, end: 0);
  }

  // 📊 ADVANCED STATS
  Widget _buildAnimatedStats(Map<String, dynamic> stats, bool isMobile) {
    final List<Map<String, dynamic>> statItems = [
      {'icon': Icons.inventory_2_rounded, 'title': 'Products', 'value': stats['products'], 'color': const Color(0xFF6366F1)},
      {'icon': Icons.shopping_cart_rounded, 'title': 'Orders', 'value': stats['orders'], 'color': const Color(0xFF10B981)},
      {'icon': Icons.people_rounded, 'title': 'Users', 'value': stats['users'], 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.currency_rupee_rounded, 'title': 'Revenue', 'value': '₹${NumberFormat('#,##,###').format(stats['revenue'])}', 'color': const Color(0xFFEC4899)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.25,
      ),
      itemCount: statItems.length,
      itemBuilder: (context, i) {
        final item = statItems[i];
        return _statCard(
          item['icon'] as IconData,
          item['title'] as String,
          item['value'].toString(),
          item['color'] as Color,
        ).animate(delay: (i * 120).ms).fadeIn(duration: 400.ms).moveY(begin: 10, end: 0);
      },
    );
  }

  Widget _statCard(IconData icon, String title, String value, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
              const Spacer(),
              const Icon(Icons.trending_up_rounded, color: Colors.green, size: 18),
            ],
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ⚡ QUICK ACTIONS
  Widget _buildQuickActions(bool isMobile) {
    final List<Map<String, dynamic>> actions = [
      {'icon': Icons.add_circle_rounded, 'title': 'Add Product', 'color': const Color(0xFF6366F1), 'route': const AddProductScreen()},
      {'icon': Icons.slideshow_rounded, 'title': 'Manage Banners', 'color': const Color(0xFFEC4899), 'route': const BannerManagementScreen()},
      {'icon': Icons.local_offer_rounded, 'title': 'Coupons', 'color': const Color(0xFFF59E0B), 'route': const CouponManagementScreen()},
      {'icon': Icons.analytics_rounded, 'title': 'Analytics', 'color': const Color(0xFF10B981), 'route': const AnalyticsScreen()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final action = actions[i];
        final Color color = action['color'] as Color;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => action['route'] as Widget)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(action['icon'] as IconData, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(action['title'] as String,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ).animate(delay: (i * 120).ms).fadeIn(duration: 350.ms).moveY(begin: 10, end: 0);
      },
    );
  }

  // 🧭 SECTION HEADER
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: AppTextStyles.titleLarge
                .copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  // 🧰 MANAGEMENT GRID
  Widget _buildManagementGrid(bool isMobile) {
    final List<Map<String, dynamic>> managements = [
      {'icon': Icons.inventory_2_rounded, 'title': 'Product Management', 'subtitle': 'View, edit & update products', 'color': const Color(0xFF6366F1), 'route': const ProductManagementScreen()},
      {'icon': Icons.shopping_cart_rounded, 'title': 'Order Management', 'subtitle': 'Monitor and track orders', 'color': const Color(0xFF10B981), 'route': const OrderManagementScreen()},
      {'icon': Icons.people_rounded, 'title': 'User Management', 'subtitle': 'Manage users & permissions', 'color': const Color(0xFFF59E0B), 'route': const UserManagementScreen()},
      {'icon': Icons.local_offer_rounded, 'title': 'Coupon Management', 'subtitle': 'Manage offers & discounts', 'color': const Color(0xFFEC4899), 'route': const CouponManagementScreen()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: isMobile ? 3 : 3.6,
      ),
      itemCount: managements.length,
      itemBuilder: (context, i) {
        final m = managements[i];
        final Color color = m['color'] as Color;
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m['route'] as Widget)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(m['icon'] as IconData, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m['title'] as String,
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(m['subtitle'] as String,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        ).animate(delay: (i * 100).ms).fadeIn(duration: 400.ms).moveY(begin: 10, end: 0);
      },
    );
  }
}