import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart'; // For BackdropFilter
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:intl/intl.dart'; // No longer needed

import '../../../../app/themes/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/wishlist_provider.dart';
import '../../../../providers/theme_provider.dart';


class ProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isGridView;


  const ProductCard({
    Key? key,
    required this.product,
    this.isGridView = false, // Default matches MobileShopScreen
  }) : super(key: key);


  @override
  State<ProductCard> createState() => _ProductCardState();
}


class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  late bool _isInWishlist;
  late bool _isInCart;
  bool _isProcessing = false;
  
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;


  @override
  void initState() {
    super.initState();
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
          .isInCart(widget.product.id);
    } catch (e) {
      _isInWishlist = false;
      _isInCart = false;
    }
  }


  Future<void> _handleAddToCart() async {
    if (_isProcessing) return;
    
    // Do not allow adding to cart if out of stock
    if (widget.product.stock == 0) {
       _showOutOfStockSnackbar();
      return;
    }
    
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();


    final cartProvider = Provider.of<CartProvider>(context, listen: false);


    if (widget.product.variants.isNotEmpty) {
      setState(() => _isProcessing = false);
      _showVariantSelectionPrompt();
      return;
    }


    try {
      await cartProvider.addItem(widget.product, quantity: 1);
      if (mounted) _showSuccessSnackbar();
    } catch (e) {
      debugPrint('❌ Cart error: $e');
      if (mounted) _showErrorSnackbar();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }


  void _showVariantSelectionPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleInfo, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '${widget.product.variants.length} options available. Please select one.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Select',
          textColor: Colors.white,
          onPressed: _navigateToProductDetails,
        ),
      ),
    );
    Future.delayed(Duration(milliseconds: 600), () {
      if (mounted) _navigateToProductDetails();
    });
  }


  void _navigateToProductDetails() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/product/${widget.product.id}');
  }


  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.solidCircleCheck, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Added to cart successfully',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }


  void _showErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleExclamation, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Failed to add item to cart',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }


  void _showOutOfStockSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.ban, color: Colors.white, size: 20), // ✅ FIXED
            SizedBox(width: 12),
            Text(
              'This product is out of stock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
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
          _isInCart = cartProvider.isInCart(widget.product.id);
        } catch (e) {
          _isInWishlist = false;
          _isInCart = false;
        }


        if (widget.isGridView) {
          // --- GRID VIEW ---
          return ScaleTransition(
            scale: _scaleAnimation,
            child: InkWell(
              onTap: () {
                _scaleController.forward().then((_) => _scaleController.reverse());
                HapticFeedback.lightImpact();
                _navigateToProductDetails();
              },
              onTapDown: (_) => _scaleController.forward(),
              onTapUp: (_) => _scaleController.reverse(),
              onTapCancel: () => _scaleController.reverse(),
              borderRadius: BorderRadius.circular(16),
              splashColor: (isDark ? AppColors.primaryLight : AppColors.primary)
                  .withOpacity(0.1),
              child: _buildGridLayout(wishlistProvider, cartProvider, isDark),
            ),
          );
        } else {
          // --- LIST VIEW ---
          return InkWell(
            onTap: _navigateToProductDetails,
            borderRadius: BorderRadius.circular(12),
            child: _buildAmazonListLayout(isDark),
          );
        }
      },
    );
  }


  // ===================================================================
  // ✅ AMAZON-STYLE LIST LAYOUT
  // ===================================================================


  Widget _buildAmazonListLayout(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDarkTheme : AppColors.borderLight,
          width: 0.5,
        ),
        boxShadow: [ // Soft shadow for list view
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
          // LEFT: Product Image
          _buildListProductImage(isDark),
          SizedBox(width: 12),
          
          // RIGHT: Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductName(isDark),
                SizedBox(height: 6),
                _buildRatingRow(isDark),
                SizedBox(height: 6),
                _buildPriceRow(isDark),
                SizedBox(height: 8),
                _buildBadgesRow(isDark),
                SizedBox(height: 8),
                _buildDeliveryInfo(isDark), 
                SizedBox(height: 10),
                _buildListAddToCartButton(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // --- List View Helpers ---


  Widget _buildListProductImage(bool isDark) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF2A2A2A) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => FaIcon(FontAwesomeIcons.image, size: 40, color: Colors.grey[700]),
                  )
                : FaIcon(FontAwesomeIcons.image, size: 40, color: Colors.grey[700]),
          ),
        ),
        // Wishlist button for List View
        Positioned(
          top: 4,
          right: 4,
          child: _buildWishlistButton(Provider.of<WishlistProvider>(context, listen: false), isDark, size: 28),
        )
      ],
    );
  }


  Widget _buildProductName(bool isDark) {
    return Text(
      widget.product.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
        height: 1.3,
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
        SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        if (!isCompact) ...[
          SizedBox(width: 4),
          Text(
            '(${widget.product.reviewCount})',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ]
      ],
    );
  }


  Widget _buildPriceRow(bool isDark) {
    final discount = widget.product.discount ?? 0;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (discount > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-$discount%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (discount > 0) SizedBox(width: 8),
        Text(
          '₹${widget.product.price.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
        if (widget.product.originalPrice != null && widget.product.originalPrice! > widget.product.price) ...[
          SizedBox(width: 8),
          Text(
            '₹${widget.product.originalPrice!.toStringAsFixed(0)}',
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


  Widget _buildBadgesRow(bool isDark) {
    final isTrending = widget.product.isTrending ?? false;
    final isFeatured = widget.product.isFeatured ?? false;


    if (!isTrending && !isFeatured) return SizedBox.shrink();


    return Wrap(
      spacing: 6,
      children: [
        if (isTrending)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade300, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.arrowTrendUp, size: 12, color: Colors.orange.shade700),
                SizedBox(width: 4),
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
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.shade300, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.solidStar, size: 12, color: Colors.blue.shade700),
                SizedBox(width: 4),
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

    if (!hasStandard && !hasExpress) {
      return SizedBox.shrink(); // Hide if no delivery info
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasStandard)
          _buildDeliveryInfoRow(
            isDark,
            icon: FontAwesomeIcons.truck,
            iconColor: Colors.green.shade700,
            title: 'Standard:',
            time: '$standardDays Days',
            isFree: isStandardFree,
          ),
        if (hasStandard && hasExpress)
          SizedBox(height: 4),
        if (hasExpress)
          _buildDeliveryInfoRow(
            isDark,
            icon: FontAwesomeIcons.boltLightning,
            iconColor: Colors.orange.shade700,
            title: 'Express:',
            time: '$expressDays Days',
            isFree: false, // Assuming express is never free
          ),
      ],
    );
  }

  Widget _buildDeliveryInfoRow(bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    required bool isFree,
  }) {
    return Row(
      children: [
        FaIcon(icon, size: 12, color: iconColor),
        SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
        SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        if (isFree) ...[
          SizedBox(width: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? Colors.green[800] : Colors.green[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDark ? Colors.green[600]! : Colors.green[300]!, 
                width: 0.5
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
          )
        ]
      ],
    );
  }


  Widget _buildListAddToCartButton(bool isDark) {
    final hasVariants = widget.product.variants.isNotEmpty;
    final isOutOfStock = widget.product.stock == 0;
    
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing || isOutOfStock ? null : _handleAddToCart,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutOfStock
              ? Colors.grey[500]
              : _isInCart
                  ? Colors.green.shade600
                  : (isDark ? AppColors.primaryLight : AppColors.primary),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon( 
                    isOutOfStock
                        ? FontAwesomeIcons.ban // ✅ FIXED
                        : _isInCart 
                            ? FontAwesomeIcons.cartShopping 
                            : (hasVariants ? FontAwesomeIcons.handPointer : FontAwesomeIcons.cartPlus),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isOutOfStock
                        ? 'Out of Stock'
                        : _isInCart 
                            ? 'In Cart' 
                            : (hasVariants ? 'Select Options' : 'Add to Cart'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }



  // ===================================================================
  // ✅ UPDATED: GRID VIEW LAYOUT
  // ===================================================================


  Widget _buildGridLayout(
    WishlistProvider wishlistProvider,
    CartProvider cartProvider,
    bool isDark,
  ) {
    final discount = widget.product.discount ?? 0;
    final hasDiscount = discount > 0;
    final hasVariants = widget.product.variants.isNotEmpty;
    final showStockBadge = widget.product.stock < 5; 
    
    final isNew = widget.product.isNew ?? false;
    final isTrending = widget.product.isTrending ?? false;
    final isFeatured = widget.product.isFeatured ?? false;
    final isVerified = widget.product.isVerified ?? false;


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
            spreadRadius: 0,
          ),
          BoxShadow(
            color: (isDark ? AppColors.primaryLight : AppColors.primary)
                .withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect( 
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 55, 
              child: Stack(
                children: [
                  _buildGridImage(isDark), 
                  
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount)
                          _buildDiscountBadge(discount),
                        if (isNew) ...[
                          const SizedBox(height: 4),
                          _buildNewBadge(isDark),
                        ],
                      ],
                    ),
                  ),


                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasVariants)
                          _buildVariantBadge(isDark),
                        if (isTrending) ...[
                          const SizedBox(height: 4),
                          _buildTrendingBadge(isDark),
                        ],
                         if (isFeatured) ...[
                          const SizedBox(height: 4),
                          _buildFeaturedBadge(isDark),
                        ],
                         if (isVerified) ...[
                          const SizedBox(height: 4),
                          _buildVerifiedBadge(isDark),
                        ],
                      ],
                    ),
                  ),
                  
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildWishlistButton(wishlistProvider, isDark),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    
                    _buildRatingRow(isDark, isCompact: true), // Compact version
                    const SizedBox(height: 4),
                    
                    _buildPriceRow(isDark), 
                    const SizedBox(height: 4),
                    
                    _buildDeliveryInfo(isDark), // Dynamic delivery info

                    const Spacer(), // Pushes button to bottom
                    
                    if (showStockBadge) ...[
                       _buildStockBadge(isDark, isCompact: true),
                       const SizedBox(height: 6),
                    ],

                    SizedBox(
                      height: 30,
                      width: double.infinity,
                      child: _buildGridAddToCartButton(cartProvider, isDark),
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
  
  // --- Grid View Helpers ---
  
  Widget _buildGridImage(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
              : [const Color(0xFFFAFAFA), const Color(0xFFF0F0F0)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: widget.product.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.product.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
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
                ),
              )
            : Container(
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
              ),
      ),
    );
  }


  Widget _buildDiscountBadge(int discount, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 7,
        vertical: isCompact ? 2 : 3,
      ),
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
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompact ? 9 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }


  Widget _buildNewBadge(bool isDark, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 7,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.green[600],
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompact ? 9 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }


  Widget _buildVariantBadge(bool isDark, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 6,
        vertical: isCompact ? 2 : 3,
      ),
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
          FaIcon(
            FontAwesomeIcons.layerGroup,
            size: isCompact ? 7 : 8,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '${widget.product.variants.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 8 : 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTrendingBadge(bool isDark, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 6,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FaIcon(
        FontAwesomeIcons.arrowTrendUp,
        size: isCompact ? 8 : 9,
        color: Colors.white,
      ),
    );
  }


  Widget _buildFeaturedBadge(bool isDark, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 6,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade700.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
       child: FaIcon(
        FontAwesomeIcons.solidStar,
        size: isCompact ? 8 : 9,
        color: Colors.white,
      ),
    );
  }


   Widget _buildVerifiedBadge(bool isDark, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 6,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade600.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
       child: FaIcon(
        FontAwesomeIcons.check,
        size: isCompact ? 8 : 9,
        color: Colors.white,
      ),
    );
  }



  Widget _buildStockBadge(bool isDark, {bool isCompact = false}) {
    final bool isOutOfStock = widget.product.stock == 0;


    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 5,
        vertical: isCompact ? 2 : 3,
      ),
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
          color: isOutOfStock 
              ? Colors.white 
              : Colors.red[isDark ? 300 : 700],
          fontSize: isCompact ? 7 : 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // NOTE: This helper is not used by the grid view
  // Widget _buildGridRatingBadge(bool isDark, {bool isCompact = false}) { ... }

  // NOTE: This helper is not used by the grid view
  // Widget _buildGridPriceSection(bool isDark, {bool isCompact = false}) { ... }


  Widget _buildWishlistButton(
    WishlistProvider wishlistProvider,
    bool isDark, {
    double size = 32,
  }) {
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
              : (isDark
                  ? Colors.grey[850]!.withOpacity(0.96)
                  : Colors.white.withOpacity(0.96)),
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


  Widget _buildGridAddToCartButton(CartProvider cartProvider, bool isDark) {
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
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        isOutOfStock 
                            ? FontAwesomeIcons.ban // ✅ FIXED
                            : _isInCart
                                ? FontAwesomeIcons.cartShopping
                                : (hasVariants
                                    ? FontAwesomeIcons.handPointer
                                    : FontAwesomeIcons.cartPlus),
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOutOfStock 
                            ? 'Sold Out'
                            : _isInCart
                                ? 'In Cart'
                                : (hasVariants ? 'Select' : 'Add'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1, 
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}