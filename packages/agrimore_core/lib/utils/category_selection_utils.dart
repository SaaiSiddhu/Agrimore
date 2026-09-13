import '../models/category_model.dart';

/// Filters an admin-configured, order-preserving list of selected category
/// ids down to only those whose category still exists in [liveCategories].
///
/// A section/strip's stored selection can outlive the categories it
/// references: `AdminProvider.deleteCategory` never scrubs a deleted
/// category's id out of any other collection's own reference to it (see
/// CAT-18's own finding on `products`). A chip-picker screen that shows a
/// raw `selectedIds.length` as its "(N/8)" counter, or uses it as the max-8
/// selection cap, or as the source of a per-item `#N` position badge, ends
/// up counting/numbering a category that no longer has a chip anywhere in
/// its own list -- confusing an admin who sees fewer than N chips checked.
///
/// While [liveCategories] is still empty (categories not loaded yet), this
/// returns [selectedIds] unchanged rather than an empty list, so a caller
/// using `.length` for a "loading" counter does not flash a wrong "(0/8)"
/// before the real category list arrives.
List<String> liveSelectedCategoryIds(
  List<String> selectedIds,
  List<CategoryModel> liveCategories,
) {
  if (liveCategories.isEmpty) return selectedIds;
  final liveIds = liveCategories.map((c) => c.id).toSet();
  return selectedIds.where(liveIds.contains).toList();
}
