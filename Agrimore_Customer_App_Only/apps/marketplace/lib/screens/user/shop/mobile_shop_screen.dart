import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/theme_provider.dart';
import 'widgets/filter_drawer.dart';
import 'widgets/product_card.dart';
import 'widgets/shop_app_bar.dart';

class MobileShopScreen extends StatefulWidget {
  final String? categoryId;
  final String? searchQuery;
  final bool showRecentlyViewed;
  final bool showDeals;

  const MobileShopScreen({
    Key? key,
    this.categoryId,
    this.searchQuery,
    this.showRecentlyViewed = false,
    this.showDeals = false,
  }) : super(key: key);

  @override
  State<MobileShopScreen> createState() => _MobileShopScreenState();
}

class _MobileShopScreenState extends State<MobileShopScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // State Management
  String _sortBy = 'newest';
  Map<String, dynamic> _appliedFilters = {};
  int _activeFiltersCount = 0;
  bool _showSearchBar = false;
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _debounceTimer;

  // Animation Controllers
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late AnimationController _filterChipAnimationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _searchSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  // Scroll State
  bool _showScrollToTop = false;
  double _scrollProgress = 0.0;
  bool _isHeaderExpanded = true;

  // Real-time Features
  StreamSubscription? _productUpdateSubscription;
  Map<String, bool> _productAvailability = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _filterChipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutBack,
    );

    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _headerFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeOut),
    );

    _scrollController.addListener(_onScroll);

    _appliedFilters = {};
    if (widget.categoryId != null) {
      _appliedFilters['categories'] = [widget.categoryId!];
    }

    // If searchQuery is passed, set it up
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchController.text = widget.searchQuery!;
      _searchQuery = widget.searchQuery!.toLowerCase().trim();
      _showSearchBar = true;
    }

    _loadData();
    _setupRealTimeUpdates();
    _filterChipAnimationController.forward();
    _updateActiveFiltersCount();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (maxScroll > 0) {
      setState(() {
        _scrollProgress = (offset / maxScroll).clamp(0.0, 1.0);
      });
    }

    if (offset > 100 && _isHeaderExpanded) {
      _isHeaderExpanded = false;
      _headerAnimationController.forward();
    } else if (offset <= 100 && !_isHeaderExpanded) {
      _isHeaderExpanded = true;
      _headerAnimationController.reverse();
    }

    if (offset > 500 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
      _fabAnimationController.forward();
    } else if (offset <= 500 && _showScrollToTop) {
      _fabAnimationController.reverse();
      setState(() => _showScrollToTop = false);
    }
  }

  Timer? _inventoryCheckTimer;

  void _setupRealTimeUpdates() {
    _inventoryCheckTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkInventoryUpdates();
    });
  }

  void _checkInventoryUpdates() {
    if (!mounted) return;
    final random = Random();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    for (var product in productProvider.products.take(5)) {
      if (random.nextBool()) {
        _productAvailability[product.id] = product.inStock;
      }
    }
  }



  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
  }

  // ✅ FIXED: Both type errors corrected here
  void _updateActiveFiltersCount() {
    int count = 0;
    if (_appliedFilters.isNotEmpty) {
      final range = _appliedFilters['priceRange'] as RangeValues?;
      if (range != null && (range.start != 0 || range.end != 10000)) count++;

      // ⬇️ --- FIX 1: Operator Precedence --- ⬇️
      if (((_appliedFilters['minRating'] as double?) ?? 0) > 0) count++;
      // ⬆️ --- END OF FIX 1 --- ⬆️

      // ⬇️ --- FIX 2: List<dynamic> cast --- ⬇️
      final categories = _appliedFilters['categories'] as List<dynamic>?;
      if (categories?.isNotEmpty ?? false) {
        count++;
      }
      // ⬆️ --- END OF FIX 2 --- ⬆️

      if (_appliedFilters['inStock'] == true) count++;
      if (_appliedFilters['isNew'] == true) count++;
      if (_appliedFilters['isVerified'] == true) count++;
      if (_appliedFilters['isTrending'] == true) count++;
    }
    setState(() => _activeFiltersCount = count);
    if (count > 0) {
      _filterChipAnimationController.forward();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearching = false; 
      });
      return;
    }
    
    setState(() => _isSearching = true); 
    
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = query.toLowerCase().trim();
        _isSearching = false;
      });
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    HapticFeedback.mediumImpact();
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _fabAnimationController.dispose();
    _filterChipAnimationController.dispose();
    _headerAnimationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _productUpdateSubscription?.cancel();
    _inventoryCheckTimer?.cancel();
    super.dispose();
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      endDrawer: FilterDrawer(
        initialFilters: _appliedFilters,
        onApply: (filters) {
          setState(() => _appliedFilters = filters);
          _updateActiveFiltersCount();
          HapticFeedback.heavyImpact();
          _showFilterAppliedFeedback();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar (Blinkit style)
            _buildBlinkitSearchBar(isDark),
            
            // 2. Filter Chips Row
            _buildFilterChipsRow(isDark),
            
            // 3. Product Grid
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, productProvider, _) {
                  if ((productProvider.isLoading && !_isRefreshing) || _isSearching) {
                    return _buildShimmerLoading(isDark);
                  }

                  final products = _getFilteredProducts(productProvider);
                  
                  if (products.isEmpty) {
                    return _buildAdvancedEmptyState(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _isRefreshing = true);
                      HapticFeedback.mediumImpact();
                      await productProvider.loadProducts();
                      setState(() => _isRefreshing = false);
                    },
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    strokeWidth: 3,
                    displacement: 50,
                    child: _buildAdvancedProductGrid(products, isDark),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Blinkit-style Search Bar ---
  Widget _buildBlinkitSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button - always goes to home with clean transition
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              // Always replace with home for clean navigation (no stuck cards)
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          // Search field
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Navigate to search screen for full search experience
                Navigator.pushNamed(context, '/search');
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.search,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _searchQuery.isNotEmpty 
                            ? _searchQuery 
                            : 'Search for products...',
                        style: TextStyle(
                          color: _searchQuery.isNotEmpty
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.grey[500] : Colors.grey[500]),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _searchController.clear();
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.mic,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter Chips Row (Blinkit style) ---
  Widget _buildFilterChipsRow(bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Filters chip
            _buildFilterChip(
              icon: Icons.tune,
              label: 'Filters',
              hasDropdown: true,
              isActive: _activeFiltersCount > 0,
              badge: _activeFiltersCount > 0 ? _activeFiltersCount.toString() : null,
              onTap: () {
                HapticFeedback.mediumImpact();
                _scaffoldKey.currentState?.openEndDrawer();
              },
              isDark: isDark,
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
            
            // Sort chip
            _buildFilterChip(
              icon: Icons.swap_vert,
              label: 'Sort',
              hasDropdown: true,
              isActive: _sortBy != 'newest',
              onTap: () => _showSortBottomSheet(isDark),
              isDark: isDark,
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
            
            // Price chip
            _buildFilterChip(
              label: 'Price',
              hasDropdown: true,
              onTap: () {
                HapticFeedback.lightImpact();
                _scaffoldKey.currentState?.openEndDrawer();
              },
              isDark: isDark,
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
            
            // Brand chip
            _buildFilterChip(
              label: 'Brand',
              hasDropdown: true,
              onTap: () {
                HapticFeedback.lightImpact();
                _scaffoldKey.currentState?.openEndDrawer();
              },
              isDark: isDark,
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
            
            // In Stock chip
            _buildFilterChip(
              label: 'In Stock',
              isActive: _appliedFilters['inStock'] == true,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _appliedFilters['inStock'] = !(_appliedFilters['inStock'] ?? false);
                });
                _updateActiveFiltersCount();
              },
              isDark: isDark,
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
            
            // New Arrivals chip
            _buildFilterChip(
              label: 'New',
              isActive: _appliedFilters['isNew'] == true,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _appliedFilters['isNew'] = !(_appliedFilters['isNew'] ?? false);
                });
                _updateActiveFiltersCount();
              },
              isDark: isDark,
              accentColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    IconData? icon,
    required String label,
    bool hasDropdown = false,
    bool isActive = false,
    String? badge,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 10 : 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? accentColor.withOpacity(0.1)
              : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive 
                ? accentColor 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isActive ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? accentColor : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            if (hasDropdown) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: isActive ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet(bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              ..._buildSortOptions(isDark),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSortOptions(bool isDark) {
    final options = [
      ('newest', 'Newest First', Icons.schedule),
      ('price_low', 'Price: Low to High', Icons.arrow_upward),
      ('price_high', 'Price: High to Low', Icons.arrow_downward),
      ('rating', 'Highest Rated', Icons.star),
      ('popular', 'Most Popular', Icons.trending_up),
    ];

    return options.map((option) {
      final isSelected = _sortBy == option.$1;
      final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
      
      return ListTile(
        leading: Icon(
          option.$3,
          color: isSelected ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        title: Text(
          option.$2,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? accentColor : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: accentColor)
            : null,
        onTap: () {
          setState(() => _sortBy = option.$1);
          Navigator.pop(context);
          HapticFeedback.selectionClick();
        },
      );
    }).toList();
  }

  // --- UI Building Widgets ---

  Widget _buildScrollProgressIndicator(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[200],
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _scrollProgress,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.primaryLight, AppColors.primaryLight.withOpacity(0.5)]
                    : [AppColors.primary, AppColors.primary.withOpacity(0.5)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToTopFAB(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 20,
      child: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
              HapticFeedback.mediumImpact();
            },
            backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            elevation: 8,
            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Top',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterStatsOverlay(bool isDark) {
    return Positioned(
      top: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(_filterChipAnimationController),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)]
                  : [Colors.white, Colors.grey[100]!],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_rounded,
                size: 16,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '$_activeFiltersCount Filter${_activeFiltersCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,  // 3 columns like Blinkit
        childAspectRatio: 0.60,  // Match home layout cards (70% image, 30% info)
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          period: const Duration(milliseconds: 1200),
          child: Container(
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildAdvancedProductGrid(List<ProductModel> products, bool isDark) {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 100 + MediaQuery.of(context).viewInsets.bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,  // 3 columns like Blinkit
        childAspectRatio: 0.60,  // Match home layout cards (70% image, 30% info)
        crossAxisSpacing: 8,  // Clean spacing
        mainAxisSpacing: 8,  // Clean spacing
      ),
      itemCount: products.length,
      itemBuilder: (context, idx) {
        final product = products[idx];
        return _buildAnimatedProductCard(product, idx, isDark);
      },
    );
  }

  Widget _buildAdvancedProductList(List<ProductModel> products, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(0, 8, 0, 100 + MediaQuery.of(context).viewInsets.bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, idx) {
        final product = products[idx];
        return _buildAnimatedProductCard(product, idx, isDark);
      },
    );
  }

  Widget _buildAnimatedProductCard(ProductModel product, int index, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index % 10 * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: ProductCard(product: product, isGridView: true), // Always grid
          ),
        );
      },
    );
  }



  Widget _buildAdvancedEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  AppColors.primaryLight.withOpacity(0.2),
                                  AppColors.primaryLight.withOpacity(0.05),
                                ]
                              : [
                                  AppColors.primary.withOpacity(0.2),
                                  AppColors.primary.withOpacity(0.05),
                                ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 70,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No products found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Try adjusting your filters or search terms\nto find what you\'re looking for',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _appliedFilters = {};
                    _activeFiltersCount = 0;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                  HapticFeedback.heavyImpact();
                },
                icon: const Icon(Icons.refresh_rounded, size: 22),
                label: const Text(
                  'Reset All Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterAppliedFeedback() {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Text(
                'Filters Applied Successfully',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      debugPrint('Error showing filter feedback snackbar: $e');
    }
  }

  // ✅ FIXED: This is the main filtering logic, now fully updated
  List<ProductModel> _getFilteredProducts(ProductProvider provider) {
    var products = List<ProductModel>.from(provider.products);

    if (_searchQuery.isNotEmpty) {
      products = products.where((p) {
        return p.name.toLowerCase().contains(_searchQuery) ||
            p.category.toLowerCase().contains(_searchQuery) ||
            p.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (widget.showRecentlyViewed) {
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products.take(20).toList();
    }

    if (widget.showDeals) {
      products = products.where((p) => p.discount > 0).toList()
        ..sort((a, b) => b.discount.compareTo(a.discount));
      return products;
    }

    if (_appliedFilters.isNotEmpty) {
      final priceRange = _appliedFilters['priceRange'] as RangeValues?;
      final minRating = _appliedFilters['minRating'] as double?;
      final inStock = _appliedFilters['inStock'] as bool?;
      
      final categories = _appliedFilters['categories'] != null
          ? List<String>.from(_appliedFilters['categories'])
          : null;
      
      final isNew = _appliedFilters['isNew'] as bool?;
      final isVerified = _appliedFilters['isVerified'] as bool?;
      final isTrending = _appliedFilters['isTrending'] as bool?;

      // ⬇️ --- FIX 3: Price Filter Typo --- ⬇️
      if (priceRange != null && (priceRange.start != 0 || priceRange.end != 10000)) {
        products = products
            .where((p) =>
                p.salePrice >= priceRange.start && p.salePrice <= priceRange.end)
            .toList();
      }
      // ⬆️ --- END OF FIX 3 --- ⬆️

      if (minRating != null && minRating > 0) {
        products = products.where((p) => p.rating >= minRating).toList();
      }
      if (inStock == true) {
        products = products.where((p) => p.inStock).toList();
      }
      if (categories != null && categories.isNotEmpty) {
        products = products.where((p) => categories.contains(p.categoryId)).toList();
      }
      if (isNew == true) {
        products = products.where((p) => p.isNew).toList();
      }
      if (isVerified == true) {
        products = products.where((p) => p.isVerified).toList();
      }
      if (isTrending == true) {
        products = products.where((p) => p.isTrending).toList();
      }
    }

    switch (_sortBy) {
      case 'price_low':
        products.sort((a, b) => a.salePrice.compareTo(b.salePrice));
        break;
      case 'price_high':
        products.sort((a, b) => b.salePrice.compareTo(a.salePrice));
        break;
      case 'rating':
        products.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'popular':
        products.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      default:
        products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return products;
  }
}