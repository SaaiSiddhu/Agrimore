import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_admin/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart';

CategoryModel _cat(String id) => CategoryModel(
      id: id,
      name: id,
      description: '',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('resolveDropdownCategoryId', () {
    final liveCategories = [_cat('veg'), _cat('fruit')];

    test('a categoryId still present in the live list resolves to itself', () {
      expect(resolveDropdownCategoryId('veg', liveCategories), 'veg');
    });

    test(
        'a categoryId whose category was deleted (absent from the live list) resolves to null',
        () {
      // Regression case: CAT-18 confirmed AdminProvider.deleteCategory never
      // scrubs references outside categories/subcategoryIds, so an existing
      // bestseller slot's stored categoryId can outlive the category itself.
      // Passing it straight through as a DropdownButtonFormField `value:`
      // (the pre-fix behavior) throws the framework's "exactly one item must
      // match value" assertion once `items` is non-empty.
      expect(resolveDropdownCategoryId('deleted-category', liveCategories), null);
    });

    test('an empty categoryId (an unconfigured slot) resolves to null', () {
      expect(resolveDropdownCategoryId('', liveCategories), null);
    });

    test('an empty live category list never matches, even the empty id', () {
      expect(resolveDropdownCategoryId('veg', const []), null);
    });
  });
}
