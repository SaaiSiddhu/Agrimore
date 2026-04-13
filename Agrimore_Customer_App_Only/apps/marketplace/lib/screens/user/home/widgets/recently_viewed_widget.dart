import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/product_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../app/routes.dart';
import '../../../../providers/theme_provider.dart';

/// Keep Shopping For / Recently Viewed section - Compact and Enhanced
class RecentlyViewedWidget extends StatelessWidget {
  const RecentlyViewedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final recentlyViewed = productProvider.recentlyViewedProducts;

        if (recentlyViewed.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    // Icon with gradient background
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withOpacity(0.2),
                            accentColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title and count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Keep Shopping',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${recentlyViewed.length > 8 ? '8+' : recentlyViewed.length}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Continue where you left off',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Compact Product Cards - Horizontal scroll
              SizedBox(
                height: 180, // More compact height
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: recentlyViewed.length > 8 ? 8 : recentlyViewed.length,
                  itemBuilder: (context, index) {
                    final product = recentlyViewed[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCompactProductCard(
                        context,
                        product,
                        isDark,
                        accentColor,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactProductCard(
    BuildContext context,
    dynamic product,
    bool isDark,
    Color accentColor,
  ) {
    // Use salePrice and originalPrice (correct field names)
    final salePrice = product.salePrice ?? 0.0;
    final originalPrice = product.originalPrice ?? 0.0;
    final hasDiscount = originalPrice > 0 && salePrice < originalPrice;
    final displayPrice = salePrice;
    final discountPercent = hasDiscount
        ? (((originalPrice - salePrice) / originalPrice) * 100).round()
        : 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(
          context,
          AppRoutes.productDetails,
          arguments: product.id,
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with discount badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      product.images.isNotEmpty ? product.images.first : '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                // Discount badge
                if (hasDiscount)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-$discountPercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Product info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '₹${displayPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 4),
                          Text(
                            '₹${originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}