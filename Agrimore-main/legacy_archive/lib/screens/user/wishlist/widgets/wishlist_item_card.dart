import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/wishlist_provider.dart';

class WishlistItemCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onRemove;

  const WishlistItemCard({
    Key? key,
    required this.product,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);

        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            AppRoutes.navigateTo(
              context,
              AppRoutes.productDetails,
              arguments: product.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      // Product Image
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          image: product.imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(product.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: product.imageUrl == null
                            ? const Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      ),

                      // Remove Button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.white,
                          elevation: 4,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              onRemove();
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: AppColors.error,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Discount Badge
                      if (product.discount != null && product.discount! > 0)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.error,
                                  AppColors.error.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '-${product.discount}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Details Section
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),

                        const Spacer(),

                        // Rating
                        if (product.rating > 0)
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                product.rating.toStringAsFixed(1),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // Price
                        Row(
                          children: [
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (product.originalPrice != null &&
                                product.originalPrice! > product.price)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '₹${product.originalPrice!.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Add to Cart Button
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: isInCart
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    AppRoutes.navigateTo(context, AppRoutes.cart);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle, size: 18),
                                  label: const Text(
                                    'In Cart',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    await cartProvider.addItem(product, quantity: 1);
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Added to cart 🛒'),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                                  label: const Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
    );
  }
}
