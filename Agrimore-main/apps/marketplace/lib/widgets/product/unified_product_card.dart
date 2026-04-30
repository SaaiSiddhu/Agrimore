import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/theme_provider.dart';

/// Layout variants for the unified product card
enum ProductCardLayout {
  /// Grid layout for home sections (width ~180, height ~360)
  grid,

  /// List layout for shop list view (horizontal with full width)
  list,

  /// Compact layout for recently viewed (width ~150, height ~220)
  compact,

  /// Horizontal layout for chat/carousels (width ~160)
  horizontal,

  /// Shop layout - edge-to-edge minimal design like Meesho/LetBuyy
  shop,

  /// Home layout - compact cards for home sections (image + name + price + badge)
  home,
}

/// Unified product card widget that replaces all scattered product card implementations.
/// 
/// Features:
/// - Multiple layout variants (grid, list, compact, horizontal)
/// - All product badges (discount, new, trending, featured, verified, variants)
/// - Wishlist and cart functionality with animations
/// - Dark mode support
/// - Delivery info display
/// - Rating display
class UnifiedProductCard extends StatefulWidget {
  final ProductModel product;
  final ProductCardLayout layout;
  final bool showWishlist;
  final bool showAddToCart;
  final bool showBadges;
  final bool showDeliveryInfo;
  final bool showRating;
  final VoidCallback? onTap;

  const UnifiedProductCard({
    Key? key,
    required this.product,
    this.layout = ProductCardLayout.grid,
    this.showWishlist = true,
    this.showAddToCart = true,
    this.showBadges = true,
    this.showDeliveryInfo = true,
    this.showRating = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<UnifiedProductCard> createState() => _UnifiedProductCardState();
}

class _UnifiedProductCardState extends State<UnifiedProductCard>
    with SingleTickerProviderStateMixin {
  late bool _isInWishlist;
  late bool _isInCart;
  bool _isProcessing = false;
  ProductVariant? _selectedVariant;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      _selectedVariant = widget.product.variants.first;
    }
    _updateStatus();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _updateStatus() {
    try {
      _isInWishlist = Provider.of<WishlistProvider>(context, listen: false)
          .isInWishlist(widget.product.id);
      _isInCart = Provider.of<CartProvider>(context, listen: false)
          .isInCart(widget.product.id, variant: _selectedVariant?.name);
    } catch (e) {
      _isInWishlist = false;
      _isInCart = false;
    }
  }

  void _navigateToProductDetails() {
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.pushNamed(context, '/product/${widget.product.id}');
    }
  }

  Future<void> _handleAddToCart() async {
    if (_isProcessing) return;

    if (widget.product.stock == 0 && (_selectedVariant == null || !_selectedVariant!.inStock)) {
      _showSnackbar('This product is out of stock', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (widget.product.variants.isNotEmpty && _selectedVariant == null) {
      setState(() => _isProcessing = false);
      _showSnackbar(
        'Please select an option first.',
        isWarning: true,
      );
      return;
    }

    try {
      await cartProvider.addItem(
        widget.product, 
        quantity: 1,
        variant: _selectedVariant?.name,
        variantPrice: _selectedVariant?.salePrice,
        variantOriginalPrice: _selectedVariant?.originalPrice,
      );
      if (mounted) _showSnackbar('Added to cart successfully');
    } catch (e) {
      debugPrint('❌ Cart error: $e');
      if (mounted) _showSnackbar('Failed to add item to cart', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false, bool isWarning = false}) {
    final color = isError
        ? Colors.red.shade600
        : isWarning
            ? Colors.orange.shade600
            : Colors.green.shade600;
    final icon = isError
        ? FontAwesomeIcons.circleExclamation
        : isWarning
            ? FontAwesomeIcons.circleInfo
            : FontAwesomeIcons.solidCircleCheck;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Consumer2<CartProvider, WishlistProvider>(
      builder: (context, cartProvider, wishlistProvider, child) {
        try {
          _isInWishlist = wishlistProvider.isInWishlist(widget.product.id);
          _isInCart = cartProvider.isInCart(widget.product.id, variant: _selectedVariant?.name);
        } catch (e) {
          _isInWishlist = false;
          _isInCart = false;
        }

        return ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: (_) => _scaleController.forward(),
            onTapUp: (_) {
              _scaleController.reverse();
              _navigateToProductDetails();
            },
            onTapCancel: () => _scaleController.reverse(),
            child: _buildLayout(isDark, wishlistProvider, cartProvider),
          ),
        );
      },
    );
  }

  Widget _buildLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    switch (widget.layout) {
      case ProductCardLayout.grid:
        return _buildGridLayout(isDark, wishlistProvider, cartProvider);
      case ProductCardLayout.list:
        return _buildListLayout(isDark, wishlistProvider, cartProvider);
      case ProductCardLayout.compact:
        return _buildCompactLayout(isDark, wishlistProvider, cartProvider);
      case ProductCardLayout.horizontal:
        return _buildHorizontalLayout(isDark, wishlistProvider, cartProvider);
      case ProductCardLayout.shop:
        return _buildShopLayout(isDark, wishlistProvider, cartProvider);
      case ProductCardLayout.home:
        return _buildHomeLayout(isDark, wishlistProvider, cartProvider);
    }
  }

