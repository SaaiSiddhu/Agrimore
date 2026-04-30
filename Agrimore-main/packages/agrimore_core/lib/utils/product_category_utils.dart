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

bool productBelongsToCategory(
  ProductModel product,
  CategoryModel category,
  List<CategoryModel> allCategories,
) {
  final ids = categoryIdsIncludingDescendants(category.id, allCategories)
      .map((e) => e.toLowerCase().trim())
      .toSet();
  final pCat = product.categoryId.toLowerCase().trim();
  if (pCat.isNotEmpty && ids.contains(pCat)) return true;

  final cName = category.name.toLowerCase().trim();
  final cSlug = category.slug?.toLowerCase().trim() ?? '';
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
