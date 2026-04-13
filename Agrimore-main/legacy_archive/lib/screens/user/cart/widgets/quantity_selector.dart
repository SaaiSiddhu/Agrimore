import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';

class QuantitySelector extends StatefulWidget {
  final int quantity;
  final Function(int) onQuantityChanged;
  final int minQuantity;
  final int maxQuantity;
  final bool enabled;
  final bool compact;
  final bool showLabel;

  const QuantitySelector({
    Key? key,
    required this.quantity,
    required this.onQuantityChanged,
    this.minQuantity = 1,
    this.maxQuantity = 99,
    this.enabled = true,
    this.compact = false,
    this.showLabel = false,
  }) : super(key: key);

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isIncreasing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleQuantityChange(int newQuantity) {
    if (widget.enabled) {
      setState(() {
        _isIncreasing = newQuantity > widget.quantity;
      });
      _pulseController.forward().then((_) => _pulseController.reverse());
      HapticFeedback.selectionClick();
      widget.onQuantityChanged(newQuantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMinQuantity = widget.quantity <= widget.minQuantity;
    final isMaxQuantity = widget.quantity >= widget.maxQuantity;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) _buildLabel(),
        if (widget.showLabel) const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.08),
                AppColors.primary.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(widget.compact ? 10 : 12),
            border: Border.all(
              color: widget.enabled
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(
                icon: widget.quantity > widget.minQuantity
                    ? Icons.remove
                    : Icons.delete_outline,
                onPressed: !isMinQuantity && widget.enabled
                    ? () => _handleQuantityChange(widget.quantity - 1)
                    : null,
                isEnabled: !isMinQuantity && widget.enabled,
                isDanger: widget.quantity == widget.minQuantity + 1,
              ),
              _buildQuantityDisplay(),
              _buildButton(
                icon: Icons.add,
                onPressed: !isMaxQuantity && widget.enabled
                    ? () => _handleQuantityChange(widget.quantity + 1)
                    : null,
                isEnabled: !isMaxQuantity && widget.enabled,
              ),
            ],
          ),
        ),
        if (!widget.compact && widget.maxQuantity < 100) _buildStockInfo(),
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Icon(
          Icons.shopping_basket_outlined,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          'Quantity',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onPressed != null
            ? () {
                HapticFeedback.heavyImpact();
                // Could add quick increment/decrement on long press
              }
            : null,
        borderRadius: BorderRadius.circular(widget.compact ? 8 : 10),
        child: Container(
          padding: EdgeInsets.all(widget.compact ? 8 : 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isEnabled && isDanger)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              Icon(
                icon,
                size: widget.compact ? 18 : 22,
                color: isEnabled
                    ? (isDanger ? AppColors.error : AppColors.primary)
                    : AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityDisplay() {
    return Container(
      constraints: BoxConstraints(
        minWidth: widget.compact ? 45 : 60,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 16,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(
          vertical: BorderSide(
            color: AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.quantity.toString(),
              style: (widget.compact
                      ? AppTextStyles.titleMedium
                      : AppTextStyles.titleLarge)
                  .copyWith(
                fontWeight: FontWeight.bold,
                color: widget.enabled ? AppColors.primary : AppColors.textDisabled,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (!widget.compact) ...[
              const SizedBox(height: 2),
              Container(
                height: 2,
                width: 20,
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.textDisabled.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfo() {
    final remainingStock = widget.maxQuantity - widget.quantity;
    final isLowStock = remainingStock <= 5 && remainingStock > 0;

    if (widget.quantity >= widget.maxQuantity || !isLowStock) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Only $remainingStock left',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
