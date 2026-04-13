// lib/screens/admin/admin_main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../app/routes.dart';

// Screens
import 'admin_dashboard.dart';
import 'products/product_management_screen.dart';
import 'orders/order_management_screen.dart';
import 'users/user_management_screen.dart';
import 'coupon/coupon_management_screen.dart';
import 'analytics/analytics_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'banners/banner_management_screen.dart';
import 'notifications/send_notification_screen.dart';
// ✅ ADD SPONSORED BANNERS IMPORT
import 'sponsored_banners/sponsored_banner_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({Key? key}) : super(key: key);

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const AdminDashboard(),
      const ProductManagementScreen(),
      const OrderManagementScreen(),
      const UserManagementScreen(),
      const CouponManagementScreen(),
      const BannerManagementScreen(),
      const SponsoredBannerManagementScreen(), // ✅ ADDED
      const SendNotificationScreen(),
      const AnalyticsScreen(),
      const AdminSettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Redirect if not admin
    if (!authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRoutes.navigateAndRemoveUntil(context, AppRoutes.main);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (!isMobile) _buildSideNavigation(authProvider),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _screens[_currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigation() : null,
      drawer: isMobile ? _buildDrawer(authProvider) : null,
    );
  }

  // 🧱 SIDE NAVIGATION (Desktop)
  Widget _buildSideNavigation(AuthProvider authProvider) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAdminHeader(authProvider),
          const Divider(color: Colors.white30, thickness: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.inventory_2_rounded, 'Products'),
                _buildNavItem(2, Icons.shopping_cart_rounded, 'Orders'),
                _buildNavItem(3, Icons.people_rounded, 'Users'),
                _buildNavItem(4, Icons.local_offer_rounded, 'Coupons'),
                _buildNavItem(5, Icons.slideshow_rounded, 'Banners'),
                _buildNavItem(6, Icons.campaign_rounded, 'Sponsored Banners'), // ✅ ADDED
                _buildNavItem(7, Icons.notifications_rounded, 'Notifications'),
                _buildNavItem(8, Icons.analytics_rounded, 'Analytics'),
                _buildNavItem(9, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
          const Divider(color: Colors.white30, thickness: 1),
          _buildExitButton(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // 👤 Admin Header
  Widget _buildAdminHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.admin_panel_settings_rounded,
                size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Admin Panel',
            style: AppTextStyles.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            authProvider.currentUser?.email ?? '',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 🧭 Navigation Item (Desktop)
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: 200.ms,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: () => setState(() => _currentIndex = index),
            leading: Icon(icon, color: Colors.white, size: 24),
            title: Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.chevron_right_rounded, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }

  // 🚪 Exit Button
  Widget _buildExitButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () => AppRoutes.navigateAndRemoveUntil(context, AppRoutes.main),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Exit Admin'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 6,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
    );
  }

  // 📱 Bottom Navigation (Mobile)
  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _currentIndex > 4 ? 4 : _currentIndex,
      onTap: (index) {
        if (index == 4) _scaffoldKey.currentState?.openDrawer();
        else setState(() => _currentIndex = index);
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey.shade500,
      selectedLabelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
      unselectedLabelStyle: AppTextStyles.bodySmall,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Products'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Users'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'More'),
      ],
    );
  }

  // 📲 Drawer for Mobile
  Widget _buildDrawer(AuthProvider authProvider) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAdminHeader(authProvider),
              const Divider(color: Colors.white30),
              Expanded(
                child: ListView(
                  children: [
                    _buildDrawerItem(0, Icons.dashboard_rounded, 'Dashboard'),
                    _buildDrawerItem(1, Icons.inventory_2_rounded, 'Products'),
                    _buildDrawerItem(2, Icons.shopping_cart_rounded, 'Orders'),
                    _buildDrawerItem(3, Icons.people_rounded, 'Users'),
                    _buildDrawerItem(4, Icons.local_offer_rounded, 'Coupons'),
                    _buildDrawerItem(5, Icons.slideshow_rounded, 'Banners'),
                    _buildDrawerItem(6, Icons.campaign_rounded, 'Sponsored Banners'), // ✅ ADDED
                    _buildDrawerItem(7, Icons.notifications_rounded, 'Notifications'),
                    _buildDrawerItem(8, Icons.analytics_rounded, 'Analytics'),
                    _buildDrawerItem(9, Icons.settings_rounded, 'Settings'),
                  ],
                ),
              ),
              const Divider(color: Colors.white30),
              _buildExitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
      onTap: () {
        Navigator.pop(context);
        setState(() => _currentIndex = index);
      },
    );
  }
}
