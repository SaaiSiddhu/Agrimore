import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/coupon_model.dart';
import '../../../../providers/coupon_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../coupon_selection_screen.dart';

class CartSummary extends StatefulWidget {
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double tax;
  final double total;
  final String? couponCode;

  const CartSummary({
    Key? key,
    required this.subtotal,
    this.discount = 0.0,
    this.deliveryCharge = 0.0,
    this.tax = 0.0,
    required this.total,
    this.couponCode,
  }) : super(key: key);

  @override
  State<CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends State<CartSummary> with TickerProviderStateMixin {
  final TextEditingController _couponController = TextEditingController();
  bool _isApplying = false;
  bool _showCouponSection = false;

  late AnimationController _slideController;
  late AnimationController _successController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _successScaleAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    if (widget.couponCode != null) {
      _couponController.text = widget.couponCode!;
      _showCouponSection = true;
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    _slideController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _toggleCouponSection() {
    setState(() => _showCouponSection = !_showCouponSection);
    if (_showCouponSection) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _applyManualCoupon() async {
    if (_couponController.text.trim().isEmpty) {
      _showErrorSnackbar('Please enter a coupon code');
      return;
    }

    setState(() => _isApplying = true);
    HapticFeedback.selectionClick();

    final couponProvider = context.read<CouponProvider>();
    final success = await couponProvider.applyCouponByCode(
      _couponController.text.trim(),
      widget.subtotal,
    );

    setState(() => _isApplying = false);

    if (success && mounted) {
      _successController.forward().then((_) => _successController.reverse());
      HapticFeedback.heavyImpact();
      _showSuccessSnackbar('Coupon applied successfully!');
    } else if (mounted) {
      HapticFeedback.vibrate();
      _showErrorSnackbar(couponProvider.error ?? 'Invalid coupon code');
    }
  }

  void _removeCoupon() {
    _couponController.clear();
    context.read<CouponProvider>().removeCoupon();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coupon removed'),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _showAvailableCoupons() async {
    final result = await showModalBottomSheet<CouponModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CouponSelectionScreen(),
    );

    if (result != null && mounted) {
      _couponController.text = result.code;
      context.read<CouponProvider>().applyCoupon(result);
      _successController.forward().then((_) => _successController.reverse());
      _showSuccessSnackbar('Coupon applied successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildCouponToggle(),
          _buildAnimatedCouponSection(),
          _buildPriceBreakdown(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Price Summary',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget _buildCouponToggle() {
    final hasCoupon = widget.couponCode != null && widget.couponCode!.isNotEmpty;
    if (hasCoupon) return _buildAppliedCouponBadge();

    return ListTile(
      leading: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
      title: const Text('Apply Coupon'),
      subtitle: const Text('Get extra discounts'),
      trailing: Icon(
        _showCouponSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        color: AppColors.primary,
      ),
      onTap: _toggleCouponSection,
    );
  }

  // ✅ Restored method 1: Animated Coupon Input Section
  Widget _buildAnimatedCouponSection() {
    return SizeTransition(
      sizeFactor: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'ENTER COUPON CODE',
                        prefixIcon: const Icon(Icons.discount_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isApplying ? null : _applyManualCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isApplying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('APPLY'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _showAvailableCoupons,
                icon: const Icon(Icons.local_activity_outlined, color: AppColors.primary),
                label: const Text('View Available Coupons', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Restored method 2: Applied Coupon Badge
  Widget _buildAppliedCouponBadge() {
    return ScaleTransition(
      scale: _successScaleAnimation,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.couponCode!} applied — you saved ₹${widget.discount.toStringAsFixed(2)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: _removeCoupon,
              icon: const Icon(Icons.close, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRow('Subtotal', widget.subtotal),
          if (widget.discount > 0)
            _buildRow('Discount', -widget.discount, color: AppColors.success),
          _buildRow('Delivery', 0.0),
          _buildRow('Tax', 0.0),
          const Divider(thickness: 1),
          _buildRow('Total', widget.total, bold: true, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)
                  : AppTextStyles.bodyMedium),
          Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}