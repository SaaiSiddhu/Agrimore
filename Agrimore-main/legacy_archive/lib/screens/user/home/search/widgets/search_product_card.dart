import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../app/themes/app_colors.dart';
import '../../../../../app/themes/app_text_styles.dart';
import '../../../../../app/routes.dart';
import '../../../../../models/product_model.dart';
import '../../../../../providers/cart_provider.dart';
import '../../../../../providers/wishlist_provider.dart';

class SearchProductCard extends StatelessWidget {
  final ProductModel product;

  const SearchProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with Wishlist
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: product.images?.first ?? '',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.lightGrey,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.lightGrey,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 50,
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                ),
                
                // Wishlist Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer<WishlistProvider>(
                    builder: (context, wishlistProvider, child) {
                      final isInWishlist = wishlistProvider.isInWishlist(product.id);
                      
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (isInWishlist) {
                            wishlistProvider.removeFromWishlist(product.id);
                          } else {
                            wishlistProvider.addToWishlist(product);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            isInWishlist
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isInWishlist ? Colors.red : AppColors.grey,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Discount Badge
                if (product.discount != null && product.discount! > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product.discount}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Product Details
            Expanded(
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
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Rating
                    if (product.rating != null)
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.rating!.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),

                    // Price and Cart Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (product.originalPrice != null)
                              Text(
                                '₹${product.originalPrice!.toStringAsFixed(0)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        Consumer<CartProvider>(
                          builder: (context, cartProvider, child) {
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                cartProvider.addToCart(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Added to cart'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.shopping_cart_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
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
