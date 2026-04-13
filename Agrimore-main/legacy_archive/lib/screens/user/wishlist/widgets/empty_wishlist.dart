import 'package:flutter/material.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../app/routes.dart';

class EmptyWishlist extends StatelessWidget {
  const EmptyWishlist({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 32.0 : 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Heart Icon with Pulse Effect
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: _buildHeartContainer(isMobile),
                );
              },
            ),

            SizedBox(height: isMobile ? 32 : 48),

            // Title with Fade Animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    'Your Wishlist is Empty',
                    style: isMobile
                        ? AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          )
                        : AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Description with Slide Animation
            TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: const Offset(0, 20),
                end: Offset.zero,
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: value,
                  child: Opacity(
                    opacity: (20 - value.dy) / 20,
                    child: Text(
                      'Save your favorite items here so you don\'t lose them!',
                      style: isMobile
                          ? AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            )
                          : AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: isMobile ? 40 : 56),

            // Browse Button with Scale Animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: _buildBrowseButton(context, isMobile),
                );
              },
            ),

            SizedBox(height: isMobile ? 24 : 32),

            // Additional Info Cards
            if (!isMobile) _buildInfoCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartContainer(bool isMobile) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Circle with Pulse Animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 1.2),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Container(
              width: (isMobile ? 140 : 180) * value,
              height: (isMobile ? 140 : 180) * value,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05 / value),
                shape: BoxShape.circle,
              ),
            );
          },
          onEnd: () {},
        ),

        // Main Container
        Container(
          width: isMobile ? 140 : 180,
          height: isMobile ? 140 : 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.error.withOpacity(0.15),
                AppColors.error.withOpacity(0.08),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.favorite_border,
            size: isMobile ? 70 : 90,
            color: AppColors.error.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseButton(BuildContext context, bool isMobile) {
    return ElevatedButton.icon(
      onPressed: () {
        AppRoutes.navigateTo(context, AppRoutes.shop);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 32 : 48,
          vertical: isMobile ? 16 : 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
        ),
        elevation: 0,
        shadowColor: AppColors.primary.withOpacity(0.3),
      ),
      icon: Icon(
        Icons.shopping_bag_outlined,
        size: isMobile ? 20 : 24,
      ),
      label: Text(
        'Browse Products',
        style: TextStyle(
          fontSize: isMobile ? 16 : 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildInfoCard(
            icon: Icons.favorite_outline,
            title: 'Save Items',
            description: 'Keep track of products you love',
            color: AppColors.error,
          ),
          const SizedBox(width: 20),
          _buildInfoCard(
            icon: Icons.notifications_outlined,
            title: 'Get Notified',
            description: 'Receive alerts on price drops',
            color: AppColors.primary,
          ),
          const SizedBox(width: 20),
          _buildInfoCard(
            icon: Icons.shopping_cart_outlined,
            title: 'Quick Buy',
            description: 'Move items to cart easily',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
