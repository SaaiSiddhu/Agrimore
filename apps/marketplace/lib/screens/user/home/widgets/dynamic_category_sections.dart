// lib/screens/user/home/widgets/dynamic_category_sections.dart
// Admin-controlled category sections with icons - fetches from Firestore
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/category_section_provider.dart';
import '../../../../providers/shop_entry_provider.dart';

/// Resolves a category section's rendered category list in the ADMIN'S OWN
/// configured order (`categoryIds`), not a re-sorted one. `getImageForSlot`
/// (`CategorySectionSlotModel`) is a purely positional `image1..image8`
/// lookup keyed to that exact order -- the order the admin uploaded images
/// against in `edit_category_section_screen.dart`. Re-sorting the category
/// list (e.g. by `CategoryModel.compareSiblingOrder`) before pairing it with
/// that positional lookup silently pairs each category with a DIFFERENT
/// category's own uploaded image whenever the admin's selection order
/// diverges from the sort order -- which it does whenever the admin's own
/// chip-picker order (alphabetical by name) differs from displayOrder,
/// i.e. on effectively every multi-category section (CAT-21).
///
/// A category id no longer present in [liveCategories] (deleted, deactivated,
/// or hidden) is skipped, matching the existing degradation for a deleted
/// category (CAT-18/CAT-20). [alreadyShown] is shared across sibling
/// sections on the same page so the same category never renders twice
/// across two different admin-configured sections -- callers pass the same
/// mutable set across successive calls, one per slot.
List<CategoryModel> resolveOrderedSectionCategories(
  List<String> categoryIds,
  List<CategoryModel> liveCategories,
  Set<String> alreadyShown,
) {
  final byId = {for (final c in liveCategories) c.id: c};
  final result = <CategoryModel>[];
  for (final id in categoryIds) {
    final category = byId[id];
    if (category != null && alreadyShown.add(id)) {
      result.add(category);
    }
  }
  return result;
}

/// Displays admin-configured category sections from Firestore
class DynamicCategorySections extends StatefulWidget {
  final int skipCount;

  const DynamicCategorySections({Key? key, this.skipCount = 6})
      : super(key: key);

  @override
  State<DynamicCategorySections> createState() =>
      _DynamicCategorySectionsState();
}

class _DynamicCategorySectionsState extends State<DynamicCategorySections> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategorySectionProvider>().loadSlots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Consumer3<CategorySectionProvider, CategoryProvider,
        ProductProvider>(
      builder:
          (context, sectionProvider, categoryProvider, productProvider, _) {
        // If loading, show a shimmer skeleton matching this section's
        // own real header + 4-column grid shape, instead of a blank gap
        // -- mirrors mobile_home_screen.dart's own established
        // Shimmer.fromColors color scheme (HOME-17).
        if (sectionProvider.isLoading) {
          return Shimmer.fromColors(
            baseColor: isDark ? const Color(0xFF303030) : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Container(
                    height: 16,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: 8,
                    itemBuilder: (context, index) => Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final activeSlots = sectionProvider.activeSlots;
        final allCategories = categoryProvider.categories
            .where((c) => c.isActive && c.isVisible)
            .toList()
          ..sort(CategoryModel.compareSiblingOrder);

        if (activeSlots.isEmpty) {
          // Fallback to old hardcoded behavior if no admin sections configured
          return _buildFallbackSections(
            isDark,
            allCategories,
            productProvider,
            categoryProvider.categories,
          );
        }

        final shownCategoryIds = <String>{};

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: activeSlots.map((slot) {
            // Get categories for this section, in the ADMIN'S OWN configured
            // order -- see resolveOrderedSectionCategories's own doc comment
            // for why this must not be re-sorted (CAT-21).
            final sectionCategories = resolveOrderedSectionCategories(
              slot.categoryIds,
              allCategories,
              shownCategoryIds,
            );

            if (sectionCategories.isEmpty) return const SizedBox.shrink();

            return _AdminCategorySection(
              slot: slot,
              categories: sectionCategories,
              categoryTree: categoryProvider.categories,
              productProvider: productProvider,
              isDark: isDark,
            );
          }).toList(),
        );
      },
    );
  }

  /// Fallback to old behavior if no admin sections configured
  Widget _buildFallbackSections(
    bool isDark,
    List<CategoryModel> allCategories,
    ProductProvider productProvider,
    List<CategoryModel> categoryTree,
  ) {
    final seenCategoryIds = <String>{};
    final categories = allCategories
        .where((category) => seenCategoryIds.add(category.id))
        .skip(widget.skipCount)
        .toList();

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group categories into sections of 8
    final List<List<CategoryModel>> sections = [];
    for (int i = 0; i < categories.length; i += 8) {
      final end = (i + 8 < categories.length) ? i + 8 : categories.length;
      sections.add(categories.sublist(i, end));
    }

    // HOME-8: this chunk's categories are a positional slice (skip, then
    // group by 8) with no relationship to any specific theme, so every
    // section gets the same honest, generic title -- the same default this
    // code already used for any chunk past a fixed content-guessed list.
    // Naming a chunk "Grocery & Kitchen" when it happens to contain
    // Electronics/Toys/Books is exactly the hardcoded-false-content problem
    // this whole Home-CMS programme exists to remove.
    return Column(
      children: sections.map((sectionCategories) {
        return _FallbackCategorySection(
          title: 'More Categories',
          categories: sectionCategories,
          categoryTree: categoryTree,
          productProvider: productProvider,
          isDark: isDark,
        );
      }).toList(),
    );
  }
}

