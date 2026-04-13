import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/wishlist_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'widgets/product_image_carousel.dart';
import 'widgets/product_image_hero.dart';
import 'widgets/specification_list.dart';
import 'widgets/reviews_section_inline.dart';
import 'widgets/variant_selector.dart';
import 'widgets/product_share_widget.dart';
import 'widgets/delivery_info_widget.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/product/unified_product_card.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  final ScrollController _scrollController = ScrollController();
  late DatabaseService _databaseService;

  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _databaseService = DatabaseService();
    _loadProduct();

    _scrollController.addListener(() {
      final isCollapsed = _scrollController.hasClients &&
          _scrollController.offset > 250;
      if (isCollapsed != _isCollapsed) {
        setState(() {
          _isCollapsed = isCollapsed;
        });
      }
    });
  }

  void _loadProduct() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<ProductProvider>(context, listen: false);
      provider.loadProductById(widget.productId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

/// Add product to cart with selected variant
Future<void> _addToCart(BuildContext context, {bool buyNow = false}) async {
  final productProvider = Provider.of<ProductProvider>(context, listen: false);
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final product = productProvider.selectedProduct;

  if (product == null || !product.inStock) return;

  HapticFeedback.mediumImpact();

  // Get selected variant if product has variants
  String? variantName;
  double? variantPrice;
  double? variantOriginalPrice;
  
  if (product.variants.isNotEmpty) {
    final selectedVariant = productProvider.selectedVariant;
    if (selectedVariant != null) {
      variantName = selectedVariant.name;
      variantPrice = selectedVariant.salePrice;
      variantOriginalPrice = selectedVariant.originalPrice;
      print('🔍 Selected variant: $variantName, price: $variantPrice');
    } else {
      // Show error if no variant selected
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select a variant',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
  }

  // ✅ FIX: Pass variant price to addItem
  await cartProvider.addItem(
    product,
    quantity: _quantity,
    variant: variantName,
    variantPrice: variantPrice,
    variantOriginalPrice: variantOriginalPrice,
  );

  // Show success message
  if (!buyNow && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                variantName != null 
                    ? 'Added $variantName to cart!' // ✅ Show variant in message
                    : 'Added to cart successfully!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () {
            AppRoutes.navigateTo(context, AppRoutes.cart);
          },
        ),
      ),
    );
  }

  // If Buy Now, navigate to cart immediately
  if (buyNow && mounted) {
    AppRoutes.navigateTo(context, AppRoutes.cart);
  }
}


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          final product = productProvider.selectedProduct;

          if (product == null || (productProvider.isLoading && product.name.isEmpty)) {
            return _buildLoadingState(isDark);
          }

          // ✅ REDESIGNED: Blinkit-style full-bleed image + floating controls
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                // Full-bleed image hero with floating action buttons
                ProductImageHero(
                  product: product,
                  onBack: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                  onShare: () => _showShareWidget(product),
                ),
                // Overlapped info card
                _buildOverlappedInfoCard(product, isDark),
                // Similar Products section
                _buildSimilarProducts(product, isDark),
                // Bottom padding for bottom bar
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSliverAppBar(ProductModel product, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _ProductDetailsSliverHeader(
        isCollapsed: _isCollapsed,
        product: product,
        isDark: isDark,
        accentColor: accentColor,
        onBack: () {
          // ✅ FIXED: Safe back navigation - go to home if can't pop
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        onShare: () => _showShareWidget(product),
        topPadding: MediaQuery.of(context).padding.top,
      ),
    );
  }

  void _showShareWidget(ProductModel product) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductShareWidget(product: product),
    );
  }

  Widget _buildProductShowcase(ProductModel product, bool isDark) {
    // Clean product image without card wrapper - matches Blinkit/Zepto style
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ProductImageCarousel(
        images: product.images.isNotEmpty
            ? product.images
            : (product.imageUrl != null ? [product.imageUrl!] : []),
      ),
    );
  }

  /// Blinkit-style overlapped info card with all product details
  Widget _buildOverlappedInfoCard(ProductModel product, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Transform.translate(
      offset: const Offset(0, -16), // Slight overlap with image
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Delivery badge + Rating
              _buildDeliveryRatingInline(product, isDark, accentColor),
              const SizedBox(height: 16),
              
              // Row 2: Product Name
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              
              // Row 3: "Select Unit" label + Variant chips
              if (product.variants.isNotEmpty) ...[
                Text(
                  'Select Unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 10),
                _buildVariantChipsInline(product, isDark, accentColor),
                const SizedBox(height: 16),
              ],
              
              // Row 4: Divider
              Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
              
              // Row 5: View product details (expandable)
              _buildViewDetailsDropdown(product, isDark, accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryRatingInline(ProductModel product, bool isDark, Color accentColor) {
    // Use cached product data directly - no FutureBuilder for performance
    final rating = product.rating;
    final reviewCount = product.reviewCount;

    return Row(
      children: [
        // Delivery badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_filled, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Text(
                '30 MINS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Star rating - use simple icons
        Row(
          children: [
            Icon(Icons.star, size: 14, color: Colors.amber),
            const SizedBox(width: 3),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${_formatCount(reviewCount)})',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariantChipsInline(ProductModel product, bool isDark, Color accentColor) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final selectedVariant = productProvider.selectedVariant;
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: product.variants.asMap().entries.map((entry) {
              final index = entry.key;
              final variant = entry.value;
              final isSelected = selectedVariant?.name == variant.name;
              final hasDiscount = variant.originalPrice != null && 
                                  variant.originalPrice! > variant.salePrice;

              return Padding(
                padding: EdgeInsets.only(right: index < product.variants.length - 1 ? 10 : 0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    productProvider.selectVariantByName(variant.name);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isDark ? accentColor.withOpacity(0.1) : Colors.white)
                          : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected 
                            ? accentColor 
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          variant.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${variant.salePrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 4),
                              Text(
                                'MRP ₹${variant.originalPrice!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildViewDetailsDropdown(ProductModel product, bool isDark, Color accentColor) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Row(
          children: [
            Text(
              'View product details',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.keyboard_arrow_down, color: accentColor, size: 20),
        children: [
          // Description
          if (product.description.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                product.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Specifications
          SpecificationList(
            specifications: _getSpecifications(product),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPremiumBadge(ProductModel product) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (product.discount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50],
                border: Border.all(color: isDark ? Colors.red[700]! : Colors.red[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer, size: 14, color: isDark ? Colors.red[400] : Colors.red[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${product.discount}% OFF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.red[400] : Colors.red[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50],
              border: Border.all(color: isDark ? Colors.orange[700]! : Colors.orange[300]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user, size: 14, color: isDark ? Colors.orange[400] : Colors.orange[700]),
                const SizedBox(width: 4),
                Text(
                  'Authentic',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orange[400] : Colors.orange[700],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeaderCard(ProductModel product, bool isDark) {
     final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildPremiumBadge(product),
              const SizedBox(height: 12),
              Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.3,
                  color: isDark ? Colors.white : Colors.black87
                ),
              ),
              const SizedBox(height: 16),
              _buildAdvancedPrice(product, isDark, accentColor),
              const SizedBox(height: 16),
              _buildRatingRow(product, isDark, accentColor),
          ],
        )
      ),
    );
  }

  Widget _buildAdvancedPrice(ProductModel product, bool isDark, Color accentColor) {
    // ✅ Use Consumer to react to variant selection changes
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final variant = productProvider.selectedVariant;
        
        // Use variant price if selected, otherwise base product price
        final displayPrice = variant?.salePrice ?? product.salePrice;
        final displayOriginal = variant?.originalPrice ?? product.originalPrice;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₹${displayPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            if (displayOriginal != null && displayOriginal > displayPrice)
              Text(
                '₹${displayOriginal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.lineThrough,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildRatingRow(ProductModel product, bool isDark, Color accentColor) {
    // Use cached product data - no FutureBuilder for performance
    final rating = product.rating;
    final reviewCount = product.reviewCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.star, color: isDark ? Colors.black : Colors.white, size: 14),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Highly Rated',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '$reviewCount customer reviews',
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])
        ],
      ),
    );
  }

  Widget _buildKeyInfoCard(ProductModel product, bool isDark) {
    // ✅ Use Consumer to react to variant selection changes  
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final variant = productProvider.selectedVariant;
        
        // Use variant stock if selected, otherwise base product stock
        final stock = variant?.stock ?? product.stock;
        final bool inStock = stock > 0;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildCardSection(
            isDark: isDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: inStock ? Colors.green[600] : Colors.red[600],
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      inStock ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: inStock ? Colors.green[600] : Colors.red[600],
                      ),
                    ),
                  ],
                ),

                if (inStock && stock < 10)
                  Text(
                    'Only $stock left!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else if (inStock)
                  Text(
                    'Available',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else 
                  const SizedBox(),
              ],
            )
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector(bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quantity',
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!)
              ),
              child: Row(
                children: [
                  _buildQuantityButton(
                    icon: Icons.remove,
                    onTap: () {
                      if (_quantity > 1) {
                        setState(() => _quantity--);
                        HapticFeedback.selectionClick();
                      }
                    },
                    isDark: isDark
                  ),
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Text(
                      _quantity.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  _buildQuantityButton(
                    icon: Icons.add,
                    onTap: () {
                      setState(() => _quantity++);
                      HapticFeedback.selectionClick();
                    },
                    isDark: isDark
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: isDark ? AppColors.primaryLight : AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required Widget child,
    required bool isDark,
    EdgeInsetsGeometry? padding,
    String? title,
    IconData? icon,
  }) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  Icon(icon, color: accentColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : Colors.black87
                    ),
                  ),
                ],
              ),
            ),
          if (title != null) 
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Section header for inline layout
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Description section (inline)
  Widget _buildDescriptionSection(ProductModel product, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Text(
          product.description.isNotEmpty 
              ? product.description 
              : 'No description available for this product.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            height: 1.6,
          ),
        ),
      ),
    );
  }
  
  // ✅ NEW: Specifications section (inline)
  Widget _buildSpecificationsSection(ProductModel product, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(0),
        child: SpecificationList(
          specifications: _getSpecifications(product), 
          isDark: isDark,
        ),
      ),
    );
  }

  // ✅ NEW: Reviews section (inline, with fixed height)
  Widget _buildReviewsSection(ProductModel product, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: ReviewsSectionInline(
          productId: product.id,
          productName: product.name,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final product = productProvider.selectedProduct;
        if (product == null) return const SizedBox.shrink();

        final selectedVariant = productProvider.selectedVariant;
        final displayPrice = selectedVariant?.salePrice ?? product.salePrice;
        final displayOriginal = selectedVariant?.originalPrice ?? product.originalPrice;
        final displayName = selectedVariant?.name ?? '';

        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              // Left: Variant info + Price with MRP strikeout + Offer badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Variant name
                    if (displayName.isNotEmpty)
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Price row with offer badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Sale Price
                        Text(
                          '₹${displayPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Strikeout MRP
                        if (displayOriginal != null && displayOriginal > displayPrice) ...[
                          Text(
                            '₹${displayOriginal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Offer badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '${((displayOriginal - displayPrice) / displayOriginal * 100).round()}% OFF',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Inclusive of all taxes',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: Add to Cart button
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  onPressed: !product.inStock ? null : () => _addToCart(context, buyNow: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: product.inStock ? accentColor : Colors.grey[400],
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: product.inStock ? 2 : 0,
                    shadowColor: accentColor.withOpacity(0.3),
                  ),
                  child: Text(
                    product.inStock ? 'Add to cart' : 'Out of Stock',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, String> _getSpecifications(ProductModel product) {
    final specs = <String, String>{};
    
    // Add actual product specifications from database
    if (product.specifications != null && product.specifications!.isNotEmpty) {
      specs.addAll(Map<String, String>.from(product.specifications!));
    }
    
    return specs;
  }

  // ✅ NEW: Delivery Badge + Rating Row (Blinkit style)
  Widget _buildDeliveryRatingRow(ProductModel product, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final rating = product.rating;
    final reviewCount = product.reviewCount;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Delivery time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  '30 MIN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Star rating - simplified, no FutureBuilder
          Row(
            children: [
              Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${_formatCount(reviewCount)})',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 100000) return '${(count / 100000).toStringAsFixed(2)} lac';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ✅ NEW: Product Name + Price (simplified)
  Widget _buildProductInfo(ProductModel product, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final variant = productProvider.selectedVariant;
        final displayPrice = variant?.salePrice ?? product.salePrice;
        final displayOriginal = variant?.originalPrice ?? product.originalPrice;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ NEW: Expandable Product Details
  Widget _buildExpandableDetails(ProductModel product, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          collapsedBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(
            Icons.info_outline_rounded,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            size: 20,
          ),
          title: Text(
            'View product details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ),
          children: [
            // Description
            if (product.description.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Specifications
            SpecificationList(
              specifications: _getSpecifications(product),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Similar Products horizontal scroll
  Widget _buildSimilarProducts(ProductModel product, bool isDark) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        // Get products from same category
        final similarProducts = productProvider.products
            .where((p) => p.categoryId == product.categoryId && p.id != product.id && p.isActive)
            .take(6)  // ✅ Limit to 6 products (3 columns x 2 rows)
            .toList();

        if (similarProducts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Similar products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            // ✅ Grid with simple inline cards - no gap
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.58,
                ),
                itemCount: similarProducts.length,
                itemBuilder: (context, index) {
                  return _buildSimilarProductCard(similarProducts[index], isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimilarProductCard(ProductModel product, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.salePrice;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, '/product/${product.id}');
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section - fills from top
            Expanded(
              child: Container(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,  // ✅ Fill from top
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 20),
                      ),
              ),
            ),
            // Info section - fixed height
            Container(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product name
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Prices
                  Text(
                    '₹${product.salePrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      '₹${product.originalPrice!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: isDark ? AppColors.primaryLight : AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading product...',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailsSliverHeader extends SliverPersistentHeaderDelegate {
  final bool isCollapsed;
  final ProductModel product;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final double topPadding;

  _ProductDetailsSliverHeader({
    required this.isCollapsed,
    required this.product,
    required this.isDark,
    required this.accentColor,
    required this.onBack,
    required this.onShare,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Cleaner app bar - matches Blinkit style with transparent/white background
    final Color iconColor = isDark ? Colors.white : Colors.black87;
    final Color iconBgColor = isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.15);

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
      decoration: BoxDecoration(
        // Transparent when expanded, solid when collapsed
        color: isCollapsed 
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
        boxShadow: isCollapsed ? [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHeaderIcon(icon: Icons.arrow_back_rounded, color: iconColor, bgColor: iconBgColor, onTap: onBack),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  product.name,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Consumer<WishlistProvider>(
                builder: (context, wishlistProvider, child) {
                  final isInWishlist = wishlistProvider.isInWishlist(product.id);
                  return _buildHeaderIcon(
                    icon: isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isInWishlist ? Colors.red : iconColor,
                    bgColor: iconBgColor,
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (isInWishlist) {
                        await wishlistProvider.removeItem(product.id);
                      } else {
                        await wishlistProvider.addItem(product);
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildHeaderIcon(icon: Icons.share_outlined, color: iconColor, bgColor: iconBgColor, onTap: onShare),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required Color color, required Color bgColor, required VoidCallback onTap}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  @override
  double get maxExtent => topPadding + 56; 
  @override
  double get minExtent => topPadding + 56;

  @override
  bool shouldRebuild(covariant _ProductDetailsSliverHeader oldDelegate) {
    return oldDelegate.isCollapsed != isCollapsed ||
           oldDelegate.product != product ||
           oldDelegate.isDark != isDark;
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.grey[50],
      padding: const EdgeInsets.only(top: 12),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
