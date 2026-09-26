import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../providers/market_mode_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'widgets/empty_cart.dart';
import 'blinkit_coupon_screen.dart';
import '../checkout/order_success_screen.dart';
import '../checkout/widgets/associate_code_field.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/razorpay_service.dart';
import '../../auth/login_screen.dart';

class ShippingFeeInfo {
  final double standardFee;
  final List<String> standardProducts;
  final Map<String, double> specialFees;
  final List<String> freeDeliveryProducts;
  final double? expressDeliveryFee;
  final List<String> expressAvailableProducts;
  final Map<String, String> productDeliveryDays;

  ShippingFeeInfo({
    required this.standardFee,
    required this.standardProducts,
    required this.specialFees,
    required this.freeDeliveryProducts,
    this.expressDeliveryFee,
    required this.expressAvailableProducts,
    required this.productDeliveryDays,
  });

  double get totalShippingFee {
    double total = standardProducts.isNotEmpty ? standardFee : 0;
    total += specialFees.values.fold(0.0, (sum, fee) => sum + fee);
    return total;
  }

  bool get hasMixedDelivery =>
      freeDeliveryProducts.isNotEmpty &&
      (standardProducts.isNotEmpty || specialFees.isNotEmpty);
}

class MobileCartScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const MobileCartScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<MobileCartScreen> createState() => _MobileCartScreenState();
}

