// Phase CAT-21: dynamic_category_sections.dart's own image1..image8 lookup
// (CategorySectionSlotModel.getImageForSlot) is purely positional, keyed to
// the admin's OWN configured categoryIds order (the order images were
// uploaded against in edit_category_section_screen.dart). The pre-fix code
// re-sorted the rendered category list by CategoryModel.compareSiblingOrder
// (displayOrder) before pairing it with that positional lookup -- silently
// pairing each category with a DIFFERENT category's own uploaded image
// whenever the admin's selection order diverged from displayOrder, which it
// does whenever the admin's own chip-picker order (alphabetical by name)
// differs from displayOrder -- effectively every multi-category section.
// No Firebase dependency here -- CategoryModel is a plain data class and the
// function under test is pure synchronous logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/screens/user/home/widgets/dynamic_category_sections.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  CategoryModel cat(String id, int displayOrder) => CategoryModel(
        id: id,
        name: id,
        description: '',
        displayOrder: displayOrder,
        createdAt: now,
      );

  group('resolveOrderedSectionCategories', () {
    test(
        "preserves the admin's own categoryIds order even when it diverges "
        'from displayOrder -- the exact CAT-21 regression case', () {
      // A (displayOrder 0), B (1), C (2) -- but the admin selected C, A, B.
      final a = cat('a', 0);
      final b = cat('b', 1);
      final c = cat('c', 2);
      final liveCategories = [a, b, c];

      final result = resolveOrderedSectionCategories(
        ['c', 'a', 'b'],
        liveCategories,
        <String>{},
      );

      // Must come back as [C, A, B] -- matching categoryIds, NOT [A, B, C]
      // (what a displayOrder sort would produce, and what the pre-fix code
      // actually returned).
      expect(result.map((cat) => cat.id).toList(), ['c', 'a', 'b']);
    });

    test('a deleted category id is skipped without disturbing the order of '
        'the ids around it', () {
      final a = cat('a', 0);
      final b = cat('b', 1);
      final liveCategories = [a, b];

      final result = resolveOrderedSectionCategories(
        ['a', 'deleted-cat', 'b'],
        liveCategories,
        <String>{},
      );

      expect(result.map((cat) => cat.id).toList(), ['a', 'b']);
    });

    test('a duplicate id in categoryIds is deduped, first occurrence kept',
        () {
      final a = cat('a', 0);
      final result = resolveOrderedSectionCategories(
        ['a', 'a'],
        [a],
        <String>{},
      );
      expect(result.map((cat) => cat.id).toList(), ['a']);
    });

    test(
        'alreadyShown is shared across successive calls -- a category shown '
        "in an earlier section does not repeat in a later one", () {
      final a = cat('a', 0);
      final b = cat('b', 1);
      final liveCategories = [a, b];
      final shown = <String>{};

      final firstSection =
          resolveOrderedSectionCategories(['a', 'b'], liveCategories, shown);
      final secondSection =
          resolveOrderedSectionCategories(['a', 'b'], liveCategories, shown);

      expect(firstSection.map((cat) => cat.id).toList(), ['a', 'b']);
      expect(secondSection, isEmpty);
    });

    test('an empty categoryIds list resolves to empty', () {
      expect(
        resolveOrderedSectionCategories(<String>[], [cat('a', 0)], <String>{}),
        isEmpty,
      );
    });
  });
}
