// Phase CAT-13: productBelongsToCategory's id-based match already walks the
// full descendant subtree (via categoryIdsIncludingDescendants); its legacy
// name/slug fallback (for products whose categoryId/categoryName holds a
// NAME instead of a real id -- see ProductModel.parseCategoryId's own
// fallback chain) did not, so a legacy product tagged by a SUBCATEGORY's
// name was invisible when browsing the parent, even though an equivalent
// real-id product in the same subcategory was found fine. No Firebase
// dependency here -- CategoryModel/ProductModel are plain data classes and
// the utility under test is pure synchronous logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_core/agrimore_core.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  CategoryModel category({
    required String id,
    required String name,
    String? parentId,
    int level = 0,
  }) {
    return CategoryModel(
      id: id,
      name: name,
      description: '',
      createdAt: now,
      parentId: parentId,
      level: level,
    );
  }

  ProductModel product({required String categoryId, String? categoryName}) {
    return ProductModel(
      id: 'p_${categoryId}_${categoryName ?? ''}',
      name: 'Test product',
      description: '',
      salePrice: 10,
      categoryId: categoryId,
      categoryName: categoryName,
      images: const [],
      stock: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  final fruits = category(id: 'cat_fruits', name: 'Fruits');
  final apples = category(id: 'cat_apples', name: 'Apples', parentId: 'cat_fruits', level: 1);
  final vegetables = category(id: 'cat_veg', name: 'Vegetables');
  final allCategories = [fruits, apples, vegetables];

  group('productBelongsToCategory', () {
    test('regression: real id matches its own top-level category', () {
      final p = product(categoryId: 'cat_fruits');
      expect(productBelongsToCategory(p, fruits, allCategories), isTrue);
    });

    test('regression: real id matches via a descendant (categoryIdsIncludingDescendants)', () {
      final p = product(categoryId: 'cat_apples');
      expect(productBelongsToCategory(p, fruits, allCategories), isTrue);
    });

    test('regression: legacy name matches its own top-level category', () {
      final p = product(categoryId: 'Fruits');
      expect(productBelongsToCategory(p, fruits, allCategories), isTrue);
    });

    test('CAT-13 bug: legacy name matches via a descendant, same as a real id would', () {
      final p = product(categoryId: 'Apples');
      expect(
        productBelongsToCategory(p, fruits, allCategories),
        isTrue,
        reason: 'a legacy product named after a subcategory must be found '
            'under its parent, the same way a real subcategory id already is',
      );
    });

    test('no over-matching: an unrelated legacy name does not match', () {
      final p = product(categoryId: 'Vegetables');
      expect(productBelongsToCategory(p, fruits, allCategories), isFalse);
    });

    test('a leaf category with no descendants behaves exactly as before', () {
      final matching = product(categoryId: 'cat_apples');
      final legacyMatching = product(categoryId: 'Apples');
      final nonMatching = product(categoryId: 'cat_fruits');
      expect(productBelongsToCategory(matching, apples, allCategories), isTrue);
      expect(productBelongsToCategory(legacyMatching, apples, allCategories), isTrue);
      expect(productBelongsToCategory(nonMatching, apples, allCategories), isFalse);
    });
  });
}