/// Admin-controlled section with icon from Firestore
class _AdminCategorySection extends StatelessWidget {
  final CategorySectionSlotModel slot;
  final List<CategoryModel> categories;
  final List<CategoryModel> categoryTree;
  final ProductProvider productProvider;
  final bool isDark;

  const _AdminCategorySection({
    required this.slot,
    required this.categories,
    required this.categoryTree,
    required this.productProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - just text, no icon
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Text(
            slot.sectionName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
        ),
        // Category Grid - compact
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 4,
                childAspectRatio: 1.05,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];

                // Use admin-uploaded image for this slot position (1-indexed)
                final slotImage = slot.getImageForSlot(index + 1);

                // Fallback to product image if no slot image
                String imageUrl = slotImage ?? '';
                if (imageUrl.isEmpty) {
                  final categoryProduct = productProvider.products
                      .where((p) =>
                          p.isActive &&
                          productBelongsToCategory(p, category, categoryTree))
                      .take(1)
                      .toList();
                  imageUrl = categoryProduct.isNotEmpty
                      ? categoryProduct.first.imageUrl ?? ''
                      : category.imageUrl ?? '';
                }

                return _EnhancedCategoryTile(
                  category: category,
                  productImageUrl: imageUrl,
                  isDark: isDark,
                  bgColor: slot.bgColor,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<ShopEntryProvider>().openShopWithCategory(
                          categoryId: category.id,
                          categoryName: category.name,
                        );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Fallback section (when no admin config)
class _FallbackCategorySection extends StatelessWidget {
  final String title;
  final List<CategoryModel> categories;
  final List<CategoryModel> categoryTree;
  final ProductProvider productProvider;
  final bool isDark;

  const _FallbackCategorySection({
    required this.title,
    required this.categories,
    required this.categoryTree,
    required this.productProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
        ),

        // Category Grid
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 4,
                childAspectRatio: 1.05, // Even shorter cells
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryProduct = productProvider.products
                    .where((p) =>
                        p.isActive &&
                        productBelongsToCategory(p, category, categoryTree))
                    .take(1)
                    .toList();

                return _EnhancedCategoryTile(
                  category: category,
                  productImageUrl: categoryProduct.isNotEmpty
                      ? categoryProduct.first.imageUrl ?? ''
                      : category.imageUrl ?? '',
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.read<ShopEntryProvider>().openShopWithCategory(
                          categoryId: category.id,
                          categoryName: category.name,
                        );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EnhancedCategoryTile extends StatefulWidget {
  final CategoryModel category;
  final String productImageUrl;
  final bool isDark;
  final Color? bgColor;
  final VoidCallback onTap;

  const _EnhancedCategoryTile({
    required this.category,
    required this.productImageUrl,
    required this.isDark,
    this.bgColor,
    required this.onTap,
  });

  @override
  State<_EnhancedCategoryTile> createState() => _EnhancedCategoryTileState();
}

class _EnhancedCategoryTileState extends State<_EnhancedCategoryTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tileBgColor = widget.bgColor ??
        (widget.isDark ? const Color(0xFF303030) : const Color(0xFFFFF9E6));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            // Image Container - ultra compact
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tileBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.grey[700]!
                        : const Color(0xFFE8E0D0),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: widget.productImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.productImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          // PERF-1: this is a small compact category tile;
                          // without a decode-size hint, the source decodes
                          // at full native resolution.
                          memCacheWidth: 200,
                          placeholder: (context, url) => _buildLargeIcon(),
                          errorWidget: (context, url, error) =>
                              _buildLargeIcon(),
                        )
                      : _buildLargeIcon(),
                ),
              ),
            ),

            const SizedBox(height: 2),

            // Category Name - ultra compact
            SizedBox(
              height: 18,
              child: Text(
                widget.category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.grey[300] : Colors.black87,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeIcon() {
    return Center(
      child: Icon(
        Icons.widgets_rounded,
        size: 36,
        color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
      ),
    );
  }
}
