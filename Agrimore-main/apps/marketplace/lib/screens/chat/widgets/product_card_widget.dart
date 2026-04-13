import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../widgets/product/unified_product_card.dart';

/// Product card widget for chat - uses UnifiedProductCard horizontal layout.
/// Converts Map<String, dynamic> to ProductModel internally.
class ProductCardWidget extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductCardWidget({
    Key? key,
    required this.product,
    required this.onTap,
  }) : super(key: key);

  ProductModel _convertToProductModel() {
    final price = (product['price'] ?? 0).toDouble();
    final originalPrice = product['originalPrice']?.toDouble();

    return ProductModel(
      id: product['id'] ?? '',
      name: product['name'] ?? 'Product',
      description: product['description'] ?? '',
      salePrice: price,
      originalPrice: originalPrice,
      categoryId: product['categoryId'] ?? product['category'] ?? '',
      images: product['images'] != null
          ? List<String>.from(product['images'])
          : (product['imageUrl'] != null ? [product['imageUrl']] : []),
      stock: product['stock'] ?? 100,
      rating: (product['rating'] ?? 0.0).toDouble(),
      reviewCount: product['reviews'] ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UnifiedProductCard(
      product: _convertToProductModel(),
      layout: ProductCardLayout.horizontal,
      showWishlist: true,
      showAddToCart: true,
      showBadges: true,
      showDeliveryInfo: false,
      showRating: true,
      onTap: onTap,
    );
  }
}
