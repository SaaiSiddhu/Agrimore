// lib/screens/user/profile/profile_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../helpers/ad_helper.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';
import '../../../providers/order_provider.dart';
import '../../auth/auth_screen.dart';
import '../../admin/admin_main_screen.dart';
import '../orders/my_orders_screen.dart';
import '../wishlist/wishlist_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'saved_addresses_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _toastAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _toastSlideAnimation;
  late Animation<double> _toastFadeAnimation;
  late Animation<double> _toastScaleAnimation;

  bool _notificationsEnabled = true;
  int _ordersCount = 0;
  int _wishlistCount = 0;
  int _addressesCount = 0;
  bool _isLoadingStats = true;
  bool _isCheckingAuth = true;

  bool _showToast = false;
  String _toastMessage = '';
  IconData _toastIcon = Icons.check_circle;
  Color _toastColor = const Color(0xFF2D7D3C);
  Timer? _toastTimer;

  // Banner ad that appears below the logout button
  BannerAd? _bannerAd;
  AnchoredAdaptiveBannerAdSize? _adSize;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _toastAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _toastSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _toastAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _toastFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.easeOut),
    );

    _toastScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.elasticOut),
    );

    _checkAuthenticationAndLoadData();
    _loadNotificationSetting();

    // Initialize ads and load the single banner
    MobileAds.instance.initialize().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBannerAd();
      });
    });
  }

  Future<void> _loadBannerAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    
    if (size == null || !mounted) return;
    
    setState(() {
      _adSize = size;
    });

    _bannerAd = BannerAd(
      adUnitId: AdHelper.profileBannerBottomAdUnitId, 
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Ad loaded successfully!');
          if (mounted) setState(() => _isBannerAdReady = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Ad failed to load: $error');
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
        },
      ),
    );
    await _bannerAd!.load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _toastAnimationController.dispose();
    _toastTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _showToastMessage(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    _toastTimer?.cancel();

    setState(() {
      _toastMessage = message;
      _toastIcon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;
      _toastColor = isSuccess ? const Color(0xFF2D7D3C) : Colors.red;
      _showToast = true;
    });

    _toastAnimationController.forward();

    _toastTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _toastAnimationController.reverse().then((_) {
          if (mounted) setState(() => _showToast = false);
        });
      }
    });
  }

  Future<void> _checkAuthenticationAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);

    if (user == null || authProvider.currentUser == null) {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        });
      }
      return;
    }

    setState(() => _isCheckingAuth = false);
    _animationController.forward(); // This triggers the entry animation
    _loadUserStats();
  }

  // ✅✅✅
  // FIXED: This function now queries the correct paths based on your Firestore rules.
  // ✅✅✅
  Future<void> _loadUserStats() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint("❌ Error loading user stats: User is null.");
        if (mounted) setState(() => _isLoadingStats = false);
        return;
      }

      debugPrint("✅ [Stats] Loading stats for user: $userId");

      // --- 1. Get Orders (Correct as per your rules) ---
      debugPrint("✅ [Stats] Querying 'orders' collection where 'userId' == $userId");
      final ordersFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      // --- 2. Get Wishlist (FIXED: Using 'wishlists' root collection) ---
      // Your rules show `match /wishlists/{userId}`
      // Your provider shows this is a single doc with a `productIds` array
      final wishlistPath = 'wishlists/$userId';
      debugPrint("✅ [Stats] Querying wishlist document at: $wishlistPath");
      final wishlistFuture = FirebaseFirestore.instance
          .collection('wishlists') // Plural, as per your rules
          .doc(userId)
          .get();

      // --- 3. Get Addresses (FIXED: Using 'addresses' root collection) ---
      // Your rules show `match /addresses/{addressId}`
      debugPrint("✅ [Stats] Querying 'addresses' collection where 'userId' == $userId");
      final addressesFuture = FirebaseFirestore.instance
          .collection('addresses') // Root collection, as per your rules
          .where('userId', isEqualTo: userId)
          .get();

      // Wait for all futures to complete
      final results = await Future.wait([
        ordersFuture,
        wishlistFuture,
        addressesFuture,
      ]);

      // --- Process results ---
      final ordersSnapshot = results[0] as QuerySnapshot;
      final wishlistDoc = results[1] as DocumentSnapshot; // This is a single document
      final addressesSnapshot = results[2] as QuerySnapshot;

      // Process Wishlist Document
      int wishlistCount = 0;
      if (wishlistDoc.exists) {
        final data = wishlistDoc.data() as Map<String, dynamic>?;
        // Count the length of the 'productIds' array (based on your WishlistProvider)
        if (data != null && data.containsKey('productIds')) {
          wishlistCount = (data['productIds'] as List?)?.length ?? 0;
        }
        debugPrint("✅ [Stats] Found wishlist doc, item count: $wishlistCount");
      } else {
        // This case is for the `wishlists/{userId}/items` subcollection model
        // To be safe, let's query that too if the doc-array model fails.
        // But for now, your WishlistProvider implies the doc-array model.
        // Let's also check the subcollection 'items' as a fallback
        // based on your rules: `match /wishlists/{userId} { match /items/{itemId}`
        debugPrint("✅ [Stats] Wishlist doc not found at $wishlistPath. Checking 'items' subcollection...");
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('wishlists')
            .doc(userId)
            .collection('items')
            .get();
        wishlistCount = itemsSnapshot.docs.length;
        debugPrint("✅ [Stats] Found ${itemsSnapshot.docs.length} items in subcollection.");
      }

      if (mounted) {
        setState(() {
          _ordersCount = ordersSnapshot.docs.length;
          _wishlistCount = wishlistCount; // Set the correct count
          _addressesCount = addressesSnapshot.docs.length;
          _isLoadingStats = false;
        });
        debugPrint("✅ [Stats] State updated successfully: O:$_ordersCount, W:$_wishlistCount, A:$_addressesCount");
      }
    } catch (e, stackTrace) {
      // This will catch any errors
      debugPrint('❌❌❌ [Stats] CRITICAL ERROR loading user stats: $e');
      debugPrint('Stack Trace: $stackTrace');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }


Future<void> _loadNotificationSetting() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading notification: $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      if (value) {
        final permission = await Permission.notification.request();
        
        if (!permission.isGranted) {
          _showToastMessage('⚠️ Notification permission denied', isSuccess: false);
          return;
        }
      }

      setState(() => _notificationsEnabled = value);

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'notificationsEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showToastMessage(
          value ? '✅ Notifications enabled' : '🔕 Notifications disabled',
          isSuccess: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Error toggling notifications: $e');
      _showToastMessage('Failed to update', isSuccess: false);
      setState(() => _notificationsEnabled = !value);
    }
  }

  void _navigateToScreen(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _logout(bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 30,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      } catch (e) {
        _showToastMessage('Logout failed', isSuccess: false);
      }
    }
  }

  Widget _buildCompactHeader(dynamic user, bool isDark) {
    // Add top padding to account for the status bar
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      // Apply gradient and padding
      padding: EdgeInsets.fromLTRB(20, 16 + topPadding, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // ✅ Use dark subtle gradient for dark mode, bright green for light
          colors: isDark
              ? [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D3A2D),
                  const Color(0xFF3A4D3A),
                ]
              : [
                  const Color(0xFF2D7D3C),
                  const Color(0xFF3DA34E),
                  const Color(0xFF4DB85F),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
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
                      ? Image.network(
                          user!.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              // Use a gradient that matches the header
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                    ? [const Color(0xFF2D3A2D), const Color(0xFF3A4D3A)]
                                    : [const Color(0xFF2D7D3C), const Color(0xFF3DA34E)],
                                ),
                              ),
                              child: const Icon(Icons.person, size: 35, color: Colors.white),
                            );
                          },
                        )
                      : Container(
                          // Use a gradient that matches the header
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                ? [const Color(0xFF2D3A2D), const Color(0xFF3A4D3A)]
                                : [const Color(0xFF2D7D3C), const Color(0xFF3DA34E)],
                            ),
                          ),
                          child: const Icon(Icons.person, size: 35, color: Colors.white),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'email@example.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToScreen(EditProfileScreen()),
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
    Widget? trailing,
  }) {
    // Logic for tile color (accent)
    final tileColor = color ?? (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tileColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tileColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdBanner(BannerAd? ad, bool isReady, bool isDark) {
    final double height = (_adSize != null) ? _adSize!.height.toDouble() : 60.0;

    // Return a placeholder if ad isn't ready or failed to load
    if (!isReady || ad == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ),
      );
    }

    // Main ad container
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign_rounded,
                    size: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              height: height,
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              child: Center(
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to create the count badge
  Widget _buildCountBadge(int count, bool isDark) {
    // This logic is correct as per your home_app_bar example
    // It uses the bright accent color (primaryLight) in dark mode
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      // REMOVED SafeArea from here to allow header to go to the top
      body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Consumer<app_auth.AuthProvider>(
                  builder: (context, authProvider, child) {
                    final user = authProvider.currentUser;

                    // Calculate the header height
                    // 16 (top padding) + 70 (avatar) + 20 (bottom padding)
                    // We add the status bar height
                    final double headerHeight =
                        MediaQuery.of(context).padding.top + 106;

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // ✅✅✅ START: MODIFIED CODE ✅✅✅
                        // Replaced SliverToBoxAdapter with SliverPersistentHeader
                        // to make the header sticky.
                        SliverPersistentHeader(
                          delegate: _StickyProfileHeaderDelegate(
                            child: _buildCompactHeader(user, isDark),
                            height: headerHeight,
                          ),
                          pinned: true,
                        ),
                        // ✅✅✅ END: MODIFIED CODE ✅✅✅
                        
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildMenuTile(
                                  icon: Icons.lock_outline,
                                  title: 'Change Password',
                                  subtitle: 'Secure your account',
                                  isDark: isDark,
                                  onTap: () => _navigateToScreen(ChangePasswordScreen()),
                                ),
                                _buildMenuTile(
                                  icon: Icons.location_on_outlined,
                                  title: 'Saved Addresses',
                                  subtitle: 'Manage delivery locations',
                                  isDark: isDark,
                                  onTap: () => _navigateToScreen(SavedAddressesScreen()),
                                  // Count badge
                                  trailing: _isLoadingStats
                                      ? null
                                      : _buildCountBadge(_addressesCount, isDark),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Activity',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildMenuTile(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'My Orders',
                                  subtitle: 'Track & manage orders',
                                  isDark: isDark,
                                  onTap: () => _navigateToScreen(
                                    ChangeNotifierProvider(
                                      create: (_) => OrderProvider(),
                                      child: const MyOrdersScreen(),
                                    ),
                                  ),
                                  trailing: _isLoadingStats
                                      ? null
                                      : _buildCountBadge(_ordersCount, isDark),
                                ),
                                _buildMenuTile(
                                  icon: Icons.favorite_outline,
                                  title: 'Wishlist',
                                  subtitle: 'Saved items',
                                  isDark: isDark,
                                  onTap: () => _navigateToScreen(WishlistScreen()),
                                  // Count badge
                                  trailing: _isLoadingStats
                                      ? null
                                      : _buildCountBadge(_wishlistCount, isDark),
                                ),

                                const SizedBox(height: 16),
                                Text(
                                  'Preferences',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildMenuTile(
                                  icon: Icons.notifications_outlined,
                                  title: 'Notifications',
                                  subtitle: 'Push notifications',
                                  isDark: isDark,
                                  onTap: () {},
                                  trailing: Transform.scale(
                                    scale: 0.75,
                                    child: Switch(
                                      value: _notificationsEnabled,
                                      onChanged: _toggleNotifications,
                                      activeColor: isDark
                                          ? AppColors.primaryLight
                                          : const Color(0xFF2D7D3C),
                                    ),
                                  ),
                                ),
                                _buildMenuTile(
                                  icon: Icons.settings_outlined,
                                  title: 'Settings',
                                  subtitle: 'App preferences',
                                  isDark: isDark,
                                  onTap: () => _navigateToScreen(SettingsScreen()),
                                ),

                                if (authProvider.isAdmin) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildMenuTile(
                                    icon: Icons.admin_panel_settings_outlined,
                                    title: 'Admin Dashboard',
                                    subtitle: 'Manage app content',
                                    color: Colors.purple,
                                    isDark: isDark,
                                    onTap: () => _navigateToScreen(AdminMainScreen()),
                                  ),
                                ],

                                // Legal & Policies Section
                                const SizedBox(height: 16),
                                Text(
                                  'Legal & Policies',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildMenuTile(
                                  icon: Icons.description_outlined,
                                  title: 'Terms and Conditions',
                                  subtitle: 'Usage terms',
                                  isDark: isDark,
                                  onTap: () => Navigator.pushNamed(context, '/terms-and-conditions'),
                                ),
                                _buildMenuTile(
                                  icon: Icons.privacy_tip_outlined,
                                  title: 'Privacy Policy',
                                  subtitle: 'Data protection',
                                  isDark: isDark,
                                  onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
                                ),
                                _buildMenuTile(
                                  icon: Icons.local_shipping_outlined,
                                  title: 'Shipping Policy',
                                  subtitle: 'Delivery info',
                                  isDark: isDark,
                                  onTap: () => Navigator.pushNamed(context, '/shipping-policy'),
                                ),
                                _buildMenuTile(
                                  icon: Icons.policy_outlined,
                                  title: 'Cancellation & Refunds',
                                  subtitle: 'Return policy',
                                  isDark: isDark,
                                  onTap: () => Navigator.pushNamed(context, '/cancellation-refund'),
                                ),
                                _buildMenuTile(
                                  icon: Icons.support_agent_outlined,
                                  title: 'Contact Us',
                                  subtitle: 'Get help',
                                  isDark: isDark,
                                  color: Colors.blue,
                                  onTap: () => Navigator.pushNamed(context, '/contact-us'),
                                ),

                                const SizedBox(height: 20),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red, Colors.red.shade700],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _logout(isDark),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.logout_rounded,
                                                color: Colors.white, size: 18),
                                            SizedBox(width: 10),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Bottom Banner Ad
                                const SizedBox(height: 16),
                                _buildAdBanner(_bannerAd, _isBannerAdReady, isDark),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Enhanced Toast - Wrapped in SafeArea
            if (_showToast)
              SafeArea(
                bottom: false, // Only apply top safe area
                child: SlideTransition(
                  position: _toastSlideAnimation,
                  child: FadeTransition(
                    opacity: _toastFadeAnimation,
                    child: ScaleTransition(
                      scale: _toastScaleAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_toastColor, _toastColor.withOpacity(0.9)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _toastColor.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_toastIcon, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _toastMessage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }
}

// ✅✅✅ START: NEW HELPER CLASS ✅✅✅
// This delegate is required to make a custom widget
// behave as a persistent (sticky) header.
class _StickyProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyProfileHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_StickyProfileHeaderDelegate oldDelegate) {
    // Rebuild only if the child or height actually changes
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
