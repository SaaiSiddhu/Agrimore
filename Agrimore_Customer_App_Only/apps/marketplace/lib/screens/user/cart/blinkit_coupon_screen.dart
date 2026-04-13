import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/theme_provider.dart';

class BlinkitCouponScreen extends StatefulWidget {
  const BlinkitCouponScreen({Key? key}) : super(key: key);

  @override
  State<BlinkitCouponScreen> createState() => _BlinkitCouponScreenState();
}

class _BlinkitCouponScreenState extends State<BlinkitCouponScreen>
    with TickerProviderStateMixin {
  final TextEditingController _couponCodeController = TextEditingController();
  bool _isApplying = false;
  final Set<String> _expandedCoupons = {};
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
      _showSnackBar('Please enter a coupon code', isError: true);
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
      Navigator.pop(context, couponProvider.appliedCoupon);
    } else if (mounted) {
      HapticFeedback.vibrate();
      _showSnackBar(couponProvider.error ?? 'Failed to apply coupon', isError: true);
    }
  }

  void _applyCoupon(CouponModel coupon) {
    HapticFeedback.mediumImpact();
    context.read<CouponProvider>().applyCoupon(coupon);
    Navigator.pop(context, coupon);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
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
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // App Bar
            _buildAppBar(isDark, cardColor),
            
            // Coupon Code Input
            _buildCouponInput(isDark, cardColor, accentColor),
            
            // Coupon List
            Expanded(
              child: Consumer<CouponProvider>(
                builder: (context, couponProvider, child) {
                  if (couponProvider.isLoading) {
                    return _buildLoadingState(accentColor);
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

  Widget _buildAppBar(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          Text(
            'Coupons',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponInput(bool isDark, Color cardColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: cardColor,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _couponCodeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Type coupon code here',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _applyManualCoupon(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isApplying ? null : _applyManualCoupon,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              backgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isApplying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Apply',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color accentColor) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No coupons available',
            style: TextStyle(
              fontSize: 16,
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
    // Group coupons by type - using actual CouponType values
    final discountOffers = couponProvider.availableCoupons.where((c) => c.type == CouponType.percentage || c.type == CouponType.flat).toList();
    final specialOffers = couponProvider.availableCoupons.where((c) => c.type == CouponType.buyOneGetOne).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (discountOffers.isNotEmpty) ...[
            _buildSectionHeader('Discount offers', isDark),
            ...discountOffers.map((coupon) => _buildBlinkitCouponCard(
              coupon,
              orderAmount,
              cartItems,
              isDark,
              cardColor,
              accentColor,
            )),
          ],
          if (specialOffers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader('Special offers', isDark),
            ...specialOffers.map((coupon) => _buildBlinkitCouponCard(
              coupon,
              orderAmount,
              cartItems,
              isDark,
              cardColor,
              accentColor,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildBlinkitCouponCard(
    CouponModel coupon,
    double orderAmount,
    List<CartItemModel> cartItems,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final canApply = orderAmount >= coupon.minOrderAmount;
    final discount = coupon.calculateDiscount(orderAmount, cartItems: cartItems);
    final remaining = (coupon.minOrderAmount - orderAmount).clamp(0.0, coupon.minOrderAmount);
    final isExpanded = _expandedCoupons.contains(coupon.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCouponColor(coupon).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getCouponColor(coupon).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: _getCouponIcon(coupon),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Offer details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use code ${coupon.code}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Apply button
                ElevatedButton(
                  onPressed: canApply ? () => _applyCoupon(coupon) : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: canApply ? accentColor : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Condition bullets
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Min order / remaining
                if (!canApply)
                  _buildConditionRow(
                    '• Add items worth ₹${remaining.toStringAsFixed(0)} more to apply this offer',
                    Colors.blue.shade700,
                  ),
                
                // Savings badge
                if (canApply && discount > 0)
                  _buildConditionRow(
                    '• Save ₹${discount.toStringAsFixed(0)} on this order',
                    Colors.green.shade700,
                  ),
                
                // Description
                _buildConditionRow(
                  '• ${coupon.description}',
                  isDark ? Colors.grey[500]! : Colors.grey[700]!,
                ),
                
                // Expiry
                if (isExpanded) ...[
                  _buildConditionRow(
                    '• Valid until ${coupon.validTo.day}/${coupon.validTo.month}/${coupon.validTo.year}',
                    isDark ? Colors.grey[500]! : Colors.grey[700]!,
                  ),
                  if (coupon.usageLimit != null)
                    _buildConditionRow(
                      '• Can be used ${coupon.usageLimit} time${coupon.usageLimit! > 1 ? 's' : ''}',
                      isDark ? Colors.grey[500]! : Colors.grey[700]!,
                    ),
                ],
              ],
            ),
          ),
          
          // Read more toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedCoupons.remove(coupon.id);
                } else {
                  _expandedCoupons.add(coupon.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    isExpanded ? '- Read less' : '+ Read more',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Color _getCouponColor(CouponModel coupon) {
    switch (coupon.type) {
      case CouponType.percentage:
        return Colors.green;
      case CouponType.flat:
        return Colors.blue;
      case CouponType.buyOneGetOne:
        return Colors.purple;
    }
  }

  Widget _getCouponIcon(CouponModel coupon) {
    Color color = _getCouponColor(coupon);
    
    switch (coupon.type) {
      case CouponType.percentage:
        return FaIcon(FontAwesomeIcons.percent, size: 18, color: color);
      case CouponType.flat:
        return FaIcon(FontAwesomeIcons.indianRupeeSign, size: 18, color: color);
      case CouponType.buyOneGetOne:
        return FaIcon(FontAwesomeIcons.gift, size: 18, color: color);
    }
  }
}
