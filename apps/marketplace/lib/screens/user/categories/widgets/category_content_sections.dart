import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Category hero banner — renders [CategoryModel.bannerImageUrl] (the field
/// the admin Category form already uploads to, see
/// category_management_screen.dart's "Banner (1920x400)" upload) as an
/// overlay hero. Collapses to nothing when the category has no banner
/// configured — presentation only, the name/description/CTA are real
/// category data, never invented copy.
class CategoryHeroBanner extends StatelessWidget {
  final CategoryModel category;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onShopNow;

  const CategoryHeroBanner({
    super.key,
    required this.category,
    required this.isDark,
    required this.accentColor,
    required this.onShopNow,
  });

  @override
  Widget build(BuildContext context) {
    final bannerUrl = (category.bannerImageUrl ?? '').trim();
    if (bannerUrl.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1.95,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: bannerUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
              ),
              errorWidget: (_, __, ___) => Container(
                color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.05),
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Semantics(
                label: '${category.name} banner',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (category.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onShopNow,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Shop Now',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                color: accentColor, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally-scrollable "All" + direct-subcategory filter chips for the
/// selected top-level category. Selecting a chip filters the product grid
/// below in place (categories_screen.dart's `_selectedSubcategoryId`) — it
/// does not navigate away, which is what tapping a Shop-by-Category card
/// already does.
class CategoryFilterChips extends StatelessWidget {
  final List<CategoryModel> subcategories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final bool isDark;
  final Color accentColor;

  const CategoryFilterChips({
    super.key,
    required this.subcategories,
    required this.selectedId,
    required this.onSelect,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (subcategories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(label: 'All', id: null),
          for (final sub in subcategories) ...[
            const SizedBox(width: 8),
            _chip(label: sub.name, id: sub.id),
          ],
        ],
      ),
    );
  }

  Widget _chip({required String label, required String? id}) {
    final isSelected = selectedId == id;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? const Color(0xFF232323) : const Color(0xFFF3F3F3)),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Popular Picks" — a horizontally-scrolling strip of pre-built product
/// cards. Takes ready-made card widgets (rather than [ProductModel]s) so it
/// can reuse categories_screen.dart's own existing product-card widget —
/// same pricing/cart/discount rendering as the grid below — without making
/// that private class public.
class PopularPicksSection extends StatelessWidget {
  final List<Widget> cards;
  final bool isDark;

  const PopularPicksSection({
    super.key,
    required this.cards,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Picks',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          // A couple of pixels taller than the general grid's own
          // mainAxisExtent (195) — the shared product card's content
          // (2-line bilingual names are common in this catalog) sits right
          // at that budget already; this section gives it a little more
          // headroom rather than touching the shared card's internals.
          height: 226,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(width: 134, child: cards[i]),
          ),
        ),
      ],
    );
  }
}
