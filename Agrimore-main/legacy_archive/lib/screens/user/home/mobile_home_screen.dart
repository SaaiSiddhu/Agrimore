import 'dart:async'; // No longer needed for Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../helpers/ad_helper.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/banner_slider.dart';
import 'widgets/recently_viewed_widget.dart';
import 'widgets/sponsored_banner.dart';
import 'widgets/categories_grid.dart';
import 'widgets/all_products_grid.dart';
import 'widgets/trending_products.dart';
import 'widgets/featured_products.dart';
import 'widgets/deals_for_you.dart';

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
  DateTime? _lastRefreshTime;

  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  // Get the height of the app bar to position the snackbar below it
  final double _appBarHeight =
      const PreferredSize(preferredSize: Size.fromHeight(160), child: HomeAppBar())
          .preferredSize
          .height;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadData();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native ad loaded successfully');
          if (mounted) {
            setState(() => _isNativeAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Native ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isNativeAdLoaded = false;
            });
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.primary,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black87,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black54,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black45,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    );

    _nativeAd!.load();
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
    if (offset > 800 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
      _fabAnimationController.forward();
      HapticFeedback.selectionClick();
    } else if (offset <= 800 && _showBackToTop) {
      setState(() => _showBackToTop = false);
      _fabAnimationController.reverse();
    }
  }

  Future<void> _loadData({bool showIndicator = true}) async {
    if (!mounted) return;
    if (_isRefreshing && showIndicator) return;

    setState(() => _isRefreshing = true);
    _lastRefreshTime = DateTime.now();

    try {
      // Load both providers at the same time
      await Future.wait([
        Provider.of<ProductProvider>(context, listen: false).loadProducts(),
        Provider.of<CategoryProvider>(context, listen: false).loadCategories(),
      ]);

      if (mounted) {
        setState(() => _isRefreshing = false);
        _staggerAnimationController.forward(from: 0.0);
        if (showIndicator) _showSuccessIndicator();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
        if (showIndicator) _showErrorSnackBar();
      }
    }
  }

  // --- ⬇️ FIXED SNACKBAR POSITIONING ⬇️ ---
  void _showSuccessIndicator() {
    if (!mounted) return;
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
        top: statusBarHeight + _appBarHeight + 8.0, // 8.0 is for padding
        left: 16,
        right: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8.0,
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // --- ⬇️ FIXED SNACKBAR POSITIONING ⬇️ ---
  void _showErrorSnackBar() {
    if (!mounted) return;
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
        top: statusBarHeight + _appBarHeight + 8.0, // 8.0 is for padding
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
    _nativeAd?.dispose();
    // Clear snackbars on dispose to prevent errors
    ScaffoldMessenger.of(context).clearSnackBars();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(160),
        child: HomeAppBar(), // <-- 1. HOME APP BAR (Stays here)
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading && !_isRefreshing) {
            return _buildShimmerLoading(isDark);
          }

          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await _loadData();
            },
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            strokeWidth: 3.0,
            displacement: 60,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // 1. Banner Slider (Was 1 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 0,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: BannerSlider(),
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

                // 3. Categories Grid (Was 3 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 2,
                    child: const CategoriesGrid(),
                  ),
                ),

                // 4. Sponsored Banner (Was 4 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 3,
                    child: const SponsoredBanner(),
                  ),
                ),

                // 5. Deals For You (Was 5 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 4,
                    child: const DealsForYou(),
                  ),
                ),

                // 6. Trending Products (Was 6 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 5,
                    child: const TrendingProducts(),
                  ),
                ),

                // 7. Native Ad (Was "place the Admob ad" in your list)
                if (_isNativeAdLoaded && _nativeAd != null)
                  SliverToBoxAdapter(
                    child: _buildAnimatedBoxWrapper(
                      index: 6,
                      child: _buildSponsoredNativeAd(isDark),
                    ),
                  ),

                // 8. Featured Products (Was 7 in your list)
                SliverToBoxAdapter(
                  child: _buildAnimatedBoxWrapper(
                    index: 7,
                    child: const FeaturedProducts(),
                  ),
                ),

                // 9. All Products (Was 8 in your list)
                _buildAnimatedSliverWrapper(
                  index: 8,
                  sliver: const AllProductsGrid(),
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

  // --- SPONSORED NATIVE AD (Simplified) ---
  Widget _buildSponsoredNativeAd(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 280,
            maxHeight: 320,
          ),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }

  // --- Simple Footer ---
  Widget _buildSimpleFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
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

  // --- FLOATING ACTION BUTTON (Simplified) ---
  Widget _buildFloatingActionButton(bool isDark) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fabAnimationController,
          curve: Curves.easeOutBack,
        ),
      ),
      child: FloatingActionButton(
        onPressed: _scrollToTop,
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
      ),
    );
  }
}