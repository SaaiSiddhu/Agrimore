// lib/screens/user/home/widgets/featured_products.dart
// Blinkit-style category grid - 4 columns x 2 rows
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/routes.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/shop_entry_provider.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';

class FeaturedProducts extends StatelessWidget {
  const FeaturedProducts({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Consumer2<CategoryProvider, ProductProvider>(
      builder: (context, categoryProvider, productProvider, _) {
        // Get categories 15-22 (third group of 8)
        final allCategories = categoryProvider.categories
            .where((c) => c.isActive)
            .toList();
        
        // Skip first 14 (used in Bestsellers + Snacks), take next 8
        final categories = allCategories.skip(14).take(8).toList();
        
        // If not enough categories in 3rd group, use remaining
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                'Beauty & Personal Care',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            
            // Category Grid - 4 columns x 2 rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  // Get featured product from this category for the image
                  final categoryProduct = productProvider.products
                      .where((p) =>
                          p.isActive &&
                          productBelongsToCategory(
                            p,
                            category,
                            categoryProvider.categories,
                          ))
                      .take(1)
                      .toList();
                  
                  return _CategoryTile(
                    category: category,
                    productImageUrl: categoryProduct.isNotEmpty 
                        ? categoryProduct.first.imageUrl ?? ''
                        : '',
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<ShopEntryProvider>().openShopWithCategory(
                            categoryId: category.id,
                            categoryName: category.name,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final String productImageUrl;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.productImageUrl,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Product Image in rounded container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.grey[700]! 
                      : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: productImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: productImageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _categoryIcon(),
                    )
                  : _categoryIcon(),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Category Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.black87,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon() {
    return Center(
      child: Icon(
        Icons.category_outlined,
        size: 32,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
    );
  }
}