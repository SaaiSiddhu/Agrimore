// CAT-17: the canonical, single implementation of "what is this product's
// real category id", shared by every money-calculation path that needs it
// (functions/src/customer/productCreditHold.ts, functions/src/customer/
// sellerNotifications.ts). Before this phase, productCreditHold.ts carried
// its own copy (added by CAT-16) and sellerNotifications.ts did a bare
// `product.categoryId` property access with no fallback at all -- a real DRY
// gap CAT-16 itself did not close, since it fixed one copy without knowing a
// second, less complete one existed elsewhere. Extracted here so a third
// consumer never has to choose between duplicating this again or leaving
// itself out of sync.
export function resolveProductCategoryId(product: FirebaseFirestore.DocumentData): string | null {
  // Mirrors ProductModel.parseCategoryId's full fallback chain
  // (packages/agrimore_core/lib/models/product_model.dart): canonical
  // `categoryId` string, then legacy `category` as either a map with its own
  // `id` or a plain string, then `categoryName`. Deliberately still returns
  // null (not Dart's own 'general' display fallback) when nothing matches:
  // every current caller uses this to decide whether a product falls inside
  // an admin-configured allow-list or category-rate table, where null
  // already means "exclude" / "use the default rate", the conservative
  // choice for a money decision -- 'general' would flip an unresolvable
  // product to conditionally-included/rated if an admin's own config
  // happened to contain that literal string, a real behavior change with no
  // clear justification, not a safe widening.
  if (typeof product.categoryId === "string" && product.categoryId) return product.categoryId;
  const cat = product.category;
  if (cat && typeof cat === "object" && typeof cat.id === "string" && cat.id) return cat.id;
  if (typeof cat === "string" && cat) return cat;
  if (typeof product.categoryName === "string" && product.categoryName) return product.categoryName;
  return null;
}
