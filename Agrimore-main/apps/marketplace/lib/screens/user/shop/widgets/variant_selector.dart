import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Modern variant selector with horizontal chips showing name + price
/// Matches Blinkit/Zepto style "Select Unit" design
class VariantSelector extends StatelessWidget {
  const VariantSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final product = productProvider.selectedProduct;
        if (product == null || product.variants.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedVariant = productProvider.selectedVariant;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - "Select Unit"
            Text(
              'Select Unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            
            // Horizontal scrolling variant chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: product.variants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final variant = entry.value;
                  final isSelected = selectedVariant?.name == variant.name;
                  
                  return Padding(
                    padding: EdgeInsets.only(right: index < product.variants.length - 1 ? 12 : 0),
                    child: _buildVariantChip(
                      context: context,
                      variant: variant,
                      isSelected: isSelected,
                      isDark: isDark,
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        productProvider.selectVariantByName(variant.name);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVariantChip({
    required BuildContext context,
    required ProductVariant variant,
    required bool isSelected,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final hasDiscount = variant.originalPrice != null && 
                        variant.originalPrice! > variant.salePrice;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? accentColor.withOpacity(0.08)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? accentColor 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: accentColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Variant name (e.g., "300 ml" or "6 x 300 ml")
            Text(
              variant.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected 
                    ? accentColor 
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            // Price row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sale price
                Text(
                  '₹${variant.salePrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                // Original price (if discounted)
                if (hasDiscount) ...[
                  const SizedBox(width: 6),
                  Text(
                    'MRP ₹${variant.originalPrice!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}