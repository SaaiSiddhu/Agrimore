import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class EmptyCart extends StatefulWidget {
  final VoidCallback? onStartShopping;

  const EmptyCart({
    Key? key,
    this.onStartShopping,
  }) : super(key: key);

  @override
  State<EmptyCart> createState() => _EmptyCartState();
}

class _EmptyCartState extends State<EmptyCart> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    
    // Bounce animation for cart icon
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Fade animation for content
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Floating animation
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Start animations
    _bounceController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedCartIcon(),
              const SizedBox(height: 40),
              _buildTitle(),
              const SizedBox(height: 16),
              _buildDescription(),
              const SizedBox(height: 40),
              _buildActionButtons(),
              const SizedBox(height: 24),
              _buildQuickLinks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCartIcon() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: ScaleTransition(
            scale: _bounceAnimation,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ),
                  // Inner container
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.2),
                          AppColors.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
                  // Floating sparkles
                  _buildSparkle(top: 20, left: 20, delay: 0),
                  _buildSparkle(top: 40, right: 30, delay: 300),
                  _buildSparkle(bottom: 30, left: 40, delay: 600),
                  _buildSparkle(bottom: 20, right: 20, delay: 900),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSparkle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required int delay,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1500),
        builder: (context, value, child) {
          return Opacity(
            opacity: (value * 2 - 1).abs(),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Your Cart is Empty',
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      children: [
        Text(
          'Looks like you haven\'t added anything yet',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Start exploring and add your favorite products!',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (widget.onStartShopping == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onStartShopping?.call();
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Start Shopping',
                      style: AppTextStyles.buttonLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLinks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            icon: Icons.local_offer_outlined,
            text: 'Check out our latest deals',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.favorite_outline,
            text: 'Save items to wishlist for later',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            icon: Icons.notifications_outlined,
            text: 'Enable notifications for exclusive offers',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
