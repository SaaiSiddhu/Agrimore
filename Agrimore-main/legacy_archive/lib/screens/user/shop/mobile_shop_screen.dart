import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import '../../../app/themes/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/theme_provider.dart';
import 'widgets/filter_drawer.dart';
import 'widgets/product_card.dart';
import 'widgets/shop_app_bar.dart';

class MobileShopScreen extends StatefulWidget {
  final String? categoryId;
  final bool showRecentlyViewed;
  final bool showDeals;

  const MobileShopScreen({
    Key? key,
    this.categoryId,
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
  bool _isGridView = false; // Default to list view
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

  // AdMob Configuration
  // ✅ FIXED: Cache now tracks loading state (null) vs loaded (BannerAd)
  final Map<int, BannerAd?> _gridAdCache = {};
  final Map<int, BannerAd?> _listAdCache = {};
  final List<int> _adIndexes = [];
  bool _adsInitialized = false;
  static const String adUnitId = 'ca-app-pub-4374614015135326/6979650971';

  // Real-time Features
  StreamSubscription? _productUpdateSubscription;
  Map<String, bool> _productAvailability = {};
  Set<String> _priceDropProducts = {};
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

    _loadData();
    _initAds();
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

  void _setupRealTimeUpdates() {
    Timer.periodic(const Duration(seconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkInventoryUpdates();
      _checkPriceDrops();
    });
  }

  void _checkInventoryUpdates() {
    final random = Random();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    for (var product in productProvider.products.take(5)) {
      if (random.nextBool()) {
        _productAvailability[product.id] = product.inStock;
      }
    }
  }

  void _checkPriceDrops() {
    final random = Random();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    for (var product in productProvider.products.take(3)) {
      if (random.nextDouble() > 0.75 && product.discount > 0) {
        if (!_priceDropProducts.contains(product.id)) {
          _priceDropProducts.add(product.id);
          _showPriceDropNotification(product);
        }
      }
    }
  }

  void _showPriceDropNotification(ProductModel product) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_down, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔥 Price Drop Alert!',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.name} - ${product.discount}% OFF',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _initAds() async {
    if (!_adsInitialized) {
      await MobileAds.instance.initialize();
      _adsInitialized = true;
      debugPrint('✅ Mobile Ads initialized');
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

  void _setupAdIndexes(int productCount) {
    _adIndexes.clear();
    if (productCount < 6) return;
    
    int next = _isGridView ? 6 : 4;
    int adCounter = 0;
    
    while (next < productCount + adCounter && adCounter < 8) {
      _adIndexes.add(next);
      adCounter++;
      next += _isGridView ? 7 : 5;
    }
  }

  // --- Ad Loading Logic ---

  // ✅ FIXED: Ad loading logic
  Future<void> _loadGridAd(int idx) async {
    // This check is now handled in the itemBuilder, but we keep this as a safeguard.
    if (!_adsInitialized || _gridAdCache[idx] != null) return;

    if (_gridAdCache.length >= 6) {
      final oldestKey = _gridAdCache.keys.first;
      _gridAdCache[oldestKey]?.dispose();
      _gridAdCache.remove(oldestKey);
    }

    try {
      final BannerAd ad = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.mediumRectangle,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad loadedAd) { 
            debugPrint("✅ Grid Ad loaded at index $idx");
            if (mounted) setState(() => _gridAdCache[idx] = loadedAd as BannerAd);
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint("❌ Grid Ad failed at $idx: ${err.message}");
            ad.dispose();
            // Remove from cache so we can try again later
            if (mounted) setState(() => _gridAdCache.remove(idx));
          },
        ),
      );
      await ad.load();
    } catch (e) {
      debugPrint("⚠️ Grid Ad creation error at $idx: $e");
      if (mounted) setState(() => _gridAdCache.remove(idx));
    }
  }
  
  // ✅ FIXED: Ad loading logic
  Future<void> _loadListAd(int idx) async {
    if (!_adsInitialized || _listAdCache[idx] != null) return;

    if (_listAdCache.length >= 6) {
      final oldestKey = _listAdCache.keys.first;
      _listAdCache[oldestKey]?.dispose();
      _listAdCache.remove(oldestKey);
    }

    try {
      final BannerAd ad = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.largeBanner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad loadedAd) {
            debugPrint("✅ List Ad loaded at index $idx");
            if (mounted) setState(() => _listAdCache[idx] = loadedAd as BannerAd);
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint("❌ List Ad failed at $idx: ${err.message}");
            ad.dispose();
            // Remove from cache so we can try again later
            if (mounted) setState(() => _listAdCache.remove(idx));
          },
        ),
      );
      await ad.load();
    } catch (e) {
      debugPrint("⚠️ List Ad creation error at $idx: $e");
      if (mounted) setState(() => _listAdCache.remove(idx));
    }
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
    _gridAdCache.forEach((_, ad) => ad?.dispose());
    _listAdCache.forEach((_, ad) => ad?.dispose());
    super.dispose();
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    String appBarTitle = widget.showRecentlyViewed
        ? 'Recently Viewed'
        : widget.showDeals
            ? 'Special Deals'
            : 'Shop';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: ShopAppBar(
        title: appBarTitle,
        isGridView: _isGridView,
        onViewToggle: () {
          setState(() => _isGridView = !_isGridView);
          HapticFeedback.mediumImpact();
        },
        sortBy: _sortBy,
        onSortChanged: (v) {
          setState(() => _sortBy = v);
          HapticFeedback.selectionClick();
        },
        activeFiltersCount: _activeFiltersCount,
        onFilterTap: () {
          HapticFeedback.mediumImpact();
          _scaffoldKey.currentState?.openEndDrawer();
        },
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
      ),
      endDrawer: FilterDrawer(
        initialFilters: _appliedFilters,
        onApply: (filters) {
          setState(() => _appliedFilters = filters);
          _updateActiveFiltersCount();
          HapticFeedback.heavyImpact();
          _showFilterAppliedFeedback();
        },
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                if ((productProvider.isLoading && !_isRefreshing) || _isSearching) {
                  return _buildShimmerLoading(isDark);
                }

                final products = _getFilteredProducts(productProvider);
                
                if (products.isEmpty) {
                  return _buildAdvancedEmptyState(isDark);
                }

                _setupAdIndexes(products.length);

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
                  child: _isGridView
                      ? _buildAdvancedProductGrid(products, isDark)
                      : _buildAdvancedProductList(products, isDark),
                );
              },
            ),
          ),
          
          if (_scrollProgress > 0.05) _buildScrollProgressIndicator(isDark),
          if (_showScrollToTop) _buildScrollToTopFAB(isDark),
          if (_activeFiltersCount > 0 && !_showSearchBar) _buildFilterStatsOverlay(isDark),
        ],
      ),
    );
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
    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
            period: const Duration(milliseconds: 1200),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      );
    } 
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          period: const Duration(milliseconds: 1200),
          child: Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedProductGrid(List<ProductModel> products, bool isDark) {
    final totalItems = products.length + _adIndexes.length;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: totalItems,
      itemBuilder: (context, idx) {
        if (_adIndexes.contains(idx)) {
          // ✅ FIXED: Only call loadAd if it's not already loading or loaded
          if (!_gridAdCache.containsKey(idx)) {
            _gridAdCache[idx] = null; // Mark as 'loading'
            _loadGridAd(idx);
          }
          final ad = _gridAdCache[idx]; // Will be null or a BannerAd
          return ad != null
              ? _buildGridAdCard(ad, isDark)
              : _buildAdLoadingCard(isDark, true);
        }

        int productIndex = idx;
        for (final adIdx in _adIndexes) {
          if (idx > adIdx) productIndex--;
        }

        final product = products[productIndex];
        return _buildAnimatedProductCard(product, idx, isDark);
      },
    );
  }

  Widget _buildAdvancedProductList(List<ProductModel> products, bool isDark) {
    final totalItems = products.length + _adIndexes.length;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: totalItems,
      itemBuilder: (context, idx) {
        if (_adIndexes.contains(idx)) {
          // ✅ FIXED: Only call loadAd if it's not already loading or loaded
          if (!_listAdCache.containsKey(idx)) {
            _listAdCache[idx] = null; // Mark as 'loading'
            _loadListAd(idx);
          }
          final ad = _listAdCache[idx]; // Will be null or a BannerAd
          return ad != null
              ? _buildListAdCard(ad, isDark)
              : _buildAdLoadingCard(isDark, false);
        }

        int productIndex = idx;
        for (final adIdx in _adIndexes) {
          if (idx > adIdx) productIndex--;
        }

        final product = products[productIndex];
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
            child: ProductCard(product: product, isGridView: _isGridView),
          ),
        );
      },
    );
  }

  // --- Ad Card Widgets ---

  Widget _buildGridAdCard(BannerAd ad, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade600,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.amber.shade600,
              child: const Text(
                'SPONSORED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListAdCard(BannerAd ad, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade600,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.amber.shade600,
              child: const Text(
                'SPONSORED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              alignment: Alignment.center,
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdLoadingCard(bool isDark, bool isGrid) {
    return Container(
      height: isGrid ? 300 : 100,
      margin: isGrid ? null : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850]!.withOpacity(0.5) : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
          strokeWidth: 2,
        ),
      ),
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