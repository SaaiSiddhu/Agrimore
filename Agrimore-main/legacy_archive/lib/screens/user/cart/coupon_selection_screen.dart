import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/coupon_model.dart';
import '../../../models/cart_item_model.dart';

class CouponSelectionScreen extends StatefulWidget {
  const CouponSelectionScreen({Key? key}) : super(key: key);

  @override
  State<CouponSelectionScreen> createState() => _CouponSelectionScreenState();
}

class _CouponSelectionScreenState extends State<CouponSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _couponCodeController = TextEditingController();
  bool _isApplying = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CouponProvider>().fetchAvailableCoupons();
    });
  }

  @override
  void dispose() {
    _couponCodeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _applyManualCoupon() async {
    if (_couponCodeController.text.trim().isEmpty) {
      _showError('Please enter a coupon code');
      HapticFeedback.vibrate();
      return;
    }

    setState(() => _isApplying = true);
    HapticFeedback.selectionClick();

    final couponProvider = context.read<CouponProvider>();
    final cartProvider = context.read<CartProvider>();

    final success = await couponProvider.applyCouponByCode(
      _couponCodeController.text.trim(),
      cartProvider.subtotal,
    );

    setState(() => _isApplying = false);

    if (success && mounted) {
      HapticFeedback.heavyImpact();
      final coupon = couponProvider.appliedCoupon;
      Navigator.pop(context, coupon);
    } else if (mounted) {
      HapticFeedback.vibrate();
      _showError(couponProvider.error ?? 'Failed to apply coupon');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    final cartProvider = context.watch<CartProvider>();
    final orderAmount = cartProvider.subtotal;
    final cartItems = cartProvider.items;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(isDark, cardColor, accentColor),
            _buildManualCouponEntry(isDark, cardColor, accentColor),
            _buildStatsBar(orderAmount, isDark, cardColor, accentColor),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            Expanded(
              child: Consumer<CouponProvider>(
                builder: (context, couponProvider, child) {
                  if (couponProvider.isLoading) {
                    return _buildLoadingState(accentColor, isDark);
                  }

                  if (couponProvider.availableCoupons.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return _buildCouponList(
                    couponProvider,
                    orderAmount,
                    cartItems,
                    isDark,
                    cardColor,
                    accentColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(
                  FontAwesomeIcons.ticket,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apply Coupon',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose the best deal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualCouponEntry(bool isDark, Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.keyboard,
                size: 14,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Enter Coupon Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    color: isDark ? Colors.grey[850] : Colors.grey[50],
                  ),
                  child: TextField(
                    controller: _couponCodeController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ENTER CODE',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FaIcon(
                          FontAwesomeIcons.barcode,
                          color: accentColor,
                          size: 18,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _applyManualCoupon(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isApplying ? null : _applyManualCoupon,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  backgroundColor: accentColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isApplying
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      )
                    : Text(
                        'APPLY',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(
    double orderAmount,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: FontAwesomeIcons.cartShopping,
              label: 'Cart Value',
              value: '₹${orderAmount.toStringAsFixed(0)}',
              isDark: isDark,
              accentColor: accentColor,
            ),
          ),
          Container(
            width: 1,
            height: 35,
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Consumer<CouponProvider>(
              builder: (context, couponProvider, child) {
                final availableCount = couponProvider.availableCoupons.length;
                return _buildStatItem(
                  icon: FontAwesomeIcons.tags,
                  label: 'Available',
                  value: '$availableCount Coupons',
                  isDark: isDark,
                  accentColor: accentColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(icon, size: 14, color: accentColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(Color accentColor, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading coupons...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponList(
    CouponProvider couponProvider,
    double orderAmount,
    List<CartItemModel> cartItems,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: couponProvider.availableCoupons.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final coupon = couponProvider.availableCoupons[index];
        return _buildCompactCouponCard(
          coupon,
          orderAmount,
          cartItems,
          index,
          isDark,
          cardColor,
          accentColor,
        );
      },
    );
  }

  Widget _buildCompactCouponCard(
    CouponModel coupon,
    double orderAmount,
    List<CartItemModel> cartItems,
    int index,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final canApply = orderAmount >= coupon.minOrderAmount;
    final discount = coupon.calculateDiscount(orderAmount, cartItems: cartItems);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: canApply
            ? () {
                HapticFeedback.mediumImpact();
                context.read<CouponProvider>().applyCoupon(coupon);
                Navigator.pop(context, coupon);
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canApply
                  ? accentColor.withValues(alpha: 0.5)
                  : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
              width: canApply ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: canApply
                            ? accentColor.withOpacity(0.15)
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.ticketSimple,
                        color: canApply
                            ? accentColor
                            : (isDark ? Colors.grey[600] : Colors.grey[500]),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coupon.code,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: canApply
                                  ? accentColor
                                  : (isDark ? Colors.grey[500] : Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coupon.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canApply)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.piggyBank,
                              size: 11,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${discount.toStringAsFixed(0)} OFF',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.circleInfo,
                            size: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              coupon.description,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Details Row
                    Row(
                      children: [
                        // Min Order
                        if (coupon.minOrderAmount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: canApply
                                  ? Colors.green.withOpacity(isDark ? 0.15 : 0.08)
                                  : Colors.red.withOpacity(isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: canApply
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  canApply
                                      ? FontAwesomeIcons.circleCheck
                                      : FontAwesomeIcons.circleXmark,
                                  size: 10,
                                  color: canApply
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  canApply
                                      ? 'Min ₹${coupon.minOrderAmount.toStringAsFixed(0)}'
                                      : 'Add ₹${(coupon.minOrderAmount - orderAmount).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: canApply
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        
                        // Expiry
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.clock,
                                size: 10,
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Exp: ${coupon.validTo.day}/${coupon.validTo.month}/${coupon.validTo.year}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Apply Button
                        if (canApply)
                          FaIcon(
                            FontAwesomeIcons.arrowRight,
                            size: 14,
                            color: accentColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.ticketSimple,
                  size: 40,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Coupons Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for exciting offers!\nNew deals are added regularly.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
