// lib/screens/user/main_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_entry_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/web_url_helper.dart';
import 'home/home_screen.dart';
import 'categories/categories_screen.dart';  // ✅ NEW
import 'shop/shop_screen.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';
import '../chat/ai_chat_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final String? searchQuery;
  final String? categoryId;
  final String? categoryName;

  const MainScreen({
    Key? key,
    this.initialIndex = 0,
    this.searchQuery,
    this.categoryId,
    this.categoryName,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _currentIndex;
  late AnimationController _bottomBarAnimationController;
  late AnimationController _fadeAnimationController;
  // --- NEW ---
  late AnimationController _fabPulseController;
  // --- END NEW ---
  late Animation<Offset> _bottomBarSlideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;
  DateTime? _lastBackPressTime;
  
  // Scroll-aware bottom nav visibility
  bool _isBottomNavVisible = true;
  double _lastScrollPosition = 0;
  static const double _scrollThreshold = 25.0; // Increased for smoother response

  final Map<int, AnimationController> _iconControllers = {};
  final Map<int, AnimationController> _iconBounceControllers = {};

  late ShopEntryProvider _shopEntry;
  int _lastShopTabRequest = 0;

  List<Widget> _buildScreens() => [
        const HomeScreen(),
        Consumer<ShopEntryProvider>(
          builder: (context, se, _) {
            final cid = widget.categoryId ?? se.categoryId;
            final cname = widget.categoryName ?? se.categoryName;
            return ShopScreen(
              categoryId: cid,
              categoryName: cname,
              searchQuery: widget.searchQuery,
            );
          },
        ),
        const CategoriesScreen(),
        const CartScreen(),
        const ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _shopEntry = context.read<ShopEntryProvider>();
    _lastShopTabRequest = _shopEntry.shopTabRequestCount;
    _shopEntry.addListener(_onShopEntryChanged);

    if (widget.categoryId != null || widget.categoryName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _shopEntry.openShopWithCategory(
          categoryId: widget.categoryId,
          categoryName: widget.categoryName,
        );
      });
    }

    WidgetsBinding.instance.addObserver(this);

    _bottomBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // --- NEW: Initialize FAB Pulse Controller ---
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // --- END NEW ---

    _bottomBarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _bottomBarAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Update loop to 5 items
    for (int i = 0; i < 5; i++) {
      _iconControllers[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _iconBounceControllers[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _bottomBarAnimationController.forward();
        _fadeAnimationController.forward();
      }
    });

    _initializeData();

    // --- NEW: Start FAB pulse if on home screen ---
    if (_currentIndex == 0) {
      _fabPulseController.repeat(reverse: true);
    }
    // --- END NEW ---

    // ✅ Ensure URL is correct on load (e.g. if redirected from login)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWebUrl(_currentIndex);
      });
    }
  }

  Future<void> _initializeData() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final wishlistProvider =
            Provider.of<WishlistProvider>(context, listen: false);

        cartProvider.loadCart();
        wishlistProvider.loadWishlist();
      } catch (e) {
        debugPrint('❌ Error initializing data: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _refreshCurrentScreen();
    }
  }

  void _refreshCurrentScreen() {
    if (!mounted) return;

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final wishlistProvider =
          Provider.of<WishlistProvider>(context, listen: false);

      cartProvider.loadCart();
      wishlistProvider.loadWishlist();
    } catch (e) {
      debugPrint('⚠️ Error refreshing data: $e');
    }
  }

  // ✅ Helper: Get route path for each tab index
  String _getRouteForIndex(int index) {
    switch (index) {
      case 0: return '/home';
      case 1: return '/shop';
      case 2: return '/categories';
      case 3: return '/cart';
      case 4: return '/profile';
      default: return '/home';
    }
  }

  // ✅ Update browser URL on web without triggering navigation
  void _updateWebUrl(int index) {
    updateWebUrl(_getRouteForIndex(index));
  }

  Future<void> _onTabTapped(int index) async {
    if (_isNavigating || _currentIndex == index) return;

    HapticFeedback.mediumImpact();

    // Icon bounce animation
    _iconBounceControllers[index]?.forward().then((_) {
      _iconBounceControllers[index]?.reverse();
    });

    setState(() => _isNavigating = true);

    // Fade out
    await _fadeAnimationController.reverse();

    if (mounted) {
      setState(() => _currentIndex = index);
    }

    // ✅ Update browser URL on web (without full navigation/rebuild)
    if (kIsWeb && mounted) {
      _updateWebUrl(index);
    }

    //
    // --- MODIFICATION: Start/Stop FAB Pulse ---
    //
    if (_currentIndex == 0) {
      _fabPulseController.repeat(reverse: true);
    } else {
      _fabPulseController.stop();
      _fabPulseController.value = 0.0; // Reset animation
    }
    // --- END MODIFICATION ---

    // Fade in
    await _fadeAnimationController.forward();

    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  Future<void> _handleBackNavigation() async {
    if (_currentIndex != 0) {
      await _onTabTapped(0);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      _showSnackBar('Press back again to exit', isError: false);
      return;
    }

    SystemNavigator.pop();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onShopEntryChanged() {
    if (!mounted) return;
    final n = _shopEntry.shopTabRequestCount;
    if (n > _lastShopTabRequest) {
      _lastShopTabRequest = n;
      setState(() => _currentIndex = 1);
    }
  }

  @override
  void dispose() {
    _shopEntry.removeListener(_onShopEntryChanged);
    WidgetsBinding.instance.removeObserver(this);
    _bottomBarAnimationController.dispose();
    _fadeAnimationController.dispose();
    // --- NEW ---
    _fabPulseController.dispose();
    // --- END NEW ---
    for (var controller in _iconControllers.values) {
      controller.dispose();
    }
    for (var controller in _iconBounceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevent keyboard from pushing layout up
        extendBody: true, // Key: Body extends behind nav, prevents layout thrashing
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: IndexedStack(
              index: _currentIndex,
              children: _buildScreens(),
            ),
          ),
        ),
        bottomNavigationBar: AnimatedSlide(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  opacity: _isBottomNavVisible ? 1.0 : 0.0,
                  child: _buildBottomNavigationBar(isDark),
                ),
              ),
      ),
    );
  }

  // Handle scroll notifications to show/hide bottom nav
  bool _handleScrollNotification(ScrollNotification notification) {
    // Ignore horizontal scrolls (like carousel PageView)
    if (notification.metrics.axis == Axis.horizontal) {
      return false;
    }
    
    if (notification is ScrollUpdateNotification) {
      final currentPosition = notification.metrics.pixels;
      final delta = currentPosition - _lastScrollPosition;
      
      // Only respond if we've scrolled more than threshold
      if (delta.abs() > _scrollThreshold) {
        if (delta > 0 && _isBottomNavVisible) {
          // Scrolling down (content moving up) - hide nav
          setState(() => _isBottomNavVisible = false);
        } else if (delta < 0 && !_isBottomNavVisible) {
          // Scrolling up (content moving down) - show nav
          setState(() => _isBottomNavVisible = true);
        }
        _lastScrollPosition = currentPosition;
      }
    }
    
    // If at top of scroll, always show nav
    if (notification is ScrollEndNotification) {
      if (notification.metrics.pixels <= 0) {
        setState(() => _isBottomNavVisible = true);
      }
    }
    
    return false; // Don't absorb the notification
  }

  //
  // --- NEW WIDGET: Advanced, Rectangular, Pulsing AI FAB ---
  //
  Widget _buildAIFab(bool isDark) {
    final color = isDark ? AppColors.primaryLight : AppColors.primary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Slide and fade animation
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1.5, 1.5), // From off-screen bottom-right
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _currentIndex == 0
          // Show FAB only on Home Screen (index 0)
          ? AnimatedBuilder(
              key: const ValueKey('fab'),
              animation: _fabPulseController,
              builder: (context, child) {
                final pulseValue = _fabPulseController.value; // 0.0 to 1.0
                final glow = (pulseValue * 8.0); // 0 to 8 blur
                final scale = 1.0 - (pulseValue * 0.05); // Subtle "breathing" in
                
                // Container wrapper for the pulsing shadow
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3 + (pulseValue * 0.15)), // Pulsing opacity
                        blurRadius: 12 + glow, // Pulsing glow
                        spreadRadius: pulseValue * 2, // Pulsing spread
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: scale, // Breathing scale
                    child: FloatingActionButton.extended(
                      heroTag: 'ai-fab',
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        // Navigate to AIChatScreen as a new page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AIChatScreen()),
                        );
                      },
                      elevation: 0, // Shadow is handled by the container
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)), // Rectangular
                      backgroundColor: color, // Matching green theme
                      icon: const FaIcon(
                        FontAwesomeIcons.robot,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Chat Bot',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          // Use an empty SizedBox (with a key) for the "off" state
          : const SizedBox(key: ValueKey('empty-fab')),
    );
  }
  // --- END NEW WIDGET ---

  Widget _buildBottomNavigationBar(bool isDark) {
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    // Removed SlideTransition - using AnimatedSlide wrapper instead
    return Container(
        // Flat rectangular design - no margin, no rounded corners
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
              spreadRadius: 0,
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 0 - Home (Material Icon)
                  _buildMaterialNavItem(
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    label: 'Home',
                    index: 0,
                    isDark: isDark,
                  ),
                  // 1 - Shop (Material Icon)
                  _buildMaterialNavItem(
                    activeIcon: Icons.store_rounded,
                    inactiveIcon: Icons.store_outlined,
                    label: 'Shop',
                    index: 1,
                    isDark: isDark,
                  ),
                  // 2 - Category (CENTER - Special elevated button)
                  Expanded(
                    child: _buildCenterNavItem(isDark),
                  ),
                  // 3 - Cart (Material Icon)
                  _buildMaterialNavItem(
                    activeIcon: Icons.shopping_cart_rounded,
                    inactiveIcon: Icons.shopping_cart_outlined,
                    label: 'Cart',
                    index: 3,
                    showBadge: true,
                    badgeProvider: 'cart',
                    isDark: isDark,
                  ),
                  // 4 - Profile (Material Icon)
                  _buildMaterialNavItem(
                    activeIcon: Icons.person_rounded,
                    inactiveIcon: Icons.person_outline_rounded,
                    label: 'Profile',
                    index: 4,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  // Premium elevated center button for Categories
  Widget _buildCenterNavItem(bool isDark) {
    final isActive = _currentIndex == 2;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _iconBounceControllers[2]!,
        builder: (context, child) {
          final bounceValue = _iconBounceControllers[2]!.value;
          final scale = 1.0 + (bounceValue * 0.12);
          
          return Center(
            child: Transform.scale(
              scale: scale,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, glowValue, child) {
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isActive
                            ? [
                                primaryColor,
                                primaryColor.withOpacity(0.85),
                              ]
                            : [
                                isDark ? const Color(0xFF2D2D2D) : Colors.grey[100]!,
                                isDark ? const Color(0xFF252525) : Colors.grey[50]!,
                              ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive 
                            ? primaryColor.withOpacity(0.4 + (glowValue * 0.2))
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isActive ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        // Primary shadow
                        BoxShadow(
                          color: isActive 
                              ? primaryColor.withOpacity(0.35 + (glowValue * 0.15))
                              : Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                          blurRadius: isActive ? 18 + (glowValue * 6) : 10,
                          offset: const Offset(0, 4),
                          spreadRadius: isActive ? 1 + (glowValue * 2) : 0,
                        ),
                        // Inner highlight for depth
                        if (!isDark && !isActive)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.9),
                            blurRadius: 0,
                            offset: const Offset(-1, -1),
                          ),
                        // Ambient glow when active
                        if (isActive)
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 24,
                            spreadRadius: 0,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? Icons.grid_view_rounded : Icons.grid_view,
                          color: isActive 
                              ? Colors.white 
                              : (isDark ? Colors.white70 : Colors.black87),
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: isActive 
                                ? Colors.white.withOpacity(0.95)
                                : (isDark ? Colors.white70 : Colors.black87),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // Modern Material Icon nav item with outlined/filled states
  Widget _buildMaterialNavItem({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required int index,
    required bool isDark,
    bool showBadge = false,
    String? badgeProvider,
  }) {
    final isActive = _currentIndex == index;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _iconBounceControllers[index]!,
          builder: (context, child) {
            final bounceValue = _iconBounceControllers[index]!.value;
            final scale = 1.0 + (bounceValue * 0.12);

            return Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryColor.withOpacity(0.18),
                                    primaryColor.withOpacity(0.08),
                                  ],
                                )
                              : null,
                          color: isActive ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: isActive
                              ? Border.all(
                                  color: primaryColor.withOpacity(0.15),
                                  width: 1,
                                )
                              : null,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isActive ? activeIcon : inactiveIcon,
                          color: isActive
                              ? primaryColor
                              : (isDark ? Colors.white70 : Colors.black87),
                          size: 23,
                        ),
                      ),
                      if (showBadge && badgeProvider != null)
                        _buildBadge(badgeProvider),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: isActive ? 11 : 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? primaryColor
                          : (isDark ? Colors.white70 : Colors.black87),
                      letterSpacing: 0.2,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
    bool showBadge = false,
    String? badgeProvider,
    bool isSpecial = false,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _iconBounceControllers[index]!,
          builder: (context, child) {
            final bounceValue = _iconBounceControllers[index]!.value;
            final scale = 1.0 + (bounceValue * 0.2);

            return Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: isActive && isSpecial
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.purple.shade600,
                                    Colors.blue.shade600,
                                  ],
                                )
                              : null,
                          color: isActive && !isSpecial
                              ? (isDark
                                  ? AppColors.primaryLight.withOpacity(0.2)
                                  : AppColors.primary.withOpacity(0.15))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: (isSpecial
                                            ? Colors.purple
                                            : (isDark
                                                ? AppColors.primaryLight
                                                : AppColors.primary))
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: FaIcon(
                          icon,
                          color: isActive
                              ? (isSpecial
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.primaryLight
                                      : AppColors.primary))
                              : (isDark ? Colors.white70 : Colors.black87),
                          size: 20,
                        ),
                      ),
                      if (showBadge && badgeProvider != null)
                        _buildBadge(badgeProvider),
                      if (isActive && isSpecial)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: isActive ? 11 : 10,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive
                          ? (isSpecial
                              ? Colors.purple.shade600
                              : (isDark
                                  ? AppColors.primaryLight
                                  : AppColors.primary))
                          : (isDark ? Colors.white70 : Colors.black87),
                      letterSpacing: 0.2,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBadge(String providerType) {
    if (providerType == 'cart') {
      return Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final count = cartProvider.itemCount;
          if (count == 0) return const SizedBox.shrink();

          return _buildBadgeContainer(count);
        },
      );
    } else if (providerType == 'wishlist') {
      return Consumer<WishlistProvider>(
        builder: (context, wishlistProvider, child) {
          final count = wishlistProvider.itemCount;
          if (count == 0) return const SizedBox.shrink();

          return _buildBadgeContainer(count);
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBadgeContainer(int count) {
    return Positioned(
      right: 0,
      top: -2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade600,
                    Colors.green.shade500,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}