import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../app/routes.dart';
import 'widgets/category_content_sections.dart';

/// Premium Quick Commerce Style Categories Screen
/// Enhanced with Blinkit/Zepto-inspired design patterns
class CategoriesScreen extends StatefulWidget {
  // Non-null only when embedded as a MainScreen tab — see main_screen.dart's
  // _buildScreens(). This screen has no other reach path today, but falls
  // back to a plain pop if ever pushed standalone in the future.
  final VoidCallback? onBack;

  const CategoriesScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  static const bool _showCategoryImages = true;
  static const bool _showProductImages = true;

  int _selectedIndex = 0;
  String _searchQuery = '';
  bool _isSearching = false;
  String? _selectedSubcategoryId; // null = the "All" chip
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AnalyticsService _analytics = AnalyticsService();

  late AnimationController _staggerController;
  late AnimationController _searchAnimController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadCategories();
    _analytics.logScreenView(screenName: 'categories');
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _searchAnimController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);

      if (categoryProvider.categories.isEmpty) {
        categoryProvider.loadCategories();
      }

      // ✅ FIX: Load products too if empty, otherwise category grid shows 'No products'
      // Bounded — this screen filters the in-memory catalog per-category
      // client-side (see _getFilteredProducts), same reasoning as the shop
      // screens.
      if (productProvider.products.isEmpty) {
        productProvider.loadProducts(limit: 100);
      }

      _staggerController.forward();
    });
  }

  void _onCategorySelected(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
        _searchQuery = '';
        _searchController.clear();
        _isSearching = false;
        _selectedSubcategoryId = null;
      });
      _staggerController.forward(from: 0.0);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final mainCategories =
          categoryProvider.categories.where((c) => c.isMainCategory).toList();
      if (index < mainCategories.length) {
        _analytics.logCustomEvent(
          name: 'category_selected',
          parameters: {'category_id': mainCategories[index].id},
        );
      }
    }
  }

  void _onSubcategoryChipSelected(String? subcategoryId) {
    if (_selectedSubcategoryId == subcategoryId) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedSubcategoryId = subcategoryId);
    _analytics.logCustomEvent(
      name: 'category_chip_selected',
      parameters: {'subcategory_id': subcategoryId ?? 'all'},
    );
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchAnimController.forward();
        _searchFocusNode.requestFocus();
      } else {
        _searchAnimController.reverse();
        _searchQuery = '';
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF7F7F7),
      appBar: _buildAppBar(isDark, accentColor),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          if (categoryProvider.isLoading) {
            return _buildShimmerLoading(isDark);
          }

          if (categoryProvider.categories.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final allCategories = categoryProvider.categories;
          final mainCategories =
              allCategories.where((c) => c.isMainCategory).toList();

          return Row(
            children: [
              // Enhanced Left Sidebar
              _EnhancedCategorySidebar(
                categories: mainCategories,
                selectedIndex: _selectedIndex,
                onCategorySelected: _onCategorySelected,
                isDark: isDark,
                accentColor: accentColor,
              ),

              // Right Content Area
              Expanded(
                child: mainCategories.isNotEmpty &&
                        _selectedIndex < mainCategories.length
                    ? _buildCategoryContent(
                        mainCategories[_selectedIndex],
                        allCategories,
                        isDark,
                        accentColor,
                      )
                    : _buildEmptyState(isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  // Same hero gradient as profile_screen.dart's header, and the same
  // white-circular-card treatment for its back button — brings this app
  // bar's icon language in line with Profile's and the home app bar's
  // wallet/profile buttons instead of bare icons on a flat colour fill.
  PreferredSizeWidget _buildAppBar(bool isDark, Color accentColor) {
    final heroDark = isDark ? const Color(0xFF14251B) : const Color(0xFF1B5E20);
    final heroLight = isDark ? const Color(0xFF1A1A2E) : const Color(0xFF2E7D32);

    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [heroDark, heroLight],
          ),
        ),
      ),
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 56,
      titleSpacing: 4,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: _buildCardIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isSearching
            ? _buildSearchField(isDark)
            : const Text(
                'Categories',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _buildCardIconButton(
            icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
            onTap: _toggleSearch,
          ),
        ),
        if (!_isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            child: Consumer<CartProvider>(
              builder: (context, cart, _) => _buildCardIconButton(
                icon: Icons.shopping_bag_outlined,
                onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
                badge: cart.itemCount > 0 ? cart.itemCount : null,
              ),
            ),
          ),
      ],
    );
  }

  // A 36x36 white circular card — exactly profile_screen.dart's
  // _buildBackButton treatment, reused here for every app bar icon so the
  // toolbar reads as one consistent set of buttons, not bare icons on a
  // colour fill.
  Widget _buildCardIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: Colors.black87),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search in category...',
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          prefixIcon: Icon(Icons.search,
              color: Colors.white.withValues(alpha: 0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategoryContent(
    CategoryModel category,
    List<CategoryModel> allCategories,
    bool isDark,
    Color accentColor,
  ) {
    final subcategories =
        allCategories.where((c) => c.parentId == category.id).toList();

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await Provider.of<ProductProvider>(context, listen: false)
            .loadProducts(limit: 100);
      },
      color: accentColor,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Category Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: _PremiumCategoryHeader(
                category: category,
                isDark: isDark,
                accentColor: accentColor,
                onViewAll: () => AppRoutes.navigateToCategoryProducts(
                  context,
                  category.id,
                  categoryName: category.name,
                ),
              ),
            ),
          ),

          // Hero banner — admin-controlled (category.bannerImageUrl); renders
          // nothing when the category has none configured.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: CategoryHeroBanner(
                category: category,
                isDark: isDark,
                accentColor: accentColor,
                onShopNow: () {
                  _analytics.logCustomEvent(
                    name: 'category_banner_clicked',
                    parameters: {'category_id': category.id},
                  );
                  AppRoutes.navigateToCategoryProducts(
                    context,
                    category.id,
                    categoryName: category.name,
                  );
                },
              ),
            ),
          ),

          // Filter chips — "All" + the selected category's direct
          // subcategories; narrows the product grid below in place.
          if (subcategories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: CategoryFilterChips(
                  subcategories: subcategories,
                  selectedId: _selectedSubcategoryId,
                  onSelect: _onSubcategoryChipSelected,
                  isDark: isDark,
                  accentColor: accentColor,
                ),
              ),
            ),

          // Subcategory image grid ("Shop by Category")
          if (subcategories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                child: _PremiumSubcategoryGrid(
                  subcategories: subcategories,
                  isDark: isDark,
                  accentColor: accentColor,
                ),
              ),
            ),

          // Popular Picks — featured products in the current scope, falling
          // back to a short plain slice when none are marked featured yet.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Consumer<ProductProvider>(
                builder: (context, productProvider, _) {
                  final scoped =
                      _getFilteredProducts(productProvider, category, allCategories);
                  final popular = scoped.where((p) => p.isFeatured).toList();
                  final picks = (popular.isNotEmpty ? popular : scoped)
                      .take(8)
                      .toList();
                  return PopularPicksSection(
                    isDark: isDark,
                    cards: [
                      for (final product in picks)
                        _AdvancedProductCard(
                          product: product,
                          isDark: isDark,
                          accentColor: accentColor,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Search Results Count
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Consumer2<ProductProvider, CategoryProvider>(
                  builder: (context, productProvider, categoryProvider, _) {
                    final count = _getFilteredProducts(
                      productProvider,
                      category,
                      categoryProvider.categories,
                    ).length;
                    return Text(
                      '$count results for "$_searchQuery"',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Product Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
            sliver:
                _buildProductGrid(category, allCategories, isDark, accentColor),
          ),
        ],
      ),
    );
  }

  List<ProductModel> _getFilteredProducts(
    ProductProvider productProvider,
    CategoryModel category,
    List<CategoryModel> allCategories,
  ) {
    // A selected filter chip narrows to one direct subcategory instead of
    // the whole top-level category; "All" (null) keeps the original scope.
    CategoryModel scopeCategory = category;
    if (_selectedSubcategoryId != null) {
      final chipCategory = allCategories
          .where((c) => c.id == _selectedSubcategoryId)
          .firstOrNull;
      if (chipCategory != null) scopeCategory = chipCategory;
    }

    var products = productProvider.products
        .where((p) => productBelongsToCategory(p, scopeCategory, allCategories))
        .toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    }

    return products;
  }

  Widget _buildProductGrid(
    CategoryModel category,
    List<CategoryModel> allCategories,
    bool isDark,
    Color accentColor,
  ) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading && productProvider.products.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 195,
                crossAxisSpacing: 6,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Shimmer.fromColors(
                  baseColor: isDark ? const Color(0xFF303030) : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                childCount: 6,
              ),
            ),
          );
        }

        final categoryProducts =
            _getFilteredProducts(productProvider, category, allCategories);

        if (categoryProducts.isEmpty) {
          return SliverToBoxAdapter(child: _buildNoProductsState(isDark));
        }

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 195,
            crossAxisSpacing: 6,
            mainAxisSpacing: 8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _buildAnimatedProductCard(
                categoryProducts[index],
                isDark,
                accentColor,
                index,
              );
            },
            childCount: categoryProducts.length,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedProductCard(
      ProductModel product, bool isDark, Color accentColor, int index) {
    final interval = Interval(
      (index * 0.05).clamp(0.0, 0.5),
      ((index * 0.05) + 0.5).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animation =
            CurvedAnimation(parent: _staggerController, curve: interval);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: _AdvancedProductCard(
        product: product,
        isDark: isDark,
        accentColor: accentColor,
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF303030) : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Row(
        children: [
          // Sidebar shimmer
          Container(
            width: 76,
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            child: ListView.builder(
              itemCount: 8,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemBuilder: (_, __) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(height: 8, width: 40, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          // Content shimmer
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header shimmer
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Chips shimmer
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (_, __) => Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grid shimmer
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisExtent: 195,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 9,
                      itemBuilder: (_, __) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _buildNoProductsState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No products found' : 'No products yet',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: Text(
                  'Clear search',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 56,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No categories available',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ENHANCED SIDEBAR WIDGET
// ============================================================================

class _EnhancedCategorySidebar extends StatelessWidget {
  final List<CategoryModel> categories;
  final int selectedIndex;
  final Function(int) onCategorySelected;
  final bool isDark;
  final Color accentColor;

  const _EnhancedCategorySidebar({
    required this.categories,
    required this.selectedIndex,
    required this.onCategorySelected,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151515) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedIndex == index;

          return _EnhancedSidebarItem(
            category: category,
            isSelected: isSelected,
            onTap: () => onCategorySelected(index),
            isDark: isDark,
            accentColor: accentColor,
          );
        },
      ),
    );
  }
}

class _EnhancedSidebarItem extends StatefulWidget {
  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color accentColor;

  const _EnhancedSidebarItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.accentColor,
  });

  @override
  State<_EnhancedSidebarItem> createState() => _EnhancedSidebarItemState();
}

class _EnhancedSidebarItemState extends State<_EnhancedSidebarItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Row(
          children: [
            // A flush accent bar against the sidebar's true left edge reads
            // as "attached to the rail," unlike the old version which
            // floated inside the item's own margin with a visible gap
            // before it reached the edge.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 3,
              height: 34,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: widget.isSelected ? widget.accentColor : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: widget.isSelected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.accentColor.withValues(alpha: widget.isDark ? 0.22 : 0.13),
                            widget.accentColor.withValues(alpha: widget.isDark ? 0.12 : 0.06),
                          ],
                        )
                      : null,
                  border: widget.isSelected
                      ? Border.all(color: widget.accentColor.withValues(alpha: 0.25), width: 1)
                      : Border.all(color: Colors.transparent, width: 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category icon with a coloured ring when selected
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? widget.accentColor.withValues(alpha: widget.isDark ? 0.22 : 0.12)
                            : (widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3)),
                        shape: BoxShape.circle,
                        border: widget.isSelected
                            ? Border.all(color: widget.accentColor, width: 2)
                            : Border.all(color: Colors.transparent, width: 2),
                        boxShadow: widget.isSelected
                            ? [
                                BoxShadow(
                                  color: widget.accentColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                      ),
                      child: _buildCategoryIcon(),
                    ),
                    const SizedBox(height: 6),
                    // Category name
                    SizedBox(
                      height: 24,
                      child: Text(
                        widget.category.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: widget.isSelected
                              ? widget.accentColor
                              : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                          height: 1.15,
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
    );
  }

  Widget _buildCategoryIcon() {
    if (!_CategoriesScreenState._showCategoryImages) {
      return _buildFallbackIcon();
    }

    final String targetUrl = (widget.category.iconUrl?.isNotEmpty ?? false)
        ? widget.category.iconUrl!
        : (widget.category.imageUrl ?? '');

    if (targetUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: targetUrl,
          fit: BoxFit.cover,
          width: 44,
          height: 44,
          placeholder: (_, __) => _buildFallbackIcon(),
          errorWidget: (_, __, ___) => _buildFallbackIcon(),
        ),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Icon(
      _getCategoryIcon(widget.category.name),
      color: widget.isSelected
          ? widget.accentColor
          : (widget.isDark ? Colors.grey[500] : Colors.grey[600]),
      size: 22,
    );
  }

  // Categories without an admin-uploaded image fall back to this — it was
  // only covering non-grocery categories (fashion, electronics, books...)
  // so grocery staples like Dairy/Fruits/Meats/Laundry all landed on the
  // same generic triangle-circle-square placeholder glyph. Grocery keywords
  // checked first since this is primarily a grocery marketplace.
  IconData _getCategoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('dairy') || n.contains('milk') || n.contains('cheese') || n.contains('paneer')) {
      return Icons.icecream_rounded;
    }
    if (n.contains('fruit')) return Icons.apple_rounded;
    if (n.contains('vegetable') || n.contains('veggie')) return Icons.eco_rounded;
    if (n.contains('flower')) return Icons.local_florist_rounded;
    if (n.contains('meat') || n.contains('chicken') || n.contains('fish') || n.contains('seafood')) {
      return Icons.set_meal_rounded;
    }
    if (n.contains('laundry') || n.contains('detergent') || n.contains('wash')) {
      return Icons.local_laundry_service_rounded;
    }
    if (n.contains('clean')) return Icons.cleaning_services_rounded;
    if (n.contains('bakery') || n.contains('bread')) return Icons.bakery_dining_rounded;
    if (n.contains('snack') || n.contains('chip') || n.contains('namkeen')) return Icons.fastfood_rounded;
    if (n.contains('beverage') || n.contains('drink') || n.contains('juice')) return Icons.local_drink_rounded;
    if (n.contains('tea') || n.contains('coffee')) return Icons.coffee_rounded;
    if (n.contains('spice') || n.contains('masala')) return Icons.local_fire_department_rounded;
    if (n.contains('oil') || n.contains('ghee')) return Icons.water_drop_rounded;
    if (n.contains('rice') || n.contains('grain') || n.contains('atta') || n.contains('flour')) {
      return Icons.grass_rounded;
    }
    if (n.contains('frozen')) return Icons.ac_unit_rounded;
    if (n.contains('pet')) return Icons.pets_rounded;
    if (n.contains('stationery') || n.contains('office')) return Icons.edit_note_rounded;
    if (n.contains('grocery') || n.contains('food')) return Icons.local_grocery_store_rounded;
    if (n.contains('fashion') || n.contains('cloth')) return Icons.checkroom_rounded;
    if (n.contains('mobile') || n.contains('phone')) return Icons.phone_android_rounded;
    if (n.contains('electronic')) return Icons.devices_rounded;
    if (n.contains('home') || n.contains('furniture')) return Icons.home_rounded;
    if (n.contains('beauty') || n.contains('personal')) return Icons.face_rounded;
    if (n.contains('health')) return Icons.health_and_safety_rounded;
    if (n.contains('baby') || n.contains('toy')) return Icons.child_care_rounded;
    if (n.contains('sport')) return Icons.sports_soccer_rounded;
    if (n.contains('book')) return Icons.menu_book_rounded;
    return Icons.category_rounded;
  }
}

