// lib/screens/user/home/widgets/product_section_widget.dart
// 3-column fixed grid product section (Blinkit style)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../app/routes.dart';
import '../../../../providers/theme_provider.dart';
import 'product_card_compact.dart';

class ProductSectionWidget extends StatelessWidget {
  final String sectionTitle;
  final List<ProductModel> products;
  final String? categoryId;
  final VoidCallback? onSeeAll;
  final bool showSeeAllFooter;
  final int maxProducts;

  const ProductSectionWidget({
    super.key,
    required this.sectionTitle,
    required this.products,
    this.categoryId,
    this.onSeeAll,
    this.showSeeAllFooter = true,
    this.maxProducts = 6, // 3 columns x 2 rows
  });

  void _navigateToCategory(BuildContext context) {
    if (onSeeAll != null) {
      onSeeAll!();
    } else if (categoryId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.shop,
        arguments: {'categoryId': categoryId, 'categoryName': sectionTitle},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    if (products.isEmpty) return const SizedBox.shrink();

    // Limit products to maxProducts (default 6)
    final displayProducts = products.take(maxProducts).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _navigateToCategory(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 3-Column Grid
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.52, // Taller cards to prevent overflow
              ),
              itemCount: displayProducts.length,
              itemBuilder: (context, index) {
                return ProductCardCompact(
                  product: displayProducts[index],
                  categoryName: sectionTitle,
                  onSeeMore: () => _navigateToCategory(context),
                );
              },
            ),
          ),
        ),
        
        // See All Footer - always visible with light background
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _navigateToCategory(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.grey[850] 
                    : const Color(0xFFF0F4F0), // Light green-tinted background
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : const Color(0xFFE0E8E0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Preview images
                  if (products.length >= 3)
                    SizedBox(
                      width: 60,
                      height: 24,
                      child: Stack(
                        children: List.generate(3, (i) => Positioned(
                          left: i * 16.0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              color: Colors.grey[300],
                              image: products[i].imageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(products[i].imageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                        )),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'See all products',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
