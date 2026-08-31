// lib/screens/user/profile/profile_screen.dart
// Profile — sticky-header list design.
//
// The header is a real SliverAppBar(pinned: true) + FlexibleSpaceBar, not a
// scroll listener faking it: Flutter collapses the hero (avatar/name) into
// a plain "Profile" title bar as the user scrolls, and pins it there —
// exactly the two states a scroll capture of this screen shows.
//
// The menu below only lists items that are real, working destinations.
// Two that were here before are deliberately gone:
//   - "Help & Support" routed to AIChatScreen, which Phase 21 (this same
//     session) made permanently dormant after the Gemini key was revoked —
//     every message now returns a static "unavailable" reply. Reachable,
//     but not something that works.
//   - "Language" only ever called local setState on the selected row; it
//     never persisted a choice or changed the app's locale anywhere.
// Neither does what tapping it implies, so neither belongs in a list whose
// whole point is "everything here actually does something."

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
import '../../../providers/cart_provider.dart';
import '../../../providers/seller_provider.dart';
import '../../../providers/market_mode_provider.dart';
import '../../../providers/wallet_provider.dart';

const _kAppVersion = '1.0.7'; // mirrors pubspec.yaml's version: line

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

  // Drives the collapsed-header "Profile" label: invisible while the hero
  // (avatar/name) is expanded, fades in next to the back button only once
  // scrolled far enough that the hero itself has scrolled out of view — so
  // there's never a moment with both the hero name AND this label showing.
  final ScrollController _scrollController = ScrollController();
  double _headerCollapse = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkAuthAndLoadData();
  }

  void _onScroll() {
    final progress = (_scrollController.offset / 150).clamp(0.0, 1.0);
    if (progress != _headerCollapse) {
      setState(() => _headerCollapse = progress);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SellerProvider>().checkSellerStatus();
      // Pull the latest users/{uid} doc so name/email/phone/photo shown here
      // reflect any edit made elsewhere (Edit Profile, phone/email change,
      // an admin edit) rather than the stale copy cached in AuthProvider
      // since login.
      context.read<app_auth.AuthProvider>().refreshUserData();
      // WalletProvider is only loaded on signup and on the Wallet screen's
      // own init today, so an existing user who logs in and opens Profile
      // without ever visiting Wallet would otherwise see a stale/zero
      // balance on the card below.
      context.read<WalletProvider>().loadWallet();
    });
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

  void _navigateTo(String route) async {
    HapticFeedback.lightImpact();
    await Navigator.pushNamed(context, route);
    // Re-run the same load used on entry (stats + seller status + a fresh
    // profile fetch) after returning — e.g. from Edit Profile, or an address
    // add/delete — so this screen never shows what was true before the trip,
    // without needing a manual pull-to-refresh.
    if (mounted) _checkAuthAndLoadData();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _LogoutDialog(),
    );

    if (confirmed == true && mounted) {
      try {
        Provider.of<CartProvider>(context, listen: false).reset();
      } catch (e) {}
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  String _formatDob(DateTime dob) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dob.day.toString().padLeft(2, '0')} ${months[dob.month - 1]} ${dob.year}';
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
      body: Consumer2<app_auth.AuthProvider, SellerProvider>(
        builder: (context, authProvider, sellerProvider, child) {
          final user = authProvider.currentUser;

          return CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              _buildHeaderSliver(user, isDark, _headerCollapse),

              // Quick Action Cards — pulled up to float over the header
              // gradient's fade zone (see _buildHeaderSliver), so there is
              // no hard colour seam between the hero and the rest of the
              // page; the cards' own shadow is what separates them, not a
              // background-colour change. A real negative top margin (not
              // Transform.translate, which only shifts pixels and would
              // leave a dangling gap below) so the sliver's reported height
              // shrinks to match — nothing after this needs compensating.
              SliverToBoxAdapter(
                child: Consumer<WalletProvider>(
                  builder: (context, walletProvider, _) =>
                      _buildQuickActions(isDark, walletProvider),
                ),
              ),

              // Appearance Toggle
              SliverToBoxAdapter(
                child: _buildAppearanceToggle(isDark, themeProvider),
              ),

              // B2B Ordering Mode Toggle
              SliverToBoxAdapter(
                child: Consumer<MarketModeProvider>(
                  builder: (context, marketMode, _) => _buildB2BToggle(isDark, marketMode),
                ),
              ),

              // Your Information Section
              SliverToBoxAdapter(
                child: _buildSection(
                  title: 'Your information',
                  isDark: isDark,
                  items: [
                    _MenuItem(
                      icon: Icons.shopping_bag_rounded,
                      title: 'My Orders',
                      count: _isLoadingStats ? null : _ordersCount,
                      onTap: () => _navigateTo(AppRoutes.orders),
                    ),
                    _MenuItem(
                      icon: Icons.event_repeat_rounded,
                      title: 'My Subscriptions',
                      onTap: () => _navigateTo(AppRoutes.mySubscriptions),
                    ),
                    _MenuItem(
                      icon: Icons.location_on_rounded,
                      title: 'Delivery Addresses',
                      count: _isLoadingStats ? null : _addressesCount,
                      onTap: () => _navigateTo(AppRoutes.savedAddresses),
                    ),
                    _MenuItem(
                      icon: Icons.favorite_rounded,
                      title: 'Your Wishlist',
                      count: _isLoadingStats ? null : _wishlistCount,
                      onTap: () => _navigateTo(AppRoutes.wishlist),
                    ),
                  ],
                ),
              ),

              // Payment & Rewards Section
              SliverToBoxAdapter(
                child: _buildSection(
                  title: 'Payment and rewards',
                  isDark: isDark,
                  items: [
                    _MenuItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Agrimore Wallet',
                      onTap: () => _navigateTo(AppRoutes.wallet),
                    ),
                    _MenuItem(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Rewards & Offers',
                      onTap: () => _navigateTo(AppRoutes.rewards),
                    ),
                    _MenuItem(
                      icon: Icons.bolt_rounded,
                      title: 'Flash Sale',
                      onTap: () => _navigateTo(AppRoutes.flashSale),
                    ),
                    _MenuItem(
                      icon: Icons.group_add_rounded,
                      title: 'Refer & Earn',
                      onTap: () => _navigateTo(AppRoutes.referral),
                    ),
                  ],
                ),
              ),

              // Grow With Agrimore Section
              if (!authProvider.isAdmin)
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Grow with Agrimore',
                    isDark: isDark,
                    items: [
                      if (sellerProvider.isApproved)
                        _MenuItem(
                          icon: Icons.storefront_rounded,
                          title: 'Seller dashboard',
                          onTap: () => _navigateTo(AppRoutes.sellerPanel),
                        )
                      else
                        _MenuItem(
                          icon: Icons.storefront_rounded,
                          title: sellerProvider.isPending
                              ? 'Seller application (pending)'
                              : 'Seller registration',
                          onTap: () => _navigateTo(AppRoutes.sellerApply),
                        ),
                      _MenuItem(
                        icon: Icons.badge_rounded,
                        title: 'Employee application',
                        onTap: () => _navigateTo(AppRoutes.employeeApply),
                      ),
                      _MenuItem(
                        icon: Icons.handshake_rounded,
                        title: 'Become a Sales Associate',
                        onTap: () => _navigateTo(AppRoutes.associateOnboarding),
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
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      onTap: () => _navigateTo(AppRoutes.notifications),
                    ),
                    _MenuItem(
                      icon: Icons.ios_share_rounded,
                      title: 'Share Agrimore',
                      onTap: () => _showShareBottomSheet(isDark),
                    ),
                    _MenuItem(
                      icon: Icons.settings_rounded,
                      title: 'Account Settings',
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
    );
  }

  // Sticky header: SliverAppBar(pinned: true) keeps the back button pinned
  // as the hero (avatar/name/phone·DOB) scrolls away underneath it — no
  // title text takes its place; a floating back arrow over whatever is
  // currently under it is all the top bar needs once the page has its own
  // section headers doing the labelling.
  Widget _buildHeaderSliver(dynamic user, bool isDark, double headerCollapse) {
    final pageBackground = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final heroDark = isDark ? const Color(0xFF14251B) : const Color(0xFF1B5E20);
    final heroLight = isDark ? const Color(0xFF1A1A2E) : const Color(0xFF2E7D32);
    final gradientColors = [heroDark, heroLight, pageBackground];

    final subtitleParts = <String>[
      if (user?.phone != null && user.phone.toString().trim().isNotEmpty)
        user.phone.toString(),
      if (user?.dateOfBirth is DateTime) _formatDob(user.dateOfBirth as DateTime),
    ];

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: 236,
      backgroundColor: pageBackground,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _buildBackButton(isDark),
      ),
      centerTitle: false,
      titleSpacing: 4,
      // Only the collapsed toolbar strip is ever visible here (the hero's
      // name/avatar live in flexibleSpace's background below) — opacity is
      // driven by scroll offset so it's invisible while the hero shows and
      // fades in once the user has scrolled past it.
      title: Opacity(
        opacity: headerCollapse,
        child: Text(
          'Profile',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            // Fades all the way to the page's own background colour by the
            // bottom of the header — no hard colour seam where this sliver
            // ends and the scrollable body begins. The quick-action cards
            // right below (see _buildQuickActions) are pulled up with a
            // negative top margin into this fade zone, so they read as
            // floating across the boundary rather than starting fresh
            // below a line.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: user?.photoUrl != null
                              ? Image.network(user!.photoUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.person_rounded, size: 44, color: Colors.white),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateTo(AppRoutes.editProfile),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: heroDark, width: 1.5),
                          ),
                          child: Icon(Icons.edit_rounded, size: 14, color: heroLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join(' • '),
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, WalletProvider walletProvider) {
    return Padding(
      // A NEGATIVE top inset here previously crashed at runtime —
      // RenderPadding asserts padding.isNonNegative (shifted_box.dart);
      // Padding's own constructor has no such check, so `flutter analyze`
      // and a plain read of the widget tree don't catch it, only running
      // the screen does. The header gradient already fades all the way to
      // the exact page background colour by its own bottom edge (see
      // _buildHeaderSliver), so there is no hard seam to hide with an
      // overlap in the first place — a small ordinary gap is enough.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _buildQuickActionCard(
            icon: Icons.shopping_bag_rounded,
            label: 'Your orders',
            count: _isLoadingStats ? null : _ordersCount,
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.orders),
            color: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 12),
          _buildQuickActionCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            // The live balance, shown right on the profile screen instead of
            // requiring a trip to the Wallet screen to find out.
            subtitle: '₹${walletProvider.balance.toStringAsFixed(0)}',
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.wallet),
            color: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
          ),
          const SizedBox(width: 12),
          _buildQuickActionCard(
            icon: Icons.card_giftcard_rounded,
            label: 'Rewards',
            isDark: isDark,
            onTap: () => _navigateTo(AppRoutes.rewards),
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
    String? subtitle,
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
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
            Icons.brightness_6_rounded,
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
                    Icons.keyboard_arrow_down_rounded,
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

  Widget _buildB2BToggle(bool isDark, MarketModeProvider marketMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'B2B (Wholesale) Mode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    marketMode.isB2B
                        ? 'Showing wholesale pricing and MOQ'
                        : 'Showing regular retail pricing',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: marketMode.isB2B,
              onChanged: (value) {
                HapticFeedback.mediumImpact();
                marketMode.setB2B(value);
              },
              activeThumbColor: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ],
        ),
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
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Invite Friends & Keep Growing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text('Share Agrimore with your circle and earn rewards!', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareIcon(Icons.sms_rounded, 'SMS', Colors.blue, isDark),
                _buildShareIcon(Icons.link_rounded, 'Copy Link', Colors.grey, isDark),
                _buildShareIcon(Icons.email_rounded, 'Email', Colors.red, isDark),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareIcon(IconData icon, String label, Color color, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Clipboard.setData(const ClipboardData(text: 'Download Agrimore: https://agrimore.in'));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 48),
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
            'v$_kAppVersion',
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
