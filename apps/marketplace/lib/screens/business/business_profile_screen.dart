import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/theme_provider.dart';
import '../../providers/business_follow_provider.dart';
import '../../providers/category_provider.dart';
import '../user/shop/widgets/product_grid.dart';
import 'storefront_visibility.dart';

/// BUSINESS-NETWORK-1 (slice 1 of 2): a customer-facing public profile for a
/// seller -- name/shop details + their product list + a follow button. The
/// seller's own "Mini Portal" (SellerPanelScreen, apps/marketplace) is a
/// stub with no bearing on this; this is the customer's VIEW of a seller,
/// not the seller's own management UI (that lives in apps/seller).
///
/// Reads `sellers/{sellerId}` directly (firestore.rules: `allow read: if
/// true`, confirmed at claim time -- no rules change needed for this
/// screen) and `products` filtered by `sellerId`. Follow state is scoped
/// to this screen via a plain (non-widget-tree) BusinessFollowProvider
/// instance -- no need for main.dart's app-wide MultiProvider for a toggle
/// that only matters while this screen is open.
class BusinessProfileScreen extends StatefulWidget {
  final String sellerId;

  const BusinessProfileScreen({Key? key, required this.sellerId})
      : super(key: key);

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

const _kProductsPageSize = 20;
const _kCategoryPageSize = 60;

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Map<String, dynamic>? _seller;
  List<ProductModel> _products = [];
  int? _productCount;
  bool _loading = true;
  String? _error;
  bool _descriptionExpanded = false;
  String? _selectedCategoryId;
  DocumentSnapshot<Map<String, dynamic>>? _lastProductDoc;
  bool _hasMoreProducts = true;
  bool _loadingMoreProducts = false;
  final BusinessFollowProvider _followProvider = BusinessFollowProvider();

  // SELLER-STOREFRONT-EDIT-1: a selected category is fetched from the server
  // (sellerId + categoryId, equality-only — no composite index), so products
  // beyond the pages already loaded are not missed.
  final Map<String, List<ProductModel>> _categoryProducts = {};
  String? _loadingCategoryId;

  List<ProductModel> get _filteredProducts {
    final id = _selectedCategoryId;
    if (id == null) return _products;
    return _categoryProducts[id] ?? _products.where((p) => p.categoryId == id).toList();
  }

