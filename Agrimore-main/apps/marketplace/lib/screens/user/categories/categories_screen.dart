import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../app/routes.dart';

/// Premium Quick Commerce Style Categories Screen
/// Enhanced with Blinkit/Zepto-inspired design patterns
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
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
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      if (categoryProvider.categories.isEmpty) {
        categoryProvider.loadCategories();
      }
      
      // ✅ FIX: Load products too if empty, otherwise category grid shows 'No products'
      if (productProvider.products.isEmpty) {
        productProvider.loadProducts();
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
      });
      _staggerController.forward(from: 0.0);
    }
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
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF7F7F7),
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
          final mainCategories = allCategories.where((c) => c.isMainCategory).toList();

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
                child: mainCategories.isNotEmpty && _selectedIndex < mainCategories.length
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

  PreferredSizeWidget _buildAppBar(bool isDark, Color accentColor) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : accentColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 52,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isSearching
            ? _buildSearchField(isDark)
            : const Text(
                'Categories',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: _toggleSearch,
        ),
        if (!_isSearching)
          Consumer<CartProvider>(
            builder: (context, cart, _) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search in category...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6), size: 20),
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
    final subcategories = allCategories.where((c) => c.parentId == category.id).toList();

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await Provider.of<ProductProvider>(context, listen: false).loadProducts();
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
                onViewAll: () => AppRoutes.navigateToCategoryProducts(context, category.id),
              ),
            ),
          ),

          // Subcategory Chips
          if (subcategories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 6),
                child: _PremiumSubcategoryChips(
                  subcategories: subcategories,
                  isDark: isDark,
                  accentColor: accentColor,
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
            sliver: _buildProductGrid(category, allCategories, isDark, accentColor),
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
    var products = productProvider.products
        .where((p) => productBelongsToCategory(p, category, allCategories))
        .toList();
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      products = products.where((p) =>
        p.name.toLowerCase().contains(query) || 
        p.description.toLowerCase().contains(query)
      ).toList();
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
                mainAxisExtent: 230,
                crossAxisSpacing: 6,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
                  highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
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
            mainAxisExtent: 230,
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

  Widget _buildAnimatedProductCard(ProductModel product, bool isDark, Color accentColor, int index) {
    final interval = Interval(
      (index * 0.05).clamp(0.0, 0.5),
      ((index * 0.05) + 0.5).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animation = CurvedAnimation(parent: _staggerController, curve: interval);
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
      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisExtent: 230,
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
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

class _EnhancedSidebarItemState extends State<_EnhancedSidebarItem> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (widget.isSelected) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _EnhancedSidebarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      widget.isSelected ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Stack(
                children: [
                  // Selection indicator bar
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: widget.isSelected ? 3 : 0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.accentColor,
                            widget.accentColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Main content
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? (widget.isDark 
                              ? widget.accentColor.withOpacity(0.12)
                              : widget.accentColor.withOpacity(0.08))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category icon with glow effect
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: widget.isDark 
                                ? Colors.grey[850] 
                                : (widget.isSelected ? widget.accentColor.withOpacity(0.1) : const Color(0xFFF5F5F5)),
                            shape: BoxShape.circle,
                            boxShadow: widget.isSelected ? [
                              BoxShadow(
                                color: widget.accentColor.withOpacity(0.25),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ] : null,
                          ),
                          child: _buildCategoryIcon(),
                        ),
                        const SizedBox(height: 5),
                        // Category name
                        SizedBox(
                          height: 24,
                          child: Text(
                            widget.category.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
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
                ],
              ),
            );
          },
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
      size: 20,
    );
  }

  IconData _getCategoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('grocery') || n.contains('food')) return Icons.local_grocery_store;
    if (n.contains('fashion') || n.contains('cloth')) return Icons.checkroom;
    if (n.contains('mobile') || n.contains('phone')) return Icons.phone_android;
    if (n.contains('electronic')) return Icons.devices;
    if (n.contains('home') || n.contains('furniture')) return Icons.home;
    if (n.contains('beauty') || n.contains('personal')) return Icons.face;
    if (n.contains('health')) return Icons.health_and_safety;
    if (n.contains('baby') || n.contains('toy')) return Icons.child_care;
    if (n.contains('sport')) return Icons.sports_soccer;
    if (n.contains('book')) return Icons.menu_book;
    return Icons.category;
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
      padding: const EdgeInsets.all(12),
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
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.15),
                  accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ((category.iconUrl?.isNotEmpty ?? false) || (category.imageUrl?.isNotEmpty ?? false))
                && _CategoriesScreenState._showCategoryImages
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: (category.iconUrl?.isNotEmpty ?? false) ? category.iconUrl! : category.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.category_rounded,
                    color: accentColor,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                if (category.description != null && category.description!.isNotEmpty) ...[
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
                  colors: [accentColor, accentColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
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
// PREMIUM SUBCATEGORY CHIPS
// ============================================================================

class _PremiumSubcategoryChips extends StatelessWidget {
  final List<CategoryModel> subcategories;
  final bool isDark;
  final Color accentColor;

  const _PremiumSubcategoryChips({
    required this.subcategories,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subcategories.length,
        itemBuilder: (context, index) {
          final subcat = subcategories[index];
          return _SubcategoryChip(
            category: subcat,
            isDark: isDark,
            accentColor: accentColor,
            isFirst: index == 0,
          );
        },
      ),
    );
  }
}

class _SubcategoryChip extends StatefulWidget {
  final CategoryModel category;
  final bool isDark;
  final Color accentColor;
  final bool isFirst;

  const _SubcategoryChip({
    required this.category,
    required this.isDark,
    required this.accentColor,
    required this.isFirst,
  });

  @override
  State<_SubcategoryChip> createState() => _SubcategoryChipState();
}

class _SubcategoryChipState extends State<_SubcategoryChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        AppRoutes.navigateToCategoryProducts(context, widget.category.id);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: EdgeInsets.only(right: 8, left: widget.isFirst ? 0 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF252525) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.15 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_CategoriesScreenState._showCategoryImages &&
                  ((widget.category.iconUrl?.isNotEmpty ?? false) ||
                      (widget.category.imageUrl?.isNotEmpty ?? false))) ...[
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: (widget.category.iconUrl?.isNotEmpty ?? false) ? widget.category.iconUrl! : widget.category.imageUrl!,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 18,
                      height: 18,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.category.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
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
               widget.product.originalPrice! * 100).round()
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
                  color: widget.isDark ? Colors.grey[800]! : const Color(0xFFE8E8E8),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
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
                          padding: const EdgeInsets.all(8),
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
                                  colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
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
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? Colors.white : Colors.black87,
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
                                  color: widget.isDark ? Colors.white : Colors.black87,
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

                          const SizedBox(height: 6),

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

  Widget _buildCartButton(CartProvider cartProvider, bool isInCart, int quantity) {
    if (isInCart && quantity > 0) {
      // Quantity Controls
      return Container(
        height: 28,
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
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: Icon(
                  quantity > 1 ? Icons.remove : Icons.delete_outline,
                  color: Colors.white,
                  size: 14,
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
                    fontSize: 12,
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
                width: 28,
                height: 28,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 14,
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
        height: 28,
        decoration: BoxDecoration(
          color: widget.isDark 
              ? widget.accentColor.withOpacity(0.15) 
              : widget.accentColor.withOpacity(0.1),
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
