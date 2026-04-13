import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/themes/app_colors.dart';
import '../../../app/routes.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/theme_provider.dart';
import '../shop/widgets/product_card.dart';
import 'widgets/empty_wishlist.dart';

class MobileWishlistScreen extends StatefulWidget {
  const MobileWishlistScreen({Key? key}) : super(key: key);

  @override
  State<MobileWishlistScreen> createState() => _MobileWishlistScreenState();
}

class _MobileWishlistScreenState extends State<MobileWishlistScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    _loadWishlist();
  }

  void _loadWishlist() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
      wishlistProvider.loadWishlist();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark, cardColor, accentColor),
      body: Consumer2<WishlistProvider, ProductProvider>(
        builder: (context, wishlistProvider, productProvider, child) {
          if (wishlistProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          if (wishlistProvider.isEmpty) {
            return const EmptyWishlist();
          }

          final wishlistProductIds = wishlistProvider.productIds;
          final products = productProvider.products
              .where((product) => wishlistProductIds.contains(product.id))
              .toList();

          return RefreshIndicator(
            color: accentColor,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              wishlistProvider.loadWishlist();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Stats Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildStatsCard(
                      wishlistProvider,
                      isDark,
                      cardColor,
                      accentColor,
                    ),
                  ),
                ),

                // Grid View with ProductCard
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                (index / products.length) * 0.5,
                                1.0,
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                          child: ProductCard(
                            product: products[index],
                            isGridView: true,
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color cardColor, Color accentColor) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'My Wishlist',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        Consumer<WishlistProvider>(
          builder: (context, wishlistProvider, child) {
            if (wishlistProvider.itemCount > 0) {
              return IconButton(
                onPressed: () => _showClearConfirmation(context),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade600,
                    size: 18,
                  ),
                ),
                tooltip: 'Clear All',
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsCard(
    WishlistProvider wishlistProvider,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.red.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${wishlistProvider.itemCount} ${wishlistProvider.itemCount == 1 ? 'Product' : 'Products'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Move All Button
          ElevatedButton(
            onPressed: () => _moveAllToCart(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Move All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade600,
                      Colors.red.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Clear Wishlist?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove all items from your wishlist?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearWishlist(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearWishlist(BuildContext context) async {
    final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);

    HapticFeedback.heavyImpact();
    await wishlistProvider.clearWishlist();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Wishlist cleared',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
    }
  }

  void _moveAllToCart(BuildContext context) async {
    final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final wishlistProductIds = wishlistProvider.productIds;
    final products = productProvider.products
        .where((product) => wishlistProductIds.contains(product.id))
        .toList();

    if (products.isEmpty) return;

    HapticFeedback.mediumImpact();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentColor),
              const SizedBox(height: 16),
              Text(
                'Moving to cart...',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (var product in products) {
      await cartProvider.addItem(product, quantity: 1);
    }

    await wishlistProvider.clearWishlist();

    // Close loading
    if (mounted) Navigator.pop(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.shopping_cart_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${products.length} items moved to cart',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () {
              AppRoutes.navigateTo(context, AppRoutes.cart);
            },
          ),
        ),
      );
    }
  }
}
