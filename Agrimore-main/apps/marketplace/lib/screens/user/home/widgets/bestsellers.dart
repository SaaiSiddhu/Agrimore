// lib/screens/user/home/widgets/bestsellers.dart
// Premium Blinkit-style Bestsellers - Admin-controlled with fallback
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/bestseller_provider.dart';
import '../../../../providers/shop_entry_provider.dart';

class DealsForYou extends StatefulWidget {
  const DealsForYou({Key? key}) : super(key: key);

  @override
  State<DealsForYou> createState() => _DealsForYouState();
}

class _DealsForYouState extends State<DealsForYou> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force refresh to get latest admin config
      context.read<BestsellerProvider>().refresh();
    });
  }

  // Card background colors
  static const List<Color> _cardColors = [
    Color(0xFFFFF8E1), Color(0xFFE8F5E9), Color(0xFFFCE4EC),
    Color(0xFFE3F2FD), Color(0xFFFFF3E0), Color(0xFFF3E5F5),
    Color(0xFFE0F2F1), Color(0xFFFBE9E7), Color(0xFFEDE7F6),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Consumer3<BestsellerProvider, CategoryProvider, ProductProvider>(
      builder: (context, bestsellerProvider, categoryProvider, productProvider, _) {
        
        // If still loading, show nothing
        if (bestsellerProvider.isLoading) {
          return const SizedBox.shrink();
        }
        
        final adminSlots = bestsellerProvider.activeSlots;
        final categories = categoryProvider.categories.where((c) => c.isActive).toList();
        
        // Build display items - 9 slots
        final displayItems = <_DisplayItem>[];
        
        for (int i = 0; i < 9; i++) {
          // Check if admin configured this position
          final adminSlot = adminSlots.where((s) => s.position == i + 1).firstOrNull;
          
          if (adminSlot != null) {
            // Use admin slot
            displayItems.add(_DisplayItem.fromSlot(adminSlot));
          } else if (i < categories.length) {
            // Fallback to category
            final category = categories[i];
            final categoryProducts = productProvider.products
                .where((p) =>
                    p.isActive &&
                    productBelongsToCategory(p, category, categoryProvider.categories))
                .take(4)
                .toList();
            final totalProducts = productProvider.products
                .where((p) =>
                    p.isActive &&
                    productBelongsToCategory(p, category, categoryProvider.categories))
                .length;
            displayItems.add(_DisplayItem.fromCategory(
              category, 
              categoryProducts, 
              totalProducts,
              _cardColors[i % _cardColors.length],
            ));
          }
        }
        
        if (displayItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.85, // Slightly taller to prevent overflow
                ),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];
                  return _BestsellerCard(
                    item: item,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<ShopEntryProvider>().openShopWithCategory(
                            categoryId: item.categoryId,
                            categoryName: item.categoryName,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Text(
        'Bestsellers',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Display item - can be from admin slot or fallback category
class _DisplayItem {
  final String categoryId;
  final String categoryName;
  final List<String> images;
  final int moreCount;
  final Color bgColor;
  final bool isAdminSlot;

  _DisplayItem({
    required this.categoryId,
    required this.categoryName,
    required this.images,
    required this.moreCount,
    required this.bgColor,
    required this.isAdminSlot,
  });

  factory _DisplayItem.fromSlot(BestsellerSlotModel slot) {
    return _DisplayItem(
      categoryId: slot.categoryId,
      categoryName: slot.categoryName,
      images: slot.images,
      moreCount: 0,
      bgColor: slot.bgColor,
      isAdminSlot: true,
    );
  }

  factory _DisplayItem.fromCategory(
    CategoryModel category, 
    List<ProductModel> products,
    int totalProducts,
    Color defaultColor,
  ) {
    return _DisplayItem(
      categoryId: category.id,
      categoryName: category.name,
      images: products.map((p) => p.imageUrl ?? '').where((url) => url.isNotEmpty).toList(),
      moreCount: totalProducts > 4 ? totalProducts - 4 : 0,
      bgColor: defaultColor,
      isAdminSlot: false,
    );
  }
}

/// Unified card widget
class _BestsellerCard extends StatefulWidget {
  final _DisplayItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _BestsellerCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_BestsellerCard> createState() => _BestsellerCardState();
}

class _BestsellerCardState extends State<_BestsellerCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final images = widget.item.images;
    final moreCount = widget.item.moreCount;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[850] : widget.item.bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isDark ? Colors.grey[700]! : Colors.grey.shade200,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.15 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2x2 Image Grid - Fixed aspect ratio
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: images.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.widgets_rounded,
                              size: 32,
                              color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                          )
                        : GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                              childAspectRatio: 1,
                            ),
                            itemCount: 4,
                            itemBuilder: (context, index) {
                              final hasImage = index < images.length && images[index].isNotEmpty;
                              final is4thTile = index == 3;
                              
                              Widget tile;
                              if (hasImage) {
                                tile = _ImageTile(
                                  imageUrl: images[index],
                                  isDark: widget.isDark,
                                );
                              } else {
                                tile = Container(
                                  decoration: BoxDecoration(
                                    color: widget.isDark 
                                        ? Colors.grey[800]!.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }
                              
                              // Add badge to 4th tile
                              if (is4thTile && moreCount > 0) {
                                return Stack(
                                  children: [
                                    Positioned.fill(child: tile),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3949AB),
                                          borderRadius: BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '+$moreCount',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              
                              return tile;
                            },
                          ),
                  ),
                ),
              ),
              
              // Category Name - No gap
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isDark 
                      ? Colors.grey[800]!.withOpacity(0.4)
                      : Colors.white.withOpacity(0.65),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                ),
                child: Text(
                  widget.item.categoryName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark 
                        ? AppColors.primaryLight 
                        : const Color(0xFF3949AB),
                    letterSpacing: -0.2,
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

/// Image tile widget
class _ImageTile extends StatelessWidget {
  final String imageUrl;
  final bool isDark;

  const _ImageTile({required this.imageUrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        memCacheWidth: 300,
        placeholder: (context, url) => Container(
          color: isDark ? Colors.grey[800] : Colors.transparent,
        ),
        errorWidget: (context, url, error) => Container(
          color: isDark ? Colors.grey[800] : Colors.white,
        ),
      ),
    );
  }
}