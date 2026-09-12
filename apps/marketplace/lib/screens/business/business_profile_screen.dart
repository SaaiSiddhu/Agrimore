import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/theme_provider.dart';
import '../../providers/business_follow_provider.dart';
import '../user/shop/widgets/product_grid.dart';

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

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Map<String, dynamic>? _seller;
  List<ProductModel> _products = [];
  int? _productCount;
  bool _loading = true;
  String? _error;
  final BusinessFollowProvider _followProvider = BusinessFollowProvider();

  @override
  void initState() {
    super.initState();
    _followProvider.addListener(_onFollowChanged);
    _followProvider.checkFollowing(widget.sellerId);
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

      final productsSnap = await productsQuery.limit(60).get();
      final countSnap = await productsQuery.count().get();

      if (!mounted) return;
      setState(() {
        _seller = sellerDoc.exists ? sellerDoc.data() : null;
        _products =
            productsSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
        _productCount = countSnap.count;
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final shopName = (_seller?['shopName'] as String?)?.trim();
    final shopAddress = (_seller?['shopAddress'] as String?)?.trim();
    final logoUrl = (_seller?['logoUrl'] as String?)?.trim();
    final coverUrl = (_seller?['coverImageUrl'] as String?)?.trim();

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
                                const SizedBox(height: 14),
                                _buildFollowButton(isDark, accentColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Products (${_products.length})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (_products.isEmpty)
                            const EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No products yet',
                              message: 'This seller has not listed any products yet.',
                            )
                          else
                            ProductGrid(products: _products),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}
