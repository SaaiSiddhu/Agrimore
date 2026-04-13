// lib/screens/user/home/widgets/recently_viewed_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../providers/product_provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../providers/theme_provider.dart'; // Added

class RecentlyViewedWidget extends StatefulWidget {
  const RecentlyViewedWidget({Key? key}) : super(key: key);

  @override
  State<RecentlyViewedWidget> createState() => _RecentlyViewedWidgetState();
}

class _RecentlyViewedWidgetState extends State<RecentlyViewedWidget>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final recentlyViewed = productProvider.recentlyViewedProducts;

        if (recentlyViewed.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: _buildSectionHeader(
                context: context,
                title: 'Keep Shopping For',
                subtitle: 'Continue where you left off',
                totalProducts: recentlyViewed.length,
                isDark: isDark,
                onSeeAll: () {
                  Navigator.pushNamed(context, AppRoutes.recentlyViewed);
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220, // This height is correct for this card
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recentlyViewed.length > 10 ? 10 : recentlyViewed.length,
                itemBuilder: (context, index) {
                  final product = recentlyViewed[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(
                        context,
                        AppRoutes.productDetail,
                        arguments: product.id,
                      );
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Color(0xFF1E1E1E) : Colors.white, // Dark mode color
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06), // Dark mode shadow
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: product.images.first,
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? Colors.grey[800] : AppColors.lightGrey,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDark ? Colors.grey[800] : AppColors.lightGrey,
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 40,
                                  color: isDark ? Colors.grey[600] : AppColors.grey,
                                ),
                              ),
                            ),
                          ),
                          // Product Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      color: isDark ? Colors.white : Colors.black, // Dark mode text
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '₹${product.price.toStringAsFixed(0)}',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                      fontWeight: FontWeight.bold,
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
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- REUSED HEADER from all_products_grid.dart ---
  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int totalProducts,
    required bool isDark,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              width: 5,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.primaryLight,
                          AppColors.primaryLight.withValues(alpha: 0.5),
                        ]
                      : [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.5),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.primaryLight : AppColors.primary)
                        .withValues(alpha: 0.4 + (_shimmerController.value * 0.2)),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.primaryLight.withValues(alpha: 0.2),
                                AppColors.primaryLight.withValues(alpha: 0.1),
                              ]
                            : [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.primary.withValues(alpha: 0.06),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? AppColors.primaryLight.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${totalProducts > 10 ? '10+' : totalProducts}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onSeeAll();
          },
          style: TextButton.styleFrom(
            foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: const [
              Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 12),
            ],
          ),
        ),
      ],
    );
  }
}