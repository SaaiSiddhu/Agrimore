import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/theme_provider.dart';

class HomeAppBar extends StatefulWidget {
  const HomeAppBar({Key? key}) : super(key: key);

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _timeGreeting = '';
  String _dailyQuote = '';
  int _notificationCount = 0;
  late TextEditingController _searchController;
  
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _setupAnimations();
    _updateTimeGreeting();
    _loadNotificationCount();

    Future.delayed(const Duration(seconds: 30), _loadNotificationCount);
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
  }

  void _safeSyncState(VoidCallback callback) {
    if (_isMounted && mounted) {
      try {
        setState(callback);
      } catch (e) {
        debugPrint('⚠️ Error in setState: $e');
      }
    }
  }

  void _updateTimeGreeting() {
    final hour = DateTime.now().hour;
    _safeSyncState(() {
      if (hour < 6) {
        _timeGreeting = '🌙 Good Night';
        _dailyQuote = 'Rest well, tomorrow brings new opportunities';
      } else if (hour < 12) {
        _timeGreeting = '☀️ Good Morning';
        _dailyQuote = 'Rise and shine! Start your day with purpose';
      } else if (hour < 15) {
        _timeGreeting = '🌤️ Good Afternoon';
        _dailyQuote = 'Keep pushing! You\'re doing great';
      } else if (hour < 18) {
        _timeGreeting = '🌅 Late Afternoon';
        _dailyQuote = 'The day is still young, make it count';
      } else if (hour < 21) {
        _timeGreeting = '🌆 Good Evening';
        _dailyQuote = 'Time to wind down and reflect';
      } else {
        _timeGreeting = '🌙 Good Night';
        _dailyQuote = 'Sweet dreams await you';
      }
    });
  }

  Future<void> _loadNotificationCount() async {
    if (!_isMounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _isMounted) {
        final notifSnapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('read', isEqualTo: false)
            .count()
            .get();

        if (_isMounted && mounted) {
          _safeSyncState(() {
            _notificationCount = notifSnapshot.count ?? 0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('⚠️ Error loading notifications: $e');
      }
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF2D7D3C))
                    .withOpacity(isDark ? 0.5 : 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isDark ? 0.05 : 0.08,
                    child: CustomPaint(painter: PremiumPatternPainter()),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        children: [
                          // Row 1: Logo, Greeting, Icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.25),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                            BoxShadow(
                                              color: (isDark
                                                      ? AppColors.primaryLight
                                                      : const Color(0xFF2D7D3C))
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.asset(
                                            'assets/icons/logo_icon.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.grey[800]
                                                      : Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.eco_rounded,
                                                  color: isDark
                                                      ? AppColors.primaryLight
                                                      : const Color(0xFF2D7D3C),
                                                  size: 24,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _timeGreeting,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              String displayName = 'Welcome';
                                              if (snapshot.hasData && snapshot.data != null) {
                                                try {
                                                  final userData = snapshot.data!.data() as Map;
                                                  final firstName =
                                                      (userData['name'] as String?)?.split(' ').first ??
                                                          'User';
                                                  displayName = firstName;
                                                } catch (e) {
                                                  displayName = 'Welcome';
                                                }
                                              }

                                              return Text(
                                                displayName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildIconButton(
                                    context,
                                    icon: Icons.notifications_none_rounded,
                                    badge: _notificationCount,
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pushNamed(context, AppRoutes.notifications);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Consumer<CartProvider>(
                                    builder: (context, cartProvider, _) {
                                      return _buildIconButton(
                                        context,
                                        icon: Icons.shopping_bag_outlined,
                                        badge: cartProvider.itemCount,
                                        isDark: isDark,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.pushNamed(context, AppRoutes.cart);
                                        },
                                        badgeColor: Colors.orange,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildSearchBar(isDark),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(isDark ? 0.15 : 0.25),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 12,
                                  color: Colors.yellow[isDark ? 400 : 300],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _dailyQuote,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(isDark ? 0.9 : 0.85),
                                      fontStyle: FontStyle.italic,
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.search_rounded,
              color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.search);
              },
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Find amazing products...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required int badge,
    required bool isDark,
    required VoidCallback onTap,
    Color badgeColor = Colors.red,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isDark ? 0.15 : 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.2 : 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (badge > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [badgeColor.withOpacity(0.9), badgeColor],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withOpacity(0.7),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < size.width; i += 40) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }

    for (int i = 0; i < size.height; i += 40) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.25 + i * 0.3), size.height * 0.5),
        60 + i * 15,
        circlePaint,
      );
    }

    final accentPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (int i = 0; i < (size.width + size.height); i += 80) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble() - size.height, size.height),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(PremiumPatternPainter oldDelegate) => false;
}
