import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../app/routes.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import 'widgets/empty_wishlist.dart';
import 'widgets/wishlist_item_card.dart';

class WebWishlistScreen extends StatefulWidget {
  const WebWishlistScreen({Key? key}) : super(key: key);

  @override
  State<WebWishlistScreen> createState() => _WebWishlistScreenState();
}

class _WebWishlistScreenState extends State<WebWishlistScreen> {
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1400 ? 4 : (screenWidth > 1200 ? 3 : 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Wishlist',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer<WishlistProvider>(
            builder: (context, wishlistProvider, child) {
              if (wishlistProvider.itemCount > 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton.icon(
                    onPressed: () => _showClearConfirmation(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer2<WishlistProvider, ProductProvider>(
        builder: (context, wishlistProvider, productProvider, child) {
          if (wishlistProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
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
            onRefresh: () async {
              HapticFeedback.lightImpact();
              wishlistProvider.loadWishlist();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: AppColors.error,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Wishlist',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${wishlistProvider.itemCount} ${wishlistProvider.itemCount == 1 ? 'item' : 'items'} saved',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _moveAllToCart(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text(
                            'Move All to Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Products Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return WishlistItemCard(
                          product: products[index],
                          onRemove: () {
                            _removeItem(context, products[index].id);
                          },
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeItem(BuildContext context, String productId) {
    final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
    
    HapticFeedback.mediumImpact();
    wishlistProvider.removeItem(productId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Removed from wishlist'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Wishlist?'),
        content: const Text('Are you sure you want to remove all items from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearWishlist(context);
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
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
          content: const Text('Wishlist cleared'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _moveAllToCart(BuildContext context) async {
    final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final wishlistProductIds = wishlistProvider.productIds;
    final products = productProvider.products
        .where((product) => wishlistProductIds.contains(product.id))
        .toList();

    HapticFeedback.mediumImpact();

    for (var product in products) {
      await cartProvider.addItem(product, quantity: 1);
    }

    await wishlistProvider.clearWishlist();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${products.length} items moved to cart'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
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
