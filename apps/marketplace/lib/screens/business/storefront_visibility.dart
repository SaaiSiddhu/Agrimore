import 'package:agrimore_core/agrimore_core.dart';

/// SELLER-STOREFRONT-EDIT-1: what a buyer may see on a seller's storefront.
/// Same rule as the catalogue (database_service.dart filters `p.isActive`;
/// ProductModel reads a missing `isActive` as true, so legacy products stay
/// visible). Hidden and draft products never appear. Pure — unit-tested.
bool isVisibleOnStorefront(ProductModel p) => p.isActive && !p.isDraft;

/// Up to three non-empty highlights from sellers/{uid}.highlights.
List<String> storefrontHighlights(Map<String, dynamic>? seller) => [
      for (final h in (seller?['highlights'] as List?) ?? const [])
        if (h is String && h.trim().isNotEmpty) h.trim(),
    ].take(3).toList();
