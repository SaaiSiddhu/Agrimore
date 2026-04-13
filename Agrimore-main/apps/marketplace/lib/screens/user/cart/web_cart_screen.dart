import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'widgets/cart_item_card.dart';
import 'widgets/cart_summary.dart';
import 'widgets/empty_cart.dart';
import 'coupon_selection_screen.dart';

class WebCartScreen extends StatefulWidget {
  const WebCartScreen({Key? key}) : super(key: key);

  @override
  State<WebCartScreen> createState() => _WebCartScreenState();
}

class _WebCartScreenState extends State<WebCartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _listScrollController = ScrollController();
  bool _isSummarySticky = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _listScrollController.addListener(_scrollListener);
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
    });
  }

  void _scrollListener() {
    if (_listScrollController.offset > 100 && !_isSummarySticky) {
      setState(() => _isSummarySticky = true);
    } else if (_listScrollController.offset <= 100 && _isSummarySticky) {
      setState(() => _isSummarySticky = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _showClearCartDialog(CartProvider cartProvider) async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.error, AppColors.error.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clear Entire Cart?'),
                  SizedBox(height: 4),
                  Text(
                    'This action cannot be undone',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const Text(
          'All items in your cart will be permanently removed. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await cartProvider.clearCart();
      if (mounted) {
        HapticFeedback.heavyImpact();
        SnackbarHelper.showSuccess(context, 'Cart cleared successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer2<CartProvider, CouponProvider>(
        builder: (context, cartProvider, couponProvider, child) {
          if (cartProvider.isLoading) {
            return _buildLoadingState();
          }

          if (cartProvider.isEmpty) {
            return EmptyCart(
              onStartShopping: () => Navigator.pop(context),
            );
          }

          final deliveryCharge = 40.0;
          final tax = cartProvider.subtotal * 0.05;
          // UPDATED: call calculateDiscount() without passing subtotal
          final discount = couponProvider.calculateDiscount();
          final total = cartProvider.subtotal + deliveryCharge + tax - discount;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400),
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildCartItemsList(cartProvider, discount),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 420,
                      child: _buildOrderSummary(
                        cartProvider,
                        couponProvider,
                        deliveryCharge,
                        tax,
                        discount,
                        total,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_cart, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          const Text('Shopping Cart'),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 80,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.grey.shade200,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      actions: [
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            if (cartProvider.isEmpty) return const SizedBox.shrink();

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, 
                        color: AppColors.primary, 
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'Item' : 'Items'}',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _showClearCartDialog(cartProvider),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  label: const Text('Clear All', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCartItemsList(CartProvider cartProvider, double discount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  Colors.white,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cart Items',
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'product' : 'products'} in your cart',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (discount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Saving ₹${discount.toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: _listScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: cartProvider.items.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final item = cartProvider.items[index];
                return CartItemCard(
                  item: item,
                  onRemove: () async {
                    final success = await cartProvider.removeItem(item.productId);
                    if (success && mounted) {
                      SnackbarHelper.showSuccess(context, 'Item removed from cart');
                    }
                  },
                  onQuantityChanged: (quantity) async {
                    await cartProvider.updateQuantity(item.productId, quantity);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(
    CartProvider cartProvider,
    CouponProvider couponProvider,
    double deliveryCharge,
    double tax,
    double discount,
    double total,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _isSummarySticky
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: _isSummarySticky ? 25 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CartSummary(
              subtotal: cartProvider.subtotal,
              discount: discount,
              deliveryCharge: deliveryCharge,
              tax: tax,
              total: total,
              couponCode: couponProvider.appliedCoupon?.code,
            ),
          ),
          const SizedBox(height: 20),
          _buildCheckoutButton(total),
          const SizedBox(height: 20),
          _buildSecurityBadges(),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(double total) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.heavyImpact();
          // AppRoutes.navigateTo(context, AppRoutes.checkout);
          SnackbarHelper.showInfo(context, 'Checkout coming soon!');
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          shadowColor: AppColors.primary.withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              'Proceed to Checkout',
              style: AppTextStyles.buttonLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₹${total.toStringAsFixed(2)}',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadges() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                'Secure Checkout',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecurityBadge(Icons.lock_outline, 'SSL\nSecure'),
              _buildSecurityBadge(Icons.payment, '100% Safe\nPayment'),
              _buildSecurityBadge(Icons.local_shipping, 'Free\nDelivery'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your cart...',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}