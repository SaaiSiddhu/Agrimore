import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../models/product_model.dart';

class VariantSelector extends StatelessWidget {
  // ✅ REMOVED all parameters, now uses Provider
  const VariantSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    // ✅ NEW: Consumes the ProductProvider to get state
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final product = productProvider.selectedProduct;
        if (product == null || product.variantOptions.isEmpty) {
          return const SizedBox.shrink();
        }

        // ✅ NEW: Uses the _buildCardSection UI
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    Icon(Icons.style_outlined, color: accentColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Select Variant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: isDark ? Colors.grey[800]! : Colors.grey[200], height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: product.variantOptions.map((option) {
                    return _buildOptionRow(context, option, isDark, accentColor, productProvider);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionRow(
    BuildContext context,
    VariantOption option,
    bool isDark,
    Color accentColor,
    ProductProvider productProvider,
  ) {
    // ✅ NEW: Reads selected option from the provider
    final selectedValue = productProvider.selectedOptions[option.name];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: option.values.map((value) {
            final isSelected = selectedValue == value;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                // ✅ NEW: Calls the provider to update the state
                productProvider.selectVariantOption(option.name, value);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor
                      : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}