class _MobileCartScreenState extends State<MobileCartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  bool _isProcessingBogo = false;
  bool _expressDeliverySelected = false;

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // Delivery instructions
  bool _avoidCalling = false;
  bool _dontRing = false;
  String _deliveryNote = '';

  // Payment method
  String _selectedPaymentMethod = 'Razorpay'; // Default to Razorpay

  // The associate attribution code. Mirrors payment_method_screen.dart's
  // _employeeCodeController exactly: required for B2B (cart's
  // CartProvider.cartMode == 'B2B'), and — as of Phase 16B — also the
  // OPTIONAL Sales Associate code for B2C. The two renderings are mutually
  // exclusive, so one controller and one dispose() covers both.
  final TextEditingController _employeeCodeController =
      TextEditingController();

  // Phase 16B: this quick-checkout bottom bar is cramped and sits inches
  // above the pay button, so the optional B2C code field starts collapsed
  // behind a one-line prompt. That keeps D2 literally true here — a
  // customer with no code taps exactly what they tap today — while still
  // making the field reachable for one who has one.
  bool _showAssociateCodeField = false;

  // Wallet & Checkout
  bool _isPlacingOrder = false;
  RazorpayService? _razorpayService;
  final Map<String, CartItemModel> _bogoFreeItems = {};
  final Map<String, ProductModel> _productCache = {};

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
      // "You might also like" (_buildYouMightAlsoLike) only ever shows up to
      // 9 products (6 shown + 3 preview), filtered by category overlap with
      // the cart — it never needs the full catalog. 30 is a deliberate
      // middle ground: small enough to be real savings over an unbounded
      // fetch, large enough to have a reasonable chance of covering
      // whichever categories are actually in the user's cart (an exact
      // category-scoped query would be better but is a larger change than
      // this phase's footprint — see the completion report).
      context
          .read<ProductProvider>()
          .loadProducts(limit: 30); // Load for "You might also like"
      context
          .read<AddressProvider>()
          .loadAddresses(); // Load addresses for selection list
      _loadProductDetails();
    });
  }

  void _scrollListener() {
    if (_scrollController.offset > 200 && !_showFab) {
      setState(() => _showFab = true);
      _fabController.forward();
    } else if (_scrollController.offset <= 200 && _showFab) {
      setState(() => _showFab = false);
      _fabController.reverse();
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _employeeCodeController.dispose();
    _razorpayService?.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetails() async {
    final cartProvider = context.read<CartProvider>();

    for (final item in cartProvider.items) {
      if (!_productCache.containsKey(item.productId)) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('products')
              .doc(item.productId)
              .get();

          if (doc.exists && doc.data() != null) {
            _productCache[item.productId] =
                ProductModel.fromMap(doc.data()!, doc.id);
          }
        } catch (e) {
          debugPrint('❌ Error loading product ${item.productId}: $e');
        }
      }
    }

    if (mounted) setState(() {});
  }

  ShippingFeeInfo _calculateShippingFees(List<CartItemModel> items) {
    final standardFeeProducts = <String>[];
    final specialFees = <String, double>{};
    final freeDeliveryProducts = <String>[];
    final expressAvailableProducts = <String>[];
    final productDeliveryDays = <String, String>{};

    double? commonStandardFee;
    double? expressDeliveryFee;

    for (final item in items) {
      if (item.isFreeItem) continue;

      final product = _productCache[item.productId];
      if (product == null) continue;

      final shippingDays = product.shippingDays ?? '2-3';
      productDeliveryDays[item.productName] = shippingDays;

      final isFreeDelivery = product.isFreeDelivery ?? false;
      if (isFreeDelivery) {
        freeDeliveryProducts.add(item.productName);
        continue;
      }

      final hasExpressDelivery = product.expressDelivery ?? false;
      if (hasExpressDelivery) {
        expressAvailableProducts.add(item.productName);
        if (expressDeliveryFee == null) {
          expressDeliveryFee =
              (product.shippingPrice?.toDouble() ?? 40.0) + 9.0;
        }
      }

      final shippingPrice = product.shippingPrice?.toDouble() ?? 40.0;

      if (commonStandardFee == null) {
        commonStandardFee = shippingPrice;
        standardFeeProducts.add(item.productName);
      } else if (shippingPrice == commonStandardFee) {
        standardFeeProducts.add(item.productName);
      } else if (shippingPrice > commonStandardFee) {
        specialFees[item.productName] = shippingPrice;
      } else {
        standardFeeProducts.add(item.productName);
      }
    }

    return ShippingFeeInfo(
      standardFee: commonStandardFee ?? 0,
      standardProducts: standardFeeProducts,
      specialFees: specialFees,
      freeDeliveryProducts: freeDeliveryProducts,
      expressDeliveryFee: expressDeliveryFee,
      expressAvailableProducts: expressAvailableProducts,
      productDeliveryDays: productDeliveryDays,
    );
  }

  Future<void> _processBogoCoupon(
    CouponModel? coupon,
    CartProvider cartProvider,
  ) async {
    if (_isProcessingBogo) return;

    setState(() => _isProcessingBogo = true);

    try {
      final hadFreeItems = _bogoFreeItems.isNotEmpty;
      _bogoFreeItems.clear();

      if (coupon == null || coupon.type != CouponType.buyOneGetOne) {
        setState(() => _isProcessingBogo = false);
        return;
      }

      final buyId = coupon.buyProductId;
      final getId = coupon.getProductId;

      if (buyId == null) {
        setState(() => _isProcessingBogo = false);
        return;
      }

      CartItemModel? buyItem;
      try {
        buyItem =
            cartProvider.items.firstWhere((item) => item.productId == buyId);
      } catch (_) {
        buyItem = null;
      }

      if (buyItem == null) {
        setState(() => _isProcessingBogo = false);
        return;
      }

      if (getId == null) {
        final freeItem = CartItemModel(
          id: '${buyItem.id}_free',
          productId: buyItem.productId,
          productName: buyItem.productName,
          productImage: buyItem.productImage,
          price: 0,
          quantity: 1,
          userId: buyItem.userId,
          addedAt: DateTime.now(),
          variant: buyItem.variant,
          isFreeItem: true,
          freeItemLabel: 'BOGO Free',
          linkedBuyItemId: buyItem.id,
        );
        _bogoFreeItems[buyItem.productId] = freeItem;
      } else {
        try {
          final getDoc = await FirebaseFirestore.instance
              .collection('products')
              .doc(getId)
              .get();

          if (getDoc.exists && getDoc.data() != null) {
            final getProduct = ProductModel.fromMap(getDoc.data()!, getDoc.id);
            final freeItem = CartItemModel(
              id: '${getId}_free',
              productId: getId,
              productName: getProduct.name,
              productImage: getProduct.imageUrl ?? '',
              price: 0,
              quantity: 1,
              userId: buyItem.userId,
              addedAt: DateTime.now(),
              isFreeItem: true,
              freeItemLabel: 'BOGO Free',
              linkedBuyItemId: buyItem.id,
            );
            _bogoFreeItems[getId] = freeItem;
          }
        } catch (e) {
          debugPrint('❌ Error fetching free product: $e');
        }
      }

      if (_bogoFreeItems.isNotEmpty && !hadFreeItems && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '🎉 BOGO applied! Free item added to cart',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('❌ BOGO processing error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingBogo = false);
    }
  }

  // Restored — see _buildBlinkitAppBar's own comment for why. Modernized to
  // this file's current async-safety convention (isolated context.mounted-
  // shaped checks, a distinct dialogContext) rather than the compound
  // `confirmed == true && mounted` shape this had before it was deleted,
  // which the analyzer doesn't reliably recognize as a real guard.
  Future<void> _showClearCartDialog(CartProvider cartProvider) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Clear Cart'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all items from your cart? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await cartProvider.clearCart();
    _bogoFreeItems.clear();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    SnackbarHelper.showSuccess(context, 'Cart cleared successfully');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Consumer2<CartProvider, CouponProvider>(
          builder: (context, cartProvider, couponProvider, child) {
            if (cartProvider.isLoading) {
              return _buildLoadingState(accentColor, isDark);
            }

            if (cartProvider.isEmpty) {
              return Column(
                children: [
                  _buildBlinkitAppBar(isDark, cardColor, cartProvider),
                  Expanded(
                    child: EmptyCart(
                      onStartShopping: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    ),
                  ),
                ],
              );
            }

            final currentCoupon = couponProvider.appliedCoupon;
            if (currentCoupon != null &&
                currentCoupon.type == CouponType.buyOneGetOne &&
                _bogoFreeItems.isEmpty &&
                !_isProcessingBogo) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _processBogoCoupon(currentCoupon, cartProvider);
              });
            }

            final pricingData = _calculateAdvancedPricing(
              cartProvider,
              couponProvider,
            );

            return Column(
              children: [
                // Blinkit-style App Bar
                _buildBlinkitAppBar(isDark, cardColor, cartProvider),

                // Main scrollable content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([
                        Future(() => cartProvider.loadCart()),
                        Future(() => _loadProductDetails()),
                        Future.delayed(const Duration(milliseconds: 500)),
                      ]);
                    },
                    color: accentColor,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Delivery Time Header
                          _buildDeliveryTimeHeader(
                              cartProvider.items.length, isDark, cardColor),

                          // Cart Items
                          _buildBlinkitCartItems(
                              cartProvider, isDark, cardColor, accentColor),

                          const SizedBox(height: 8),

                          // Free Delivery Progress + See all coupons (moved above)
                          _buildFreeDeliveryProgress(
                            pricingData['subtotal']!,
                            isDark,
                            cardColor,
                            accentColor,
                          ),

                          // You might also like section
                          _buildYouMightAlsoLike(
                              cartProvider, isDark, cardColor, accentColor),

                          // Bill Details
                          _buildBillDetails(
                            pricingData,
                            couponProvider,
                            isDark,
                            cardColor,
                            accentColor,
                          ),

                          // Delivery Instructions
                          _buildDeliveryInstructions(
                              isDark, cardColor, accentColor),

                          // Bottom spacing for sticky bar
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sticky Bottom Bar — the true chargeable total (subtotal -
                // coupon + delivery), the same figure createOrder.ts
                // computes and verifies server-side.
                _buildBlinkitBottomBar(
                  pricingData['finalTotal'] ?? 0.0,
                  cartProvider.cartMode,
                  isDark,
                  accentColor,
                  cardColor,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Blinkit-style App Bar ---
  Widget _buildBlinkitAppBar(
      bool isDark, Color cardColor, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
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
          // Back button — when this is the Cart tab inside MainScreen,
          // onBack switches the tab back to Home; when reached via a real
          // push (order details, the /cart route, etc.) it just pops. A
          // tinted card behind the icon rather than Profile/Categories'
          // literal white circle — this app bar's own background is
          // already near-white in light mode, so a white-on-white card
          // would have no visible contrast.
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF2F2F2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 19,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Checkout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          // Restored: this app bar's earlier revision had a Clear Cart
          // button; the redesign into this Blinkit-style bar dropped it
          // without a replacement anywhere else in the UI, leaving a fully
          // working feature (see _showClearCartDialog) with no way to reach
          // it. Hidden when the cart is already empty — nothing to clear.
          if (!cartProvider.isEmpty)
            GestureDetector(
              onTap: () => _showClearCartDialog(cartProvider),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF2F2F2),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Delivery Time Header ---
  Widget _buildDeliveryTimeHeader(int itemCount, bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          // Premium clock icon like truck icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text('⏱️', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery in 2-3 days',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Shipment of $itemCount item${itemCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Blinkit-style Cart Items ---
  Widget _buildBlinkitCartItems(CartProvider cartProvider, bool isDark,
      Color cardColor, Color accentColor) {
    return Container(
      color: cardColor,
      child: Column(
        children: cartProvider.items.map((item) {
          final product = _productCache[item.productId];
          return _buildBlinkitCartItem(
            item: item,
            product: product,
            isDark: isDark,
            accentColor: accentColor,
            onRemove: () =>
                cartProvider.removeItem(item.productId, variant: item.variant),
            onQuantityChanged: (qty) => cartProvider
                .updateQuantity(item.productId, qty, variant: item.variant),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlinkitCartItem({
    required CartItemModel item,
    ProductModel? product,
    required bool isDark,
    required Color accentColor,
    void Function()? onRemove,
    void Function(int)? onQuantityChanged,
  }) {
    final cartProvider = context.read<CartProvider>();
    final isB2B = cartProvider.cartMode == 'B2B' ||
        (cartProvider.cartMode == null &&
            context.read<MarketModeProvider>().isB2B);
    final minQty = (isB2B && (product?.b2bMoq ?? 0) > 0) ? product!.b2bMoq! : 1;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Enhanced Product Image Card
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF2A2A2A), const Color(0xFF1F1F1F)]
                        : [const Color(0xFFF8F8F8), const Color(0xFFEEEEEE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.network(
                      item.productImage,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.shopping_bag_outlined,
                            size: 24, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (item.variant != null && item.variant!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.variant!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    if (isB2B && (product?.b2bMoq ?? 0) > 0) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Wholesale | Min: ${product!.b2bMoq}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Move item to wishlist
                        final wishlistProvider =
                            context.read<WishlistProvider>();
                        final product = _productCache[item.productId];
                        if (product != null) {
                          wishlistProvider.addItem(product);
                          final cartProvider = context.read<CartProvider>();
                          cartProvider.removeItem(item.productId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Moved to wishlist'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Move to wishlist',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    isDark ? Colors.grey[500] : Colors.grey[500],
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Quantity + Price Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Green Quantity Control
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF15A32A), Color(0xFF0D8320)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D8320).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (item.quantity > minQty) {
                              onQuantityChanged?.call(item.quantity - 1);
                            } else {
                              onRemove?.call();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            child: Text('–',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onQuantityChanged?.call(item.quantity + 1);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            child: Text('+',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Text(
                    '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Dashed Separator Line
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: List.generate(
              50,
              (index) => Expanded(
                child: Container(
                  height: 1,
                  color: index.isEven
                      ? (isDark ? Colors.grey[700] : Colors.grey[300])
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- You Might Also Like Section (Blinkit Style) ---
  Widget _buildYouMightAlsoLike(CartProvider cartProvider, bool isDark,
      Color cardColor, Color accentColor) {
    final productProvider = context.read<ProductProvider>();
    final cartCategoryIds = cartProvider.items
        .map((item) => _productCache[item.productId]?.categoryId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    // Get similar products from cart categories, excluding items already in cart
    final cartProductIds = cartProvider.items.map((i) => i.productId).toSet();
    final allSuggestedProducts = productProvider.products
        .where((p) =>
            p.isActive &&
            !cartProductIds.contains(p.id) &&
            (cartCategoryIds.isEmpty || cartCategoryIds.contains(p.categoryId)))
        .toList();

    final suggestedProducts =
        allSuggestedProducts.take(6).toList(); // 3 columns x 2 rows
    final previewProducts =
        allSuggestedProducts.skip(6).take(3).toList(); // For circular images

    if (suggestedProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'You might also like',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // 3x2 Product Grid - Compact
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // 0.54 gave each cell a fixed height that the card's actual
              // content (image + a 20px top-padding reservation for the
              // floating ADD button + unit badge + up-to-2-line name +
              // rating/delivery row + price row) routinely exceeded —
              // the classic RenderFlex overflow. 0.48 gives real headroom
              // instead of riding right at the edge of a tight estimate.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 8,
                childAspectRatio: 0.48,
              ),
              itemCount: suggestedProducts.length,
              itemBuilder: (context, index) {
                final product = suggestedProducts[index];
                return _buildBlinkitProductCard(
                    product, isDark, accentColor, cartProvider);
              },
            ),
          ),

          const SizedBox(height: 10),

          // See all products card - Compact
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/shop');
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF303030)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    // Circular product images stack - Smaller
                    SizedBox(
                      width: 56,
                      height: 28,
                      child: Stack(
                        children: [
                          ...List.generate(
                            previewProducts.length.clamp(0, 3),
                            (index) => Positioned(
                              left: index * 14.0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cardColor,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        previewProducts[index].primaryImage,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[200],
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[200],
                                      child: Icon(Icons.image,
                                          size: 12, color: Colors.grey[400]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Text
                    Expanded(
                      child: Text(
                        'See all products',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                        ),
                      ),
                    ),

                    // Arrow
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Blinkit-style Product Card (Matching Home Screen ProductCardCompact)
  Widget _buildBlinkitProductCard(ProductModel product, bool isDark,
      Color accentColor, CartProvider cartProvider) {
    final hasDiscount = product.originalPrice != null &&
        product.originalPrice! > product.salePrice;
    final isInCart = cartProvider.isInCart(product.id);
    final quantity = cartProvider.getItemQuantity(product.id);
    final hasVariants = product.variants.isNotEmpty;
    final variantCount = product.variants.length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, '/product/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            if (!isDark)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section with Premium Overlays
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Product Image with Gradient Overlay
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      const Color(0xFF2A2A2A),
                                      const Color(0xFF1A1A1A)
                                    ]
                                  : [
                                      const Color(0xFFFAFAFA),
                                      const Color(0xFFF0F0F0)
                                    ],
                            ),
                          ),
                          child: product.primaryImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.primaryImage,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            accentColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[400],
                                    size: 36,
                                  ),
                                )
                              : Icon(Icons.image_outlined,
                                  color: Colors.grey[400], size: 36),
                        ),
                        // Subtle bottom gradient for text readability
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Wishlist Heart - Frosted Glass Effect
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final wishlistProvider = context.read<WishlistProvider>();
                      wishlistProvider.toggleItem(product);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_outline_rounded,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),

                // Premium ADD Button - Floating Style
                Positioned(
                  bottom: -16,
                  left: 12,
                  right: 12,
                  child: isInCart && quantity > 0
                      ? _buildPremiumQuantityControl(
                          product, quantity, accentColor, cartProvider)
                      : _buildPremiumAddButton(product, accentColor,
                          cartProvider, hasVariants, variantCount),
                ),
              ],
            ),

            // Product Info - Premium Typography
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Unit badge with accent dot
                  if (product.unit != null && product.unit!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.unit!,
                            style: TextStyle(
                              fontSize: 9,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Product Name - Better Typography
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Rating & Delivery - Same Row (Like Blinkit Reference)
                  Row(
                    children: [
                      // Rating badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 10, color: Colors.amber[700]),
                            const SizedBox(width: 2),
                            Text(
                              product.rating?.toStringAsFixed(1) ?? '0.0',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delivery badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 10, color: accentColor),
                            const SizedBox(width: 2),
                            Text(
                              '30 MIN',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Price - Premium Look
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${product.salePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumAddButton(ProductModel product, Color accentColor,
      CartProvider cartProvider, bool hasVariants, int variantCount) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        cartProvider.addItem(product);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Colors.white],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accentColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 14,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Text(
              'ADD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
            if (hasVariants) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '+$variantCount',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumQuantityControl(ProductModel product, int quantity,
      Color accentColor, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (quantity > 1) {
                cartProvider.updateQuantity(product.id, quantity - 1);
              } else {
                cartProvider.removeItem(product.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                quantity > 1
                    ? Icons.remove_rounded
                    : Icons.delete_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              cartProvider.updateQuantity(product.id, quantity + 1);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDeliveryProgress(
      double subtotal, bool isDark, Color cardColor, Color accentColor) {
    const freeDeliveryThreshold = 499.0;
    final remaining =
        (freeDeliveryThreshold - subtotal).clamp(0.0, freeDeliveryThreshold);
    final progress = (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0);
    final hasFreeDelivery = remaining <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasFreeDelivery
              ? [
                  Colors.green.shade50,
                  Colors.green.shade100,
                ]
              : [
                  const Color(0xFFFFF8E1),
                  const Color(0xFFFFECB3),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              hasFreeDelivery ? Colors.green.shade200 : Colors.amber.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasFreeDelivery
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.amber.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main delivery section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Animated truck/delivery icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hasFreeDelivery
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.amber.shade400, Colors.amber.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: hasFreeDelivery
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🚚',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasFreeDelivery) ...[
                        // Success state
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'FREE DELIVERY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Yay! You\'ve unlocked free delivery 🎉',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ] else ...[
                        // Progress state
                        Text(
                          'Add ₹${remaining.toStringAsFixed(0)} more for FREE delivery',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Premium progress bar
                        Stack(
                          children: [
                            // Background track
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // Progress fill with gradient
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              height: 8,
                              width: MediaQuery.of(context).size.width *
                                  0.55 *
                                  progress,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade500,
                                    Colors.orange.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            // Progress indicator dot
                            Positioned(
                              left: (MediaQuery.of(context).size.width *
                                      0.55 *
                                      progress) -
                                  4,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.orange.shade600, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${subtotal.toStringAsFixed(0)} / ₹${freeDeliveryThreshold.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow or Achievement badge
                if (!hasFreeDelivery)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color:
                hasFreeDelivery ? Colors.green.shade200 : Colors.amber.shade200,
          ),

          // See all coupons link
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _openBlinkitCouponScreen();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.local_offer_outlined,
                        size: 14, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'See all coupons & offers',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBlinkitCouponScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BlinkitCouponScreen(),
    );
  }

  // --- Bill Details (Blinkit style) ---
  Widget _buildBillDetails(
    Map<String, double> pricing,
    CouponProvider couponProvider,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final subtotal = pricing['subtotal'] ?? 0;
    final discount = pricing['couponDiscount'] ?? 0;
    final shipping = pricing['shippingFee'] ?? 0;
    final total = pricing['finalTotal'] ?? 0;
    final hasCoupon = couponProvider.appliedCoupon != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF252525), const Color(0xFF1E1E1E)]
                    : [const Color(0xFFF8F8F8), cardColor],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.8), accentColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🧾', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Bill Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (hasCoupon && discount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 4),
                        Text(
                          'Saving ₹${discount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bill items
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              children: [
                // Items total
                _buildBillRow(
                  emoji: '🛒',
                  label: 'Items total',
                  value: '₹${subtotal.toStringAsFixed(0)}',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),

                // Handling charge (waived)
                _buildBillRow(
                  emoji: '📦',
                  label: 'Handling charge',
                  value: '₹2',
                  isDark: isDark,
                  isStrikethrough: true,
                  badge: 'FREE',
                  badgeColor: Colors.blue,
                ),
                const SizedBox(height: 10),

                // Delivery charge
                _buildBillRow(
                  emoji: '🚚',
                  label: 'Delivery charge',
                  value:
                      shipping > 0 ? '₹${shipping.toStringAsFixed(0)}' : 'FREE',
                  isDark: isDark,
                  valueColor: shipping > 0 ? null : Colors.green.shade600,
                ),

                // Coupon discount row - Same format as other items
                if (hasCoupon && discount > 0) ...[
                  const SizedBox(height: 10),
                  _buildBillRow(
                    emoji: '🏷️',
                    label: 'Coupon (${couponProvider.appliedCoupon!.code})',
                    value: '-₹${discount.toStringAsFixed(0)}',
                    isDark: isDark,
                    valueColor: Colors.green.shade600,
                  ),
                ],
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),

          // Grand total
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (discount > 0) ...[
                      Text(
                        '₹${(total + discount).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.9),
                            accentColor
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow({
    required String emoji,
    required String label,
    required String value,
    required bool isDark,
    bool isStrikethrough = false,
    Color? valueColor,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: badgeColor ?? Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.grey[300] : Colors.grey[800]),
            decoration: isStrikethrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  // --- Delivery Instructions ---
  Widget _buildDeliveryInstructions(
      bool isDark, Color cardColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF252525), const Color(0xFF1E1E1E)]
                    : [const Color(0xFFF8F8F8), cardColor],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.8), accentColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📋', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Delivery Instructions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick action chips
                Row(
                  children: [
                    _buildInstructionChip(
                      emoji: '📵',
                      label: 'Avoid calling',
                      isSelected: _avoidCalling,
                      isDark: isDark,
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _avoidCalling = !_avoidCalling);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildInstructionChip(
                      emoji: '🔕',
                      label: "Don't ring bell",
                      isSelected: _dontRing,
                      isDark: isDark,
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _dontRing = !_dontRing);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Voice note section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF252525)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isRecording
                          ? Colors.red.shade400
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      width: _isRecording ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red.shade500
                                  : (isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.mic_rounded,
                              size: 18,
                              color: _isRecording
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _recordedFilePath != null
                                      ? 'Voice note recorded'
                                      : (_isRecording
                                          ? 'Recording...'
                                          : 'Add voice note'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isRecording
                                        ? Colors.red.shade500
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                                Text(
                                  _isRecording
                                      ? _formatDuration(_recordDuration)
                                      : (_recordedFilePath != null
                                          ? 'Tap play to listen'
                                          : 'Tap mic to start'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Action buttons
                          if (_recordedFilePath != null && !_isRecording) ...[
                            // Play/Pause button
                            GestureDetector(
                              onTap: _togglePlayback,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accentColor.withValues(alpha: 0.9),
                                      accentColor
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Delete button
                            GestureDetector(
                              onTap: _deleteRecording,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red.shade500,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Record/Stop button
                            GestureDetector(
                              onTap: _isRecording
                                  ? _stopRecording
                                  : _startRecording,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: _isRecording
                                      ? null
                                      : LinearGradient(
                                          colors: [
                                            Colors.red.shade400,
                                            Colors.red.shade600
                                          ],
                                        ),
                                  color: _isRecording ? Colors.grey[300] : null,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: _isRecording
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.red
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Icon(
                                  _isRecording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  size: 22,
                                  color: _isRecording
                                      ? Colors.red.shade600
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Text note input
                TextField(
                  onChanged: (val) => _deliveryNote = val,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add delivery note (optional)...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF252525)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    suffixIcon: Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionChip({
    required String emoji,
    required String label,
    required bool isSelected,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.08)
                  ])
                : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF252525) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? accentColor
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 14, color: accentColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Audio recording methods
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/delivery_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _recordDuration = Duration.zero;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration += const Duration(seconds: 1);
          });
        });

        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_recordedFilePath != null) {
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
        setState(() => _isPlaying = true);

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      }
    }
    HapticFeedback.lightImpact();
  }

  void _deleteRecording() {
    HapticFeedback.mediumImpact();
    setState(() {
      _recordedFilePath = null;
      _recordDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // --- Payment Method Selection ---
  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Razorpay':
        return Icons.payment_rounded;
      case 'COD':
        return Icons.local_shipping_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  void _showPaymentMethodSheet(bool isDark, Color accentColor) {
    final methods = [
      {
        'name': 'Razorpay',
        'icon': Icons.payment_rounded,
        'subtitle': 'UPI, Cards, Wallets & More',
        'color': const Color(0xFF3B82F6),
        'recommended': true,
      },
      {
        'name': 'COD',
        'icon': Icons.local_shipping_rounded,
        'subtitle': 'Cash on Delivery',
        'color': const Color(0xFFF59E0B),
        'recommended': false,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.8), accentColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Payment options
            ...methods.map((method) => GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _selectedPaymentMethod = method['name'] as String;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == method['name']
                          ? accentColor.withValues(alpha: 0.1)
                          : (isDark
                              ? const Color(0xFF252525)
                              : const Color(0xFFF8F8F8)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedPaymentMethod == method['name']
                            ? accentColor
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: _selectedPaymentMethod == method['name'] ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (method['color'] as Color).withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            method['icon'] as IconData,
                            color: method['color'] as Color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      method['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (method['recommended'] as bool) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'Recommended',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: accentColor,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                method['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedPaymentMethod == method['name'])
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 14),
                          ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --- Order Placement ---
  Future<void> _placeOrder(double finalTotal, AddressModel address) async {
    if (_isPlacingOrder) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please login to place order', isError: true);
      return;
    }

    setState(() => _isPlacingOrder = true);
    HapticFeedback.heavyImpact();

    try {
      if (_selectedPaymentMethod == 'COD') {
        await _createOrderInFirestore(
            address: address, paymentStatus: 'pending');
      } else {
        // Online payment - use unified RazorpayService (works on web + mobile)
        _razorpayService = RazorpayService();
        _razorpayService!.initialize(
          onSuccess: (paymentId, orderId, signature) {
            _handlePaymentSuccess(paymentId, orderId, signature, address);
          },
          onFailure: (error) {
            _handlePaymentError(error);
          },
          onDismiss: () {
            setState(() => _isPlacingOrder = false);
          },
        );
        await _razorpayService!.openCheckout(
          amount: finalTotal,
          userName: address.name,
          userEmail: user.email ?? 'user@example.com',
          userPhone: address.phone,
          description: 'Agrimore Order Payment',
          context: context,
        );
      }
    } catch (e) {
      debugPrint('Order placement error: $e');
      _showSnackBar('Error: ${e.toString()}', isError: true);
      setState(() => _isPlacingOrder = false);
    }
  }

  Future<void> _handlePaymentSuccess(
    String paymentId,
    String? orderId,
    String? signature,
    AddressModel address,
  ) async {
    final verified = await _razorpayService?.verifyPayment(
          paymentId: paymentId,
          orderId: orderId ?? '',
          signature: signature ?? '',
        ) ??
        false;
    if (!verified) {
      _handlePaymentError('Payment verification failed');
      return;
    }

    await _createOrderInFirestore(
      address: address,
      paymentStatus: 'paid',
      razorpayPaymentId: paymentId,
      razorpayOrderId: orderId,
      razorpaySignature: signature,
    );
  }

  void _handlePaymentError(String error) {
    debugPrint('Payment failed: $error');
    _showSnackBar('Payment failed: $error', isError: true);
    setState(() => _isPlacingOrder = false);
  }

  /// Calls the server-validated `createOrder` callable
  /// (functions/src/customer/createOrder.ts) instead of writing order
  /// documents directly to Firestore. `orders`' firestore.rules now has
  /// `allow create: if false` — any remaining direct client write here would
  /// simply fail with permission-denied, which is exactly what was breaking
  /// checkout via this screen. Mirrors payment_method_screen.dart's
  /// `_createSellerScopedOrders`: only productId/quantity are sent, never
  /// prices or totals. orderMode is derived from CartProvider.cartMode (set
  /// at add-to-cart time) rather than MarketModeProvider.isB2B, since it
  /// reflects what's actually in the cart rather than the toggle's current
  /// state — see the comment on _buildBlinkitBottomBar for the known gap
  /// where cartMode can be null on a reloaded cart with items.
  Future<void> _createOrderInFirestore({
    required AddressModel address,
    required String paymentStatus,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final cartProvider = context.read<CartProvider>();
      final couponProvider = context.read<CouponProvider>();

      if (cartProvider.items.isEmpty) {
        throw Exception('Cart is empty');
      }

      final isB2B = cartProvider.cartMode == 'B2B' ||
          (cartProvider.cartMode == null &&
              context.read<MarketModeProvider>().isB2B);
      final employeeCode = _employeeCodeController.text.trim();
      if (isB2B && employeeCode.isEmpty) {
        throw Exception('Employee ID is required for B2B orders');
      }

      final pricing = _calculateAdvancedPricing(cartProvider, couponProvider);
      final shippingFee = pricing['shippingFee'] ?? 0.0;
      final expressDeliveryFee = pricing['expressDeliveryFee'] ?? 0.0;
      final deliveryCharge = shippingFee + expressDeliveryFee;
      // deliveryCharge/couponCode are sent below and createOrder.ts
      // re-derives its own grandTotal server-side (subtotal - discount +
      // deliveryCharge + tax) from them — this function deliberately never
      // computes or sends a total. The amount actually charged via Razorpay
      // (for non-COD orders) is fixed *before* this function runs, at the
      // "Pay"/"Place Order" button's call to _buildBlinkitBottomBar/
      // _placeOrder, and must equal what createOrder computes.

      // paymentMethod values in this screen's UI are 'COD'/'Razorpay'
      // (display casing); createOrder.ts compares paymentMethod against the
      // literal lowercase string "cod" to decide whether Razorpay
      // verification is required. Sending the raw display-cased value would
      // make a COD order look like a non-COD one server-side and fail with
      // "Razorpay payment details are required for non-COD orders".
      final normalizedPaymentMethod = _selectedPaymentMethod.toLowerCase();

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createOrder',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'items': cartProvider.items
            .map((item) => {
                  'productId': item.productId,
                  'quantity': item.quantity,
                  // SELLER-CATALOGUE-2: the server prices and stocks the chosen option.
                  if (item.variant != null && item.variant!.isNotEmpty) 'variantId': item.variant,
                })
            .toList(),
        'orderMode': isB2B ? 'B2B' : 'B2C',
        // Phase 16B, Workstream 1b/1c — identical rule to
        // payment_method_screen.dart. B2B unchanged: key always sent, same
        // trimmed value, still hard-failing above when empty. B2C sends the
        // key only when the customer actually typed something, so an empty
        // or whitespace-only field yields a payload with no `employeeCode`
        // key — byte-identical to every B2C order placed before this phase.
        // (createOrder.ts line 121 collapses both `undefined` and `""` to
        // "" anyway, so this is a wire-shape choice, not a behavioural one.)
        if (isB2B)
          'employeeCode': employeeCode
        else if (employeeCode.isNotEmpty)
          'employeeCode': employeeCode,
        'deliveryAddress': address.toOrderMap(),
        'paymentMethod': normalizedPaymentMethod,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
        if (couponProvider.appliedCoupon?.code != null)
          'couponCode': couponProvider.appliedCoupon!.code,
        'deliveryCharge': deliveryCharge,
        'tax': 0.0,
        // _deliveryNote is captured from the delivery-instructions TextField
        // above but was never included in this payload — createOrder.ts has
        // always accepted and stored `notes` correctly (see its own
        // definition), this screen just never sent it, so every note typed
        // here was silently discarded before reaching the order. Mirrors
        // payment_method_screen.dart's own createOrder call, the other of
        // the two call sites, which already sends notes correctly.
        if (_deliveryNote.trim().isNotEmpty) 'notes': _deliveryNote.trim(),
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception('Failed to create order');
      }

      final createdRefs =
          (data['orders'] as List).cast<Map<dynamic, dynamic>>();
      final db = FirebaseFirestore.instance;
      final createdOrders = <OrderModel>[];
      await Future.wait(createdRefs.map((ref) async {
        final orderId = ref['orderId'] as String;
        try {
          final doc = await db
              .collection('orders')
              .doc(orderId)
              .get()
              .timeout(const Duration(seconds: 3));
          if (doc.exists && doc.data() != null) {
            createdOrders.add(OrderModel.fromMap(doc.data()!, doc.id));
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching created order doc: $e');
        }
      }));

      final OrderModel finalOrder;
      if (createdOrders.isNotEmpty) {
        finalOrder = createdOrders.first;
      } else if (createdRefs.isNotEmpty) {
        final firstRef = createdRefs.first;
        final orderId = firstRef['orderId']?.toString() ?? 'unknown';
        final orderNumber = firstRef['orderNumber']?.toString() ??
            'ORD-${DateTime.now().millisecondsSinceEpoch}';
        final subtotal = pricing['subtotal'] ?? cartProvider.subtotal;
        final couponDiscount = pricing['couponDiscount'] ?? 0.0;
        final grandTotal = subtotal - couponDiscount + deliveryCharge;
        finalOrder = OrderModel(
          id: orderId,
          userId: userId,
          orderNumber: orderNumber,
          items: cartProvider.items,
          deliveryAddress: address,
          subtotal: subtotal,
          discount: couponDiscount,
          deliveryCharge: deliveryCharge,
          tax: 0.0,
          total: grandTotal,
          paymentMethod: normalizedPaymentMethod,
          paymentStatus: paymentStatus,
          orderStatus: 'pending',
          orderMode: isB2B ? 'B2B' : 'B2C',
          employeeCode: employeeCode.isNotEmpty ? employeeCode : null,
          razorpayOrderId: razorpayOrderId,
          razorpayPaymentId: razorpayPaymentId,
          razorpaySignature: razorpaySignature,
          couponCode: couponProvider.appliedCoupon?.code,
          notes: _deliveryNote.trim().isNotEmpty ? _deliveryNote.trim() : null,
          createdAt: DateTime.now(),
        );
      } else {
        throw Exception('Order creation failed');
      }

      await cartProvider.clearCart();
      couponProvider.removeCoupon();

      if (!mounted) return;

      setState(() => _isPlacingOrder = false);
      HapticFeedback.heavyImpact();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(order: finalOrder),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      debugPrint('Order creation error: $e');
      _showSnackBar('Error creating order: ${e.toString()}', isError: true);
      setState(() => _isPlacingOrder = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Sticky Bottom Bar ---
  Widget _buildBlinkitBottomBar(double total, String? cartMode, bool isDark,
      Color accentColor, Color cardColor) {
    // cartMode ('B2B'/'B2C'/null) comes from CartProvider.cartMode, set at
    // add-to-cart time — it reflects what's actually in the cart, unlike
    // MarketModeProvider.isB2B which only reflects the toggle's current
    // state and could have changed since items were added. NOTE: cartMode
    // can be null even with items in the cart if CartProvider was recreated
    // and reloaded a persisted cart from Firestore (loadCart() never
    // restores cartMode — it's in-memory-only) — see the completion report
    // for this phase for why null is treated as B2C here rather than fixed.
    final isB2B = cartMode == 'B2B' ||
        (cartMode == null && context.read<MarketModeProvider>().isB2B);
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, _) {
        final address = addressProvider.hasAddresses
            ? (addressProvider.selectedAddress ??
                addressProvider.defaultAddress)
            : null;
        final hasAddress = address != null;

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Address Row
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      _showSnackBar(
                          'Please sign in to manage delivery addresses',
                          isError: true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, '/profile/addresses');
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF252525)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Premium Home Icon (like truck/clock)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withValues(alpha: 0.9),
                                accentColor
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🏠', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Address Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      hasAddress
                                          ? 'Delivering to ${address.addressType ?? 'Home'}'
                                          : 'Add delivery address',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ],
                              ),
                              if (hasAddress)
                                Text(
                                  '${address.addressLine1}${address.landmark != null ? ', ${address.landmark}' : ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Text(
                                  'Tap to select address',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: accentColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Change button
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isB2B) ...[
                  const SizedBox(height: 10),
                  AssociateCodeField(
                    controller: _employeeCodeController,
                    isDark: isDark,
                    accentColor: accentColor,
                    dense: true,
                    isB2B: true,
                  ),
                ] else ...[
                  // Phase 16B, Workstream 1a — the optional B2C Sales
                  // Associate code, collapsed by default (see
                  // _showAssociateCodeField). Purely additive: the prompt is
                  // a single tappable line, and nothing in this branch is
                  // read by the "Proceed to Pay" button below, whose only
                  // code guard is `isB2B && ...` and so cannot fire here.
                  const SizedBox(height: 10),
                  if (_showAssociateCodeField)
                    AssociateCodeField(
                      controller: _employeeCodeController,
                      isDark: isDark,
                      accentColor: accentColor,
                      dense: true,
                    )
                  else
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showAssociateCodeField = true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined,
                                size: 15, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              'Have a Sales Associate code?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 10),

                // Payment Buttons Row
                Row(
                  children: [
                    // Select Payment Method Button
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showPaymentMethodSheet(isDark, accentColor);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF252525) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accentColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getPaymentIcon(_selectedPaymentMethod),
                                size: 18,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedPaymentMethod,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Proceed to Pay Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isPlacingOrder
                            ? null
                            : () {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  _showSnackBar(
                                      'Please sign in to complete your order',
                                      isError: true);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LoginScreen()),
                                  );
                                  return;
                                }
                                if (!hasAddress || address == null) {
                                  _showSnackBar(
                                      'Please select or add a delivery address',
                                      isError: true);
                                  Navigator.pushNamed(
                                      context, '/profile/addresses');
                                  return;
                                }
                                if (isB2B &&
                                    _employeeCodeController.text
                                        .trim()
                                        .isEmpty) {
                                  _showSnackBar(
                                      'Employee ID is required for B2B orders',
                                      isError: true);
                                  return;
                                }
                                // `total` here is already the true
                                // chargeable amount (see the call site of
                                // _buildBlinkitBottomBar) — the same figure
                                // createOrder.ts computes and verifies
                                // server-side.
                                _placeOrder(total, address);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              accentColor.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isPlacingOrder
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _selectedPaymentMethod == 'COD'
                                        ? 'Place Order'
                                        : 'Pay',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '₹${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, double> _calculateAdvancedPricing(
    CartProvider cartProvider,
    CouponProvider couponProvider,
  ) {
    final subtotal = cartProvider.subtotal;
    final coupon = couponProvider.appliedCoupon;

    double couponDiscount = 0;
    double bogoValue = 0;
    double flatDiscount = 0;
    double percentageDiscount = 0;

    if (coupon != null) {
      couponDiscount = couponProvider.calculateDiscount(
        orderAmount: subtotal,
        items: cartProvider.items,
      );

      switch (coupon.type) {
        case CouponType.flat:
          flatDiscount = couponDiscount;
          break;
        case CouponType.percentage:
          percentageDiscount = couponDiscount;
          break;
        case CouponType.buyOneGetOne:
          bogoValue = couponDiscount;
          break;
      }
    }

    final shippingInfo = _calculateShippingFees(cartProvider.items);

    // ✅ Delivery fee logic: FREE for orders ₹499+, otherwise ₹40
    const double freeDeliveryThreshold = 499.0;
    const double standardDeliveryFee = 40.0;
    final shippingFee =
        subtotal >= freeDeliveryThreshold ? 0.0 : standardDeliveryFee;

    final expressDeliveryFee = _expressDeliverySelected
        ? (shippingInfo.expressDeliveryFee ?? 0.0)
        : 0.0;

    final finalTotal = subtotal -
        couponDiscount +
        shippingFee +
        expressDeliveryFee;

    return {
      'subtotal': subtotal,
      'couponDiscount': couponDiscount,
      'bogoValue': bogoValue,
      'flatDiscount': flatDiscount,
      'percentageDiscount': percentageDiscount,
      'shippingFee': shippingFee,
      'expressDeliveryFee': expressDeliveryFee,
      'finalTotal': finalTotal < 0 ? 0 : finalTotal,
    };
  }

  Widget _buildLoadingState(Color accentColor, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
          const SizedBox(height: 16),
          Text('Loading your cart...',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      ),
    );
  }

}
