import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../widgets/product/unified_product_card.dart';

/// Horizontal product card for chat carousels.
/// Converts Map<String, dynamic> to ProductModel and uses UnifiedProductCard.
class ProductCardHorizontal extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;

  const ProductCardHorizontal({
    Key? key,
    required this.product,
    this.onTap,
  }) : super(key: key);

  ProductModel _convertToProductModel() {
    final salePrice = double.tryParse(product['salePrice']?.toString() ?? '') ??
        double.tryParse(product['price']?.toString() ?? '') ??
        0;
    final originalPrice =
        double.tryParse(product['originalPrice']?.toString() ?? '') ??
            double.tryParse(product['mrp']?.toString() ?? '') ??
            salePrice;

    String imageUrl = '';
    final imageData = product['images'] ?? product['imageUrl'];
    if (imageData is List && imageData.isNotEmpty) {
      imageUrl = imageData.first.toString();
    } else if (imageData is String) {
      imageUrl = imageData;
    }

    return ProductModel(
      id: product['id'] ?? '',
      name: product['name']?.toString().trim().isNotEmpty == true
          ? product['name']
          : 'Unnamed Product',
      description: product['description'] ?? '',
      salePrice: salePrice,
      originalPrice: originalPrice > salePrice ? originalPrice : null,
      categoryId: product['categoryId'] ?? '',
      images: imageUrl.isNotEmpty ? [imageUrl] : [],
      stock: product['stock'] ?? 100,
      rating: 0.0,
      reviewCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: UnifiedProductCard(
        product: _convertToProductModel(),
        layout: ProductCardLayout.compact, // Use compact for horizontal scroll
        showWishlist: false,
        showAddToCart: false,
        showBadges: true,
        showDeliveryInfo: false,
        showRating: false,
        onTap: onTap,
      ),
    );
  }
}