import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../providers/theme_provider.dart';

class DeliveryInfoForm extends StatelessWidget {
  final TextEditingController shippingDaysController;
  final TextEditingController shippingPriceController;
  final TextEditingController freeShippingAboveController;
  final bool isFreeDelivery;
  final bool expressDelivery;
  final TextEditingController expressDeliveryDaysController;
  final Function(bool) onFreeDeliveryChanged;
  final Function(bool) onExpressDeliveryChanged;

  const DeliveryInfoForm({
    Key? key,
    required this.shippingDaysController,
    required this.shippingPriceController,
    required this.freeShippingAboveController,
    required this.isFreeDelivery,
    required this.expressDelivery,
    required this.expressDeliveryDaysController,
    required this.onFreeDeliveryChanged,
    required this.onExpressDeliveryChanged,
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
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 40, color: accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery & Shipping', style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      'Set delivery times and shipping costs.',
                      style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Standard Delivery Days
        _buildTextFormField(
          controller: shippingDaysController,
          label: 'Standard Delivery Days',
          hint: 'e.g., 2-3',
          icon: Icons.calendar_today_outlined,
          isDark: isDark,
          fillColor: inputFillColor,
        ),
        
        const SizedBox(height: 16),

        // Free Delivery Toggle
        _buildToggleCard(
          title: 'Free Delivery',
          subtitle: 'Offer free standard shipping for this item',
          value: isFreeDelivery,
          onChanged: (val) => onFreeDeliveryChanged(val ?? false),
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        // Shipping Price Fields (conditionally visible)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: isFreeDelivery ? const SizedBox.shrink() : Column(
            children: [
              _buildTextFormField(
                controller: shippingPriceController,
                label: 'Shipping Price (₹)',
                hint: '40',
                icon: Icons.currency_rupee,
                isDark: isDark,
                fillColor: inputFillColor,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: freeShippingAboveController,
                label: 'Free Shipping Above (₹)',
                hint: '500',
                icon: Icons.local_offer_outlined,
                isDark: isDark,
                fillColor: inputFillColor,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Express Delivery Toggle
        _buildToggleCard(
          title: 'Enable Express Delivery',
          subtitle: 'Offer a faster shipping option',
          value: expressDelivery,
          onChanged: (val) => onExpressDeliveryChanged(val ?? false),
          icon: Icons.flash_on_rounded,
          color: AppColors.warning,
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        // Express Delivery Days (conditionally visible)
         AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: !expressDelivery ? const SizedBox.shrink() : Column(
            children: [
              _buildTextFormField(
                controller: expressDeliveryDaysController,
                label: 'Express Delivery Days',
                hint: 'e.g., 1',
                icon: Icons.calendar_today,
                isDark: isDark,
                fillColor: inputFillColor,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
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
    TextInputType? keyboardType,
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
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      keyboardType: keyboardType,
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