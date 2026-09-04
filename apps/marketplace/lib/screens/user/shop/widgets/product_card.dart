// shop/widgets/product_card.dart - Backwards-compatible wrapper
// Uses UnifiedProductCard internally for consistent behavior

import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../widgets/product/unified_product_card.dart';

/// Product card widget for shop screens.
/// This is a thin wrapper around UnifiedProductCard for backwards compatibility.
/// Use UnifiedProductCard directly for new code.
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isGridView;

  const ProductCard({
    Key? key,
    required this.product,
    this.isGridView = true, // Default to grid now
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use shop layout (R2-style) for storefront consistency.
    return UnifiedProductCard(
      product: product,
      layout: ProductCardLayout.shop,
      showWishlist: true,
      showAddToCart: true,
      showBadges: true,
      showDeliveryInfo: false,
      showRating: false,
    );
  }
}