  Future<void> _selectCategory(String? id) async {
    setState(() => _selectedCategoryId = id);
    if (id == null || _categoryProducts.containsKey(id)) return;
    setState(() => _loadingCategoryId = id);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: widget.sellerId)
          .where('categoryId', isEqualTo: id)
          .limit(_kCategoryPageSize)
          .get();
      if (!mounted) return;
      setState(() {
        _categoryProducts[id] =
            snap.docs.map((d) => ProductModel.fromFirestore(d)).where(isVisibleOnStorefront).toList();
      });
    } catch (e) {
      debugPrint('Storefront category load failed: $e');
    } finally {
      if (mounted) setState(() => _loadingCategoryId = null);
    }
  }

  List<String> get _categoryIdsInProducts {
    final seen = <String>{};
    final ordered = <String>[];
    for (final p in _products) {
      if (seen.add(p.categoryId)) ordered.add(p.categoryId);
    }
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    _followProvider.addListener(_onFollowChanged);
    _followProvider.checkFollowing(widget.sellerId);
    // Fire-and-forget: category chips are a secondary enhancement, not
    // load-bearing for the primary content below. loadCategories() already
    // no-ops on a warm cache (most navigations here arrive from a screen
    // that loaded categories already).
    context.read<CategoryProvider>().loadCategories();
    _load();
  }

  void _onFollowChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _followProvider.removeListener(_onFollowChanged);
    _followProvider.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(widget.sellerId)
          .get();

      final productsQuery = FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: widget.sellerId);

      final productsSnap = await productsQuery.limit(_kProductsPageSize).get();
      // Count only what a buyer can see (hidden/draft products are stored
      // with isActive: false).
      final countSnap = await productsQuery.where('isActive', isEqualTo: true).count().get();

      if (!mounted) return;
      setState(() {
        _seller = sellerDoc.exists ? sellerDoc.data() : null;
        _products = productsSnap.docs
            .map((d) => ProductModel.fromFirestore(d))
            .where(isVisibleOnStorefront)
            .toList();
        _categoryProducts.clear();
        _productCount = countSnap.count;
        _lastProductDoc = productsSnap.docs.isNotEmpty ? productsSnap.docs.last : null;
        _hasMoreProducts = productsSnap.docs.length == _kProductsPageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Real pagination (SELLER-STOREFRONT-1 WS3): a document cursor over the
  // same sellerId query _load() already runs, replacing the old one-shot
  // .limit(60) fetch. Category-chip filtering stays client-side over
  // whatever pages are currently loaded (unchanged from WS2) rather than
  // adding a server-side categoryId filter here -- that would need a new
  // sellerId+categoryId composite index this phase has no way to verify
  // safe without a live emulator seeded with realistic multi-category
  // data, so it is left out rather than shipped unverified.
  Future<void> _loadMoreProducts() async {
    if (_loadingMoreProducts || !_hasMoreProducts || _lastProductDoc == null) return;
    setState(() => _loadingMoreProducts = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: widget.sellerId)
          .startAfterDocument(_lastProductDoc!)
          .limit(_kProductsPageSize)
          .get();

      if (!mounted) return;
      setState(() {
        _products.addAll(snap.docs.map((d) => ProductModel.fromFirestore(d)).where(isVisibleOnStorefront));
        _lastProductDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastProductDoc;
        _hasMoreProducts = snap.docs.length == _kProductsPageSize;
        _loadingMoreProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMoreProducts = false);
      SnackbarHelper.showError(context, 'Could not load more products. Please try again.');
    }
  }

  Widget _buildLoadMoreControl(bool isDark, Color accentColor) {
    if (_selectedCategoryId != null || !_hasMoreProducts) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _loadingMoreProducts
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(
                onPressed: _loadMoreProducts,
                style: OutlinedButton.styleFrom(foregroundColor: accentColor),
                child: const Text('Load more'),
              ),
      ),
    );
  }

  // Hidden for a signed-out viewer or the seller viewing their own profile
  // (matches firestore.rules' own sellerId != request.auth.uid guard on
  // create -- a seller can never actually follow themselves, so no button
  // that would only ever fail).
  Widget _buildFollowButton(bool isDark, Color accentColor) {
    final viewerUid = FirebaseAuth.instance.currentUser?.uid;
    if (viewerUid == null || viewerUid == widget.sellerId) {
      return const SizedBox.shrink();
    }

    final isFollowing = _followProvider.isFollowing;
    final isLoading = _followProvider.isLoading;

    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: isLoading
            ? null
            : () async {
                final result =
                    await _followProvider.toggleFollow(widget.sellerId);
                if (result == null && mounted) {
                  SnackbarHelper.showError(
                    context,
                    'Could not update follow status. Please try again.',
                  );
                }
              },
        icon: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isFollowing
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : accentColor,
                ),
              )
            : Icon(
                isFollowing ? Icons.check : Icons.add,
                size: 16,
                color: isFollowing
                    ? (isDark ? Colors.white70 : Colors.black54)
                    : accentColor,
              ),
        label: Text(isFollowing ? 'Following' : 'Follow'),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isFollowing ? (isDark ? Colors.white70 : Colors.black54) : accentColor,
          side: BorderSide(
            color: isFollowing
                ? (isDark ? Colors.white24 : Colors.black26)
                : accentColor,
          ),
        ),
      ),
    );
  }

  // SELLER-STOREFRONT-1. `sellers/{uid}.createdAt` is a server timestamp set
  // at approval (createSellerByAdmin.ts / the admin approval batch) -- a
  // real signal, not derived from any client-controllable field.
  String? _tenureLabel() {
    final createdAt = _seller?['createdAt'];
    if (createdAt is! Timestamp) return null;
    final days = DateTime.now().difference(createdAt.toDate()).inDays;
    if (days < 30) return 'New seller';
    if (days < 365) {
      final months = (days / 30).floor();
      return '$months mo${months > 1 ? 's' : ''}';
    }
    final years = (days / 365).floor();
    return '$years yr${years > 1 ? 's' : ''}';
  }

  Widget _buildMetricStat(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Verified reflects `status == 'approved'`, rules-enforced
  // (ownerCannotApproveSellerStatus() -- a seller can never self-approve).
  // Not always true here: unlike ADMIN-SELLER-CMS-1's own admin list (which
  // filters status=='approved'), this screen opens any sellerId directly,
  // so a pending/rejected seller's profile is reachable and must not show
  // this badge.
  Widget _buildVerifiedBadge(bool isVerified) {
    if (!isVerified) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 13, color: AppColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            'Verified Seller',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark) {
    final tenure = _tenureLabel();
    final isVerified = _seller?['status'] == 'approved';
    if (_productCount == null && tenure == null && !isVerified) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          if (_productCount != null)
            _buildMetricStat('$_productCount', 'Products', isDark),
          if (_productCount != null && tenure != null) const SizedBox(width: 24),
          if (tenure != null) _buildMetricStat(tenure, 'On Agrimore', isDark),
          if (isVerified) ...[
            const Spacer(),
            _buildVerifiedBadge(true),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverBanner(bool isDark, Color accentColor, String? coverUrl) {
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: hasCover
            ? null
            : LinearGradient(
                colors: [accentColor.withValues(alpha: 0.85), accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        image: hasCover
            ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
            : null,
      ),
    );
  }

  // "About Seller" -- description (new, ADMIN-SELLER-CMS-1) + the full
  // shopAddress (already shown compact in the header; repeated here for a
  // seller whose address is too long for that single line). Renders
  // nothing when the seller has set neither, matching the "no broken
  // layout for a seller with none of the new fields" invariant.
  Widget _buildAboutSection(bool isDark, String? description, String? shopAddress) {
    final hasDescription = description != null && description.isNotEmpty;
    final hasAddress = shopAddress != null && shopAddress.isNotEmpty;
    if (!hasDescription && !hasAddress) return const SizedBox.shrink();

    const collapsedLines = 3;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.surfaceDark : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Seller',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (hasDescription) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: _descriptionExpanded ? null : collapsedLines,
              overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _descriptionExpanded ? 'Show less' : 'Read more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
          if (hasAddress) ...[
            SizedBox(height: hasDescription ? 10 : 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    shopAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Only platform-backed claims: Verified reflects the same rules-enforced
  // status this screen's own metrics-row badge uses; Secure Payments is a
  // platform-wide fact (Razorpay HMAC + live-status verification applies
  // to every order regardless of seller, security.md invariant I5) --
  // mirrors landing_screen.dart's own trust-badge copy/icons exactly, since
  // both are the same true claim in a different context. Deliberately NOT
  // included: any delivery-speed or return-rate claim -- no per-seller
  // fulfilment-metric data exists anywhere in this codebase to back one.
  Widget _buildTrustStrip(bool isDark, bool isVerified) {
    Widget badge(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: isDark ? AppColors.primaryLight : AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          if (isVerified) badge(Icons.verified_user_rounded, 'Verified Seller'),
          badge(Icons.shield_rounded, 'Secure Payments'),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? accentColor : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  // Derived from this seller's own products' categoryId (ProductModel,
  // required field) -- no schema change. Resolves a display name via the
  // app-wide CategoryProvider already registered in main.dart; falls back
  // to the raw id only in the (expected to be rare) case a category was
  // deleted after a product referenced it.
  Widget _buildCategoryChips(bool isDark, Color accentColor, CategoryProvider categoryProvider) {
    final ids = _categoryIdsInProducts;
    if (ids.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: ids.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildCategoryChip(
                label: 'All',
                isActive: _selectedCategoryId == null,
                onTap: () => _selectCategory(null),
                isDark: isDark,
                accentColor: accentColor,
              );
            }
            final id = ids[index - 1];
            final name = categoryProvider.getCategoryById(id)?.name ?? id;
            return _buildCategoryChip(
              label: name,
              isActive: _selectedCategoryId == id,
              onTap: () => _selectCategory(_selectedCategoryId == id ? null : id),
              isDark: isDark,
              accentColor: accentColor,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final categoryProvider = context.watch<CategoryProvider>();
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final shopName = (_seller?['shopName'] as String?)?.trim();
    final shopAddress = (_seller?['shopAddress'] as String?)?.trim();
    final logoUrl = (_seller?['logoUrl'] as String?)?.trim();
    final coverUrl = (_seller?['coverImageUrl'] as String?)?.trim();
    final description = (_seller?['description'] as String?)?.trim();
    final isVerified = _seller?['status'] == 'approved';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey[50],
      appBar: AppBar(
        title: Text(shopName?.isNotEmpty == true ? shopName! : 'Business Profile'),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          // BUSINESS-NETWORK-2: the entry point into the followers' feed --
          // deliberately a small addition here rather than a new persistent
          // bottom-nav tab or main-menu item.
          IconButton(
            icon: const Icon(Icons.dynamic_feed_outlined),
            tooltip: 'Following feed',
            onPressed: () => Navigator.pushNamed(context, '/business-feed'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(
                  message: 'Could not load this business profile.',
                  onRetry: _load,
                )
              : _seller == null
                  ? const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Not found',
                      message: 'This business could not be found.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          _buildCoverBanner(isDark, accentColor, coverUrl),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: accentColor.withValues(alpha: 0.1),
                                      backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
                                          ? NetworkImage(logoUrl)
                                          : null,
                                      child: (logoUrl == null || logoUrl.isEmpty)
                                          ? Icon(Icons.storefront, color: accentColor, size: 28)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shopName?.isNotEmpty == true ? shopName! : 'Business Profile',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          if (shopAddress?.isNotEmpty == true) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              shopAddress!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                _buildMetricsRow(isDark),
                                if (storefrontHighlights(_seller).isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final h in storefrontHighlights(_seller))
                                        Chip(
                                          avatar: Icon(Icons.check_circle, size: 16, color: accentColor),
                                          label: Text(h),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 14),
                                _buildFollowButton(isDark, accentColor),
                              ],
                            ),
                          ),
                          _buildAboutSection(isDark, description, shopAddress),
                          _buildTrustStrip(isDark, isVerified),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Products (${_productCount ?? _products.length})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          _buildCategoryChips(isDark, accentColor, categoryProvider),
                          if (_loadingCategoryId != null && _loadingCategoryId == _selectedCategoryId)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_filteredProducts.isEmpty)
                            EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: _products.isEmpty ? 'No products yet' : 'No products in this category',
                              message: _products.isEmpty
                                  ? 'This seller has not listed any products yet.'
                                  : 'Try a different category.',
                            )
                          else
                            ProductGrid(products: _filteredProducts),
                          _buildLoadMoreControl(isDark, accentColor),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}
