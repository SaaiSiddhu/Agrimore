import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../models/product_model.dart';
import '../../../models/review_model.dart';
import '../../../services/database_service.dart';
import 'widgets/product_image_carousel.dart';
import 'widgets/specification_list.dart';
import 'widgets/reviews_section.dart';
import 'widgets/variant_selector.dart';
import 'widgets/product_share_widget.dart';
import 'widgets/delivery_info_widget.dart';
import '../../../providers/theme_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({
    Key? key,
    required this.productId,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _quantity = 1;
  final ScrollController _scrollController = ScrollController();
  late DatabaseService _databaseService;

  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _databaseService = DatabaseService();
    _tabController = TabController(length: 4, vsync: this);
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
    _tabController.dispose();
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
  if (product.variants.isNotEmpty) {
    final selectedVariant = productProvider.selectedVariant;
    if (selectedVariant != null) {
      variantName = selectedVariant.name;
      print('🔍 Selected variant: $variantName'); // ✅ DEBUG
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

  // ✅ FIX: Pass variant to addItem
  await cartProvider.addItem(
    product,
    quantity: _quantity,
    variant: variantName, // ✅ ADD THIS LINE
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

          return NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                _buildSliverAppBar(product, isDark),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _buildProductShowcase(product, isDark),
                      _buildProductHeaderCard(product, isDark),
                      _buildKeyInfoCard(product, isDark),
                      if (product.variants.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: VariantSelector(),
                        ),
                      _buildQuantitySelector(isDark),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: DeliveryInfoWidget(productId: product.id),
                      ),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    child: _buildTabBar(isDark),
                  ),
                ),
              ];
            },
            body: _buildTabContent(product, isDark),
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
        onBack: () => Navigator.pop(context),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: ProductImageCarousel(
          images: product.images.isNotEmpty
              ? product.images
              : (product.imageUrl != null ? [product.imageUrl!] : []),
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '₹${product.price.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 12),
        if (product.originalPrice != null &&
            product.originalPrice! > product.price)
          Text(
            '₹${product.originalPrice!.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              decoration: TextDecoration.lineThrough,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
  
  Widget _buildRatingRow(ProductModel product, bool isDark, Color accentColor) {
    return FutureBuilder<ReviewStats?>(
      future: _databaseService.getReviewStats(product.id),
      builder: (context, snapshot) {
        double rating = product.rating;
        int reviewCount = product.reviewCount;

        if (snapshot.hasData && snapshot.data != null) {
          rating = snapshot.data!.averageRating;
          reviewCount = snapshot.data!.totalReviews;
        }

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
      },
    );
  }

  Widget _buildKeyInfoCard(ProductModel product, bool isDark) {
     final bool inStock = product.stock > 0;
     
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

             if (inStock && product.stock < 10)
              Text(
                'Only ${product.stock} left!',
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

  Widget _buildTabBar(bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.grey[50],
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TabBar(
            controller: _tabController,
            labelColor: isDark ? Colors.black : Colors.white,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            indicator: BoxDecoration(
              color: accentColor,
            ),
            indicatorPadding: const EdgeInsets.all(0),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Description'),
              Tab(text: 'Specifications'),
              Tab(text: 'Reviews'),
              Tab(text: 'Q&A'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ProductModel product, bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDescriptionTab(product, isDark),
        _buildSpecificationsTab(product, isDark),
        _buildReviewsTab(product, isDark),
        _buildQATab(isDark),
      ],
    );
  }

  Widget _buildDescriptionTab(ProductModel product, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Key Features',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem('Premium quality & durability', isDark),
            _buildFeatureItem('Eco-friendly materials', isDark),
            _buildFeatureItem('Easy to use & maintain', isDark),
            _buildFeatureItem('Best value for money', isDark),
            _buildFeatureItem('Certified authentic', isDark),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpecificationsTab(ProductModel product, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
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

  Widget _buildReviewsTab(ProductModel product, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ReviewsSection(
        productId: product.id,
        productName: product.name,
        isDark: isDark,
      ),
    );
  }

  Widget _buildQATab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: _buildCardSection(
        isDark: isDark,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87
              ),
            ),
            const SizedBox(height: 16),
            _buildQAItem(
              'Is this product authentic?',
              'Yes, 100% authentic products sourced directly from manufacturers.',
              isDark
            ),
            _buildQAItem(
              'What is the warranty?',
              '1 year manufacturer warranty included.',
              isDark
            ),
            _buildQAItem(
              'Can I return?',
              'Yes, 7-day easy return policy available.',
              isDark
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontSize: 13, 
                color: isDark ? Colors.grey[300] : Colors.grey[800]
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQAItem(String question, String answer, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q: $question',
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A: $answer',
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? Colors.grey[400] : Colors.grey[700]
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
          ),
        ],
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

        return Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!))
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: !product.inStock ? null : () => _addToCart(context, buyNow: false),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Add to Cart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: product.inStock 
                        ? (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]) 
                        : (isDark ? Colors.grey[800] : Colors.grey[300]),
                    foregroundColor: product.inStock ? accentColor : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: !product.inStock ? null : () => _addToCart(context, buyNow: true),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Buy Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: product.inStock ? accentColor : Colors.grey[500],
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 4,
                    shadowColor: product.inStock ? accentColor.withOpacity(0.3) : Colors.transparent,
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
    final specs = Map<String, String>.from(product.specifications ?? {});
    
    specs['Brand'] = specs['Brand'] ?? 'Agrimore';
    specs['Category'] = product.category;
    specs['SKU'] = product.id.substring(0, 10);
    specs['Warranty'] = '1 Year Manufacturer Warranty';
    specs['Return Policy'] = '7 Day Easy Returns';
    specs['Shipping'] = product.isFreeDelivery == true 
      ? 'Free Delivery' 
      : 'Starts at ₹${product.shippingPrice?.toStringAsFixed(0)}';
      
    return specs;
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
    final Color titleColor = isCollapsed ? (isDark ? Colors.white : Colors.black87) : Colors.white;
    final Color iconColor = isCollapsed ? (isDark ? Colors.white : Colors.black87) : Colors.white;
    final Color iconBgColor = isCollapsed ? (isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!) : Colors.white.withOpacity(0.2);

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
      decoration: BoxDecoration(
        color: isCollapsed ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) : (isDark ? const Color(0xFF2D3A2D) : AppColors.primary),
        gradient: isCollapsed ? null : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D3A2D),
                  const Color(0xFF3A4D3A),
                ]
              : [
                  const Color(0xFF2D7D3C),
                  const Color(0xFF3DA34E),
                  const Color(0xFF4DB85F),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: isCollapsed ? [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                    color: titleColor,
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
