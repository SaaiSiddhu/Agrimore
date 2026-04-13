import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/theme_provider.dart';

class ProductForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController originalPriceController;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final bool isFeatured;
  final bool isVerified; // ✅ NEW
  final bool isTrending; // ✅ NEW
  final Function(String?) onCategoryChanged;
  final Function(bool?) onFeaturedChanged;
  final Function(bool?) onVerifiedChanged; // ✅ NEW
  final Function(bool?) onTrendingChanged; // ✅ NEW

  const ProductForm({
    Key? key,
    required this.nameController,
    required this.priceController,
    required this.originalPriceController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.isFeatured,
    required this.isVerified, // ✅ NEW
    required this.isTrending, // ✅ NEW
    required this.onCategoryChanged,
    required this.onFeaturedChanged,
    required this.onVerifiedChanged, // ✅ NEW
    required this.onTrendingChanged, // ✅ NEW
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Product Name
        _buildTextFormField(
          controller: nameController,
          label: 'Product Name *',
          hint: 'e.g., Organic Fertilizer',
          icon: Icons.label_outline,
          isDark: isDark,
          fillColor: inputFillColor,
          validator: (v) => v?.isEmpty ?? true ? 'Product name is required' : null,
        ),

        const SizedBox(height: 16),

        // Category Dropdown
        Consumer<CategoryProvider>(
          builder: (context, categoryProvider, child) {
            final categories = categoryProvider.categories;
            return DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category *',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                hintText: 'Select a category',
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                prefixIcon: Icon(Icons.category_outlined, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                ),
                filled: true,
                fillColor: inputFillColor,
              ),
              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              items: [
                ...categories
                    .map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name)))
                    .toList(),
              ],
              onChanged: (value) => onCategoryChanged(value),
              validator: (v) => v == null ? 'Category is required' : null,
            );
          },
        ),

        const SizedBox(height: 16),

        // Price Row
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: priceController,
                label: 'Sale Price (₹) *',
                hint: '100',
                icon: Icons.currency_rupee,
                isDark: isDark,
                fillColor: inputFillColor,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Invalid';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextFormField(
                controller: originalPriceController,
                label: 'Original Price (₹)',
                hint: '150',
                icon: Icons.money_off,
                isDark: isDark,
                fillColor: inputFillColor,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Description
        _buildTextFormField(
          controller: descriptionController,
          label: 'Description *',
          hint: 'Detailed product description...',
          icon: Icons.description_outlined,
          isDark: isDark,
          fillColor: inputFillColor,
          maxLines: 5,
          validator: (v) => v?.isEmpty ?? true ? 'Description is required' : null,
        ),

        const SizedBox(height: 16),

        // Toggles
        _buildToggleCard(
          title: 'Featured Product',
          subtitle: 'Show on homepage and get better visibility',
          value: isFeatured,
          onChanged: onFeaturedChanged,
          icon: Icons.star_rounded,
          color: AppColors.warning,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
         _buildToggleCard(
          title: 'Verified Product',
          subtitle: 'Show a "Verified by Agrimore" badge',
          value: isVerified,
          onChanged: onVerifiedChanged,
          icon: Icons.verified_user_rounded,
          color: Colors.blue,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
         _buildToggleCard(
          title: 'Trending Product',
          subtitle: 'Show a "Trending" badge',
          value: isTrending,
          onChanged: onTrendingChanged,
          icon: Icons.local_fire_department_rounded,
          color: Colors.red,
          isDark: isDark,
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

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool?) onChanged,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        value: value,
        onChanged: onChanged,
        activeColor: color,
        secondary: Icon(
          icon,
          color: value ? color : (isDark ? Colors.grey[600] : Colors.grey),
        ),
      ),
    );
  }
}