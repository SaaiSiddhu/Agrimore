// lib/screens/user/shop/widgets/product_image_hero.dart
// Blinkit-style full-bleed image carousel with floating action buttons

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/wishlist_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/product_provider.dart';
import '../../../../app/routes.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductImageHero extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onBack;
  final VoidCallback? onShare;

  const ProductImageHero({
    Key? key,
    required this.product,
    required this.onBack,
    this.onShare,
  }) : super(key: key);

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
    final topPadding = MediaQuery.of(context).padding.top;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    final selectedVariant = productProvider.selectedVariant;
    List<String> images = selectedVariant?.images != null && selectedVariant!.images.isNotEmpty 
        ? selectedVariant.images 
        : (widget.product.images.isNotEmpty 
            ? widget.product.images 
            : (widget.product.imageUrl != null ? [widget.product.imageUrl!] : []));

    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Stack(
        children: [
          // IMAGE CAROUSEL - Full bleed
          Column(
            children: [
              // Space for safe area
              SizedBox(height: topPadding),
              // Image
              _buildImageCarousel(isDark, accentColor, images),
              // Small pagination dots - always show if multiple images
              _buildSmallDots(isDark, accentColor, images),
              const SizedBox(height: 8),
            ],
          ),

          // FLOATING ACTION BAR - Top overlay
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: _buildFloatingActionBar(isDark, accentColor),
          ),
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
          child: kIsWeb ? Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => errorWidget,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return loaderWidget;
            },
          ) : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => loaderWidget,
            errorWidget: (context, url, error) => errorWidget,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSmallDots(bool isDark, Color accentColor, List<String> images) {
    // Debug: print image count
    debugPrint('🖼️ Product images count: ${images.length}');
    debugPrint('🖼️ Images: $images');
    
    // Hide dots only if no images at all
    if (images.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: images.asMap().entries.map((entry) {
          final isActive = _currentIndex == entry.key;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 18 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? accentColor
                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingActionBar(bool isDark, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LEFT: Back button (left arrow)
        _buildActionButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            // Slide left animation
            Navigator.of(context).pop();
          },
          isDark: isDark,
          size: 20,
        ),
        
        // RIGHT: Search, Wishlist, Share
        Row(
          children: [
            // Search
            _buildActionButton(
              icon: Icons.search_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.search);
              },
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            
            // Wishlist
            Consumer<WishlistProvider>(
              builder: (context, wishlistProvider, _) {
                final isWishlisted = wishlistProvider.isInWishlist(widget.product.id);
                return _buildActionButton(
                  icon: isWishlisted ? Icons.favorite : Icons.favorite_outline,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    wishlistProvider.toggleItem(widget.product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isWishlisted ? 'Removed from wishlist' : 'Added to wishlist',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: isWishlisted ? Colors.grey[700] : Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  isDark: isDark,
                  iconColor: isWishlisted ? Colors.red : null,
                );
              },
            ),
            const SizedBox(width: 8),
            
            // Share
            _buildActionButton(
              icon: Icons.ios_share_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                if (widget.onShare != null) {
                  widget.onShare!();
                } else {
                  Share.share(
                    'Check out ${widget.product.name} on Agrimore!\n₹${widget.product.salePrice.toStringAsFixed(0)}',
                    subject: widget.product.name,
                  );
                }
              },
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
    double size = 22,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.black.withOpacity(0.5) 
              : Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size,
          color: iconColor ?? (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
