// lib/screens/user/home/widgets/featured_products.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../app/routes.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../shop/widgets/product_card.dart';

class FeaturedProducts extends StatefulWidget {
  const FeaturedProducts({Key? key}) : super(key: key);

  @override
  State<FeaturedProducts> createState() => _FeaturedProductsState();
}

class _FeaturedProductsState extends State<FeaturedProducts>
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
        final featuredProducts = productProvider.products
            .where((p) => p.isFeatured && p.isActive)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (featuredProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: _buildSectionHeader(
                context: context,
                title: 'Featured For You',
                subtitle: 'Handpicked items just for you',
                totalProducts: featuredProducts.length,
                isDark: isDark,
                onSeeAll: () {
                  Navigator.pushNamed(context, AppRoutes.shop, arguments: {'isFeatured': true});
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 360, // Height to prevent overflow
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: math.min(featuredProducts.length, 8), // Limit to 8
                itemBuilder: (context, index) {
                  final product = featuredProducts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: SizedBox(
                      width: 180, // Grid-style card width
                      child: ProductCard(
                        product: product,
                        isGridView: true,
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
                          AppColors.primaryLight.withOpacity(0.5),
                        ]
                      : [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.5),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.primaryLight : AppColors.primary)
                        .withOpacity(0.4 + (_shimmerController.value * 0.2)),
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
                                AppColors.primaryLight.withOpacity(0.2),
                                AppColors.primaryLight.withValues(alpha: 0.1),
                              ]
                            : [
                                AppColors.primary.withOpacity(0.15),
                                AppColors.primary.withOpacity(0.08),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? AppColors.primaryLight.withOpacity(0.3)
                            : AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      '${totalProducts > 8 ? '8+' : totalProducts}',
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