// ============================================================================
// PREMIUM CATEGORY HEADER
// ============================================================================

class _PremiumCategoryHeader extends StatelessWidget {
  final CategoryModel category;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onViewAll;

  const _PremiumCategoryHeader({
    required this.category,
    required this.isDark,
    required this.accentColor,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1E1E), const Color(0xFF252525)]
              : [Colors.white, const Color(0xFFFAFAFA)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : const Color(0xFFE8E8E8),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ((category.iconUrl?.isNotEmpty ?? false) ||
                        (category.imageUrl?.isNotEmpty ?? false)) &&
                    _CategoriesScreenState._showCategoryImages
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: (category.iconUrl?.isNotEmpty ?? false)
                          ? category.iconUrl!
                          : category.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.category_rounded,
                    color: accentColor,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 10),
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category names sometimes carry a bilingual "English/
                // Translation" form (admin-entered), which can run to 3+
                // lines unbounded — capped here so the banner stays a
                // fixed, compact height regardless of name length.
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                if (category.description != null &&
                    category.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // View All button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onViewAll();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREMIUM SUBCATEGORY GRID
// ============================================================================

class _PremiumSubcategoryGrid extends StatelessWidget {
  final List<CategoryModel> subcategories;
  final bool isDark;
  final Color accentColor;

  const _PremiumSubcategoryGrid({
    required this.subcategories,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Shop by Category',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${subcategories.length}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: subcategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 118,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            return _SubcategoryImageCard(
              category: subcategories[index],
              isDark: isDark,
              accentColor: accentColor,
            );
          },
        ),
      ],
    );
  }
}

