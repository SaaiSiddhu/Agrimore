// lib/screens/user/profile/profile_screen.dart
// Profile — sticky-header list design, evolved into the customer account hub
// (Phase PROFILE-1) toward a supplied visual reference: a 4-up quick-action
// row, a rewards band, and a grouped menu, all wired to real data — no
// reference-image sample value (name/phone/balances/counts) is hard-coded.
// Phase PROFILE-2 closed the remaining visual gap against that same
// reference: every menu row now carries its own coloured icon badge
// (_MenuItem.color, derived into a pastel circle by _buildMenuItem — the
// same single-colour derivation the now-deleted profile_menu_item.dart
// widget used).
// Phase PROFILE-3 redid the hero against a third, more specific owner
// reference: a compact photo-background hero (assets/images/Profile/
// profile_bg.png) with a left-aligned avatar+identity row, back+bell only
// in the top bar, and the four quick-action cards now use the owner's own
// AI/Wallet/Orders/Wishlist_Icon.png badges instead of Material icons.
// This explicitly reverses two PROFILE-2/PROFILE-1 decisions per the
// owner's own new instructions: the "AgriMore" wordmark is gone (no
// logo/title in the top bar) and so is the header's settings shortcut
// (only back + bell are named) — Settings stays fully reachable via the
// "Account Settings" row below, unaffected.
//
// The header is a real SliverAppBar(pinned: true) + FlexibleSpaceBar, not a
// scroll listener faking it: Flutter collapses the hero (avatar/name) into
// a plain "Profile" title bar as the user scrolls, and pins it there —
// exactly the two states a scroll capture of this screen shows.
//
// The menu below only lists items that are real, working destinations.
// "Language" stays deliberately gone: it only ever called local setState on
// the selected row, never persisted a choice or changed the app's locale
// anywhere, and no i18n infrastructure exists yet to back it (re-checked at
// Phase PROFILE-1, still true). "Help & Support" is back, but pointed at a
// real destination this time — a mailto: to the same support address
// Settings' own "Report a Bug" already uses — not the old AIChatScreen
// route, which is a genuine AI assistant now (see the AI Assistant quick
// action below), not a support-ticket surface.
//
// A note on a comment this file used to carry: it previously said Help &
// Support's old AIChatScreen route was "permanently dormant" after a shared
// Gemini key was revoked. That was true when written, but Phase AI-2
// replaced that dead shared-key path with `aiChatProxy` (a Cloud Function
// that uses each caller's OWN connected key, from AI-1) — confirmed by
// reading `ai_chat_service.dart`'s own header comment, which documents
// exactly that switch. The AI Assistant quick action below routes to that
// now-real chat screen via `AppRoutes.support` (never `AppRoutes.aiChat`,
// which is a declared-but-unregistered route constant that 404s).

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import 'delete_account_screen.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/seller_provider.dart';
import '../../../providers/market_mode_provider.dart';
import '../../../providers/wallet_provider.dart';

const _kAppVersion = '1.0.7'; // mirrors pubspec.yaml's version: line

class ProfileScreen extends StatefulWidget {
  // Non-null when embedded as MainScreen's Profile tab (see
  // main_screen.dart's _buildScreens()), where a plain pop would exit
  // MainScreen entirely instead of switching tabs. When this screen is
  // reached the other way — pushed from the home app bar's avatar — onBack
  // is left null and the fallback plain pop already lands back on Home,
  // since that's exactly where it was pushed from. Either path ends up
  // back on Home, which is the point.
  final VoidCallback? onBack;

  const ProfileScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isCheckingAuth = true;
  int _ordersCount = 0; // total orders ever placed — shown on the "My Orders" menu row
  int _activeOrdersCount = 0; // not yet in a terminal state — shown on the Orders quick action
  int _wishlistCount = 0;
  int _addressesCount = 0;
  int _unreadNotifications = 0;
  int _pendingRewardsCount = 0; // unscratched scratch cards (users/{uid}/scratchCards)
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

