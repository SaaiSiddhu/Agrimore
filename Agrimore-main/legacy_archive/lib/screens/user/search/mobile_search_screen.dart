import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../models/product_model.dart';

class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({Key? key}) : super(key: key);

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _performSearch(String query) {
    setState(() => _searchQuery = query);

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;

    _searchResults = allProducts.where((product) {
      final searchLower = query.toLowerCase();
      return product.name.toLowerCase().contains(searchLower) ||
          product.description.toLowerCase().contains(searchLower);
    }).toList();

    setState(() => _isSearching = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _performSearch,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _buildBody(isMobile),
    );
  }

  Widget _buildBody(bool isMobile) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchQuery.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults(isMobile);
    }

    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        childAspectRatio: 0.65,
        crossAxisSpacing: isMobile ? 12 : 20,
        mainAxisSpacing: isMobile ? 12 : 20,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_searchResults[index]);
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Consumer2<CartProvider, WishlistProvider>(
      builder: (context, cartProvider, wishlistProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);
        final isInWishlist = wishlistProvider.isInWishlist(product.id);

        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            AppRoutes.navigateTo(
              context,
              AppRoutes.productDetails,
              arguments: product.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          image: product.imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(product.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: product.imageUrl == null
                            ? const Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      ),
                      // Wishlist Button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white,
                          elevation: 2,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () async {
                              if (isInWishlist) {
                                await wishlistProvider.removeItem(product.id);
                              } else {
                                await wishlistProvider.addItem(product);
                              }
                            },
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isInWishlist ? Icons.favorite : Icons.favorite_border,
                                color: isInWishlist ? AppColors.error : AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: isInCart
                                ? null
                                : () async {
                                    await cartProvider.addItem(product, quantity: 1);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInCart ? AppColors.success : AppColors.primary,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isInCart ? 'In Cart' : 'Add',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 40 : 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: isMobile ? 100 : 120,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            SizedBox(height: isMobile ? 24 : 32),
            Text(
              'Search for products',
              style: (isMobile ? AppTextStyles.titleLarge : AppTextStyles.headlineMedium).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Find what you\'re looking for',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 40 : 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: isMobile ? 100 : 120,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            SizedBox(height: isMobile ? 24 : 32),
            Text(
              'No products found',
              style: (isMobile ? AppTextStyles.titleLarge : AppTextStyles.headlineMedium).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try searching with different keywords',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