class _SubcategoryImageCard extends StatefulWidget {
  final CategoryModel category;
  final bool isDark;
  final Color accentColor;

  const _SubcategoryImageCard({
    required this.category,
    required this.isDark,
    required this.accentColor,
  });

  @override
  State<_SubcategoryImageCard> createState() => _SubcategoryImageCardState();
}

class _SubcategoryImageCardState extends State<_SubcategoryImageCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.category.iconUrl?.trim().isNotEmpty ?? false)
        ? widget.category.iconUrl!.trim()
        : (widget.category.imageUrl ?? '').trim();

    return Semantics(
      button: true,
      label: widget.category.name,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          AppRoutes.navigateToCategoryProducts(
            context,
            widget.category.id,
            categoryName: widget.category.name,
          );
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF252525) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    widget.isDark ? Colors.grey[800]! : const Color(0xFFE7E7E7),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDark ? 0.16 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: imageUrl.isNotEmpty &&
                            _CategoriesScreenState._showCategoryImages
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildFallbackImage(),
                            errorWidget: (_, __, ___) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      widget.category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: widget.accentColor.withValues(alpha: widget.isDark ? 0.14 : 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.category_rounded,
        color: widget.accentColor,
        size: 26,
      ),
    );
  }
}

// ============================================================================
// ADVANCED PRODUCT CARD WITH QUANTITY CONTROLS
// ============================================================================

