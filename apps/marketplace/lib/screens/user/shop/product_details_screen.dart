import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../providers/address_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'widgets/product_image_hero.dart';
import 'widgets/specification_list.dart';
import 'widgets/reviews_section_inline.dart';
import 'widgets/product_share_widget.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/cart_fly_animation.dart';
import '../rfq/widgets/request_quote_sheet.dart';

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
  final ScrollController _scrollController = ScrollController();
  // Key for the Add-to-Cart button -- used to get its screen position for fly animation
  final GlobalKey _addToCartKey = GlobalKey();

  bool _isCollapsed = false;
  /// `one_off`, `daily`, or `weekly` -- forwarded to checkout (auto-delivery).
  /// Driven by `_subscribeChecked`: unchecked always means `one_off`;
  /// checked keeps whichever of daily/weekly was last chosen (defaults to
  /// daily the first time it's checked).
  String _subscriptionCadence = 'one_off';
  bool _subscribeChecked = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
    // Fire-and-forget, same pattern as CategoryProvider elsewhere on this
    // screen tree: loadAddresses() is idempotent-safe and most navigations
    // here arrive from a screen (home/checkout) that already loaded them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AddressProvider>().loadAddresses();
    });

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

  /// Adds the selected variant (or the base product, if it has none) to the
  /// cart at quantity 1. The sticky bottom bar transforms into a `[-] N [+]`
  /// stepper once the item is in the cart (see `_buildBottomBar`) -- matching
  /// this app's own established quick-commerce add-then-adjust pattern
  /// rather than asking for a quantity before the first add.
  Future<void> _addToCart(BuildContext context) async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final product = productProvider.selectedProduct;

    if (product == null || !product.inStock) return;

    if (_subscriptionCadence == 'daily') {
      cartProvider.setCheckoutSubscriptionIntent('Auto Delivery', 'Daily');
    } else if (_subscriptionCadence == 'weekly') {
      cartProvider.setCheckoutSubscriptionIntent('Auto Delivery', 'Weekly');
    } else {
      cartProvider.clearCheckoutSubscriptionIntent();
    }

    HapticFeedback.mediumImpact();

    String? variantName;
    double? variantPrice;
    double? variantOriginalPrice;

    if (product.variants.isNotEmpty) {
      final selectedVariant = productProvider.selectedVariant;
      if (selectedVariant != null) {
        variantName = selectedVariant.name;
        variantPrice = selectedVariant.salePrice;
        variantOriginalPrice = selectedVariant.originalPrice;
      } else {
        // Defensive: loadProductById/selectVariantByName always pick a
        // default variant when one exists, so this should not happen in
        // practice -- kept as a guard against a null selectedVariant rather
        // than silently adding the wrong price.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
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
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    await cartProvider.addItem(
      product,
      quantity: 1,
      variant: variantName,
      variantPrice: variantPrice,
      variantOriginalPrice: variantOriginalPrice,
    );

    // `context` is this method's own parameter, not necessarily the State's
    // live context getter, so the State's `mounted` field doesn't guarantee
    // it's still valid after the addItem() await above -- check context.mounted.
    if (!context.mounted) return;

    Offset? startPos;
    final renderBox = _addToCartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      startPos = Offset(
        offset.dx + renderBox.size.width / 2,
        offset.dy + renderBox.size.height / 2,
      );
    }
    final imageUrl = (variantName != null
        ? (productProvider.selectedVariant?.images.firstOrNull ?? product.primaryImage)
        : product.primaryImage);
    CartFlyAnimationOverlay.triggerFly(
      context: context,
      imageUrl: imageUrl,
      startPosition: startPos,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                variantName != null
                    ? 'Added $variantName to cart!'
                    : 'Added to cart successfully!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          final product = productProvider.selectedProduct;

          if (productProvider.isLoading && (product == null || product.name.isEmpty)) {
            return _buildLoadingState(isDark);
          }

          // Product not found (e.g. deleted product accessed via deep link)
          if (!productProvider.isLoading && product == null) {
            return _buildNotFoundState(isDark);
          }

          // At this point product is guaranteed non-null
          final loadedProduct = product!;

          return CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  isCollapsed: _isCollapsed,
                  product: loadedProduct,
                  isDark: isDark,
                  onBack: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                  onShare: () => _showShareWidget(loadedProduct),
                  topPadding: MediaQuery.of(context).padding.top,
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    ProductImageHero(product: loadedProduct),
                    // PDP-2: one unified card -- rating, name, short
                    // description, price, variant picker -- replaces the
                    // old split between this card (name/variants) and the
                    // bottom bar (price only).
                    _buildUnifiedInfoCard(loadedProduct, isDark),
                    // PDP-2: delivery window + the user's own selected
                    // address + subscription opt-in, as one card.
                    _buildDeliverySubscriptionCard(loadedProduct, isDark),
                    // BUSINESS-NETWORK-1: discovery link to the seller's business
                    // profile -- without this the feature has no entry point.
                    _buildSoldBySection(loadedProduct, isDark),
                    // PDP-2: the product's own real description + specs,
                    // pulled out of the collapsible dropdown into a plain
                    // visible section.
                    _buildProductHighlights(loadedProduct, isDark),
                    _buildReviewsSection(loadedProduct, isDark),
                    // Similar Products section
                    _buildSimilarProducts(loadedProduct, isDark),
                    // Bottom padding for the sticky bottom bar
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
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

  /// PDP-2: one unified card -- rating, name, short description, product
  /// badges, price, variant picker. Replaces the old split between this
  /// card (name/variants only) and the bottom bar (which owned price alone).
  /// Price here is read the same variant-aware way the bottom bar already
  /// does (`Consumer<ProductProvider>`, selectedVariant overrides the base
  /// product price) so the two never disagree.
  Widget _buildUnifiedInfoCard(ProductModel product, bool isDark) {
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
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
              // Row 1: Rating
              _buildRatingInline(product, isDark),
              const SizedBox(height: 10),

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

              // Row 3: short description (real product.description,
              // truncated -- not a separate/fabricated field, this codebase
              // only ever had the one `description` field on ProductModel).
              if (product.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  product.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.35,
                  ),
                ),
              ],
              _buildProductBadges(product, isDark),
              const SizedBox(height: 14),

              // Row 4: Price + sale price (variant-aware, same source as
              // the bottom bar).
              _buildPriceRow(isDark, accentColor),
              const SizedBox(height: 16),

              // Row 5: "Select Unit" label + Variant chips
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingInline(ProductModel product, bool isDark) {
    final rating = product.rating;
    final reviewCount = product.reviewCount;

    return Row(
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
          '(${_formatCount(reviewCount)} ratings)',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Variant-aware price + sale price, reading the exact same
  /// selectedVariant-overrides-product source the bottom bar already uses
  /// (product_provider.dart), so the two can never show different numbers.
  Widget _buildPriceRow(bool isDark, Color accentColor) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final product = productProvider.selectedProduct;
        if (product == null) return const SizedBox.shrink();
        final selectedVariant = productProvider.selectedVariant;
        final displayPrice = selectedVariant?.salePrice ?? product.salePrice;
        final displayOriginal = selectedVariant?.originalPrice ?? product.originalPrice;
        final hasDiscount = displayOriginal != null && displayOriginal > displayPrice;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '₹${displayPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (hasDiscount) ...[
              const SizedBox(width: 8),
              Text(
                '₹${displayOriginal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.lineThrough,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 8),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // The real delivery-window label this codebase has ever established --
  // home_app_bar.dart's own copy (`isB2B ? 'Bulk Freight' : '30 minutes'`),
  // mirrored rather than inventing a new "10 minutes" quick-commerce claim
  // with no backing capability anywhere in functions/src or this app (no
  // dark-store/fast-delivery flag exists on ProductModel or sellers). No
  // pre-purchase minute-level ETA field exists anywhere in this codebase
  // (the only `etaMinutes` machinery is live delivery-partner tracking for
  // an order already placed); whether "30 minutes" itself is a verified
  // operational SLA or aspirational copy is a real open question, disclosed
  // in PRODUCT_DETAIL_CURRENT_STATE.md, not resolved by this phase either.
  String _deliveryWindowLabel(ProductModel product) =>
      product.isB2BEnabled ? 'Bulk Freight' : '30 minutes';

  /// PDP-1 WS3: data-driven trust badges off the product's own real boolean
  /// fields -- replaces the unconditional, fabricated "Authentic" badge that
  /// only ever existed in dead code (PRODUCT_DETAIL_CURRENT_STATE.md §5 item
  /// 5). Capped to 2 so this never turns into a wall of pills (master-prompt
  /// §137's own "1-3, not 7" guidance).
  Widget _buildProductBadges(ProductModel product, bool isDark) {
    final badges = <_ProductBadge>[
      if (product.isVerified) const _ProductBadge('Verified Product', Icons.verified_rounded, Colors.blue),
      if (product.isFeatured) const _ProductBadge('Featured', Icons.star_rounded, Colors.purple),
      if (product.isTrending) const _ProductBadge('Trending', Icons.trending_up_rounded, Colors.deepOrange),
      if (product.isNew) const _ProductBadge('New', Icons.fiber_new_rounded, Colors.teal),
    ].take(2).toList();

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badges.map((b) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? b.color.withValues(alpha: 0.18) : b.color.shade50,
              border: Border.all(color: isDark ? b.color.shade300 : b.color.shade200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(b.icon, size: 12, color: isDark ? b.color.shade200 : b.color.shade700),
                const SizedBox(width: 4),
                Text(
                  b.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? b.color.shade200 : b.color.shade700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
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
                          ? (isDark ? accentColor.withValues(alpha: 0.1) : Colors.white)
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

  /// PDP-2: "Product Highlights" as the product's own real description +
  /// specifications -- replaces the old collapsed-by-default "View product
  /// details" ExpansionTile with a plainly visible section, and is no
  /// longer duplicated inside the info card (short description there is
  /// the same field, truncated). Real data only: `product.description`
  /// (ProductModel's only description field -- there is no separate
  /// "highlights" field anywhere in this codebase to draw fabricated
  /// marketing bullets from) and `product.specifications`.
  Widget _buildProductHighlights(ProductModel product, bool isDark) {
    final specs = _getSpecifications(product);
    if (product.description.trim().isEmpty && specs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildCardSection(
        isDark: isDark,
        title: 'Product Highlights',
        icon: Icons.info_outline_rounded,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.description.trim().isNotEmpty) ...[
              Text(
                product.description.trim(),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              if (specs.isNotEmpty) const SizedBox(height: 14),
            ],
            if (specs.isNotEmpty) SpecificationList(specifications: specs, isDark: isDark),
          ],
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
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                      color: isDark ? Colors.white : Colors.black87,
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

  // BUSINESS-NETWORK-1 (slice 1): the only entry point into a seller's
  // business profile screen. `ProductModel` carries sellerId but not the
  // seller's display name, so this fetches sellers/{sellerId} directly
  // (allow read: if true -- public, no rules change needed here). Renders
  // nothing if the product has no sellerId or the seller doc/shopName is
  // missing, rather than showing a broken-looking empty card.
  Widget _buildSoldBySection(ProductModel product, bool isDark) {
    if (product.sellerId.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('sellers')
            .doc(product.sellerId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final shopName = (data['shopName'] as String?)?.trim();
          if (shopName == null || shopName.isEmpty) {
            return const SizedBox.shrink();
          }
          // PDP-1 WS3: firestore.rules' ownerCannotApproveSellerStatus()
          // makes self-approval impossible, so status == 'approved' is a
          // genuine, rules-enforced verification signal -- not a
          // self-reported claim. No seller rating is shown here: the
          // reviews collection is product-scoped only (no sellerId field),
          // so there is no real seller-level rating to show yet
          // (PRODUCT_DETAIL_CURRENT_STATE.md §4 -- candidate SELLER-METRICS-1).
          final isVerifiedSeller = data['status'] == 'approved';
          final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pushNamed(
              context,
              '/business/${product.sellerId}',
            ),
            child: _buildCardSection(
              isDark: isDark,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.storefront, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sold by',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shopName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (isVerifiedSeller) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified_rounded, size: 15, color: accentColor),
                            ],
                          ],
                        ),
                        if (isVerifiedSeller) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Verified Seller',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// PDP-2: delivery window + the user's own real selected address +
  /// subscription opt-in, as one card (replaces the old subscription-only
  /// card). Address comes from AddressProvider.defaultAddress -- the same
  /// provider the checkout flow already reads -- never fabricated; when the
  /// user has none saved yet, this shows a real "Add address" prompt
  /// instead of inventing a placeholder pin code.
  Widget _buildDeliverySubscriptionCard(ProductModel product, bool isDark) {
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    final deliveryLabel = _deliveryWindowLabel(product);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery window
            Row(
              children: [
                Icon(
                  product.isB2BEnabled ? Icons.local_shipping_outlined : Icons.access_time_filled,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Get it in $deliveryLabel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Real selected/default delivery address
            Consumer<AddressProvider>(
              builder: (context, addressProvider, _) {
                final address = addressProvider.defaultAddress;
                return InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.savedAddresses),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address != null
                              ? 'Delivering to ${address.city}${address.zipcode.isNotEmpty ? ' - ${address.zipcode}' : ''}'
                              : 'Add a delivery address',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        address != null ? 'Change' : 'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
            const SizedBox(height: 14),
            // Subscribe & Save opt-in
            Row(
              children: [
                Icon(Icons.autorenew_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  'Subscribe & Save',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Get fresh supplies automatically, on your own schedule.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() {
                _subscribeChecked = !_subscribeChecked;
                _subscriptionCadence = _subscribeChecked ? 'daily' : 'one_off';
              }),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Checkbox(
                    value: _subscribeChecked,
                    activeColor: accent,
                    onChanged: (checked) => setState(() {
                      _subscribeChecked = checked ?? false;
                      _subscriptionCadence = _subscribeChecked ? 'daily' : 'one_off';
                    }),
                  ),
                  Expanded(
                    child: Text(
                      'Add to subscription',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_subscribeChecked) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Daily'),
                    selected: _subscriptionCadence == 'daily',
                    onSelected: (_) => setState(() => _subscriptionCadence = 'daily'),
                    selectedColor: accent.withValues(alpha: 0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Weekly'),
                    selected: _subscriptionCadence == 'weekly',
                    onSelected: (_) => setState(() => _subscriptionCadence = 'weekly'),
                    selectedColor: accent.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'You can skip or cancel anytime from your orders.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PDP-1 WS2: resurrected -- ReviewsSectionInline (stats bars, first-3
  // reviews, Add Review dialog) was fully built but had no live call site
  // anywhere on this screen (PRODUCT_DETAIL_CURRENT_STATE.md §3/§5 item 2).
  Widget _buildReviewsSection(ProductModel product, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

    return Consumer2<ProductProvider, CartProvider>(
      builder: (context, productProvider, cartProvider, child) {
        final product = productProvider.selectedProduct;
        if (product == null) return const SizedBox.shrink();

        final selectedVariant = productProvider.selectedVariant;
        final displayPrice = selectedVariant?.salePrice ?? product.salePrice;
        final displayOriginal = selectedVariant?.originalPrice ?? product.originalPrice;
        final displayName = selectedVariant?.name ?? '';
        // null when the product has no variants -- matches CartProvider's
        // own null-variant branch (see cart_provider.dart's isInCart/getItemQuantity).
        final variantKey = selectedVariant?.name;
        final cartQuantity = cartProvider.getItemQuantity(product.id, variant: variantKey);
        final inCart = cartQuantity > 0;

        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase RFQ-2: a bulk-quote entry point for B2B-enabled
              // products only -- RFQ-1's createRfq already refuses any
              // product where isB2BEnabled isn't true, so this mirrors that
              // same gate client-side rather than showing a button that
              // would always fail.
              if (product.isB2BEnabled) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRequestQuoteSheet(context, product, isDark),
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('Request a Bulk Quote'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  // Left: Variant info + Price with MRP strikeout + Offer badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '₹${displayPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                  // Right: Add to Cart, or a live quantity stepper once in cart
                  SizedBox(
                    key: _addToCartKey,
                    width: 140,
                    child: !product.inStock
                        ? ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[400],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          )
                        : inCart
                            ? _buildQuantityStepper(
                                isDark, accentColor, product, variantKey, cartQuantity, cartProvider)
                            : ElevatedButton(
                                onPressed: () => _addToCart(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                  shadowColor: accentColor.withValues(alpha: 0.3),
                                ),
                                child: const Text(
                                  'Add to cart',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// `[-] N [+]` stepper replacing the Add-to-Cart button once this
  /// (product, variant) pair is already in the cart -- master-prompt's own
  /// "transform into quantity controls" requirement. Reads/writes go
  /// straight through the existing CartProvider (optimistic local update,
  /// no loading flicker); nothing new is introduced here.
  Widget _buildQuantityStepper(
    bool isDark,
    Color accentColor,
    ProductModel product,
    String? variantKey,
    int quantity,
    CartProvider cartProvider,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepperButton(
            icon: Icons.remove,
            isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              cartProvider.decrementQuantity(product.id, variant: variantKey);
            },
          ),
          Text(
            '$quantity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
          _stepperButton(
            icon: Icons.add,
            isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              cartProvider.incrementQuantity(product.id, variant: variantKey);
            },
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required bool isDark, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 48,
          child: Icon(icon, size: 18, color: isDark ? Colors.black : Colors.white),
        ),
      ),
    );
  }

  void _showRequestQuoteSheet(BuildContext context, ProductModel product, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RequestQuoteSheet(
        productId: product.id,
        productName: product.name,
        moq: product.b2bMoq ?? 1,
        isDark: isDark,
      ),
    );
  }

  Map<String, String> _getSpecifications(ProductModel product) {
    final specs = <String, String>{};

    if (product.specifications != null && product.specifications!.isNotEmpty) {
      specs.addAll(Map<String, String>.from(product.specifications!));
    }

    return specs;
  }

  String _formatCount(int count) {
    if (count >= 100000) return '${(count / 100000).toStringAsFixed(2)} lac';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // Recommendations rail. PDP-1 WS4: prefer the curated
  // product.relatedProductIds signal (admin/seller-set; product_provider.dart's
  // loadProductById already resolves it into `relatedProducts` on every
  // load) over the generic same-category fallback when it's populated --
  // matches master-prompt's own ranking preference (curated over generic).
  // Falls back to the same-category query, unchanged, when relatedProductIds
  // is empty (still the common case today -- see
  // PRODUCT_DETAIL_CURRENT_STATE.md §5 item 7 / §8).
  Widget _buildSimilarProducts(ProductModel product, bool isDark) {
    return Consumer2<ProductProvider, CategoryProvider>(
      builder: (context, productProvider, categoryProvider, _) {
        final curated = productProvider.relatedProducts
            .where((p) => p.id != product.id && p.isActive)
            .take(6)
            .toList();

        List<ProductModel> similarProducts;
        String sectionTitle;

        if (curated.isNotEmpty) {
          similarProducts = curated;
          sectionTitle = 'You May Also Like';
        } else {
          final all = categoryProvider.categories;
          CategoryModel? bucket;
          try {
            bucket = all.firstWhere((c) => c.id == product.categoryId);
          } catch (_) {
            try {
              final nm = (product.categoryName ?? '').toLowerCase().trim();
              if (nm.isNotEmpty) {
                bucket = all.firstWhere((c) => c.name.toLowerCase().trim() == nm);
              }
            } catch (_) {
              bucket = null;
            }
          }

          similarProducts = productProvider.products.where((p) {
            if (p.id == product.id || !p.isActive) return false;
            if (bucket != null) {
              return productBelongsToCategory(p, bucket, all);
            }
            return p.categoryId == product.categoryId;
          }).take(6).toList();
          sectionTitle = 'Similar products';
        }

        if (similarProducts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                sectionTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
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
            Expanded(
              child: Container(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
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
            Container(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Product Not Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This product may have been removed or is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned sticky app bar for the sliver scroll: back / search / wishlist /
/// share, transparent-over-the-hero-image when expanded, solid with the
/// product name fading in once scrolled (PDP-1 WS2). Adapted from the
/// previously dead `_ProductDetailsSliverHeader` (same pinned-header
/// pattern, folded forward rather than rebuilt) with a search icon added to
/// match this screen's own top-navigation contract (back/search/wishlist/
/// share) -- the original only had back/wishlist/share.
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isCollapsed;
  final ProductModel product;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final double topPadding;

  _StickyHeaderDelegate({
    required this.isCollapsed,
    required this.product,
    required this.isDark,
    required this.onBack,
    required this.onShare,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final Color iconColor = isDark ? Colors.white : Colors.black87;
    final Color iconBgColor = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15);

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
      decoration: BoxDecoration(
        color: isCollapsed
            ? (isDark ? AppColors.surfaceDark : Colors.white)
            : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
        boxShadow: isCollapsed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _headerIcon(icon: Icons.arrow_back_rounded, color: iconColor, bgColor: iconBgColor, onTap: onBack),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
          _headerIcon(
            icon: Icons.search_rounded,
            color: iconColor,
            bgColor: iconBgColor,
            onTap: () => Navigator.pushNamed(context, AppRoutes.search),
          ),
          const SizedBox(width: 8),
          Consumer<WishlistProvider>(
            builder: (context, wishlistProvider, child) {
              final isInWishlist = wishlistProvider.isInWishlist(product.id);
              return _headerIcon(
                icon: isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isInWishlist ? Colors.red : iconColor,
                bgColor: iconBgColor,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  if (isInWishlist) {
                    await wishlistProvider.removeItem(product.id);
                    if (context.mounted) {
                      SnackbarHelper.showInfo(context, 'Removed from wishlist');
                    }
                  } else {
                    await wishlistProvider.addItem(product);
                    if (context.mounted) {
                      SnackbarHelper.showSuccess(context, 'Added to wishlist');
                    }
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          _headerIcon(icon: Icons.share_outlined, color: iconColor, bgColor: iconBgColor, onTap: onShare),
        ],
      ),
    );
  }

  Widget _headerIcon({required IconData icon, required Color color, required Color bgColor, required VoidCallback onTap}) {
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
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.isCollapsed != isCollapsed ||
        oldDelegate.product != product ||
        oldDelegate.isDark != isDark;
  }
}

/// One data-driven trust badge (PDP-1 WS3) -- see _buildProductBadges.
class _ProductBadge {
  final String label;
  final IconData icon;
  final MaterialColor color;
  const _ProductBadge(this.label, this.icon, this.color);
}
