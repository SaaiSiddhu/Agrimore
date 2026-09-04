import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../../widgets/product/unified_product_card.dart';

/// Search product card - thin wrapper around UnifiedProductCard
/// Using grid layout with all features enabled for search results
class SearchProductCard extends StatelessWidget {
  final ProductModel product;

  const SearchProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UnifiedProductCard(
      product: product,
      layout: ProductCardLayout.grid,
      showWishlist: true,
      showAddToCart: true,
      showBadges: true,
      showDeliveryInfo: false, // Keep compact for search results
      showRating: true,
    );
  }
}