class _AdvancedProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isDark;
  final Color accentColor;

  const _AdvancedProductCard({
    required this.product,
    required this.isDark,
    required this.accentColor,
  });

  @override
  State<_AdvancedProductCard> createState() => _AdvancedProductCardState();
}

class _AdvancedProductCardState extends State<_AdvancedProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final isInCart = cartProvider.isInCart(widget.product.id);
        final quantity = cartProvider.getItemQuantity(widget.product.id);
        final hasDiscount = widget.product.originalPrice != null &&
            widget.product.originalPrice! > widget.product.price;
        final discountPercent = hasDiscount
            ? ((widget.product.originalPrice! - widget.product.price) /
                    widget.product.originalPrice! *
                    100)
                .round()
            : 0;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            AppRoutes.navigateToProductDetails(context, widget.product.id);
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.grey[800]!
                      : const Color(0xFFE8E8E8),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        // Product Image
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? const Color(0xFF222222)
                                : const Color(0xFFFAFAFA),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: widget.product.images.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.product.images.first,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Shimmer.fromColors(
                                    baseColor: widget.isDark
                                        ? Colors.grey[800]!
                                        : Colors.grey[300]!,
                                    highlightColor: widget.isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[100]!,
                                    child: Container(color: Colors.grey),
                                  ),
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[400],
                                    size: 28,
                                  ),
                                )
                              : Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 32,
                                  color: Colors.grey[400],
                                ),
                        ),

                        // Discount Badge
                        if (hasDiscount)
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE53935),
                                    Color(0xFFFF5252)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$discountPercent% OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Details Section
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  widget.isDark ? Colors.white : Colors.black87,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 2),

                          // Unit/Variant
                          if (widget.product.unit != null ||
                              (widget.product.variants.isNotEmpty))
                            Text(
                              widget.product.unit ??
                                  widget.product.variants.first.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: widget.isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                            ),

                          const Spacer(),

                          // Price Row
                          Row(
                            children: [
                              Text(
                                '₹${widget.product.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${widget.product.originalPrice!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Add/Quantity Button
                          _buildCartButton(cartProvider, isInCart, quantity),
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

  Widget _buildCartButton(
      CartProvider cartProvider, bool isInCart, int quantity) {
    if (isInCart && quantity > 0) {
      // Quantity Controls
      return Container(
        height: 25,
        decoration: BoxDecoration(
          color: widget.accentColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Decrease
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (quantity > 1) {
                  cartProvider.decrementQuantity(widget.product.id);
                } else {
                  cartProvider.removeItem(widget.product.id);
                }
              },
              child: Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                child: Icon(
                  quantity > 1 ? Icons.remove : Icons.delete_outline,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
            // Quantity
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  '$quantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Increase
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                cartProvider.incrementQuantity(widget.product.id);
              },
              child: Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ADD Button
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        cartProvider.addItem(widget.product, quantity: 1);
      },
      child: Container(
        height: 25,
        decoration: BoxDecoration(
          color: widget.isDark
              ? widget.accentColor.withValues(alpha: 0.15)
              : widget.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.accentColor,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'ADD',
          style: TextStyle(
            color: widget.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
