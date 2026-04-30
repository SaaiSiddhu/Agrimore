import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/shop_entry_provider.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';

/// Highlights Grocery & Kitchen categories under Bestsellers (admin categories + product thumbnails).
class GroceryKitchenHomeStrip extends StatelessWidget {
  const GroceryKitchenHomeStrip({Key? key}) : super(key: key);

  static bool _isGroceryOrKitchen(CategoryModel c) {
    final n = c.name.toLowerCase();
    final s = (c.slug ?? '').toLowerCase();
    return n.contains('grocery') ||
        n.contains('kitchen') ||
        s.contains('grocery') ||
        s.contains('kitchen');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Consumer2<CategoryProvider, ProductProvider>(
      builder: (context, categoryProvider, productProvider, _) {
        final cats = categoryProvider.categories
            .where((c) => c.isActive && _isGroceryOrKitchen(c))
            .take(8)
            .toList();

        if (cats.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Grocery & Kitchen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SizedBox(
              height: 112,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = cats[i];
                  String? thumb;
                  for (final p in productProvider.products) {
                    if (!p.isActive) continue;
                    if (!productBelongsToCategory(
                      p,
                      c,
                      categoryProvider.categories,
                    )) {
                      continue;
                    }
                    final u = p.imageUrl;
                    if (u != null && u.isNotEmpty) {
                      thumb = u;
                      break;
                    }
                  }

                  return _Tile(
                    label: c.name,
                    imageUrl: thumb ?? c.imageUrl ?? c.iconUrl,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<ShopEntryProvider>().openShopWithCategory(
                            categoryId: c.id,
                            categoryName: c.name,
                          );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isDark;
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.imageUrl,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 96,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: accent.withOpacity(0.12),
                            child: Icon(Icons.storefront, color: accent),
                          ),
                        )
                      : ColoredBox(
                          color: accent.withOpacity(0.12),
                          child: Icon(Icons.storefront, color: accent),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
