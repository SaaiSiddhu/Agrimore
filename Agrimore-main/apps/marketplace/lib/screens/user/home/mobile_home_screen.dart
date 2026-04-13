import 'dart:async'; // No longer needed for Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/banner_provider.dart';
import '../../../providers/category_section_provider.dart';
import '../../../providers/section_banner_provider.dart';
import '../../../providers/theme_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/banner_slider.dart';
import 'widgets/recently_viewed_widget.dart';
import 'widgets/product_section_widget.dart';
import 'widgets/bestsellers.dart';
import 'widgets/dynamic_category_sections.dart';
import 'widgets/section_banner_carousel.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({Key? key}) : super(key: key);

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  late AnimationController _staggerAnimationController;

  bool _showBackToTop = false;
  bool _isRefreshing = false;
  bool _isAppBarCollapsed = false;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }



  void _initAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _staggerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkAndRefresh();
    }
  }

  void _checkAndRefresh() {
    if (_lastRefreshTime == null) return;
    final difference = DateTime.now().difference(_lastRefreshTime!);
    if (difference.inMinutes >= 5) {
      _loadData(showIndicator: false);
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    
    // Collapse app bar when scrolled past 50 pixels
    if (offset > 50 && !_isAppBarCollapsed) {
      setState(() => _isAppBarCollapsed = true);
    } else if (offset <= 50 && _isAppBarCollapsed) {
      setState(() => _isAppBarCollapsed = false);
    }
    
    // FAB visibility
    if (offset > 800 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
      _fabAnimationController.forward();
      HapticFeedback.selectionClick();
    } else if (offset <= 800 && _showBackToTop) {
      setState(() => _showBackToTop = false);
      _fabAnimationController.reverse();
    }
  }

  Future<void> _loadData({bool showIndicator = true, bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_isRefreshing && showIndicator) return;

    // ✅ OPTIMIZATION: Skip if data already loaded (unless force refresh)
    if (!forceRefresh) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final bannerProvider = Provider.of<BannerProvider>(context, listen: false);
      
      if (productProvider.hasProducts && 
          (categoryProvider.hasCategories || categoryProvider.categories.isNotEmpty) && 
          bannerProvider.banners.isNotEmpty) {
        debugPrint('📦 Home data already cached, skipping reload...');
        // Still trigger animations if first time showing
        if (_staggerAnimationController.status == AnimationStatus.dismissed) {
          _staggerAnimationController.forward();
        }
        return;
      }
    }

    setState(() => _isRefreshing = true);
    _lastRefreshTime = DateTime.now();

    // Load all providers in parallel - don't block UI
    Future.wait([
      Provider.of<ProductProvider>(context, listen: false).loadProducts(forceRefresh: forceRefresh),
      Provider.of<CategoryProvider>(context, listen: false).loadCategories(forceRefresh: forceRefresh),
      Provider.of<BannerProvider>(context, listen: false).loadBanners(forceRefresh: forceRefresh),
      Provider.of<CategorySectionProvider>(context, listen: false).loadSections(forceRefresh: forceRefresh),
      Provider.of<SectionBannerProvider>(context, listen: false).loadBanners(forceRefresh: forceRefresh),
    ]).then((_) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _staggerAnimationController.forward(from: 0.0);
        if (showIndicator && forceRefresh) _showSuccessIndicator();
      }
    }).catchError((e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
        if (showIndicator) _showErrorSnackBar();
      }
    });
  }

  // --- ⬇️ FIXED SNACKBAR POSITIONING ⬇️ ---
  void _showSuccessIndicator() {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Get the status bar height
      final statusBarHeight = MediaQuery.of(context).padding.top;

      final snackBar = SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Content refreshed',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        // This margin positions it correctly below the app bar
        margin: EdgeInsets.only(
          top: statusBarHeight + (_isAppBarCollapsed ? 100 : 155) + 8.0,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8.0,
        duration: const Duration(seconds: 3),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      debugPrint('Error showing success snackbar: $e');
    }
  }

  // --- ⬇️ FIXED SNACKBAR POSITIONING ⬇️ ---
  void _showErrorSnackBar() {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Get the status bar height
      final statusBarHeight = MediaQuery.of(context).padding.top;

      final snackBar = SnackBar(
        content: Row(
          children: const [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to refresh content.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        // This margin positions it correctly below the app bar
        margin: EdgeInsets.only(
          top: statusBarHeight + (_isAppBarCollapsed ? 100 : 155) + 8.0,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8.0,
        duration: const Duration(seconds: 5), // Longer for error
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () => _loadData(),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      debugPrint('Error showing error snackbar: $e');
    }
  }
  // --- ⬆️ END OF MODIFICATIONS ⬆️ ---

  void _scrollToTop() {
    HapticFeedback.mediumImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _staggerAnimationController.dispose();
    // Note: Cannot call ScaffoldMessenger.of(context) here as context is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : AppColors.primary.withValues(alpha: 0.05),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isAppBarCollapsed ? 100 : 170),
        child: HomeAppBar(isCollapsed: _isAppBarCollapsed),
      ),
      body: Consumer2<ProductProvider, CategoryProvider>(
        builder: (context, productProvider, categoryProvider, child) {
          // ✅ ENHANCED: Skip shimmer if we have cached products
          // Only show shimmer on first load with NO data
          final hasContent = productProvider.hasProducts || categoryProvider.hasCategories;
          if (productProvider.isLoading && !_isRefreshing && !hasContent) {
            return _buildShimmerLoading(isDark);
          }
          
          // ✅ Start animations immediately if we have cached content
          if (hasContent && _staggerAnimationController.status == AnimationStatus.dismissed) {
            _staggerAnimationController.forward();
          }

          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await _loadData(forceRefresh: true);  // ✅ Force Firebase fetch
            },
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            strokeWidth: 3.0,
            displacement: 60,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // 1. Banner Slider
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 0,
                    child: Column(
                      children: const [
                        BannerSlider(), // No padding for edge-to-edge
                        SizedBox(height: 0), // No space below banner
                      ],
                    ),
                  ),
                ),

                // 2. Recently Viewed (Was 2 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 1,
                    child: const RecentlyViewedWidget(),
                  ),
                ),

                // 3. Deals For You
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 2,
                    child: const DealsForYou(),
                  ),
                ),

                // 6. Dynamic Category Sections (covers all remaining categories)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 5,
                    child: const DynamicCategorySections(skipCount: 6),
                  ),
                ),

                // 9. Product Sections by Category (Blinkit-style horizontal scroll)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 8,
                    child: _buildProductSections(productProvider, categoryProvider),
                  ),
                ),

                // 10. Simple Footer (Kept at the end for good UX)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 9,
                    child: _buildSimpleFooter(isDark),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(isDark),
    );
  }

  // --- Staggered Animation Wrapper for BOX widgets ---
  Widget _buildAnimatedBoxWrapper({required Widget child, required int index}) {
    final interval = Interval(
      (index * 0.1).clamp(0.0, 1.0),
      ((index + 4) * 0.1).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerAnimationController,
          curve: interval,
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _staggerAnimationController,
          curve: interval,
        ),
        child: child,
      ),
    );
  }

  // --- Staggered Animation Wrapper for SLIVER widgets ---
  Widget _buildAnimatedSliverWrapper(
      {required Widget sliver, required int index}) {
    final interval = Interval(
      (index * 0.1).clamp(0.0, 1.0),
      ((index + 4) * 0.1).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );

    return SliverFadeTransition(
      opacity: CurvedAnimation(
        parent: _staggerAnimationController,
        curve: interval,
      ),
      sliver: sliver,
    );
  }

  // --- Shimmer Loading Placeholder ---
  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Banner
          Container(
            height: 180,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          // Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          // Product List
          Container(
            height: 220,
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          // Product Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  // --- Product Sections by Category (Blinkit-style) ---
  Widget _buildProductSections(ProductProvider productProvider, CategoryProvider categoryProvider) {
    final categories = categoryProvider.categories.where((c) => c.isActive).toList();
    final allProducts = productProvider.products.where((p) => p.isActive).toList();
    
    // Group products by category
    final Map<String, List<ProductModel>> productsByCategory = {};
    for (final product in allProducts) {
      productsByCategory.putIfAbsent(product.categoryId, () => []);
      productsByCategory[product.categoryId]!.add(product);
    }
    
    // Build sections for categories with products (max 8 sections)
    List<Widget> sections = [];
    int sectionCount = 0;
    const int maxSections = 8;
    const int productsPerSection = 10;
    
    for (final category in categories) {
      if (sectionCount >= maxSections) break;
      
      final categoryProducts = productsByCategory[category.id] ?? [];
      if (categoryProducts.isEmpty) continue;
      
      sectionCount++;
      
      // Limit products per section
      final displayProducts = categoryProducts.take(productsPerSection).toList();
      
      sections.add(
        ProductSectionWidget(
          sectionTitle: category.name,
          products: displayProducts,
          categoryId: category.id,
          onSeeAll: () {
            Navigator.pushNamed(
              context,
              AppRoutes.shop,
              arguments: {'categoryId': category.id, 'categoryName': category.name},
            );
          },
        ),
      );
      
      // Add section banner carousel only after 5th section
      if (sectionCount == 5) {
        sections.add(const SectionBannerCarousel(afterSection: 5));
      }
    }
    
    return Column(children: sections);
  }

  // --- Simple Footer ---
  Widget _buildSimpleFooter(bool isDark) {
    return Padding(
      // Extra padding at bottom to account for bottom navigation bar (extendBody: true)
      padding: const EdgeInsets.only(top: 48.0, bottom: 120.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 1,
            width: 60,
            color: isDark ? Colors.grey[800] : Colors.grey[300],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "You're all caught up!",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ),
          Container(
            height: 1,
            width: 60,
            color: isDark ? Colors.grey[800] : Colors.grey[300],
          ),
        ],
      ),
    );
  }

  // --- FLOATING ACTION BUTTON (Compact scroll-to-top) ---
  Widget _buildFloatingActionButton(bool isDark) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fabAnimationController,
          curve: Curves.easeOutBack,
        ),
      ),
      child: SizedBox(
        width: 36,
        height: 36,
        child: FloatingActionButton.small(
          onPressed: _scrollToTop,
          backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
          elevation: 4,
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}