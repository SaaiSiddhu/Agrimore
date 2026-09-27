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

/// ADMR-32: the symmetric counterpart to isLowStock — a product is only
/// genuinely out of stock when the base AND every one of its variants are
/// all at zero (or below). A product whose base is empty but some variant
/// still has stock remains sellable via that variant, so it is not "out of
/// stock" as a whole. Deliberately pure (no draft/inactive exclusion,
/// unlike isLowStock) — callers already compose that explicitly, matching
/// how ProductListFilter.active/outOfStock already spell it out themselves.
/// An empty variants list makes `every` vacuously true, so a non-variant
/// product's behaviour is unchanged: base <= 0 alone decides it.
bool isOutOfStock(ProductModel p) {
  if (p.stock > 0) return false;
  return p.variants.every((v) => v.stock <= 0);
}