  // Orders whose lifecycle has ended — everything else (including any
  // status this app doesn't recognise yet) counts as active. Undercounting
  // a genuinely active order is worse than a rare overcount from an unknown
  // status, so unknown defaults to active rather than the other way round.
  static const Set<String> _terminalOrderStatuses = {
    'delivered', 'cancelled', 'returned', 'refunded',
  };

  bool _isActiveOrder(Map<String, dynamic> data) {
    // Order documents have historically used both `orderStatus` (the
    // canonical OrderModel field) and, on some, `status` — the same
    // defensive fallback ai_chat_service.dart's handleGetOrders already
    // uses. Normalized (lowercased, separators stripped) to absorb the
    // casing/underscore drift AppColors.getOrderStatusColor already has to
    // handle for the same reason.
    final raw = (data['orderStatus'] ?? data['status'] ?? 'pending').toString();
    final normalized = raw.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    return !_terminalOrderStatuses.contains(normalized);
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
        // Same subcollection + `unread` field notifications_screen.dart
        // itself reads — a header-badge count must never invent its own
        // source of truth for what "unread" means.
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .get(),
        // Same subcollection + `isScratched` field rewards_screen.dart's
        // own `_pendingCards` getter reads (docs missing the field also
        // count as pending, matching that getter's `!= true` check exactly
        // — a server-side `where(isEqualTo: false)` would silently miss
        // them).
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('scratchCards')
            .get(),
      ]);

      final ordersSnapshot = results[0] as QuerySnapshot;
      final wishlistDoc = results[1] as DocumentSnapshot;
      final addressesSnapshot = results[2] as QuerySnapshot;
      final notificationsSnapshot = results[3] as QuerySnapshot;
      final scratchCardsSnapshot = results[4] as QuerySnapshot;

      int wishlistCount = 0;
      if (wishlistDoc.exists) {
        final data = wishlistDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('productIds')) {
          wishlistCount = (data['productIds'] as List?)?.length ?? 0;
        }
      }

      final activeOrders = ordersSnapshot.docs
          .where((doc) => _isActiveOrder(doc.data() as Map<String, dynamic>))
          .length;

      final unreadNotifications = notificationsSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['unread'] == true)
          .length;

      final pendingRewards = scratchCardsSnapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['isScratched'] != true)
          .length;

      if (mounted) {
        setState(() {
          _ordersCount = ordersSnapshot.docs.length;
          _activeOrdersCount = activeOrders;
          _wishlistCount = wishlistCount;
          _addressesCount = addressesSnapshot.docs.length;
          _unreadNotifications = unreadNotifications;
          _pendingRewardsCount = pendingRewards;
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
      // signOut() is a second async gap past the mounted check above.
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  // Mirrors settings_screen.dart's own _reportBug() mailto pattern exactly —
  // the same real support address, not a new, unproven contact channel.
  Future<void> _contactSupport() async {
    final uri = Uri.parse(
      'mailto:support@agrimore.in?subject=${Uri.encodeComponent('AgriMore Support')}',
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      // SnackbarHelper, not the raw ScaffoldMessenger call _buildShareIcon
      // uses elsewhere in this file — this is a failure, and
      // settings_screen.dart's own _reportBug() (the same mailto-launch-
      // failed scenario) already established SnackbarHelper.showError as
      // the pattern for exactly this case.
      SnackbarHelper.showError(
        context,
        'No email app found. Reach us at support@agrimore.in',
      );
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

              // AgriMore Rewards band — real pending-scratch-card count,
              // never a fabricated points balance (see _loadUserStats).
              SliverToBoxAdapter(
                child: _buildRewardsBanner(isDark),
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
                      color: const Color(0xFF2E7D32),
                    ),
                    _MenuItem(
                      icon: Icons.event_repeat_rounded,
                      title: 'My Subscriptions',
                      onTap: () => _navigateTo(AppRoutes.mySubscriptions),
                      color: const Color(0xFF00897B),
                    ),
                    _MenuItem(
                      icon: Icons.request_quote_outlined,
                      title: 'My Quotes',
                      onTap: () => _navigateTo(AppRoutes.myRfqs),
                      color: const Color(0xFF3949AB),
                    ),
                    _MenuItem(
                      icon: Icons.location_on_rounded,
                      title: 'Delivery Addresses',
                      count: _isLoadingStats ? null : _addressesCount,
                      onTap: () => _navigateTo(AppRoutes.savedAddresses),
                      color: const Color(0xFF1976D2),
                    ),
                    _MenuItem(
                      icon: Icons.favorite_rounded,
                      title: 'Your Wishlist',
                      count: _isLoadingStats ? null : _wishlistCount,
                      onTap: () => _navigateTo(AppRoutes.wishlist),
                      color: AppColors.favorite,
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
                      color: AppColors.wallet,
                    ),
                    _MenuItem(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Rewards & Offers',
                      onTap: () => _navigateTo(AppRoutes.rewards),
                      color: const Color(0xFFF9A825),
                    ),
                    _MenuItem(
                      icon: Icons.bolt_rounded,
                      title: 'Flash Sale',
                      onTap: () => _navigateTo(AppRoutes.flashSale),
                      color: const Color(0xFFE64A19),
                    ),
                    _MenuItem(
                      icon: Icons.group_add_rounded,
                      title: 'Refer & Earn',
                      onTap: () => _navigateTo(AppRoutes.referral),
                      color: const Color(0xFFD81B60),
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
                          color: const Color(0xFF00796B),
                        )
                      else
                        _MenuItem(
                          icon: Icons.storefront_rounded,
                          title: sellerProvider.isPending
                              ? 'Seller application (pending)'
                              : 'Seller registration',
                          onTap: () => _navigateTo(AppRoutes.sellerApply),
                          color: const Color(0xFF00796B),
                        ),
                      _MenuItem(
                        icon: Icons.badge_rounded,
                        title: 'Employee application',
                        onTap: () => _navigateTo(AppRoutes.employeeApply),
                        color: const Color(0xFF6D4C41),
                      ),
                      _MenuItem(
                        icon: Icons.handshake_rounded,
                        title: 'Become a Sales Associate',
                        onTap: () => _navigateTo(AppRoutes.associateOnboarding),
                        color: const Color(0xFF512DA8),
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
                      count: _isLoadingStats || _unreadNotifications == 0
                          ? null
                          : _unreadNotifications,
                      onTap: () => _navigateTo(AppRoutes.notifications),
                      color: const Color(0xFFEF6C00),
                    ),
                    _MenuItem(
                      icon: Icons.support_agent_rounded,
                      title: 'Help & Support',
                      onTap: _contactSupport,
                      color: const Color(0xFF1E88E5),
                    ),
                    _MenuItem(
                      icon: Icons.ios_share_rounded,
                      title: 'Share Agrimore',
                      onTap: () => _showShareBottomSheet(isDark),
                      color: const Color(0xFF00ACC1),
                    ),
                    _MenuItem(
                      icon: Icons.settings_rounded,
                      title: 'Account Settings',
                      onTap: () => _navigateTo(AppRoutes.appSettings),
                      color: const Color(0xFF546E7A),
                    ),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      onTap: _logout,
                      isDestructive: true,
                    ),
                    // Phase 17, Workstream 2: placed last — visually
                    // subordinate to every other item in this section,
                    // including Log out, for an action this app never had
                    // a reachable path to before this phase.
                    _MenuItem(
                      icon: Icons.person_remove_outlined,
                      title: 'Delete account',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                        );
                      },
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
  //
  // Phase PROFILE-3: background switched from a green LinearGradient to
  // profile_bg.png (a bright sky-and-field illustration, viewed in full
  // before wiring it in — brightest in exactly the upper-left region the
  // avatar/text row occupies), hero made compact, layout switched from a
  // centered column to a left-aligned avatar+text row, and the header
  // actions reduced to notifications only — both per explicit owner
  // instruction, both reversing decisions this same file made one phase
  // earlier: the PROFILE-2 "AgriMore" wordmark is gone ("No AgriMore
  // logo/title") and the PROFILE-1 settings shortcut is gone ("Back button
  // on left, Bell/Notifications button on right" — no third icon named).
  // Settings itself is unaffected — still one tap away via the "Account
  // Settings" row in Other Information, below.
  Widget _buildHeaderSliver(dynamic user, bool isDark, double headerCollapse) {
    final pageBackground = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    // The photo itself never changes with the app theme, so dark mode dims
    // it with a scrim rather than trying to reskin a fixed illustration —
    // and flips hero text to white to read against that scrim, mirroring
    // how every other surface in this file already branches on isDark.
    final heroTextPrimary = isDark ? Colors.white : Colors.black87;
    final heroTextSecondary = isDark ? Colors.white70 : Colors.black54;

    final subtitleParts = <String>[
      if (user?.phone != null && user.phone.toString().trim().isNotEmpty)
        user.phone.toString(),
      if (user?.dateOfBirth is DateTime) _formatDob(user.dateOfBirth as DateTime),
    ];

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: 196,
      backgroundColor: pageBackground,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _buildBackButton(isDark),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildHeaderIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Open notifications',
            showDot: !_isLoadingStats && _unreadNotifications > 0,
            onTap: () => _navigateTo(AppRoutes.notifications),
          ),
        ),
      ],
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
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/Profile/profile_bg.png', fit: BoxFit.cover),
            if (isDark) Container(color: Colors.black.withValues(alpha: 0.55)),
            SafeArea(
              child: Padding(
                // kToolbarHeight clears the pinned back/bell row above,
                // which flexibleSpace's background renders underneath —
                // without this the avatar would sit behind those buttons.
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight - 4, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipOval(child: _buildAvatarImage(user?.photoUrl)),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: GestureDetector(
                            onTap: () => _navigateTo(AppRoutes.editProfile),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.edit_rounded, size: 13, color: AppColors.primaryDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hello,',
                            style: TextStyle(fontSize: 13, color: heroTextSecondary),
                          ),
                          Text(
                            user?.name ?? 'User',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: heroTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitleParts.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitleParts.join(' • '),
                              style: TextStyle(fontSize: 12.5, color: heroTextSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          // Real signal, not a fabricated paid-membership
                          // badge: still no membership/tier concept
                          // anywhere in this codebase (re-checked fresh
                          // against UserModel this phase too). Firebase
                          // Auth's own phoneNumber is set only after a
                          // completed phone-OTP verification — this app's
                          // primary sign-in method — and is a more
                          // reliable signal than Firestore's
                          // `phoneVerified` flag, which predates most
                          // existing accounts and was never backfilled.
                          if (FirebaseAuth.instance.currentUser?.phoneNumber != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, size: 13, color: AppColors.primaryDark),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Phase PROFILE-4: this account's own `photoUrl` turned out to be a
  // base64 `data:image/...` URI, not an `https://` Storage download URL —
  // discovered only by actually running this screen on the owner's real
  // device with a real session (every prior preview in this Profile track
  // had no session at all, so no photoUrl to trigger it). `Image.network`
  // is backed by `NetworkImage`, which is HTTP-only and throws "No host
  // specified in URI" on a data URI — caught by Flutter's image error
  // handler so it didn't crash the app, but painted nothing where the
  // avatar should be. No code anywhere in this repo writes a data URI into
  // photoUrl (checked before assuming this needed a defensive fix rather
  // than a writer-side one) — this is pre-existing Firestore data on a
  // real account, so the read side has to tolerate it. Falls back to
  // Avatar_Icon.png for null/empty, a malformed data URI, OR any other
  // Image.network failure (expired token, dead URL, offline) — the
  // errorBuilder is new defense-in-depth beyond just this one case.
  Widget _buildAvatarImage(String? photoUrl) {
    const size = 72.0;
    if (photoUrl == null || photoUrl.isEmpty) {
      return Image.asset(
        'assets/images/Profile/Avatar_Icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    if (photoUrl.startsWith('data:image')) {
      try {
        final commaIndex = photoUrl.indexOf(',');
        final bytes = base64Decode(photoUrl.substring(commaIndex + 1));
        return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
      } catch (e) {
        debugPrint('Error decoding data-URI avatar: $e');
        return Image.asset(
          'assets/images/Profile/Avatar_Icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    }
    return Image.network(
      photoUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/Profile/Avatar_Icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        if (widget.onBack != null) {
          widget.onBack!();
        } else {
          Navigator.pop(context);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.black87),
      ),
    );
  }

  // Same 36dp translucent-white circle as _buildBackButton, so the header's
  // two icon affordances (back, notifications) read as one consistent
  // language rather than two different button styles.
  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required bool showDot,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 19, color: Colors.black87),
              if (showDot)
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, WalletProvider walletProvider) {
    // Phase PROFILE-4/5: the cards overlap the hero photo's bottom edge via
    // a paint-time Transform, not a negative inset — a NEGATIVE Padding
    // here previously crashed at runtime (RenderPadding asserts
    // padding.isNonNegative in shifted_box.dart; Padding's own constructor
    // has no such check, so `flutter analyze` and a plain read of the
    // widget tree don't catch it, only running the screen does), and
    // Container.margin resolves to the same RenderPadding internally, so
    // it carries the identical risk. Transform.translate has no such
    // restriction (it's a paint-time matrix, not a layout inset) and still
    // hit-tests correctly at the painted position by default.
    //
    // PROFILE-5: PROFILE-4 paired this translate with a top: 8 inset on the
    // Padding below, so only (translateY - topInset) of the shift actually
    // reached the image — 22-8=14px, visibly too subtle live on-device (the
    // owner's own screenshot still read as "below the banner", not "on
    // it"). Top inset is now 0, so translateY IS the overlap amount, with
    // no hidden budget lost to it.
    return Transform.translate(
      offset: const Offset(0, -32),
      child: Padding(
        // Bottom inset stays 6 (unaffected by top inset — the gap below the
        // cards is topInset-independent, it's bottomInset + |translateY|
        // either way); the modest resulting +10px vs PROFILE-4's own
        // bottom gap is an accepted trade for the overlap actually reading
        // as an overlap.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            _buildQuickActionCard(
              iconAsset: 'assets/images/Profile/AI_Icon.png',
              label: 'AI Assistant',
              // Always "Ask anything" rather than a live value — whether a
              // key is connected yet is the chat screen's own business
              // (aiChatProxy already replies inline with how to connect one
              // if not; see the file header comment), not something this
              // card should try to summarize.
              subtitle: 'Ask anything',
              isDark: isDark,
              onTap: () => _navigateTo(AppRoutes.support),
              accentColor: AppColors.primaryDark,
            ),
            const SizedBox(width: 8),
            _buildQuickActionCard(
              iconAsset: 'assets/images/Profile/Wallet_Icon.png',
              label: 'Wallet',
              // The live balance, shown right on the profile screen instead
              // of requiring a trip to the Wallet screen to find out.
              subtitle: '₹${walletProvider.balance.toStringAsFixed(0)}',
              isDark: isDark,
              onTap: () => _navigateTo(AppRoutes.wallet),
              accentColor: const Color(0xFFE65100),
            ),
            const SizedBox(width: 8),
            _buildQuickActionCard(
              iconAsset: 'assets/images/Profile/Orders_Icons.png',
              label: 'Orders',
              subtitle: _isLoadingStats
                  ? null
                  : (_activeOrdersCount > 0
                        ? '$_activeOrdersCount Active'
                        : 'None active'),
              isDark: isDark,
              onTap: () => _navigateTo(AppRoutes.orders),
              accentColor: const Color(0xFF8D6E63),
            ),
            const SizedBox(width: 8),
            _buildQuickActionCard(
              iconAsset: 'assets/images/Profile/Wishlist_Icon.png',
              label: 'Wishlist',
              subtitle: _isLoadingStats
                  ? null
                  : (_wishlistCount > 0
                        ? '$_wishlistCount Item${_wishlistCount == 1 ? '' : 's'}'
                        : 'Empty'),
              isDark: isDark,
              onTap: () => _navigateTo(AppRoutes.wishlist),
              accentColor: AppColors.favorite,
            ),
          ],
        ),
      ),
    );
  }

  // The four PNGs (AI/Wallet/Orders/Wishlist_Icon.png) are each a
  // self-contained 3D badge — icon plus its own coloured circular
  // background already baked into the image, transparent surround —
  // confirmed by inspecting all four before wiring them in. They render
  // directly with no extra coloured-circle Container wrapping them (that
  // would draw a second, mismatched circle behind an image that already
  // has one); accentColor now only tints the subtitle text.
  Widget _buildQuickActionCard({
    required String iconAsset,
    required String label,
    String? subtitle,
    required bool isDark,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: subtitle == null ? label : '$label, $subtitle',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ClipOval, not just Image.asset: Wishlist_Icon.png is the
                // one PNG of the four saved without an alpha channel (`file`
                // confirms RGB, its three siblings are all RGBA) — its
                // corners are opaque white rather than transparent, which
                // was invisible on white light-mode cards but showed as a
                // stray white square on dark-mode cards. The clip is safe
                // for all four regardless of alpha: each drawn circle sits
                // well inside its own canvas with margin to spare, so the
                // largest circle inscribed in the square can never cut into
                // the artwork itself — confirmed by inspecting all four
                // before relying on it.
                ClipOval(
                  child: Image.asset(iconAsset, width: 46, height: 46),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
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
      ),
    );
  }

  // "AgriMore Rewards" band — the mockup's points figure has no backend
  // (no loyalty/points ledger exists anywhere in this codebase; the real
  // rewards system is a scratch-card cashback game that credits the real
  // wallet balance, see rewards_screen.dart/claimScratchCard). Shows a real
  // pending-card count instead of inventing a points balance.
  Widget _buildRewardsBanner(bool isDark) {
    final hasPending = !_isLoadingStats && _pendingRewardsCount > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Semantics(
        button: true,
        label: hasPending
            ? 'AgriMore Rewards, $_pendingRewardsCount reward${_pendingRewardsCount == 1 ? '' : 's'} waiting to be opened'
            : 'AgriMore Rewards, play a scratch card on every order',
        child: GestureDetector(
          onTap: () => _navigateTo(AppRoutes.rewards),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF14251B), const Color(0xFF1B5E20)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.eco_rounded,
                    color: isDark ? AppColors.primaryLight : const Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AgriMore Rewards',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasPending
                            ? '$_pendingRewardsCount reward${_pendingRewardsCount == 1 ? '' : 's'} waiting to be opened'
                            : 'Play a scratch card on every order',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasPending) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_pendingRewardsCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
              ],
            ),
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
    final badgeColor = item.isDestructive ? Colors.red : item.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, size: 20, color: badgeColor),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
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
  // Base colour for this row's icon badge — _buildMenuItem derives both the
  // pastel circle (alpha 0.12) and the icon tint from it, the same
  // single-colour derivation the now-deleted profile_menu_item.dart widget
  // used. isDestructive rows ignore this and always render red, matching
  // their text colour.
  final Color color;

  _MenuItem({
    required this.icon,
    required this.title,
    this.count,
    required this.onTap,
    this.isDestructive = false,
    this.color = const Color(0xFF757575),
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
