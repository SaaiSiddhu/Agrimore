import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/banner_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../providers/category_section_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';

// --- WIDGET IMPORTS (FIXED & MERGED FROM MOBILE) ---
import 'widgets/home_app_bar.dart';
import 'widgets/banner_slider.dart';
import 'widgets/categories_grid.dart'; // <-- FIXED
import 'widgets/bestsellers.dart'; // <-- RENAMED
import 'widgets/dynamic_category_sections.dart';
import 'widgets/recently_viewed_widget.dart'; // <-- ADDED FROM MOBILE
import 'widgets/quick_links_widget.dart'; // <-- ADDED FOR QUICK LINKS

class WebHomeScreen extends StatefulWidget {
  const WebHomeScreen({Key? key}) : super(key: key);

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  bool _showBackToTop = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _loadData();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() => _scrollOffset = offset);

    // Show/hide back to top button
    if (offset > 800 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
      _fabAnimationController.forward();
    } else if (offset <= 800 && _showBackToTop) {
      setState(() => _showBackToTop = false);
      _fabAnimationController.reverse();
    }
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final bannerProvider =
          Provider.of<BannerProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final wishlistProvider =
          Provider.of<WishlistProvider>(context, listen: false);
      final sectionProvider =
          Provider.of<CategorySectionProvider>(context, listen: false);

      // Refresh all data including banners for admin changes
      bannerProvider.loadBanners();
      productProvider.loadFeaturedProducts();
      productProvider.loadProducts();
      categoryProvider.loadCategories();
      cartProvider.loadCart();
      wishlistProvider.loadWishlist();
      sectionProvider.loadSections();
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount =
        screenWidth > 1400 ? 5 : (screenWidth > 1200 ? 4 : 3);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          _loadData();
          await Future.delayed(const Duration(milliseconds: 800));
        },
        color: AppColors.primary,
        backgroundColor: Colors.white,
        strokeWidth: 3.0,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // App Bar
            const SliverToBoxAdapter(child: HomeAppBar()),

            // Hero Banner with Parallax Effect
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: Offset(0, _scrollOffset * 0.2),
                child: Opacity(
                  opacity: (1 - _scrollOffset / 600).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: const [
                        SizedBox(height: 20),
                        BannerSlider(),
                        SizedBox(height: 20),
                        QuickLinksWidget(),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 🔥 STICKY SEARCH BAR - Web-Specific Feature
            SliverPersistentHeader(
              pinned: true,
              floating: false,
              delegate: _StickyWebSearchBarDelegate(
                minHeight: 90,
                maxHeight: 90,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // --- REORDERED & FIXED SECTION (matches mobile layout) ---

            // 1. Recently Viewed (from mobile)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildSectionWrapper(
                  child: const RecentlyViewedWidget(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),

            // 2. Categories Section (fixed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildSectionWrapper(
                  child: const CategoriesGrid(), // <-- FIXED
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),

            // 4. Bestsellers Section (fixed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildSectionWrapper(
                  child: const DealsForYou(), // Bestsellers
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),

            // 5. Dynamic Category Sections (replaces trending/featured)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildSectionWrapper(
                  child: const DynamicCategorySections(skipCount: 6),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),

            // --- END OF REORDERED SECTION ---

            // All Products Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildSectionHeader(
                  title: 'All Products',
                  subtitle: 'Discover our full collection',
                  onViewAll: () =>
                      AppRoutes.navigateTo(context, AppRoutes.shop),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Products Grid (Kept web-specific implementation)
            Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildShimmerProductCard(),
                        childCount: 10,
                      ),
                    ),
                  );
                }

                if (productProvider.products.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  );
                }

                final productsToShow = productProvider.products.length > 10
                    ? productProvider.products.sublist(0, 10)
                    : productProvider.products;

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.9 + (0.1 * value),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: _buildAdvancedProductCard(
                            productsToShow[index],
                          ),
                        );
                      },
                      childCount: productsToShow.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),

            // Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildFooter(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),

      // FAB
      floatingActionButton: ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.easeOutBack,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _scrollToTop,
            backgroundColor: AppColors.primary,
            elevation: 0,
            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            label: const Text(
              'Back to Top',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Product Card (Web-specific)
  Widget _buildAdvancedProductCard(ProductModel product) {
    return Consumer2<CartProvider, WishlistProvider>(
      builder: (context, cartProvider, wishlistProvider, child) {
        final isInWishlist = wishlistProvider.isInWishlist(product.id);
        final isInCart = cartProvider.isInCart(product.id);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              AppRoutes.navigateTo(
                context,
                AppRoutes.productDetails,
                arguments: product.id,
              );
            },
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Expanded(
                    flex: 6,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            image: product.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(product.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: product.imageUrl == null
                              ? const Center(
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                        ),

                        // Discount Badge
                        if (product.discount != null && product.discount! > 0)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.error,
                                    AppColors.error.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                '-${product.discount}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                        // Wishlist Button
                        Positioned(
                          top: 16,
                          right: 16,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 1.0,
                              end: isInWishlist ? 1.15 : 1.0,
                            ),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Material(
                                  color: Colors.white,
                                  elevation: 6,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();
                                      if (isInWishlist) {
                                        await wishlistProvider
                                            .removeItem(product.id); // ✅ FIXED
                                        _showSnackBar('Removed from wishlist',
                                            isError: false);
                                      } else {
                                        await wishlistProvider
                                            .addItem(product); // ✅ FIXED
                                        _showSnackBar('Added to wishlist ❤️',
                                            isError: false);
                                      }
                                    },
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isInWishlist
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isInWishlist
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Quick View Badge
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.visibility_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Quick View',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Details
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),

                          const Spacer(),

                          // Rating
                          if (product.rating > 0)
                            Row(
                              children: [
                                ...List.generate(5, (index) {
                                  return Icon(
                                    index < product.rating.floor()
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 18,
                                    color: Colors.amber[700],
                                  );
                                }),
                                const SizedBox(width: 6),
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 12),

                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '₹${product.price.toStringAsFixed(2)}',
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (product.originalPrice != null &&
                                  product.originalPrice! > product.price)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '₹${product.originalPrice!.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Cart Button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: isInCart
                                ? ElevatedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      AppRoutes.navigateTo(
                                          context, AppRoutes.cart);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(Icons.check_circle, size: 20),
                                    label: const Text(
                                      'In Cart',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await cartProvider.addItem(product,
                                          quantity: 1); // ✅ FIXED
                                      _showSnackBar('Added to cart 🛒',
                                          isError: false);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add_shopping_cart,
                                        size: 20),
                                    label: const Text(
                                      'Add to Cart',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
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
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required VoidCallback onViewAll,
  }) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headlineLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            onViewAll();
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          icon: Text(
            'View All',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          label: Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  //
  // --- REDUNDANT METHODS REMOVED ---
  // _buildTrendingSection() and _buildTrendingCard() were removed
  // as we are now importing the TrendingProducts() widget.
  //

  Widget _buildSectionWrapper({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildShimmerProductCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: _buildShimmerEffect(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: _buildShimmerEffect(),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: _buildShimmerEffect(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.0, end: 2.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (value - 1).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 1).clamp(0.0, 1.0),
              ],
              colors: const [
                Colors.transparent,
                Colors.white54,
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          child: Container(color: Colors.white),
        );
      },
      onEnd: () => setState(() {}),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(80.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 90,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Products Yet',
              style: AppTextStyles.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check back later for amazing products',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re all caught up!',
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Explore more products in our shop',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () {
              AppRoutes.navigateTo(context, AppRoutes.shop);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text(
              'Browse All Products',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyWebSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;

  _StickyWebSearchBarDelegate({
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: _buildWebSearchBar(context),
    );
  }

  Widget _buildWebSearchBar(BuildContext context) {
    return Hero(
      tag: 'search_bar',
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              AppRoutes.navigateTo(context, AppRoutes.search);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 64,
              constraints: const BoxConstraints(maxWidth: 800),
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 1200 ? 100 : 0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Search for products, categories...',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyWebSearchBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight;
  }
}