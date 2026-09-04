import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/admin_colors.dart';

/// Premium Stock Manager with AdminColors theme
class StockManager extends StatelessWidget {
  final TextEditingController stockController;
  final TextEditingController unitController;
  final TextEditingController minOrderController;
  final TextEditingController maxOrderController;

  const StockManager({
    Key? key,
    required this.stockController,
    required this.unitController,
    required this.minOrderController,
    required this.maxOrderController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header Card
        _buildSectionHeader(
          icon: Icons.inventory_2_rounded,
          title: 'Stock Management',
          subtitle: 'Set available quantity and order limits',
        ),
        const SizedBox(height: 24),

        // Stock Quantity Card
        _buildStockCard(),
        const SizedBox(height: 20),

        // Order Limits Header
        _buildSectionHeader(
          icon: Icons.rule_rounded,
          title: 'Order Limits',
          subtitle: 'Set minimum and maximum order quantities',
        ),
        const SizedBox(height: 16),

        // Min/Max Order Row
        Row(
          children: [
            Expanded(
              child: _buildPremiumTextField(
                controller: minOrderController,
                label: 'Minimum Order',
                hint: '1',
                icon: Icons.remove_circle_outline_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPremiumTextField(
                controller: maxOrderController,
                label: 'Maximum Order',
                hint: 'No limit',
                icon: Icons.add_circle_outline_rounded,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Stock Level Indicator
        _buildStockLevelIndicator(),

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

  Widget _buildStockCard() {
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
              Expanded(
                flex: 2,
                child: _buildPremiumTextField(
                  controller: stockController,
                  label: 'Stock Quantity',
                  hint: '0',
                  icon: Icons.inventory_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Required';
                    if (int.tryParse(v!) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPremiumTextField(
                  controller: unitController,
                  label: 'Unit',
                  hint: 'kg, L, pcs',
                  icon: Icons.straighten_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick stock buttons
          Row(
            children: [
              _buildQuickStockButton('+10', () => _adjustStock(10)),
              const SizedBox(width: 8),
              _buildQuickStockButton('+50', () => _adjustStock(50)),
              const SizedBox(width: 8),
              _buildQuickStockButton('+100', () => _adjustStock(100)),
              const SizedBox(width: 8),
              _buildQuickStockButton('Reset', () => _setStock(0), isReset: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStockButton(String label, VoidCallback onTap, {bool isReset = false}) {
    return Expanded(
      child: Material(
        color: isReset 
            ? AdminColors.error.withOpacity(0.1)
            : AdminColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isReset ? AdminColors.error : AdminColors.success,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _adjustStock(int amount) {
    final current = int.tryParse(stockController.text) ?? 0;
    stockController.text = (current + amount).toString();
  }

  void _setStock(int value) {
    stockController.text = value.toString();
  }

  Widget _buildStockLevelIndicator() {
    final stockValue = int.tryParse(stockController.text) ?? 0;
    final isLow = stockValue > 0 && stockValue < 10;
    final isOut = stockValue == 0;
    final isGood = stockValue >= 10;

    Color indicatorColor;
    String statusText;
    IconData statusIcon;

    if (isOut) {
      indicatorColor = AdminColors.error;
      statusText = 'Out of Stock';
      statusIcon = Icons.error_rounded;
    } else if (isLow) {
      indicatorColor = AdminColors.warning;
      statusText = 'Low Stock';
      statusIcon = Icons.warning_rounded;
    } else {
      indicatorColor = AdminColors.success;
      statusText = 'In Stock';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: indicatorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: indicatorColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: indicatorColor,
                  ),
                ),
                Text(
                  'Current stock: $stockValue units',
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
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}