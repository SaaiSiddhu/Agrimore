// lib/screens/user/home/widgets/product_card_compact.dart
// Ultra compact product card for 3-column grid - Modern Premium Design
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../app/routes.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/wishlist_provider.dart';
import '../../../../providers/theme_provider.dart';

class ProductCardCompact extends StatelessWidget {
  final ProductModel product;
  final String? categoryName;
  final VoidCallback? onSeeMore;

  const ProductCardCompact({
    super.key,
    required this.product,
    this.categoryName,
    this.onSeeMore,
  });

  String _formatCount(int count) {
    if (count >= 100000) return '${(count / 100000).toStringAsFixed(1)} lac';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  int _getDiscountPercent() {
    if (product.originalPrice != null && product.originalPrice! > product.salePrice) {
      return (((product.originalPrice! - product.salePrice) / product.originalPrice!) * 100).round();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final wishlistProvider = Provider.of<WishlistProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    
    final isInWishlist = wishlistProvider.isInWishlist(product.id);
    final isInCart = cartProvider.isInCart(product.id);
    final hasVariants = product.variants.isNotEmpty;
    final variantCount = product.variants.length;
    final discountPercent = _getDiscountPercent();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Use dynamic route: /product/{id} instead of template route
        Navigator.pushNamed(context, '/product/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            if (!isDark)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Premium Overlays
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Product Image with Gradient Overlay
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark 
                                  ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                                  : [const Color(0xFFFAFAFA), const Color(0xFFF0F0F0)],
                            ),
                          ),
                          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[400],
                                    size: 36,
                                  ),
                                )
                              : Icon(Icons.image_outlined, color: Colors.grey[400], size: 36),
                        ),
                        // Subtle bottom gradient for text readability
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Wishlist Heart - Frosted Glass Effect
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (isInWishlist) {
                        wishlistProvider.removeFromWishlist(product.id);
                      } else {
                        wishlistProvider.addToWishlist(product);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isInWishlist 
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isInWishlist ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        size: 16,
                        color: isInWishlist ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                
                // Premium ADD Button - Floating Style
                Positioned(
                  bottom: -16,
                  left: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (!isInCart) {
                        cartProvider.addToCart(product);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isInCart 
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.85),
                                ],
                              )
                            : const LinearGradient(
                                colors: [Colors.white, Colors.white],
                              ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isInCart 
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isInCart ? Icons.check_rounded : Icons.add_rounded,
                            size: 14,
                            color: isInCart ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isInCart ? 'ADDED' : 'ADD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isInCart ? Colors.white : AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (hasVariants && !isInCart) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '+$variantCount',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Product Info - Premium Typography
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit badge with accent dot
                  if (product.unit != null && product.unit!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.unit!,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // Product Name - Better Typography
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Rating & Delivery - Same Row
                  Row(
                    children: [
                      // Rating badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 10, color: Colors.amber[700]),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delivery badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 10, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              product.expressDelivery == true 
                                  ? (product.expressDeliveryDays ?? '20 MIN')
                                  : '30 MIN',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 5),
                  
                  // Price - Premium Look
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${product.salePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (product.originalPrice != null && product.originalPrice! > product.salePrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
