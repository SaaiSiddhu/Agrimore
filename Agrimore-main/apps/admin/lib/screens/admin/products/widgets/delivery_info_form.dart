import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/admin_colors.dart';

/// Premium Delivery Info Form with AdminColors theme
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _buildSectionHeader(
          icon: Icons.local_shipping_rounded,
          title: 'Shipping & Delivery',
          subtitle: 'Configure delivery options and pricing',
        ),
        const SizedBox(height: 24),

        // Standard Delivery Card
        _buildDeliveryMethodCard(
          title: 'Standard Delivery',
          icon: Icons.inventory_2_rounded,
          child: Column(
            children: [
              _buildPremiumTextField(
                controller: shippingDaysController,
                label: 'Delivery Days',
                hint: '2-3 days',
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 16),
              _buildPremiumToggle(
                title: 'Free Delivery',
                subtitle: 'Offer free standard shipping',
                value: isFreeDelivery,
                onChanged: (v) => onFreeDeliveryChanged(v),
                icon: Icons.local_offer_rounded,
                color: AdminColors.success,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isFreeDelivery 
                    ? CrossFadeState.showFirst 
                    : CrossFadeState.showSecond,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      _buildPremiumTextField(
                        controller: shippingPriceController,
                        label: 'Shipping Price',
                        hint: '₹40',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumTextField(
                        controller: freeShippingAboveController,
                        label: 'Free Shipping Above',
                        hint: '₹500',
                        icon: Icons.savings_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Express Delivery Card
        _buildDeliveryMethodCard(
          title: 'Express Delivery',
          icon: Icons.flash_on_rounded,
          iconColor: AdminColors.warning,
          child: Column(
            children: [
              _buildPremiumToggle(
                title: 'Enable Express',
                subtitle: 'Offer faster delivery option',
                value: expressDelivery,
                onChanged: (v) => onExpressDeliveryChanged(v),
                icon: Icons.rocket_launch_rounded,
                color: AdminColors.warning,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: expressDelivery 
                    ? CrossFadeState.showSecond 
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildPremiumTextField(
                    controller: expressDeliveryDaysController,
                    label: 'Express Delivery Days',
                    hint: '1 day',
                    icon: Icons.timer_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Info Banner
        _buildInfoBanner(),

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

  Widget _buildDeliveryMethodCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AdminColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor ?? AdminColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 15,
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
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
    required Function(bool) onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withOpacity(0.3) : Colors.grey.shade200,
          width: value ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(!value);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: value ? color.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: value ? color : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
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

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: AdminColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delivery times are estimates. Actual delivery may vary based on location.',
              style: TextStyle(
                fontSize: 12,
                color: AdminColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}