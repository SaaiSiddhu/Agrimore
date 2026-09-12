// lib/screens/user/shop/widgets/product_image_hero.dart
// Full-bleed, variant-aware image carousel + tappable thumbnail strip.
// PDP-1: top navigation (back/search/wishlist/share) moved to the screen's
// own pinned sticky header, so it stays reachable while scrolled past the
// image instead of scrolling away with it -- this widget only owns the
// media now.

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/product_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductImageHero extends StatefulWidget {
  final ProductModel product;

  const ProductImageHero({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductImageHero> createState() => _ProductImageHeroState();
}

class _ProductImageHeroState extends State<ProductImageHero> {
  int _currentIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    final selectedVariant = productProvider.selectedVariant;
    // Variant images first (already-correct variant-driven gallery); then
    // the product's own images; then the legacy single-image field.
    final List<String> images = selectedVariant?.images != null && selectedVariant!.images.isNotEmpty
        ? selectedVariant.images
        : (widget.product.images.isNotEmpty
            ? widget.product.images
            : (widget.product.imageUrl != null ? [widget.product.imageUrl!] : []));

    if (_currentIndex >= images.length) {
      // The image SET changed under us (new variant, or the product just
      // finished loading) -- don't point at a stale index into the new list.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = 0);
      });
      _currentIndex = 0;
    }

    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Column(
        children: [
          _buildImageCarousel(isDark, accentColor, images),
          const SizedBox(height: 10),
          _buildThumbnailStrip(isDark, accentColor, images),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(bool isDark, Color accentColor, List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 350,
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
      );
    }

    return CarouselSlider(
      carouselController: _carouselController,
      options: CarouselOptions(
        height: 350,
        viewportFraction: 1.0,
        enableInfiniteScroll: images.length > 1,
        onPageChanged: (index, reason) {
          setState(() => _currentIndex = index);
        },
      ),
      items: images.map((imageUrl) {
        final errorWidget = Icon(
          Icons.broken_image_rounded,
          size: 60,
          color: Colors.grey[400],
        );
        final loaderWidget = Center(
          child: CircularProgressIndicator(color: accentColor),
        );

        return Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: kIsWeb
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => errorWidget,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return loaderWidget;
                  },
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => loaderWidget,
                  errorWidget: (context, url, error) => errorWidget,
                ),
        );
      }).toList(),
    );
  }

  /// Tappable thumbnail row below the hero image -- tapping one jumps the
  /// carousel there. Replaces the old dots-only indicator (non-tappable).
  Widget _buildThumbnailStrip(bool isDark, Color accentColor, List<String> images) {
    if (images.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = _currentIndex == index;
          return GestureDetector(
            onTap: () => _carouselController.animateToPage(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: isActive ? 2 : 1,
                ),
                color: isDark ? const Color(0xFF232323) : Colors.grey[50],
              ),
              clipBehavior: Clip.antiAlias,
              child: kIsWeb
                  ? Image.network(
                      images[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 18),
                    )
                  : CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 18),
                    ),
            ),
          );
        },
      ),
    );
  }
}
