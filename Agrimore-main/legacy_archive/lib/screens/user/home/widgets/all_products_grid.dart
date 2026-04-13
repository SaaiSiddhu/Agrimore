import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../shop/widgets/product_card.dart'; // <-- IMPORTED YOUR PRODUCT CARD

class AllProductsGrid extends StatefulWidget {
  const AllProductsGrid({Key? key}) : super(key: key);

  @override
  State<AllProductsGrid> createState() => _AllProductsGridState();
}

class _AllProductsGridState extends State<AllProductsGrid>
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.products;

        if (products.isEmpty) {
          return const SliverToBoxAdapter(
            child: SizedBox.shrink(),
          );
        }

        // --- NEW: Limit to 8 products as requested ---
        final displayProducts = products.take(8).toList();

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header (from your screenshot)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), // Added padding consistency
                child: _buildSectionHeader(context, products.length, isDark),
              ),
              const SizedBox(height: 16),

              // 2xN Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    // --- This aspect ratio matches your ProductCard ---
                    childAspectRatio: 0.5, 
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: displayProducts.length,
                  itemBuilder: (context, index) {
                    // --- NEW: Use the imported ProductCard ---
                    return ProductCard(
                      product: displayProducts[index],
                      isGridView: true,
                    );
                  },
                ),
              ),

              // --- NEW: "View More" Button ---
              if (products.length > 8)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: () {
                         HapticFeedback.lightImpact();
                         Navigator.pushNamed(context, AppRoutes.shop);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                        side: BorderSide(
                          color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View More Products',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- This is the new header from your screenshot ---
  Widget _buildSectionHeader(BuildContext context, int totalProducts, bool isDark) {
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
                    'All Products',
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
                                AppColors.primary.withValues(alpha: 0.08),
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
                      '$totalProducts',
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
                'Discover our entire collection',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        // Use the "See All" from the other headers for consistency
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, AppRoutes.shop);
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