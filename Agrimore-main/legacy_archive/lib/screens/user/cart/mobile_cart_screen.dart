import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/coupon_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/product_model.dart';
import 'widgets/cart_item_card.dart';
import 'widgets/empty_cart.dart';
import 'coupon_selection_screen.dart';
import '../checkout/checkout_screen.dart';

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
  
  bool get hasMixedDelivery => freeDeliveryProducts.isNotEmpty && 
      (standardProducts.isNotEmpty || specialFees.isNotEmpty);
}

class MobileCartScreen extends StatefulWidget {
  const MobileCartScreen({Key? key}) : super(key: key);

  @override
  State<MobileCartScreen> createState() => _MobileCartScreenState();
}

class _MobileCartScreenState extends State<MobileCartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  bool _isProcessingBogo = false;
  bool _expressDeliverySelected = false;
  
  final Map<String, CartItemModel> _bogoFreeItems = {};
  final Map<String, ProductModel> _productCache = {};

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOut),
    );

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
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
            _productCache[item.productId] = ProductModel.fromMap(doc.data()!, doc.id);
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
          expressDeliveryFee = (product.shippingPrice?.toDouble() ?? 40.0) + 9.0;
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
        buyItem = cartProvider.items.firstWhere((item) => item.productId == buyId);
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
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _showClearCartDialog(CartProvider cartProvider) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await cartProvider.clearCart();
      _bogoFreeItems.clear();
      if (mounted) {
        HapticFeedback.heavyImpact();
        SnackbarHelper.showSuccess(context, 'Cart cleared successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark, cardColor),
      body: Consumer2<CartProvider, CouponProvider>(
        builder: (context, cartProvider, couponProvider, child) {
          if (cartProvider.isLoading) {
            return _buildLoadingState(accentColor, isDark);
          }

          if (cartProvider.isEmpty) {
            return EmptyCart(
              onStartShopping: () => Navigator.pop(context),
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

          return Stack(
            children: [
              Column(
                children: [
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildCartItemsSection(
                              cartProvider,
                              _bogoFreeItems.values.toList(),
                              isDark,
                              cardColor,
                              accentColor,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildCouponSection(
                              couponProvider,
                              isDark,
                              cardColor,
                              accentColor,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildDeliverySection(
                              cartProvider.items,
                              isDark,
                              cardColor,
                              accentColor,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildAdvancedPriceSummary(
                              pricingData,
                              couponProvider,
                              isDark,
                              cardColor,
                              accentColor,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildSecurityBadge(isDark, accentColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCheckoutButton(
                  pricingData['finalTotal']!,
                  isDark,
                  accentColor,
                  cardColor,
                ),
              ),
              if (_showFab) _buildScrollToTopFab(accentColor),
            ],
          );
        },
      ),
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
    final shippingFee = shippingInfo.totalShippingFee;
    final expressDeliveryFee = _expressDeliverySelected ? (shippingInfo.expressDeliveryFee ?? 0.0) : 0.0;
    
    final finalTotal = subtotal - couponDiscount + shippingFee + expressDeliveryFee;

    return {
      'subtotal': subtotal,
      'couponDiscount': couponDiscount,
      'bogoValue': bogoValue,
      'flatDiscount': flatDiscount,
      'percentageDiscount': percentageDiscount,
      'shippingFee': shippingFee,
      'expressDeliveryFee': expressDeliveryFee,
      'finalTotal': finalTotal,
    };
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color cardColor) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      title: Text(
        'Shopping Cart',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      actions: [
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            if (cartProvider.isEmpty) return const SizedBox.shrink();

            return IconButton(
              onPressed: () => _showClearCartDialog(cartProvider),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Cart',
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCartItemsSection(
    CartProvider cartProvider,
    List<CartItemModel> freeItems,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final allItems = [...cartProvider.items, ...freeItems];
    final totalItemCount = cartProvider.itemCount + freeItems.length;

    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Cart Items',
      icon: Icons.shopping_bag_outlined,
      accentColor: accentColor,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.cartShopping, size: 12, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      '$totalItemCount ${totalItemCount == 1 ? 'Item' : 'Items'}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor),
                    ),
                  ],
                ),
              ),
              if (freeItems.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.gift, size: 10, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Text(
                        '${freeItems.length} Free',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '₹${cartProvider.subtotal.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
          ),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allItems.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
            ),
            itemBuilder: (context, index) {
              final item = allItems[index];
              final isFree = item.isFreeItem;
              final product = _productCache[item.productId];
              
              return _buildCartItem(
                item: item,
                product: product,
                isFree: isFree,
                isDark: isDark,
                accentColor: accentColor,
                onRemove: isFree ? null : () async {
                  final success = await cartProvider.removeItem(item.productId);
                  if (success && mounted) {
                    SnackbarHelper.showSuccess(context, 'Item removed');
                    await _loadProductDetails();
                  }
                },
                onQuantityChanged: isFree ? null : (quantity) async {
                  await cartProvider.updateQuantity(item.productId, quantity);
                },
              );
            },
          ),
        ],
      ),
    );
  }

Widget _buildCartItem({
  required CartItemModel item,
  ProductModel? product,
  required bool isFree,
  required bool isDark,
  required Color accentColor,
  void Function()? onRemove,
  void Function(int)? onQuantityChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      color: isFree ? Colors.green.withOpacity(isDark ? 0.08 : 0.03) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: isFree ? Border.all(color: Colors.green.withOpacity(0.2)) : null,
    ),
    padding: isFree ? const EdgeInsets.all(8) : EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFree)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade500]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.gift, size: 10, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        item.freeItemLabel ?? 'FREE',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Added via BOGO offer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
        
        // ✅ REMOVED: Separate variant display - CartItemCard handles it internally
        
        CartItemCard(
          item: item,
          onRemove: onRemove ?? () {},
          onQuantityChanged: onQuantityChanged ?? (int qty) {},
        ),
      ],
    ),
  );
}


  Widget _buildCouponSection(
    CouponProvider couponProvider,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final hasAppliedCoupon = couponProvider.appliedCoupon != null;
    final isBogo = hasAppliedCoupon && couponProvider.appliedCoupon!.type == CouponType.buyOneGetOne;

    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Apply Coupon',
      icon: Icons.local_offer_rounded,
      accentColor: accentColor,
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.selectionClick();
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CouponSelectionScreen(),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasAppliedCoupon
                ? (isBogo ? Colors.purple.withOpacity(isDark ? 0.15 : 0.08) : Colors.green.withOpacity(isDark ? 0.15 : 0.08))
                : (isDark ? Colors.grey[850] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasAppliedCoupon
                  ? (isBogo ? Colors.purple.withOpacity(0.3) : Colors.green.withOpacity(0.3))
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasAppliedCoupon
                          ? (isBogo ? Colors.purple.withOpacity(0.2) : Colors.green.withOpacity(0.2))
                          : accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FaIcon(
                      hasAppliedCoupon ? (isBogo ? FontAwesomeIcons.gift : FontAwesomeIcons.circleCheck) : FontAwesomeIcons.ticket,
                      color: hasAppliedCoupon ? (isBogo ? Colors.purple.shade700 : Colors.green.shade700) : accentColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAppliedCoupon ? couponProvider.appliedCoupon!.code : 'Select or enter coupon code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: hasAppliedCoupon
                                ? (isBogo ? Colors.purple.shade700 : Colors.green.shade700)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (hasAppliedCoupon) ...[
                          const SizedBox(height: 3),
                          Text(
                            isBogo ? '🎁 Buy 1 Get 1 Free Applied' : 'Coupon applied successfully',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasAppliedCoupon)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        couponProvider.removeCoupon();
                        _bogoFreeItems.clear();
                        setState(() {});
                        SnackbarHelper.showInfo(context, 'Coupon removed');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ],
              ),
              
              if (isBogo && _bogoFreeItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.purple[900]?.withOpacity(0.2) : Colors.purple[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 12, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Free item automatically added to your cart',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.purple[200] : Colors.purple[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliverySection(
    List<CartItemModel> items,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final shippingInfo = _calculateShippingFees(items);
    final hasExpressOption = shippingInfo.expressAvailableProducts.isNotEmpty;

    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Delivery Options',
      icon: Icons.local_shipping_outlined,
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Free Delivery Products (Standard Format)
          if (shippingInfo.freeDeliveryProducts.isNotEmpty) ...[
            _buildDeliveryOption(
              title: 'Free Standard Delivery',
              subtitle: 'Delivery in ${_getDeliveryDaysRange(shippingInfo.productDeliveryDays)} business days',
              fee: null,
              products: shippingInfo.freeDeliveryProducts,
              icon: FontAwesomeIcons.truck,
              color: Colors.green,
              isDark: isDark,
              isFree: true,
            ),
            if (shippingInfo.standardProducts.isNotEmpty || shippingInfo.specialFees.isNotEmpty)
              const SizedBox(height: 12),
          ],

          // Standard Delivery (Paid)
          if (shippingInfo.standardProducts.isNotEmpty) ...[
            _buildDeliveryOption(
              title: 'Standard Delivery',
              subtitle: 'Delivery in ${_getDeliveryDaysRange(shippingInfo.productDeliveryDays)} business days',
              fee: shippingInfo.standardFee,
              products: shippingInfo.standardProducts,
              icon: FontAwesomeIcons.truck,
              color: Colors.blue,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],

          // Special Delivery Fees
          if (shippingInfo.specialFees.isNotEmpty) ...[
            ...shippingInfo.specialFees.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDeliveryOption(
                title: 'Special Delivery',
                subtitle: 'Higher shipping for: ${entry.key}',
                fee: entry.value,
                products: [entry.key],
                icon: FontAwesomeIcons.truckFast,
                color: Colors.orange,
                isDark: isDark,
              ),
            )),
          ],

          // Mixed Delivery Notice
          if (shippingInfo.hasMixedDelivery) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FaIcon(FontAwesomeIcons.circleInfo, size: 14, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mixed Delivery Fees',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Some items have free delivery, others have shipping charges',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Express Delivery Option
          if (hasExpressOption) ...[
            GestureDetector(
              onTap: () {
                setState(() => _expressDeliverySelected = !_expressDeliverySelected);
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _expressDeliverySelected
                      ? Colors.purple.withOpacity(isDark ? 0.15 : 0.08)
                      : (isDark ? Colors.grey[850] : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _expressDeliverySelected
                        ? Colors.purple.withOpacity(0.5)
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: _expressDeliverySelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FaIcon(FontAwesomeIcons.boltLightning, size: 16, color: Colors.purple.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Express Delivery',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Delivery in 1-2 business days',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          if (shippingInfo.expressAvailableProducts.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'For: ${shippingInfo.expressAvailableProducts.take(2).join(', ')}${shippingInfo.expressAvailableProducts.length > 2 ? '...' : ''}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+₹${shippingInfo.expressDeliveryFee?.toStringAsFixed(0) ?? '0'}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.purple.shade700),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _expressDeliverySelected ? Colors.purple : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                              width: 2,
                            ),
                            color: _expressDeliverySelected ? Colors.purple : Colors.transparent,
                          ),
                          child: _expressDeliverySelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDeliveryDaysRange(Map<String, String> deliveryDays) {
    if (deliveryDays.isEmpty) return '2-3';
    return deliveryDays.values.first;
  }

  Widget _buildDeliveryOption({
    required String title,
    required String subtitle,
    required double? fee,
    required List<String> products,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isFree = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFree
            ? (isDark ? Colors.green[900]?.withOpacity(0.2) : Colors.green[50])
            : (isDark ? Colors.grey[850] : Colors.grey[50]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFree
              ? Colors.green.withOpacity(0.4)
              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FaIcon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isFree)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade500]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FREE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                  ),
                )
              else
                Text(
                  '₹${fee?.toStringAsFixed(0) ?? '0'}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                ),
            ],
          ),
          if (products.length > 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.boxOpen, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${products.length} products: ${products.take(2).join(', ')}${products.length > 2 ? '...' : ''}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedPriceSummary(
    Map<String, double> pricing,
    CouponProvider couponProvider,
    bool isDark,
    Color cardColor,
    Color accentColor,
  ) {
    final subtotal = pricing['subtotal']!;
    final couponDiscount = pricing['couponDiscount']!;
    final bogoValue = pricing['bogoValue']!;
    final flatDiscount = pricing['flatDiscount']!;
    final percentageDiscount = pricing['percentageDiscount']!;
    final shippingFee = pricing['shippingFee']!;
    final expressDeliveryFee = pricing['expressDeliveryFee']!;
    final total = pricing['finalTotal']!;
    final coupon = couponProvider.appliedCoupon;

    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Price Summary',
      icon: Icons.receipt_long_rounded,
      accentColor: accentColor,
      child: Column(
        children: [
          _priceRow('Subtotal', subtotal, isDark),
          
          if (flatDiscount > 0) ...[
            const SizedBox(height: 10),
            _priceRow('Flat Discount', -flatDiscount, isDark, color: Colors.green.shade600, icon: FontAwesomeIcons.tag),
          ],
          
          if (percentageDiscount > 0) ...[
            const SizedBox(height: 10),
            _priceRow('Percentage Discount', -percentageDiscount, isDark, color: Colors.green.shade600, icon: FontAwesomeIcons.percent),
          ],
          
          if (bogoValue > 0) ...[
            const SizedBox(height: 10),
            _priceRow('BOGO Free Item Value', -bogoValue, isDark, color: Colors.purple.shade600, icon: FontAwesomeIcons.gift),
          ],

          if (shippingFee > 0) ...[
            const SizedBox(height: 10),
            _priceRow('Shipping Fee', shippingFee, isDark, color: Colors.blue.shade600, icon: FontAwesomeIcons.truck),
          ],

          if (expressDeliveryFee > 0) ...[
            const SizedBox(height: 10),
            _priceRow('Express Delivery', expressDeliveryFee, isDark, color: Colors.purple.shade600, icon: FontAwesomeIcons.boltLightning),
          ],
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
          ),
          
          _priceRow('Total Amount', total, isDark, isTotal: true, color: accentColor),
          
          if (couponDiscount > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: bogoValue > 0
                      ? [Colors.purple.withOpacity(isDark ? 0.2 : 0.1), Colors.green.withOpacity(isDark ? 0.2 : 0.1)]
                      : [Colors.green.withOpacity(isDark ? 0.2 : 0.1), Colors.green.withOpacity(isDark ? 0.15 : 0.05)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bogoValue > 0 ? Colors.purple.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bogoValue > 0 ? Colors.purple.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FaIcon(
                      bogoValue > 0 ? FontAwesomeIcons.gift : FontAwesomeIcons.piggyBank,
                      size: 16,
                      color: bogoValue > 0 ? Colors.purple.shade700 : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bogoValue > 0 ? '🎉 Total Savings (BOGO + Discount)' : '🎉 Total Savings',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          coupon != null ? coupon.displayText : '',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${couponDiscount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: bogoValue > 0 ? Colors.purple.shade700 : Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityBadge(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(isDark ? 0.15 : 0.08),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(FontAwesomeIcons.shieldHalved, color: Colors.green.shade700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('100% Safe & Secure', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 3),
                Text('Your data is encrypted & protected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required Widget child,
    required bool isDark,
    required Color cardColor,
    required Color accentColor,
    String? title,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: accentColor, size: 18),
                  const SizedBox(width: 10),
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _priceRow(String title, double value, bool isDark, {Color? color, bool isTotal = false, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              FaIcon(icon, size: 12, color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                fontSize: isTotal ? 15 : 14,
                color: isDark ? (isTotal ? Colors.white : Colors.grey[300]) : (isTotal ? Colors.black87 : Colors.grey[700]),
              ),
            ),
          ],
        ),
        Text(
          '₹${value.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            fontSize: isTotal ? 18 : 14,
            color: color ?? (isDark ? Colors.white : Colors.black87),
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
          CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
          const SizedBox(height: 16),
          Text('Loading your cart...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(double total, bool isDark, Color accentColor, Color cardColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 10, offset: const Offset(0, -2))],
        border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          backgroundColor: accentColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(FontAwesomeIcons.arrowRight, size: 20),
            const SizedBox(width: 10),
            Text('Continue to Checkout • ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToTopFab(Color accentColor) {
    return Positioned(
      bottom: 100,
      right: 16,
      child: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
          },
          backgroundColor: accentColor,
          child: const Icon(Icons.arrow_upward, color: Colors.white),
        ),
      ),
    );
  }
}
