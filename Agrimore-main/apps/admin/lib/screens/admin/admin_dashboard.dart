// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../app/themes/admin_colors.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import 'products/product_management_screen.dart';
import 'orders/order_management_screen.dart';
import 'users/user_management_screen.dart';
import 'analytics/analytics_screen.dart';
import 'coupon/coupon_management_screen.dart';
import 'products/product_form_screen.dart';
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
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    await Provider.of<AdminProvider>(context, listen: false).loadDashboardStats();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AdminColors.primary,
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
      backgroundColor: AdminColors.primary,
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
                color: AdminColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 💫 PREMIUM WELCOME BANNER
  Widget _buildWelcomeBanner(AuthProvider authProvider) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    String greetingIcon = '🌅';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = '☀️';
    }
    if (hour >= 17) {
      greeting = 'Good Evening';
      greetingIcon = '🌙';
    }

    final now = DateTime.now();
    final formattedDate = '${_getDayName(now.weekday)}, ${now.day} ${_getMonthName(now.month)} ${now.year}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary,
            AdminColors.primaryLight,
            const Color(0xFF60A5FA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with date and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'All Systems Online',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Greeting
                Row(
                  children: [
                    Text(greetingIcon, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${authProvider.currentUser?.name.split(' ')[0] ?? 'Admin'}!',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).moveY(begin: 12, end: 0);
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return '';
    }
  }

  // 📊 PREMIUM STATS SECTION
  Widget _buildAnimatedStats(Map<String, dynamic> stats, bool isMobile) {
    final revenue = (stats['revenue'] ?? 0).toDouble();
    final orders = stats['orders'] ?? 0;
    final products = stats['products'] ?? 0;
    final users = stats['users'] ?? 0;
    final pendingOrders = stats['pendingOrders'] ?? 0;
    final sellers = stats['sellers'] ?? 0;
    final categories = stats['categories'] ?? 0;
    final lowStock = stats['lowStock'] ?? 0;

    final List<_StatCardData> statItems = [
      _StatCardData(
        icon: Icons.currency_rupee_rounded,
        title: 'Total Revenue',
        value: '₹${NumberFormat('#,##,###').format(revenue)}',
        subtitle: 'Lifetime earnings',
        color: const Color(0xFF10B981),
        change: revenue > 0 ? 'Active' : 'No sales yet',
        isPositive: revenue > 0,
      ),
      _StatCardData(
        icon: Icons.receipt_long_rounded,
        title: 'Total Orders',
        value: NumberFormat('#,###').format(orders),
        subtitle: 'All time orders',
        color: const Color(0xFF3B82F6),
        change: orders > 0 ? '$orders total' : 'No orders',
        isPositive: orders > 0,
      ),
      _StatCardData(
        icon: Icons.hourglass_top_rounded,
        title: 'Pending',
        value: pendingOrders.toString(),
        subtitle: 'Awaiting action',
        color: const Color(0xFFF59E0B),
        change: pendingOrders > 0 ? 'Action needed' : 'All clear',
        isPositive: pendingOrders == 0,
      ),
      _StatCardData(
        icon: Icons.inventory_2_rounded,
        title: 'Products',
        value: products.toString(),
        subtitle: 'Active listings',
        color: const Color(0xFF8B5CF6),
        change: lowStock > 0 ? '$lowStock low stock' : 'In stock',
        isPositive: lowStock == 0,
      ),
      _StatCardData(
        icon: Icons.group_rounded,
        title: 'Users',
        value: NumberFormat('#,###').format(users),
        subtitle: 'Registered accounts',
        color: const Color(0xFF06B6D4),
        change: users > 0 ? '$users registered' : 'No users',
        isPositive: users > 0,
      ),
      _StatCardData(
        icon: Icons.storefront_rounded,
        title: 'Sellers',
        value: sellers.toString(),
        subtitle: 'Active vendors',
        color: const Color(0xFFEC4899),
        change: sellers > 0 ? '$sellers active' : 'No sellers',
        isPositive: sellers > 0,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.3 : 1.8,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => _buildStatCard(statItems[i], i),
    );
  }

  Widget _buildStatCard(_StatCardData data, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row - Icon and change badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: data.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(data.icon, color: data.color, size: 22),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: data.isPositive 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            data.isPositive ? Icons.trending_up_rounded : Icons.warning_amber_rounded,
                            size: 12,
                            color: data.isPositive ? Colors.green.shade600 : Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data.change,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: data.isPositive ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Bottom - Value and title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 80).ms).fadeIn(duration: 350.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildPrimaryStatCard(_StatCardData data, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(data.icon, color: data.color, size: 28),
                ),
                const SizedBox(width: 16),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: data.isPositive 
                                  ? Colors.green.withOpacity(0.1) 
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  data.isPositive ? Icons.trending_up_rounded : Icons.warning_rounded,
                                  size: 12,
                                  color: data.isPositive ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  data.change,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: data.isPositive ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Mini chart placeholder
                Container(
                  width: 60,
                  height: 40,
                  child: CustomPaint(
                    painter: _SparklinePainter(data.color.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).moveY(begin: 10, end: 0);
  }

  Widget _buildSecondaryStatCard(_StatCardData data, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: data.color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: data.isPositive 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data.change,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: data.isPositive ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).moveY(begin: 10, end: 0);
  }

  // ⚡ QUICK ACTIONS
  Widget _buildQuickActions(bool isMobile) {
    final List<Map<String, dynamic>> actions = [
      {'icon': Icons.add_circle_rounded, 'title': 'Add Product', 'color': const Color(0xFF6366F1), 'route': const ProductFormScreen()},
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
            color: AdminColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AdminColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: AppTextStyles.titleLarge
                .copyWith(fontWeight: FontWeight.bold, color: AdminColors.primary)),
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

// Data class for stat cards
class _StatCardData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final String change;
  final bool isPositive;

  const _StatCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.change,
    required this.isPositive,
  });
}

// Sparkline painter for mini charts
class _SparklinePainter extends CustomPainter {
  final Color color;
  
  _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Sample data points for the sparkline
    final points = [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.75, 0.9];
    
    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final y = size.height - (points[i] * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}