  // ============================================
  // GRID LAYOUT (for home sections)
  // ============================================
  Widget _buildGridLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    final discount = widget.product.discount;
    final hasDiscount = discount > 0;
    final hasVariants = widget.product.variants.isNotEmpty;
    final showStockBadge = widget.product.stock < 5;
    final isNew = widget.product.isNew;
    final isTrending = widget.product.isTrending;
    final isFeatured = widget.product.isFeatured;
    final isVerified = widget.product.isVerified;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDarkTheme : AppColors.borderLight,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowMedium : AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (55%)
            Expanded(
              flex: 55,
              child: Stack(
                children: [
                  _buildProductImage(isDark, isGrid: true),

                  // Left badges (discount, new)
                  if (widget.showBadges)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount) _buildDiscountBadge(discount),
                          if (isNew) ...[
                            const SizedBox(height: 4),
                            _buildBadge('NEW', Colors.green[600]!),
                          ],
                        ],
                      ),
                    ),

                  // Right badges (variants, trending, featured, verified)
                  if (widget.showBadges)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (hasVariants) _buildVariantBadge(isDark),
                          if (isTrending) ...[
                            const SizedBox(height: 4),
                            _buildIconBadge(FontAwesomeIcons.arrowTrendUp, Colors.purple),
                          ],
                          if (isFeatured) ...[
                            const SizedBox(height: 4),
                            _buildIconBadge(FontAwesomeIcons.solidStar, Colors.orange.shade700),
                          ],
                          if (isVerified) ...[
                            const SizedBox(height: 4),
                            _buildIconBadge(FontAwesomeIcons.check, Colors.blue.shade600),
                          ],
                        ],
                      ),
                    ),

                  // Wishlist button
                  if (widget.showWishlist)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _buildWishlistButton(wishlistProvider, isDark),
                    ),
                ],
              ),
            ),

            // Info section (45%)
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end, // Align to bottom
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Name
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: isDark ? Colors.white : const Color(0xFF0D1B2A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Rating
                    if (widget.showRating) _buildRatingRow(isDark, isCompact: true),
                    const SizedBox(height: 4),

                    // Price
                    _buildPriceRow(isDark),
                    const SizedBox(height: 4),

                    // Variant Dropdown
                    if (widget.product.variants.isNotEmpty) ...[
                      _buildVariantDropdown(isDark),
                      const SizedBox(height: 4),
                    ],

                    // Delivery
                    if (widget.showDeliveryInfo) _buildDeliveryInfo(isDark),
                    const SizedBox(height: 6),

                    // Stock badge
                    if (showStockBadge && widget.showBadges) ...[
                      _buildStockBadge(isDark),
                      const SizedBox(height: 6),
                    ],

                    // Add to cart - always at the bottom
                    if (widget.showAddToCart)
                      SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: _buildAddToCartButton(cartProvider, isDark),
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

  // ============================================
  // LIST LAYOUT (for shop list view)
  // ============================================
  Widget _buildListLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDarkTheme : AppColors.borderLight,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowMedium : AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildProductImage(isDark, isGrid: false),
                ),
              ),
              if (widget.showWishlist)
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildWishlistButton(wishlistProvider, isDark, size: 28),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.showRating) _buildRatingRow(isDark),
                const SizedBox(height: 6),
                _buildPriceRow(isDark),
                const SizedBox(height: 6),
                if (widget.product.variants.isNotEmpty) ...[
                  _buildVariantDropdown(isDark),
                  const SizedBox(height: 6),
                ],
                if (widget.showBadges) _buildBadgesRow(isDark),
                const SizedBox(height: 8),
                if (widget.showDeliveryInfo) _buildDeliveryInfo(isDark),
                const SizedBox(height: 10),
                if (widget.showAddToCart)
                  SizedBox(
                    height: 36,
                    width: double.infinity,
                    child: _buildAddToCartButton(cartProvider, isDark, isExpanded: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // COMPACT LAYOUT (for recently viewed)
  // ============================================
  Widget _buildCompactLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: _buildProductImage(isDark, isGrid: false),
            ),
          ),

          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${widget.product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HORIZONTAL LAYOUT (for chat/carousels)
  // ============================================
  Widget _buildHorizontalLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    final discount = widget.product.discount;
    final hasDiscount = discount > 0;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[100]!, Colors.grey[50]!],
                    ),
                  ),
                  child: _buildProductImage(isDark, isGrid: false),
                ),
              ),

              // Discount badge
              if (hasDiscount && widget.showBadges)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildDiscountBadge(discount),
                ),

              // Wishlist button
              if (widget.showWishlist)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildWishlistButton(wishlistProvider, isDark, size: 32),
                ),

              // Out of stock overlay
              if (widget.product.stock == 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: const Center(
                      child: Text(
                        'OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Details section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  if (widget.showRating && widget.product.rating > 0)
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 3),
                        Text(
                          widget.product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${widget.product.reviewCount})',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),

                  const Spacer(),

                  // Price
                  Row(
                    children: [
                      Text(
                        '₹${widget.product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (widget.product.originalPrice != null &&
                          widget.product.originalPrice! > widget.product.price)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '₹${widget.product.originalPrice!.toStringAsFixed(2)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Action buttons
                  if (widget.showAddToCart)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: _buildAddToCartButton(cartProvider, isDark, isCompact: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: widget.product.stock > 0
                                  ? () async {
                                      HapticFeedback.mediumImpact();
                                      final cartProvider = Provider.of<CartProvider>(context, listen: false);
                                      if (!_isInCart) {
                                        await cartProvider.addItem(widget.product, quantity: 1);
                                      }
                                      if (mounted) {
                                        Navigator.pushNamed(context, '/cart');
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.flash_on, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SHOP LAYOUT (Meesho/LetBuyy style - compact, professional)
  // ============================================
  Widget _buildShopLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    final discount = widget.product.discount;
    final hasDiscount = discount > 0;
    final isVerified = widget.product.isVerified;
    final hasFreeDelivery = (widget.product.shippingPrice ?? 0) == 0;
    final isOutOfStock = widget.product.stock == 0;

    return Container(
      // Subtle border for separation
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section - Compact 72% ratio
          Expanded(
            flex: widget.product.variants.isNotEmpty ? 62 : 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Product Image - edge to edge
                _buildProductImage(isDark, isGrid: false),

                // Out of stock overlay
                if (isOutOfStock)
                  Container(
                    color: Colors.black.withOpacity(0.55),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Discount badge - top left (compact green pill)
                if (hasDiscount && widget.showBadges)
                  Positioned(
                    top: 6,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                // Wishlist button - compact circular
                if (widget.showWishlist)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        if (_isInWishlist) {
                          await wishlistProvider.removeFromWishlist(widget.product.id);
                        } else {
                          await wishlistProvider.addToWishlist(widget.product);
                        }
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isInWishlist ? Icons.favorite : Icons.favorite_border,
                          size: 15,
                          color: _isInWishlist ? Colors.red : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Info section - Compact 28% with tight spacing
          Expanded(
            flex: widget.product.variants.isNotEmpty ? 38 : 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Product name - single line, compact
                  Text(
                    widget.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),

                  // Price row with rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price section - compact
                      Text(
                        '₹${(_selectedVariant?.salePrice ?? widget.product.price).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if ((_selectedVariant?.originalPrice ?? widget.product.originalPrice) != null &&
                          (_selectedVariant?.originalPrice ?? widget.product.originalPrice)! > (_selectedVariant?.salePrice ?? widget.product.price)) ...[
                        const SizedBox(width: 5),
                        Text(
                          '₹${(_selectedVariant?.originalPrice ?? widget.product.originalPrice)!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey[500],
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Rating - compact pill
                      if (widget.showRating && widget.product.rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 11, color: Colors.amber[700]),
                              const SizedBox(width: 2),
                              Text(
                                widget.product.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  if (widget.product.variants.isNotEmpty) ...[
                    _buildVariantDropdown(isDark),
                  ],

                  // Bottom row: Verified badge + Free Delivery - compact
                  Row(
                    children: [
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 10,
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isVerified && hasFreeDelivery) const SizedBox(width: 4),
                      if (hasFreeDelivery)
                        Text(
                          'Free Delivery',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00C853),
                          ),
                        ),
                    ],
                  ),
                  if (widget.showAddToCart) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: FilledButton(
                        onPressed: isOutOfStock || _isProcessing
                            ? null
                            : () => _handleAddToCart(),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                          foregroundColor: isDark ? Colors.black87 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          _isInCart ? 'In cart' : 'Add to cart',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HOME LAYOUT (Compact cards for home sections)
  // ============================================
  Widget _buildHomeLayout(bool isDark, WishlistProvider wishlistProvider, CartProvider cartProvider) {
    final discount = widget.product.discount;
    final hasDiscount = discount > 0;
    final isOutOfStock = widget.product.stock == 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section - 70% of card
            Expanded(
              flex: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Product Image
                  _buildProductImage(isDark, isGrid: true),

                  // Out of stock overlay
                  if (isOutOfStock)
                    Container(
                      color: Colors.black.withOpacity(0.6),
                      child: const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Discount badge - small pill at top-left
                  if (hasDiscount && widget.showBadges)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info section - 30% of card (compact)
            Expanded(
              flex: 30,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name - max 2 lines
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                    ),

                    // Price row
                    Row(
                      children: [
                        // Current price
                        Text(
                          '₹${widget.product.salePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                        // Original price (strikethrough)
                        if (hasDiscount) ...[
                          const SizedBox(width: 4),
                          Text(
                            '₹${widget.product.originalPrice!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
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

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildProductImage(bool isDark, {required bool isGrid}) {
    final imageUrl = widget.product.imageUrl;

    final errorWidget = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
              : [const Color(0xFFF5F5F5), const Color(0xFFE8E8E8)],
        ),
      ),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.image,
          size: 40,
          color: isDark ? Colors.grey[700] : Colors.grey[400],
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget;
    }

    final loaderWidget = Center(
      child: CircularProgressIndicator(
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        strokeWidth: 2.5,
      ),
    );

    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: isGrid ? BoxFit.cover : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => errorWidget,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return loaderWidget;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => loaderWidget,
      errorWidget: (context, url, error) => errorWidget,
    );
  }

  Widget _buildDiscountBadge(int discount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red[600]!, Colors.red[500]!],
        ),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '-$discount%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FaIcon(icon, size: 9, color: Colors.white),
    );
  }

  Widget _buildVariantBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.layerGroup, size: 8, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '${widget.product.variants.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(bool isDark) {
    final isOutOfStock = widget.product.stock == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? (isDark ? Colors.red[900]!.withOpacity(0.7) : Colors.red[600])
            : Colors.red.shade100.withOpacity(isDark ? 0.3 : 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isOutOfStock
              ? (isDark ? Colors.red[400]! : Colors.red[700]!)
              : Colors.red.withOpacity(isDark ? 0.4 : 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        isOutOfStock ? 'Out of Stock' : 'Only ${widget.product.stock}',
        style: TextStyle(
          color: isOutOfStock ? Colors.white : Colors.red[isDark ? 300 : 700],
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRatingRow(bool isDark, {bool isCompact = false}) {
    final rating = widget.product.rating;
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (index) {
          if (index < fullStars) {
            return FaIcon(FontAwesomeIcons.solidStar, color: Colors.amber, size: 14);
          } else if (index == fullStars && hasHalfStar) {
            return FaIcon(FontAwesomeIcons.solidStarHalfStroke, color: Colors.amber, size: 14);
          } else {
            return FaIcon(FontAwesomeIcons.star, color: Colors.grey[400], size: 14);
          }
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(width: 4),
          Text(
            '(${widget.product.reviewCount})',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceRow(bool isDark) {
    final currentPrice = _selectedVariant?.salePrice ?? widget.product.price;
    final currentOriginalPrice = _selectedVariant?.originalPrice ?? widget.product.originalPrice;
    final discount = _selectedVariant?.discount ?? widget.product.discount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (discount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-$discount%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (discount > 0) const SizedBox(width: 8),
        Text(
          '₹${currentPrice.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
        if (currentOriginalPrice != null && currentOriginalPrice > currentPrice) ...[
          const SizedBox(width: 8),
          Text(
            '₹${currentOriginalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariantDropdown(bool isDark) {
    if (widget.product.variants.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductVariant>(
          value: _selectedVariant,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          dropdownColor: isDark ? Colors.grey[850] : Colors.white,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (ProductVariant? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedVariant = newValue;
                _updateStatus();
              });
            }
          },
          items: widget.product.variants.map((ProductVariant variant) {
            return DropdownMenuItem<ProductVariant>(
              value: variant,
              child: Text(
                variant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBadgesRow(bool isDark) {
    final isTrending = widget.product.isTrending;
    final isFeatured = widget.product.isFeatured;

    if (!isTrending && !isFeatured) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      children: [
        if (isTrending)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade300, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.arrowTrendUp, size: 12, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Trending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        if (isFeatured)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.shade300, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.solidStar, size: 12, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  'Featured',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeliveryInfo(bool isDark) {
    final standardDays = widget.product.shippingDays;
    final isStandardFree = widget.product.isFreeDelivery ?? false;
    final isExpressEnabled = widget.product.expressDelivery ?? false;
    final expressDays = widget.product.expressDeliveryDays;

    final hasStandard = standardDays != null && standardDays.isNotEmpty;
    final hasExpress = isExpressEnabled && expressDays != null && expressDays.isNotEmpty;

    if (!hasStandard && !hasExpress) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasStandard)
          _buildDeliveryRow(
            isDark,
            icon: FontAwesomeIcons.truck,
            iconColor: Colors.green.shade700,
            title: 'Standard:',
            time: '$standardDays Days',
            isFree: isStandardFree,
          ),
        if (hasStandard && hasExpress) const SizedBox(height: 4),
        if (hasExpress)
          _buildDeliveryRow(
            isDark,
            icon: FontAwesomeIcons.boltLightning,
            iconColor: Colors.orange.shade700,
            title: 'Express:',
            time: '$expressDays Days',
            isFree: false,
          ),
      ],
    );
  }

  Widget _buildDeliveryRow(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    required bool isFree,
  }) {
    return Row(
      children: [
        FaIcon(icon, size: 12, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  time,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
              if (isFree) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green[800] : Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? Colors.green[600]! : Colors.green[300]!,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.green[100] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWishlistButton(WishlistProvider wishlistProvider, bool isDark, {double size = 32}) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        try {
          if (_isInWishlist) {
            await wishlistProvider.removeItem(widget.product.id);
          } else {
            await wishlistProvider.addItem(widget.product);
          }
        } catch (e) {
          debugPrint('❌ Wishlist error: $e');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _isInWishlist
              ? Colors.red[50]
              : (isDark ? Colors.grey[850]!.withOpacity(0.96) : Colors.white.withOpacity(0.96)),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isInWishlist
                ? Colors.red[200]!
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: FaIcon(
            _isInWishlist ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
            key: ValueKey<bool>(_isInWishlist),
            color: _isInWishlist
                ? Colors.red[600]
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAddToCartButton(CartProvider cartProvider, bool isDark,
      {bool isExpanded = false, bool isCompact = false}) {
    final hasVariants = widget.product.variants.isNotEmpty;
    final isOutOfStock = widget.product.stock == 0;

    return Material(
      color: isOutOfStock
          ? Colors.grey[500]
          : _isInCart
              ? Colors.green[600]
              : (isDark ? AppColors.primaryLight : AppColors.primary),
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: InkWell(
        onTap: _isProcessing || isOutOfStock || (_isInCart && !hasVariants)
            ? null
            : _handleAddToCart,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: Center(
            child: _isProcessing
                ? SizedBox(
                    width: isCompact ? 14 : 20,
                    height: isCompact ? 14 : 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        isOutOfStock
                            ? FontAwesomeIcons.ban
                            : _isInCart
                                ? FontAwesomeIcons.cartShopping
                                : (hasVariants
                                    ? FontAwesomeIcons.handPointer
                                    : FontAwesomeIcons.cartPlus),
                        color: Colors.white,
                        size: isCompact ? 12 : 16,
                      ),
                      if (!isCompact || isExpanded) ...[
                        const SizedBox(width: 4),
                        Text(
                          isOutOfStock
                              ? (isExpanded ? 'Out of Stock' : 'Sold Out')
                              : _isInCart
                                  ? 'In Cart'
                                  : (hasVariants
                                      ? (isExpanded ? 'Select Options' : 'Select')
                                      : (isExpanded ? 'Add to Cart' : 'Add')),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isExpanded ? 14 : 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
