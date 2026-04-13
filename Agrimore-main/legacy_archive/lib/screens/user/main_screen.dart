// lib/screens/user/main_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/themes/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/theme_provider.dart';
import 'home/home_screen.dart';
import 'shop/shop_screen.dart';
import 'cart/cart_screen.dart';
import 'wishlist/wishlist_screen.dart';
import 'profile/profile_screen.dart';
import '../chat/ai_chat_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    Key? key,
    this.initialIndex = 0,
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

  final Map<int, AnimationController> _iconControllers = {};
  final Map<int, AnimationController> _iconBounceControllers = {};

  //
  // --- MODIFICATION: Re-ordered screens ---
  //
  // All screens stored (Bot screen is removed from here)
  final List<Widget> _screens = const [
    HomeScreen(),
    ShopScreen(),
    CartScreen(), // <-- Swapped
    WishlistScreen(), // <-- Swapped
    ProfileScreen(),
  ];
  // --- END MODIFICATION ---

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

  @override
  void dispose() {
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
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
        //
        // --- MODIFICATION: ADDED FLOATING ACTION BUTTON ---
        //
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: _buildAIFab(isDark),
        //
        // --- END MODIFICATION ---
        //
        bottomNavigationBar: _buildBottomNavigationBar(isDark),
      ),
    );
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
    return SlideTransition(
      position: _bottomBarSlideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, -8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E).withOpacity(0.95)
                    : Colors.white.withOpacity(0.95),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 62,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      //
                      // --- MODIFICATION: Re-ordered Nav Items ---
                      //
                      _buildNavItem(
                        icon: FontAwesomeIcons.house,
                        label: 'Home',
                        index: 0,
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        icon: FontAwesomeIcons.store,
                        label: 'Shop',
                        index: 1,
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        icon: FontAwesomeIcons.cartShopping, // <-- Swapped
                        label: 'Cart',
                        index: 2, // <-- Swapped
                        showBadge: true,
                        badgeProvider: 'cart',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        icon: FontAwesomeIcons.heart, // <-- Swapped
                        label: 'Wishlist',
                        index: 3, // <-- Swapped
                        showBadge: true,
                        badgeProvider: 'wishlist',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        icon: FontAwesomeIcons.user,
                        label: 'Profile',
                        index: 4,
                        isDark: isDark,
                      ),
                      //
                      // --- END MODIFICATION ---
                      //
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                              : (isDark ? Colors.grey[500] : Colors.grey[500]),
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
                          : (isDark ? Colors.grey[500] : Colors.grey[500]),
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