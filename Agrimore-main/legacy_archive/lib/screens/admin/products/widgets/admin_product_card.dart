import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/theme_provider.dart';

class AdminProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const AdminProductCard({
    Key? key,
    required this.product,
    this.onEdit,
    this.onDelete,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final int discount = product.discount; // Use the new getter

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shadowColor: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product.images.isNotEmpty
                        ? Image.network(
                            product.images.first,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildImagePlaceholder(isDark),
                          )
                        : _buildImagePlaceholder(isDark),
                  ),
                  
                  // Discount Badge
                  if (discount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  // Out of Stock Overlay
                  if (!product.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'OUT OF\nSTOCK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product.isFeatured)
                          _buildMiniBadge(Icons.star, AppColors.warning, 'Featured', isDark),
                        if (product.isVerified) ...[
                          const SizedBox(width: 4),
                          _buildMiniBadge(Icons.verified, Colors.blue, 'Verified', isDark),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Price
                    Row(
                      children: [
                        Text(
                          '₹${product.salePrice.toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.originalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${product.originalPrice!.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Stock Status
                    Row(
                      children: [
                        _buildStockBadge(product.stock > 0, 'Stock: ${product.stock}', isDark),
                        
                        // Rating
                        if (product.reviewCount > 0) ...[
                          const SizedBox(width: 8),
                          _buildMiniBadge(Icons.star_half, AppColors.warning, product.rating.toStringAsFixed(1), isDark),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action Menu
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  if (onEdit != null)
                    PopupMenuItem(
                      child: Row(
                        children: const [
                          Icon(Icons.edit, size: 20, color: AppColors.info),
                          SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(Duration.zero, onEdit!);
                      },
                    ),
                  if (onDelete != null)
                    PopupMenuItem(
                      child: Row(
                        children: const [
                          Icon(Icons.delete, size: 20, color: AppColors.error),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(Duration.zero, onDelete!);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, Color color, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStockBadge(bool inStock, String label, bool isDark) {
    // ✅ FIXED: Added `!` for null safety, as AppColors.success/error are non-null
    final color = inStock ? (isDark ? Colors.green[300]! : AppColors.success) : (isDark ? Colors.red[300]! : AppColors.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.inventory_2, size: 40, color: isDark ? Colors.grey[600] : Colors.grey),
    );
  }
}