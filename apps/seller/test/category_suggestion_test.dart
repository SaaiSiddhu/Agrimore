// Phase CAT-15 — the seller app's own "Add Product" category field was a
// plain free-text box with no link to the real category tree at all;
// matchCategoryByName/categorySuggestionsFor are the pure resolution/
// suggestion logic behind its new autocomplete-with-freeform behaviour. Pure
// logic, no widget harness or Firebase needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:seller/screens/home/add_product_screen.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  CategoryModel category(String id, String name) {
    return CategoryModel(id: id, name: name, description: '', createdAt: now);
  }

  final categories = [
    category('cat_veg', 'Vegetables'),
    category('cat_fruit', 'Fruits'),
    category('cat_dairy', 'Dairy Products'),
  ];

  group('matchCategoryByName', () {
    test('exact case-insensitive match returns the real category', () {
      final match = matchCategoryByName('vegetables', categories);
      expect(match?.id, 'cat_veg');
    });

    test('trims surrounding whitespace before matching', () {
      final match = matchCategoryByName('  Fruits  ', categories);
      expect(match?.id, 'cat_fruit');
    });

    test('a substring-only near-miss does not exact-match', () {
      expect(matchCategoryByName('Veg', categories), isNull);
    });

    test('no match at all returns null (preserves the freeform fallback)', () {
      expect(matchCategoryByName('Handicrafts', categories), isNull);
    });

    test('empty text returns null', () {
      expect(matchCategoryByName('', categories), isNull);
    });
  });

  group('categorySuggestionsFor', () {
    test('substring match, case-insensitive', () {
      final results = categorySuggestionsFor('veg', categories);
      expect(results.map((c) => c.id), ['cat_veg']);
    });

    test('matches a name containing the query mid-string', () {
      final results = categorySuggestionsFor('duct', categories);
      expect(results.map((c) => c.id), ['cat_dairy']);
    });

    test('empty text returns no suggestions', () {
      expect(categorySuggestionsFor('', categories), isEmpty);
    });

    test('no match returns an empty list, not null', () {
      expect(categorySuggestionsFor('zzz', categories), isEmpty);
    });

    test('caps at 6 results', () {
      final many = List.generate(10, (i) => category('cat_$i', 'Apple $i'));
      expect(categorySuggestionsFor('apple', many).length, 6);
    });
  });
}
