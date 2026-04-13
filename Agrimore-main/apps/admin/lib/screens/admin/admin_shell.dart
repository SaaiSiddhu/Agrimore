// lib/screens/admin/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../app/themes/admin_colors.dart';
import '../../app/app_router.dart';
import '../../providers/auth_provider.dart';

/// AdminShell - Persistent sidebar layout for admin routes
class AdminShell extends StatefulWidget {
  final String currentPath;
  final Widget child;

  const AdminShell({
    Key? key,
    required this.currentPath,
    required this.child,
  }) : super(key: key);

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCollapsed = false;

  // Navigation items with routes
  static final List<_NavItem> _navItems = [
    _NavItem(Icons.grid_view_rounded, 'Dashboard', AdminRoutes.dashboard),
    _NavItem(Icons.inventory_2_rounded, 'Products', AdminRoutes.products),
    _NavItem(Icons.receipt_long_rounded, 'Orders', AdminRoutes.orders),
    _NavItem(Icons.delivery_dining_rounded, 'Delivery Partners', AdminRoutes.deliveryPartners),
    _NavItem(Icons.group_rounded, 'Users', AdminRoutes.users),
    _NavItem(Icons.loyalty_rounded, 'Coupons', AdminRoutes.coupons),
    _NavItem(Icons.collections_rounded, 'Banners', AdminRoutes.banners),
    _NavItem(Icons.ads_click_rounded, 'Sponsored', AdminRoutes.sponsored),
    _NavItem(Icons.view_carousel_rounded, 'Section Banners', AdminRoutes.sectionBanners),
    _NavItem(Icons.star_rounded, 'Bestsellers', AdminRoutes.bestsellers),
    _NavItem(Icons.category_rounded, 'Sections', AdminRoutes.sections),
    _NavItem(Icons.notifications_active_rounded, 'Notifications', AdminRoutes.notifications),
    _NavItem(Icons.insights_rounded, 'Analytics', AdminRoutes.analytics),
    _NavItem(Icons.settings_rounded, 'Settings', AdminRoutes.settings),
  ];

  int get _currentIndex {
    final path = widget.currentPath;
    for (int i = 0; i < _navItems.length; i++) {
      if (path.startsWith(_navItems[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    // Redirect if not admin
    if (!authProvider.isLoggedIn || !authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AdminRoutes.auth);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(authProvider),
          Expanded(
            child: Column(
              children: [
                if (isMobile) _buildMobileHeader(authProvider),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
      drawer: isMobile ? _buildDrawer(authProvider) : null,
    );
  }

  // ============================================
  // SIDEBAR (Desktop)
  // ============================================
  Widget _buildSidebar(AuthProvider authProvider) {
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
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        authProvider.currentUser?.email ?? 'Administrator',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Collapse button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isCollapsed = !_isCollapsed);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isCollapsed)
                    Text(
                      'Collapse Menu',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                    ),
                  AnimatedRotation(
                    turns: _isCollapsed ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.chevron_left_rounded, color: Colors.white.withOpacity(0.6), size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final item = _navItems[index];
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.go(item.route);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: _isCollapsed ? 12 : 16,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AdminColors.primary,
                        AdminColors.primary.withOpacity(0.8),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                  size: 22,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // MOBILE HEADER
  // ============================================
  Widget _buildMobileHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AdminColors.primary, AdminColors.primaryLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _navItems[_currentIndex].label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(
                  _getSubtitle(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AdminColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  authProvider.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSubtitle() {
    switch (_currentIndex) {
      case 0: return 'Overview';
      case 1: return 'Catalog';
      case 2: return 'Sales';
      case 3: return 'Customers';
      case 4: return 'Offers';
      case 5: return 'Media';
      case 6: return 'Ads';
      case 7: return 'Between Sections';
      case 8: return 'Featured';
      case 9: return 'Home Categories';
      case 10: return 'Alerts';
      case 11: return 'Reports';
      case 12: return 'Config';
      default: return '';
    }
  }

  // ============================================
  // BOTTOM NAV (Mobile)
  // ============================================
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
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
              _buildBottomNavItem(0, Icons.grid_view_rounded, 'Home'),
              _buildBottomNavItem(1, Icons.inventory_2_rounded, 'Products'),
              _buildBottomNavItem(2, Icons.receipt_long_rounded, 'Orders'),
              _buildBottomNavItem(3, Icons.group_rounded, 'Users'),
              _buildBottomNavItem(11, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go(_navItems[index].route);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AdminColors.primary : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AdminColors.primary : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // DRAWER (Mobile)
  // ============================================
  Widget _buildDrawer(AuthProvider authProvider) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/icons/app_icon.png', width: 50, height: 50,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AdminColors.primary, AdminColors.primaryLight]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Panel',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      Text(authProvider.currentUser?.email ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = _currentIndex == index;
                  return ListTile(
                    leading: Icon(item.icon, color: isSelected ? Colors.white : Colors.white.withOpacity(0.6)),
                    title: Text(item.label, style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    )),
                    selected: isSelected,
                    selectedTileColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item.route);
                    },
                  );
                },
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.go(AdminRoutes.auth);
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem(this.icon, this.label, this.route);
}
