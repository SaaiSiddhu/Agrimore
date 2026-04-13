import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/routes.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../models/product_model.dart';

class ProductCardWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const ProductCardWidget({
    Key? key,
    required this.product,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ProductModel _convertToProductModel() {
    final price = (widget.product['price'] ?? 0).toDouble();
    final originalPrice = widget.product['originalPrice']?.toDouble();
    
    return ProductModel(
      id: widget.product['id'] ?? '',
      name: widget.product['name'] ?? 'Product',
      description: widget.product['description'] ?? '',
      salePrice: price,
      originalPrice: originalPrice,
      categoryId: widget.product['categoryId'] ?? widget.product['category'] ?? '',
      images: widget.product['images'] != null 
          ? List<String>.from(widget.product['images'])
          : (widget.product['imageUrl'] != null ? [widget.product['imageUrl']] : []),
      stock: widget.product['stock'] ?? 100,
      rating: (widget.product['rating'] ?? 0.0).toDouble(),
      reviewCount: widget.product['reviews'] ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.product['name'] ?? 'Product';
    final price = widget.product['price'] ?? 0;
    final originalPrice = widget.product['originalPrice'];
    final imageUrl = widget.product['imageUrl'] ?? 
                     (widget.product['images']?.isNotEmpty == true 
                         ? widget.product['images'][0] 
                         : '');
    final rating = (widget.product['rating'] ?? 0.0).toDouble();
    final reviews = widget.product['reviews'] ?? 0;
    final description = widget.product['description'] ?? '';
    final inStock = (widget.product['stock'] ?? 100) > 0;

    final product = _convertToProductModel();
    final discountPercent = product.discount; // ✅ Use the getter

    return Consumer2<CartProvider, WishlistProvider>(
      builder: (context, cartProvider, wishlistProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);
        final isInWishlist = wishlistProvider.isInWishlist(product.id);

        return GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapCancel: () => _controller.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 200,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section with Badge & Wishlist
                  Stack(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey[100]!, Colors.grey[50]!],
                            ),
                          ),
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => 
                                      _buildPlaceholder(),
                                )
                              : _buildPlaceholder(),
                        ),
                      ),

                      // Discount Badge
                      if (discountPercent != null && discountPercent > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red[600]!, Colors.red[400]!],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '-$discountPercent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Wishlist Button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white,
                          elevation: 4,
                          shape: const CircleBorder(),
                          shadowColor: Colors.black.withOpacity(0.2),
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              if (isInWishlist) {
                                await wishlistProvider.removeItem(product.id);
                              } else {
                                await wishlistProvider.addItem(product);
                              }
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              child: Icon(
                                isInWishlist 
                                    ? Icons.favorite 
                                    : Icons.favorite_border,
                                color: isInWishlist ? Colors.red : Colors.grey[600],
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Stock Status Overlay
                      if (!inStock)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Details Section
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // Description
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          const SizedBox(height: 6),

                          // Rating
                          if (rating > 0)
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.amber[700],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($reviews)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),

                          const Spacer(),

                          // Price Section
                          Row(
                            children: [
                              Text(
                                '₹${price.toString()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (originalPrice != null && originalPrice > price)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '₹$originalPrice',
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Action Buttons
                          Row(
                            children: [
                              // Add to Cart Button
                              Expanded(
                                child: SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: inStock
                                        ? (isInCart
                                            ? null
                                            : () async {
                                                HapticFeedback.mediumImpact();
                                                await cartProvider.addItem(
                                                  product,
                                                  quantity: 1,
                                                );
                                                if (mounted) {
                                                  _showSnackBar(
                                                    context,
                                                    'Added to cart! 🛒',
                                                  );
                                                }
                                              })
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isInCart
                                          ? AppColors.success
                                          : AppColors.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: isInCart
                                          ? AppColors.success
                                          : Colors.grey[300],
                                      disabledForegroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Icon(
                                      isInCart 
                                          ? Icons.check 
                                          : Icons.shopping_cart_outlined,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // Buy Now Button
                              Expanded(
                                child: SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: inStock
                                        ? () async {
                                            HapticFeedback.mediumImpact();
                                            if (!isInCart) {
                                              await cartProvider.addItem(
                                                product,
                                                quantity: 1,
                                              );
                                            }
                                            if (mounted) {
                                              AppRoutes.navigateTo(
                                                context,
                                                AppRoutes.cart,
                                              );
                                            }
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[600],
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Colors.grey[300],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Icon(
                                      Icons.flash_on,
                                      size: 16,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[200]!, Colors.grey[100]!],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 50,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
