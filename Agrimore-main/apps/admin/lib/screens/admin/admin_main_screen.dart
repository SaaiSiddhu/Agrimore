// lib/screens/admin/admin_main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../app/themes/admin_colors.dart';
import '../../providers/auth_provider.dart';
import '../../app/app_router.dart';

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
import 'sponsored_banners/sponsored_banner_management_screen.dart';
import 'bestsellers/bestseller_management_screen.dart';
import 'category_sections/category_section_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({Key? key}) : super(key: key);

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCollapsed = false;

  late final List<Widget> _screens;
  late AnimationController _hoverController;

  // Modern navigation items with Lucide-style icons
  final List<_NavItem> _navItems = [
    _NavItem(Icons.grid_view_rounded, Icons.grid_view_outlined, 'Dashboard', 'Home'),
    _NavItem(Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Products', 'Catalog'),
    _NavItem(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders', 'Sales'),
    _NavItem(Icons.group_rounded, Icons.group_outlined, 'Users', 'Customers'),
    _NavItem(Icons.loyalty_rounded, Icons.loyalty_outlined, 'Coupons', 'Offers'),
    _NavItem(Icons.collections_rounded, Icons.collections_outlined, 'Banners', 'Media'),
    _NavItem(Icons.ads_click_rounded, Icons.ads_click_outlined, 'Sponsored', 'Ads'),
    _NavItem(Icons.star_rounded, Icons.star_outline_rounded, 'Bestsellers', 'Featured'),
    _NavItem(Icons.category_rounded, Icons.category_outlined, 'Sections', 'Home Categories'),
    _NavItem(Icons.notifications_active_rounded, Icons.notifications_none_rounded, 'Notifications', 'Alerts'),
    _NavItem(Icons.insights_rounded, Icons.insights_outlined, 'Analytics', 'Reports'),
    _NavItem(Icons.settings_rounded, Icons.settings_outlined, 'Settings', 'Config'),
  ];

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _screens = [
      const AdminDashboard(),
      const ProductManagementScreen(),
      const OrderManagementScreen(),
      const UserManagementScreen(),
      const CouponManagementScreen(),
      const BannerManagementScreen(),
      const SponsoredBannerManagementScreen(),
      const BestsellerManagementScreen(),
      const CategorySectionManagementScreen(),
      const SendNotificationScreen(),
      const AnalyticsScreen(),
      const AdminSettingsScreen(),
    ];
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    // Wait for auth to initialize (but not isLoading - user data loaded by splash)
    if (authProvider.isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AdminColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: AdminColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Redirect if not admin (only after auth is fully initialized)
    if (!authProvider.isLoggedIn || !authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AdminRoutes.auth);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          if (!isMobile) _buildPremiumSidebar(authProvider),
          Expanded(
            child: Column(
              children: [
                if (isMobile) _buildMobileHeader(authProvider),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.02, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _screens[_currentIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildPremiumBottomNav() : null,
      drawer: isMobile ? _buildPremiumDrawer(authProvider) : null,
    );
  }

  // ============================================
  // 🎨 PREMIUM SIDEBAR (Desktop)
  // ============================================
  Widget _buildPremiumSidebar(AuthProvider authProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: _isCollapsed ? 80 : 280,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(authProvider),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 8 : 12, vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) => _buildSidebarItem(index),
            ),
          ),
          _buildSidebarFooter(authProvider),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).moveX(begin: -20, end: 0);
  }

  Widget _buildSidebarHeader(AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.all(_isCollapsed ? 16 : 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              // App Icon
              Container(
                width: _isCollapsed ? 48 : 52,
                height: _isCollapsed ? 48 : 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AdminColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AdminColors.primary, AdminColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agrimore',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.primaryLight,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: 20),
            // Admin Profile Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AdminColors.primary, AdminColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        authProvider.currentUser?.name.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.currentUser?.name ?? 'Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          authProvider.currentUser?.email ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final item = _navItems[index];
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.05),
          splashColor: AdminColors.primary.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 0 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AdminColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AdminColors.primary.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AdminColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AdminColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.all(_isCollapsed ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        children: [
          // Collapse Toggle
          if (!_isCollapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.keyboard_double_arrow_left_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Collapse',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Logout Button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await authProvider.signOut();
                if (mounted) {
                  context.go(AdminRoutes.auth);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: _isCollapsed ? 0 : 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade300,
                      size: 20,
                    ),
                    if (!_isCollapsed) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 📱 MOBILE HEADER
  // ============================================
  Widget _buildMobileHeader(AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu Button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_rounded, size: 24, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AdminColors.primary, AdminColors.primaryLight],
                          ),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _navItems[_currentIndex].label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _navItems[_currentIndex].subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Profile
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminColors.primary, AdminColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                authProvider.currentUser?.name.substring(0, 1).toUpperCase() ?? 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 📱 PREMIUM BOTTOM NAVIGATION
  // ============================================
  Widget _buildPremiumBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Home'),
              _buildBottomNavItem(1, Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Products'),
              _buildBottomNavItem(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders'),
              _buildBottomNavItem(3, Icons.group_rounded, Icons.group_outlined, 'Users'),
              _buildBottomNavItem(10, Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData activeIcon, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AdminColors.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? AdminColors.primary : Colors.grey.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AdminColors.primary : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // 📱 LIGHT THEME DRAWER (Mobile)
  // ============================================
  Widget _buildPremiumDrawer(AuthProvider authProvider) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Light theme header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AdminColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AdminColors.primary, AdminColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agrimore',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ADMIN PANEL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = _currentIndex == index;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = index);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AdminColors.primary.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: AdminColors.primary.withOpacity(0.2)) : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AdminColors.primary : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected ? AdminColors.primary : const Color(0xFF374151),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AdminColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Sign out button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    await authProvider.signOut();
                    if (mounted) {
                      context.go(AdminRoutes.auth);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Navigation Item Model
class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  final String subtitle;

  const _NavItem(this.activeIcon, this.icon, this.label, this.subtitle);
}
