import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/wishlist_provider.dart';

class ProductInfoSection extends StatelessWidget {
  final ProductModel product;

  const ProductInfoSection({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category & Brand
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.category,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Consumer<WishlistProvider>(
                builder: (context, wishlistProvider, child) {
                  final isInWishlist = wishlistProvider.isInWishlist(product.id);
                  return IconButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      if (isInWishlist) {
                        await wishlistProvider.removeItem(product.id);
                      } else {
                        await wishlistProvider.addItem(product);
                      }
                    },
                    icon: Icon(
                      isInWishlist ? Icons.favorite : Icons.favorite_border,
                      color: isInWishlist ? Colors.red : Colors.grey,
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: () {
                  // Share functionality
                },
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Product Name
          Text(
            product.name,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 12),

          // Rating & Reviews
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < product.rating.floor()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 20,
                  color: Colors.amber[700],
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${product.rating.toStringAsFixed(1)} (${product.reviewCount ?? 0} reviews)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Price Section
          Row(
            children: [
              Text(
                '₹${product.price.toStringAsFixed(2)}',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (product.originalPrice != null &&
                  product.originalPrice! > product.price) ...[
                const SizedBox(width: 12),
                Text(
                  '₹${product.originalPrice!.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${product.discount}% OFF',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Stock Status
          Row(
            children: [
              Icon(
                product.inStock ? Icons.check_circle : Icons.cancel,
                color: product.inStock ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                product.inStock ? 'In Stock' : 'Out of Stock',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: product.inStock ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            'Description',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
