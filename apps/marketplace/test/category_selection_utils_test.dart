// Phase CAT-20: a category-section/grocery-strip chip picker's own selected-
// ids list can outlive a category that was later deleted (CAT-18's own
// finding for `products` applies identically here -- AdminProvider.deleteCategory
// never scrubs a deleted category's id out of anything else's reference to
// it). liveSelectedCategoryIds filters the raw stored list down to ids that
// still resolve to a live category, order preserved, so a caller's own
// "(N/8)" counter / 8-item cap / "#N" position badge stop counting a
// category no chip anywhere in the list can ever show again.
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_core/agrimore_core.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  CategoryModel cat(String id) =>
      CategoryModel(id: id, name: id, description: '', createdAt: now);

  final liveCategories = [cat('veg'), cat('fruit'), cat('dairy')];

  group('liveSelectedCategoryIds', () {
    test('an all-live selection passes through unchanged, order preserved', () {
      expect(
        liveSelectedCategoryIds(['fruit', 'veg'], liveCategories),
        ['fruit', 'veg'],
      );
    });

    test('a dead id in the middle is dropped, surviving order preserved', () {
      // Regression case: the deleted category's id must not occupy a
      // counted slot or shift the position of ids after it.
      expect(
        liveSelectedCategoryIds(['veg', 'deleted-cat', 'dairy'], liveCategories),
        ['veg', 'dairy'],
      );
    });

    test('an all-dead selection resolves to empty', () {
      expect(
        liveSelectedCategoryIds(['gone1', 'gone2'], liveCategories),
        <String>[],
      );
    });

    test('an empty selection resolves to empty', () {
      expect(liveSelectedCategoryIds(<String>[], liveCategories), <String>[]);
    });

    test(
        'while the live category list has not loaded yet (empty), the raw '
        'selection passes through unchanged rather than reporting zero', () {
      // A caller's "(N/8)" counter must not flash a wrong "(0/8)" during the
      // transient window before CategoryProvider.loadCategories() resolves.
      expect(
        liveSelectedCategoryIds(['veg', 'dairy'], const []),
        ['veg', 'dairy'],
      );
    });
  });
}
