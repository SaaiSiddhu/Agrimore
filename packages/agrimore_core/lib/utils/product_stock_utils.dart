import '../models/product_model.dart';

/// SELLER-OPS-1 / ADMR-4 / ADMR-31: the one canonical definition of "this
/// product is low on stock" — shared so it cannot independently drift a
/// second time (ADMR-31's own finding: the admin dashboard had reimplemented
/// a cruder, base-stock-only version of exactly this check).
const int kDefaultLowStockThreshold = 10;

bool unitIsLow(int stock, int threshold) => stock > 0 && stock <= threshold;

/// Phase ADMR-4: previously checked only `p.stock` — the base field, which a
/// variant-line sale never moves (createOrder.ts decrements a variant's own
/// stock inside product.variants[]). A product whose only stock lives in its
/// variants therefore never showed as low/out of stock. Now true when the
/// base stock is low OR any variant's own stock is — and false for a draft,
/// an inactive listing, or genuine zero stock (out-of-stock is its own,
/// distinct state, not "low").
bool isLowStock(ProductModel p) {
  if (p.isDraft || !p.isActive) return false;
  final threshold = p.lowStockThreshold ?? kDefaultLowStockThreshold;
  if (unitIsLow(p.stock, threshold)) return true;
  return p.variants.any((v) => unitIsLow(v.stock, threshold));
}
