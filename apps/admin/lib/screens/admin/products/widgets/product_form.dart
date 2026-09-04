
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/category_provider.dart';
import '../../../../app/themes/admin_colors.dart';

/// Premium Product Basic Info Form with AdminColors theme
class ProductForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController originalPriceController;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final String? selectedLocation;
  final bool isFeatured;
  final bool isVerified;
  final bool isTrending;
  final Function(String?) onCategoryChanged;
  final Function(String?) onLocationChanged;
  final Function(bool?) onFeaturedChanged;
  final Function(bool?) onVerifiedChanged;
  final Function(bool?) onTrendingChanged;

  const ProductForm({
    Key? key,
    required this.nameController,
    required this.priceController,
    required this.originalPriceController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.selectedLocation,
    required this.isFeatured,
    required this.isVerified,
    required this.isTrending,
    required this.onCategoryChanged,
    required this.onLocationChanged,
    required this.onFeaturedChanged,
    required this.onVerifiedChanged,
    required this.onTrendingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header Card
        _buildSectionHeader(
          icon: Icons.info_outline_rounded,
          title: 'Basic Information',
          subtitle: 'Enter product details',
        ),
        const SizedBox(height: 20),

        // Product Name
        _buildPremiumTextField(
          controller: nameController,
          label: 'Product Name',
          hint: 'e.g., Organic Fertilizer Premium',
          icon: Icons.label_outline_rounded,
          isRequired: true,
          validator: (v) => v?.isEmpty ?? true ? 'Product name is required' : null,
        ),

        const SizedBox(height: 16),

        // Category Dropdown
        Consumer<CategoryProvider>(
          builder: (context, categoryProvider, child) {
            final categories = categoryProvider.categories;
            // ✅ Deduplicate by ID (which equals the category name in this Firestore setup)
            final seen = <String>{};
            final uniqueCategories = categories
                .where((cat) => cat.id.isNotEmpty && seen.add(cat.id))
                .toList();
            return _buildPremiumDropdown(
              value: selectedCategory,
              label: 'Category',
              hint: 'Select a category',
              icon: Icons.category_outlined,
              items: uniqueCategories.map((cat) => 
                DropdownMenuItem(value: cat.id, child: Text(cat.name))
              ).toList(),
              onChanged: onCategoryChanged,
              validator: (v) => v == null ? 'Category is required' : null,
            );
          },
        ),

        const SizedBox(height: 16),

        // Location Dropdown
        _buildPremiumDropdown(
          value: selectedLocation,
          label: 'Location',
          hint: 'Select product location',
          icon: Icons.location_city_rounded,
          items: ['Chennai', 'Madurai', 'Theni'].map((city) => 
            DropdownMenuItem(value: city, child: Text(city))
          ).toList(),
          onChanged: onLocationChanged,
          validator: (v) => v == null ? 'Location is required' : null,
        ),

        const SizedBox(height: 20),

        // Pricing Header
        _buildSectionHeader(
          icon: Icons.currency_rupee_rounded,
          title: 'Pricing',
          subtitle: 'Set sale and original prices',
        ),
        const SizedBox(height: 16),

        // Price Row
        Row(
          children: [
            Expanded(
              child: _buildPremiumTextField(
                controller: priceController,
                label: 'Sale Price (₹)',
                hint: '99.00',
                icon: Icons.currency_rupee,
                isRequired: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Invalid price';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPremiumTextField(
                controller: originalPriceController,
                label: 'Original Price (₹)',
                hint: '149.00',
                icon: Icons.money_off_csred_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Description Header
        _buildSectionHeader(
          icon: Icons.description_outlined,
          title: 'Description',
          subtitle: 'Detailed product information',
        ),
        const SizedBox(height: 16),

        // Description
        _buildPremiumTextField(
          controller: descriptionController,
          label: 'Product Description',
          hint: 'Enter detailed product description...',
          icon: Icons.notes_rounded,
          isRequired: true,
          maxLines: 5,
          validator: (v) => v?.isEmpty ?? true ? 'Description is required' : null,
        ),

        const SizedBox(height: 24),

        // Badges Header
        _buildSectionHeader(
          icon: Icons.workspace_premium_rounded,
          title: 'Product Badges',
          subtitle: 'Enable special badges for visibility',
        ),
        const SizedBox(height: 16),

        // Toggles
        _buildPremiumToggle(
          title: 'Featured Product',
          subtitle: 'Display on homepage for better visibility',
          value: isFeatured,
          onChanged: onFeaturedChanged,
          icon: Icons.star_rounded,
          color: AdminColors.warning,
        ),
        const SizedBox(height: 12),
        _buildPremiumToggle(
          title: 'Verified Product',
          subtitle: 'Show "Verified by Agrimore" badge',
          value: isVerified,
          onChanged: onVerifiedChanged,
          icon: Icons.verified_rounded,
          color: AdminColors.info,
        ),
        const SizedBox(height: 12),
        _buildPremiumToggle(
          title: 'Trending Product',
          subtitle: 'Show "Trending" badge for popular items',
          value: isTrending,
          onChanged: onTrendingChanged,
          icon: Icons.local_fire_department_rounded,
          color: AdminColors.error,
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(0.08),
            AdminColors.primaryLight.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminColors.primary, AdminColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        fontSize: 15,
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: TextStyle(
          color: AdminColors.textSecondary,
          fontSize: 14,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: AdminColors.textSecondary.withOpacity(0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: AdminColors.primary,
          size: 22,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.error),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 12,
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _buildPremiumDropdown({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    // ✅ Guard: If value is not in the items list, reset to null to avoid Flutter assertion
    final safeValue = items.any((item) => item.value == value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AdminColors.primary),
      decoration: InputDecoration(
        labelText: '$label *',
        labelStyle: TextStyle(
          color: AdminColors.textSecondary,
          fontSize: 14,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: AdminColors.textSecondary.withOpacity(0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: AdminColors.primary,
          size: 22,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildPremiumToggle({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool?) onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? color.withOpacity(0.3) : Colors.grey.shade200,
          width: value ? 1.5 : 1,
        ),
        boxShadow: value ? [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(!value);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: value ? color.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: value ? color : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    onChanged(v);
                  },
                  activeColor: color,
                  activeTrackColor: color.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}