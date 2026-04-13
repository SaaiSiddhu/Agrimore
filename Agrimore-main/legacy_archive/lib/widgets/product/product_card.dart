import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final bool isListView;  // ADD THIS LINE

  const ProductCard({
    Key? key,
    required this.product,
    this.onTap,
    this.isListView = false,  // ADD THIS LINE WITH DEFAULT VALUE
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListCard() : _buildGridCard();
  }

  Widget _buildGridCard() {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, size: 40),
                          ),
                  ),
                  
                  // Discount Badge
                  if (product.originalPrice != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${(((product.originalPrice! - product.salePrice) / product.originalPrice!) * 100).toInt()}%',
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
            ),

            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '₹${product.salePrice.toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.originalPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.originalPrice!.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: AppTextStyles.bodySmall,
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

  Widget _buildListCard() {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.images.first,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 40),
                      ),
              ),

              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${product.salePrice.toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.originalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${product.originalPrice!.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
