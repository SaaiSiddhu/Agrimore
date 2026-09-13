import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/banner_provider.dart';
import '../../../providers/category_section_provider.dart';
import '../../../providers/section_banner_provider.dart';
import '../../../providers/home_product_section_config_provider.dart';
import '../../../providers/home_grocery_strip_config_provider.dart';
import '../../../providers/home_section_order_provider.dart';
import '../../../providers/sponsored_banner_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/shop_entry_provider.dart';
import '../../../providers/settings_provider.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/banner_slider.dart';
import 'widgets/recently_viewed_widget.dart';
import 'widgets/product_section_widget.dart';
import 'widgets/bestsellers.dart';
import 'widgets/dynamic_category_sections.dart';
import 'widgets/grocery_kitchen_home_strip.dart';
import 'widgets/section_banner_carousel.dart';
import 'widgets/sponsored_banner_strip.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({Key? key}) : super(key: key);

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Content-only heights (status bar is added separately wherever these are
  // used) for HomeAppBar's expanded/collapsed states — kept as named
  // constants since both the sliver header below and the snackbar
  // positioning need to agree on them.
  static const double _kAppBarExpandedContent = 138;
  static const double _kAppBarCollapsedContent = 60;

  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  late AnimationController _staggerAnimationController;

  bool _showBackToTop = false;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  // 0.0..1.0, updated continuously from scroll offset (see _onScroll) so the
  // app bar shrinks in step with the drag instead of snapping between two
  // fixed heights at a threshold — that snap was the "hard, not smooth" jump.
  double _headerCollapseProgress = 0.0;

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

    // Continuous 0..1 over the first 90px of scroll, instead of a boolean
    // flip at a single threshold — the app bar height and HomeAppBar's own
    // internal shrink/fade (see collapseProgress in home_app_bar.dart) both
    // read this every frame, so they track the finger 1:1.
    final headerProgress = (offset / 90).clamp(0.0, 1.0);
    if (headerProgress != _headerCollapseProgress) {
      setState(() => _headerCollapseProgress = headerProgress);
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

  Future<void> _loadData(
      {bool showIndicator = true, bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_isRefreshing && showIndicator) return;

    // ✅ OPTIMIZATION: Skip if data already loaded (unless force refresh)
    if (!forceRefresh) {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final bannerProvider =
          Provider.of<BannerProvider>(context, listen: false);

      if (productProvider.hasProducts &&
          (categoryProvider.hasCategories ||
              categoryProvider.categories.isNotEmpty) &&
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
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final location = settingsProvider.selectedLocation;

    Future.wait([
      Provider.of<ProductProvider>(context, listen: false).loadProducts(
        forceRefresh: forceRefresh,
        location: location,
        limit: 60,
      ),
      Provider.of<CategoryProvider>(context, listen: false)
          .loadCategories(forceRefresh: forceRefresh),
      Provider.of<BannerProvider>(context, listen: false)
          .loadBanners(forceRefresh: forceRefresh),
      Provider.of<CategorySectionProvider>(context, listen: false)
          .loadSections(forceRefresh: forceRefresh),
      Provider.of<SectionBannerProvider>(context, listen: false)
          .loadBanners(forceRefresh: forceRefresh),
      Provider.of<HomeProductSectionConfigProvider>(context, listen: false)
          .loadSections(forceRefresh: forceRefresh),
      Provider.of<HomeGroceryStripConfigProvider>(context, listen: false)
          .loadConfig(forceRefresh: forceRefresh),
      Provider.of<HomeSectionOrderProvider>(context, listen: false)
          .loadSettings(forceRefresh: forceRefresh),
      Provider.of<SponsoredBannerProvider>(context, listen: false)
          .loadSponsoredBanners(forceRefresh: forceRefresh),
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
          top: statusBarHeight + _kAppBarExpandedContent + 8.0,
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
          top: statusBarHeight + _kAppBarExpandedContent + 8.0,
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

  Future<void> _autoDetectLocationSilently(
      SettingsProvider settingsProvider) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // PERF-2: was `.high`/10s — this is a "which city" resolution (same
      // job as HomeAppBar's own, faster `.low`/4s call), not turn-by-turn
      // navigation; `.high` accuracy makes the OS work harder for a GPS fix
      // this doesn't need, purely adding wait. This call itself never gates
      // any visible UI (fire-and-forget from its own caller), but there is
      // no reason for it to run any slower than the one that does.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final exactLocation = [
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

        final city = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Unknown';
        final displayLocation = exactLocation.isNotEmpty ? exactLocation : city;

        await settingsProvider.changeLocation(displayLocation);
        if (mounted) {
          _loadData(forceRefresh: true);
        }
      }
    } catch (e) {
      debugPrint('Silent location detection failed: $e');
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
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.primary.withValues(alpha: 0.05),
      appBar: PreferredSize(
        // Height interpolates continuously with _headerCollapseProgress
        // (see _onScroll) instead of jumping between the two constants.
        preferredSize: Size.fromHeight(
          Tween<double>(
            begin: _kAppBarExpandedContent,
            end: _kAppBarCollapsedContent,
          ).transform(_headerCollapseProgress),
        ),
        child: HomeAppBar(collapseProgress: _headerCollapseProgress),
      ),
      body: Consumer2<ProductProvider, CategoryProvider>(
        builder: (context, productProvider, categoryProvider, child) {
          // ✅ ENHANCED: Skip shimmer if we have cached products
          // Only show shimmer on first load with NO data
          final hasContent =
              productProvider.hasProducts || categoryProvider.hasCategories;
          if (productProvider.isLoading && !_isRefreshing && !hasContent) {
            return _buildShimmerLoading(isDark);
          }

          // ✅ Start animations immediately if we have cached content
          if (hasContent &&
              _staggerAnimationController.status == AnimationStatus.dismissed) {
            _staggerAnimationController.forward();
          }

          // ✅ Show location selector if no location is set
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final settingsProvider =
                Provider.of<SettingsProvider>(context, listen: false);
            if (settingsProvider.selectedLocation == null ||
                settingsProvider.selectedLocation!.isEmpty) {
              _autoDetectLocationSilently(settingsProvider);
            }
          });

          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await _loadData(forceRefresh: true); // ✅ Force Firebase fetch
            },
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            strokeWidth: 3.0,
            displacement: 60,
            child: Consumer<HomeSectionOrderProvider>(
              builder: (context, sectionOrderProvider, child) {
                // HOME-9: the 5 reorderable sections render in the admin's
                // own configured order (falls back to today's exact order --
                // defaultMobileOrder -- when unconfigured), with FRESH
                // sequential animation indices recomputed from each
                // section's final rendered position rather than the old
                // literal per-widget index -- BannerSlider stays fixed at
                // index 0, Footer's index is always the last one.
                final mobileOrder = sectionOrderProvider.mobileOrder;

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // Banner Slider (fixed, always first)
                    SliverToBoxAdapter(
                      child: _buildAnimatedBoxWrapper(
                        index: 0,
                        child: const BannerSlider(),
                      ),
                    ),

                    // HOME-10: Sponsored Banners (fixed, always second --
                    // not one of HomeSectionOrderProvider's own reorderable
                    // identifiers; renders nothing when there are no active
                    // sponsored banners).
                    SliverToBoxAdapter(
                      child: _buildAnimatedBoxWrapper(
                        index: 1,
                        child: const SponsoredBannerStrip(),
                      ),
                    ),

                    // Reorderable sections, admin-configured order
                    for (int i = 0; i < mobileOrder.length; i++)
                      SliverToBoxAdapter(
                        child: _buildAnimatedBoxWrapper(
                          index: i + 2,
                          child: _buildSectionByIdentifier(
                            mobileOrder[i],
                            productProvider,
                            categoryProvider,
                          ),
                        ),
                      ),

                    // Simple Footer (fixed, always last)
                    SliverToBoxAdapter(
                      child: _buildAnimatedBoxWrapper(
                        index: mobileOrder.length + 2,
                        child: _buildSimpleFooter(isDark),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(isDark),
    );
  }

  // --- HOME-9: identifier -> reorderable section widget ---
  Widget _buildSectionByIdentifier(
    String identifier,
    ProductProvider productProvider,
    CategoryProvider categoryProvider,
  ) {
    switch (identifier) {
      case 'bestsellers':
        return const DealsForYou();
      case 'grocery_kitchen_strip':
        return const GroceryKitchenHomeStrip();
      case 'recently_viewed':
        return const RecentlyViewedWidget();
      case 'dynamic_category_sections':
        return const DynamicCategorySections(skipCount: 9);
      case 'product_sections':
        return _buildProductSections(productProvider, categoryProvider);
      default:
        // HomeSectionOrderProvider's own permutation validation already
        // guarantees this never happens with a valid admin config -- render
        // nothing rather than crash if it somehow does.
        return const SizedBox.shrink();
    }
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
      baseColor: isDark ? const Color(0xFF303030) : Colors.grey[300]!,
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
  Widget _buildProductSections(
      ProductProvider productProvider, CategoryProvider categoryProvider) {
    final categories = categoryProvider.categories
        .where((c) => c.isActive && c.isVisible)
        .toList()
      ..sort(CategoryModel.compareSiblingOrder);
    final allProducts =
        productProvider.products.where((p) => p.isActive).toList();

    // Group products by category (shared by both the admin-configured path
    // and the fallback path below)
    final Map<String, List<ProductModel>> productsByCategory = {};
    for (final product in allProducts) {
      CategoryModel? hit;
      for (final category in categories) {
        if (productBelongsToCategory(product, category, categories)) {
          hit = category;
          break;
        }
      }
      final key = hit?.id ?? product.categoryId;
      productsByCategory.putIfAbsent(key, () => []);
      productsByCategory[key]!.add(product);
    }

    // HOME-3: admin-configured section order/titles/caps, when the admin
    // has set any up (docs/home/CURRENT_HOME_ARCHITECTURE.md). Falls back
    // to the pre-existing loop-all-active-categories behaviour below when
    // the config collection is empty or hasn't loaded yet — never a blank
    // Home, and a fresh install behaves exactly as it always has.
    final sectionConfigProvider =
        context.watch<HomeProductSectionConfigProvider>();
    if (sectionConfigProvider.hasConfiguredSections) {
      final List<Widget> configuredSections = [];
      int configuredCount = 0;
      for (final config in sectionConfigProvider.activeSections) {
        CategoryModel? category;
        for (final c in categories) {
          if (c.id == config.categoryId) {
            category = c;
            break;
          }
        }
        // The configured category no longer exists or isn't active —
        // skip this row silently rather than render a broken section;
        // the admin screen still shows it so the gap is visible there.
        if (category == null) continue;

        final categoryProducts = productsByCategory[category.id] ?? [];
        if (categoryProducts.isEmpty) continue;

        configuredCount++;
        final displayProducts =
            categoryProducts.take(config.maxItems).toList();

        configuredSections.add(
          ProductSectionWidget(
            sectionTitle: config.titleOverride ?? category.name,
            products: displayProducts,
            categoryId: category.id,
            onSeeAll: () {
              context.read<ShopEntryProvider>().openShopWithCategory(
                    categoryId: category!.id,
                    categoryName: category.name,
                  );
            },
          ),
        );

        // Same "after the 5th section" placement as the fallback path, so
        // switching between admin-configured and fallback never moves the
        // promo banner to a jarringly different spot.
        if (configuredCount == 5) {
          configuredSections.add(const SectionBannerCarousel(afterSection: 5));
        }
      }
      // Every configured section pointed at a since-deleted/emptied
      // category — fall through to the pre-existing behaviour rather than
      // show nothing.
      if (configuredSections.isNotEmpty) {
        return Column(children: configuredSections);
      }
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
      final displayProducts =
          categoryProducts.take(productsPerSection).toList();

      sections.add(
        ProductSectionWidget(
          sectionTitle: category.name,
          products: displayProducts,
          categoryId: category.id,
          onSeeAll: () {
            context.read<ShopEntryProvider>().openShopWithCategory(
                  categoryId: category.id,
                  categoryName: category.name,
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
          child: const Icon(Icons.keyboard_arrow_up_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // --- Blinkit Style Auto Location Detect ---
  void _showAutoLocationBottomSheet(
      BuildContext context, SettingsProvider settingsProvider) {
    if (!mounted) return;

    // Prevent multiple dialogs
    if (ModalRoute.of(context)?.isCurrent != true) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        return _AutoLocationSheet(
            settingsProvider: settingsProvider,
            parentContext: context,
            onLoadData: () => _loadData(forceRefresh: true));
      },
    );
  }
}

class _AutoLocationSheet extends StatefulWidget {
  final SettingsProvider settingsProvider;
  final BuildContext parentContext;
  final VoidCallback onLoadData;

  const _AutoLocationSheet({
    required this.settingsProvider,
    required this.parentContext,
    required this.onLoadData,
  });

  @override
  State<_AutoLocationSheet> createState() => _AutoLocationSheetState();
}

class _AutoLocationSheetState extends State<_AutoLocationSheet> {
  bool _isDetecting = true;
  bool _isServiceable = false;
  String _detectedCity = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  // Define serviceable cities
  final List<String> _serviceableCities = [
    'chennai',
    'madurai',
    'theni',
    'coimbatore',
    'bengaluru',
    'bangalore'
  ];

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final city = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Unknown';
        final exactLocation = [
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
        final displayLocation = exactLocation.isNotEmpty ? exactLocation : city;

        setState(() {
          _detectedCity = displayLocation;
          _isDetecting = false;
          _isServiceable =
              _serviceableCities.any((c) => city.toLowerCase().contains(c));
        });
        await _saveLocationTargeting(
          lat: position.latitude,
          lng: position.longitude,
          state: place.administrativeArea ?? '',
          district: place.subAdministrativeArea ?? city,
          displayLocation: displayLocation,
        );

        // Automatically set and proceed if serviceable
        if (_isServiceable) {
          await widget.settingsProvider.changeLocation(displayLocation);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context);
            widget.onLoadData();
          }
        }
      } else {
        throw Exception('Could not determine city from coordinates');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDetecting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _saveLocationTargeting({
    required double lat,
    required double lng,
    required String state,
    required String district,
    required String displayLocation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('selected_latitude', lat);
    await prefs.setDouble('selected_longitude', lng);
    if (state.trim().isNotEmpty) {
      await prefs.setString('selected_state', state.trim());
    }
    if (district.trim().isNotEmpty) {
      await prefs.setString('selected_district', district.trim());
    }
    await prefs.setString('selected_location', displayLocation);
  }

  void _manualSelect(String city) async {
    await widget.settingsProvider.changeLocation(city);
    if (mounted) {
      Navigator.pop(context);
      widget.onLoadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (_isDetecting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Detecting your location...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we find sellers near you',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ] else if (_errorMessage.isNotEmpty) ...[
              Icon(Icons.location_off_rounded,
                  size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text(
                'Location Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _buildManualSelection(colorScheme),
            ] else if (_isServiceable) ...[
              Icon(Icons.check_circle_rounded,
                  size: 56, color: Colors.green.shade600),
              const SizedBox(height: 16),
              Text(
                'Delivery available in $_detectedCity!',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Loading nearby products...',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Icon(Icons.error_outline_rounded,
                  size: 56, color: Colors.orange.shade600),
              const SizedBox(height: 16),
              Text(
                'Sorry, not serviceable yet in $_detectedCity',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We are expanding quickly. Meanwhile, you can explore other cities.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _buildManualSelection(colorScheme),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSelection(ColorScheme colorScheme) {
    return Column(
      children: [
        const Text(
          'Select a city manually',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _serviceableCities.take(4).map((city) {
            String capitalized = city[0].toUpperCase() + city.substring(1);
            return ActionChip(
              label: Text(capitalized),
              onPressed: () => _manualSelect(capitalized),
              backgroundColor: colorScheme.primaryContainer,
              labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
            );
          }).toList(),
        ),
      ],
    );
  }
}
