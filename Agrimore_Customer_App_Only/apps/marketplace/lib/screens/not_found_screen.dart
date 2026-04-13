// lib/screens/not_found_screen.dart
// Premium 404 Page with Modern UI, Glassmorphism, and Trending Products

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import '../app/routes.dart';
import 'user/home/widgets/product_card_compact.dart';

class NotFoundScreen extends StatefulWidget {
  const NotFoundScreen({super.key});

  @override
  State<NotFoundScreen> createState() => _NotFoundScreenState();
}

class _NotFoundScreenState extends State<NotFoundScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Main entrance animation
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic));

    // Floating animation for the astronaut/icon
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.03),
      end: const Offset(0, 0.03),
    ).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    // Shimmer effect controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(isDark, size),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.06),
                    
                    // Premium 404 Card
                    _buildPremium404Card(isDark),
                    
                    const SizedBox(height: 40),
                    
                    // Action buttons
                    _buildActionButtons(isDark),
                    
                    const SizedBox(height: 50),
                    
                    // Trending Products
                    _buildTrendingSection(isDark),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark, Size size) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A2E)]
                  : [const Color(0xFFF5F7FA), const Color(0xFFE8EDF5)],
            ),
          ),
        ),
        
        // Floating orbs
        Positioned(
          top: -50,
          right: -50,
          child: _buildOrb(150, AppColors.primary.withOpacity(0.15)),
        ),
        Positioned(
          bottom: size.height * 0.3,
          left: -80,
          child: _buildOrb(200, AppColors.primaryLight.withOpacity(0.1)),
        ),
        Positioned(
          top: size.height * 0.4,
          right: -30,
          child: _buildOrb(100, Colors.purple.withOpacity(0.08)),
        ),
      ],
    );
  }

  Widget _buildOrb(double size, Color color) {
    return SlideTransition(
      position: _floatAnimation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }

  Widget _buildPremium404Card(bool isDark) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Floating astronaut icon
                  SlideTransition(
                    position: _floatAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primaryLight.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing rings
                            ...List.generate(3, (index) {
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.2),
                                duration: Duration(milliseconds: 1500 + (index * 300)),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Container(
                                width: 65 + (index * 18) * value,
                                height: 65 + (index * 18) * value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.15 - (index * 0.04)),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                            Icon(
                              Icons.explore_off_rounded,
                              size: 40,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Animated 404 text with shimmer
                  _buildShimmer404(isDark),
                  
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'Lost in Space',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    'The page you\'re looking for has drifted\ninto another galaxy. Let\'s bring you back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer404(bool isDark) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
                Colors.purple.shade400,
                AppColors.primaryLight,
                AppColors.primary,
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              transform: GradientRotation(_shimmerController.value * 2 * pi),
            ).createShader(bounds);
          },
          child: Text(
            '404',
            style: TextStyle(
              fontSize: 70,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -4,
              height: 1,
              shadows: [
                Shadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          // Go Home - Primary button
          Expanded(
            child: _buildPremiumButton(
              icon: Icons.home_rounded,
              label: 'Go Home',
              isPrimary: true,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.main,
                  (route) => false,
                );
              },
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Browse - Secondary button
          Expanded(
            child: _buildPremiumButton(
              icon: Icons.shopping_bag_rounded,
              label: 'Shop Now',
              isPrimary: false,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.shop);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary 
                ? null 
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
            border: isPrimary 
                ? null 
                : Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSection(bool isDark) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final allProducts = productProvider.products
            .where((p) => p.isActive)
            .toList();
        
        if (allProducts.isEmpty) return const SizedBox.shrink();
        
        final random = Random();
        allProducts.shuffle(random);
        final trendingProducts = allProducts.take(6).toList();

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header with gradient accent
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trending Now 🔥',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'While you\'re here, check these out!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Product grid with staggered animation
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.50, // Fixed overflow
                ),
                itemCount: trendingProducts.length,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 400 + (index * 100)),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: child,
                        ),
                      );
                    },
                    child: ProductCardCompact(
                      product: trendingProducts[index],
                      categoryName: 'Trending',
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
