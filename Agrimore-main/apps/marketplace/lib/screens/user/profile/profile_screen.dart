// lib/screens/user/profile/profile_screen.dart
// Blinkit-style Profile Screen - Premium UI

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isCheckingAuth = true;
  int _ordersCount = 0;
  int _wishlistCount = 0;
  int _addressesCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  Future<void> _checkAuthAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
      return;
    }
    setState(() => _isCheckingAuth = false);
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .get(),
        FirebaseFirestore.instance.collection('wishlists').doc(userId).get(),
        FirebaseFirestore.instance
            .collection('addresses')
            .where('userId', isEqualTo: userId)
            .get(),
      ]);

      final ordersSnapshot = results[0] as QuerySnapshot;
      final wishlistDoc = results[1] as DocumentSnapshot;
      final addressesSnapshot = results[2] as QuerySnapshot;

      int wishlistCount = 0;
      if (wishlistDoc.exists) {
        final data = wishlistDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('productIds')) {
          wishlistCount = (data['productIds'] as List?)?.length ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _ordersCount = ordersSnapshot.docs.length;
          _wishlistCount = wishlistCount;
          _addressesCount = addressesSnapshot.docs.length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _navigateTo(String route) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, route);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _LogoutDialog(),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Consumer<app_auth.AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.currentUser;
            
            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Simple AppBar Header
                SliverToBoxAdapter(
                  child: _buildCompactAppBar(isDark),
                ),

                // User Profile Card
                SliverToBoxAdapter(
                  child: _buildUserCard(user, isDark),
                ),

                // Quick Action Cards
                SliverToBoxAdapter(
                  child: _buildQuickActions(isDark),
                ),

                // Appearance Toggle
                SliverToBoxAdapter(
                  child: _buildAppearanceToggle(isDark, themeProvider),
                ),

                // Your Information Section
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Your information',
                    isDark: isDark,
                    items: [
                      _MenuItem(
                        icon: Icons.location_on_outlined,
                        title: 'Address book',
                        count: _isLoadingStats ? null : _addressesCount,
                        onTap: () => _navigateTo(AppRoutes.savedAddresses),
                      ),
                      _MenuItem(
                        icon: Icons.favorite_outline,
                        title: 'Your wishlist',
                        count: _isLoadingStats ? null : _wishlistCount,
                        onTap: () => _navigateTo(AppRoutes.wishlist),
                      ),
                    ],
                  ),
                ),

                // Other Information Section
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Other information',
                    isDark: isDark,
                    items: [
                      _MenuItem(
                        icon: Icons.share_outlined,
                        title: 'Share the app',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: 'About us',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.lock_outline,
                        title: 'Account privacy',
                        onTap: () => _navigateTo(AppRoutes.changePassword),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notification preferences',
                        onTap: () => _navigateTo(AppRoutes.appSettings),
                      ),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        onTap: _logout,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),

                // Footer with Version
                SliverToBoxAdapter(
                  child: _buildFooter(isDark),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back,
              size: 24,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF1B5E20)).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: user?.photoUrl != null
                  ? Image.network(user!.photoUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.person, size: 30, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'email@example.com',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit Button
          GestureDetector(
            onTap: () => _navigateTo(AppRoutes.editProfile),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildQuickActionCard(
            icon: Icons.shopping_bag_outlined,
            label: 'Your orders',
            count: _isLoadingStats ? null : _ordersCount,
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.orders),
            color: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 12),
          _buildQuickActionCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Wallet',
            isDark: isDark,
            onTap: () {},
            color: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
          ),
          const SizedBox(width: 12),
          _buildQuickActionCard(
            icon: Icons.help_outline,
            label: 'Need help?',
            isDark: isDark,
            onTap: () {},
            color: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    int? count,
    required bool isDark,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? iconColor.withOpacity(0.15) : color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  if (count != null && count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceToggle(bool isDark, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.brightness_6_outlined,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => themeProvider.toggleTheme(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    isDark ? 'DARK' : 'LIGHT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.primaryLight : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: isDark ? AppColors.primaryLight : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool isDark,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;
              
              return Column(
                children: [
                  _buildMenuItem(item, isDark),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 52,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 22,
                color: item.isDestructive
                    ? Colors.red
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: item.isDestructive
                        ? Colors.red
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (item.count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (!item.isDestructive)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      // Extra padding at bottom to account for bottom navigation bar (extendBody: true)
      padding: const EdgeInsets.only(top: 40, bottom: 120),
      child: Column(
        children: [
          Text(
            'agrimore',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[700] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final int? count;
  final VoidCallback onTap;
  final bool isDestructive;

  _MenuItem({
    required this.icon,
    required this.title,
    this.count,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, size: 32, color: Colors.red.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Log out',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to log out?',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log out',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
