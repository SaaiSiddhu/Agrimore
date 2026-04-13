import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../providers/theme_provider.dart';

class StockManager extends StatelessWidget {
  final TextEditingController stockController;
  final TextEditingController unitController; // ✅ MOVED HERE
  final TextEditingController minOrderController;
  final TextEditingController maxOrderController;

  const StockManager({
    Key? key,
    required this.stockController,
    required this.unitController, // ✅ MOVED HERE
    required this.minOrderController,
    required this.maxOrderController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stock Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2, size: 40, color: accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Management', style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      'Set available quantity and order limits',
                      style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Stock Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextFormField(
                controller: stockController,
                label: 'Stock Quantity *',
                hint: '0',
                icon: Icons.inventory_outlined,
                isDark: isDark,
                fillColor: inputFillColor,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (int.tryParse(v!) == null) return 'Invalid number';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildTextFormField(
                controller: unitController,
                label: 'Unit',
                hint: 'e.g., kg, L, pcs',
                icon: Icons.scale_outlined,
                isDark: isDark,
                fillColor: inputFillColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Min Order Quantity
        _buildTextFormField(
          controller: minOrderController,
          label: 'Minimum Order Quantity',
          hint: '1',
          icon: Icons.remove_circle_outline,
          isDark: isDark,
          fillColor: inputFillColor,
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 16),

        // Max Order Quantity
        _buildTextFormField(
          controller: maxOrderController,
          label: 'Maximum Order Quantity',
          hint: 'No limit',
          icon: Icons.add_circle_outline,
          isDark: isDark,
          fillColor: inputFillColor,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color fillColor,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
        ),
        filled: true,
        fillColor: fillColor,
        alignLabelWithHint: maxLines > 1,
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}