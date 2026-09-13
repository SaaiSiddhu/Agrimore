import '../models/category_model.dart';
import '../models/product_model.dart';

/// Category [id] plus every descendant category id in [all].
List<String> categoryIdsIncludingDescendants(
  String categoryId,
  List<CategoryModel> all,
) {
  final result = <String>{categoryId};
  final queue = <String>[categoryId];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final curLower = current.toLowerCase();
    for (final c in all) {
      final pid = c.parentId;
      if (pid != null &&
          pid.isNotEmpty &&
          pid.toLowerCase() == curLower &&
          !result.contains(c.id)) {
        result.add(c.id);
        queue.add(c.id);
      }
    }
  }
  return result.toList();
}

/// True if [product]'s legacy name-shaped category tag (its `categoryId` or
/// `categoryName` holding a NAME rather than a real id -- see
/// `ProductModel.parseCategoryId`'s own fallback chain) matches [c]'s own
/// name or slug.
bool _matchesLegacyName(ProductModel product, CategoryModel c) {
  final cName = c.name.toLowerCase().trim();
  final cSlug = c.slug?.toLowerCase().trim() ?? '';

  final pCat = product.categoryId.toLowerCase().trim();
  if (pCat.isNotEmpty) {
    if (pCat == cName || (cSlug.isNotEmpty && pCat == cSlug)) return true;
    if (pCat.contains(cName.split('/').first.trim())) return true;
    if (cName.contains(pCat)) return true;
  }

  final pname = product.categoryName?.toLowerCase().trim();
  if (pname != null && pname.isNotEmpty) {
    if (pname == cName || (cSlug.isNotEmpty && pname == cSlug)) return true;
  }
  return false;
}

bool productBelongsToCategory(
  ProductModel product,
  CategoryModel category,
  List<CategoryModel> allCategories,
) {
  final descendantIds = categoryIdsIncludingDescendants(category.id, allCategories)
      .map((e) => e.toLowerCase().trim())
      .toSet();
  final pCat = product.categoryId.toLowerCase().trim();
  if (pCat.isNotEmpty && descendantIds.contains(pCat)) return true;

  // The id-based check above already covers the whole descendant subtree.
  // A legacy product tagged by NAME instead of a real id needs the same
  // subtree covered here, or it becomes invisible under an ancestor while
  // an equivalent real-id product in the same subcategory is found fine.
  if (_matchesLegacyName(product, category)) return true;
  for (final c in allCategories) {
    if (c.id == category.id) continue;
    if (!descendantIds.contains(c.id.toLowerCase().trim())) continue;
    if (_matchesLegacyName(product, c)) return true;
  }
  return false;
}
