// lib/screens/chat/widgets/product_card_horizontal.dart
import 'package:flutter/material.dart';

class ProductCardHorizontal extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;

  const ProductCardHorizontal({
    Key? key,
    required this.product,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString().trim().isNotEmpty == true
        ? product['name']
        : 'Unnamed Product';

    // Handle images (can be list or single URL)
    String imageUrl = '';
    final imageData = product['images'] ?? product['imageUrl'];
    if (imageData is List && imageData.isNotEmpty) {
      imageUrl = imageData.first.toString();
    } else if (imageData is String) {
      imageUrl = imageData;
    }

    // Handle prices safely
    final salePrice = double.tryParse(product['salePrice']?.toString() ?? '') ??
        double.tryParse(product['price']?.toString() ?? '') ??
        0;
    final originalPrice =
        double.tryParse(product['originalPrice']?.toString() ?? '') ??
            double.tryParse(product['mrp']?.toString() ?? '') ??
            salePrice;
    final hasDiscount = originalPrice > salePrice;
    final discount = hasDiscount
        ? ((originalPrice - salePrice) / originalPrice * 100).round()
        : 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    image: imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl.isEmpty
                      ? const Center(
                          child: Icon(Icons.image_not_supported,
                              size: 36, color: Colors.grey),
                        )
                      : null,
                ),
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    right: 8,
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
                        '$discount% OFF',
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

            // DETAILS SECTION
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '₹${salePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 4),
                          Text(
                            '₹${originalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
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