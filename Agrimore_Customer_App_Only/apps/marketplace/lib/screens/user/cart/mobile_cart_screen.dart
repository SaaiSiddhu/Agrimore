import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'widgets/cart_item_card.dart';
import 'widgets/empty_cart.dart';
import 'coupon_selection_screen.dart';
import 'blinkit_coupon_screen.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/order_success_screen.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/razorpay_service.dart';

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
  double _selectedTipAmount = 0;
  
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
  String _selectedPaymentMethod = 'Razorpay';  // Default to Razorpay
  
  // Wallet & Checkout
  bool _useWalletBalance = false;
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

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOut),
    );

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
      context.read<ProductProvider>().loadProducts(); // Load for "You might also like"
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
      body: SafeArea(
        child: Consumer2<CartProvider, CouponProvider>(
          builder: (context, cartProvider, couponProvider, child) {
            if (cartProvider.isLoading) {
              return _buildLoadingState(accentColor, isDark);
            }

            if (cartProvider.isEmpty) {
              return Column(
                children: [
                  _buildBlinkitAppBar(isDark, cardColor),
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
                _buildBlinkitAppBar(isDark, cardColor),
                
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
                          _buildDeliveryTimeHeader(cartProvider.items.length, isDark, cardColor),
                          
                          // Cart Items
                          _buildBlinkitCartItems(cartProvider, isDark, cardColor, accentColor),
                          
                          const SizedBox(height: 8),
                          
                          // Free Delivery Progress + See all coupons (moved above)
                          _buildFreeDeliveryProgress(
                            pricingData['subtotal']!,
                            isDark,
                            cardColor,
                            accentColor,
                          ),
                          
                          // You might also like section
                          _buildYouMightAlsoLike(cartProvider, isDark, cardColor, accentColor),
                          
                          // Bill Details
                          _buildBillDetails(
                            pricingData,
                            couponProvider,
                            isDark,
                            cardColor,
                            accentColor,
                          ),
                          
                          // Delivery Instructions
                          _buildDeliveryInstructions(isDark, cardColor, accentColor),
                          
                          // Tip Section
                          _buildTipSection(isDark, cardColor, accentColor),
                          
                          // Wallet Section
                          _buildWalletSection(isDark, cardColor, accentColor),
                          
                          // Bottom spacing for sticky bar
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Sticky Bottom Bar
                _buildBlinkitBottomBar(
                  pricingData['finalTotal']! + _selectedTipAmount,
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
  Widget _buildBlinkitAppBar(bool isDark, Color cardColor) {
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
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          Text(
            'Checkout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              // Share cart functionality
            },
            icon: Icon(
              Icons.shopping_cart_outlined,
              size: 18,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            label: Text(
              'Share',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
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
  Widget _buildBlinkitCartItems(CartProvider cartProvider, bool isDark, Color cardColor, Color accentColor) {
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
            onRemove: () => cartProvider.removeItem(item.productId, variant: item.variant),
            onQuantityChanged: (qty) => cartProvider.updateQuantity(item.productId, qty, variant: item.variant),
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
                        child: Icon(Icons.shopping_bag_outlined, size: 24, color: Colors.grey[400]),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Move to wishlist',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
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
                            if (item.quantity > 1) {
                              onQuantityChanged?.call(item.quantity - 1);
                            } else {
                              onRemove?.call();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            child: Text('–', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onQuantityChanged?.call(item.quantity + 1);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            child: Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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
  Widget _buildYouMightAlsoLike(CartProvider cartProvider, bool isDark, Color cardColor, Color accentColor) {
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
    
    final suggestedProducts = allSuggestedProducts.take(6).toList(); // 3 columns x 2 rows
    final previewProducts = allSuggestedProducts.skip(6).take(3).toList(); // For circular images
    
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 8,
                childAspectRatio: 0.54,
              ),
              itemCount: suggestedProducts.length,
              itemBuilder: (context, index) {
                final product = suggestedProducts[index];
                return _buildBlinkitProductCard(product, isDark, accentColor, cartProvider);
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
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[750]! : Colors.grey[200]!,
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
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: previewProducts[index].primaryImage,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: isDark ? Colors.grey[700] : Colors.grey[200],
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: isDark ? Colors.grey[700] : Colors.grey[200],
                                      child: Icon(Icons.image, size: 12, color: Colors.grey[400]),
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
  Widget _buildBlinkitProductCard(ProductModel product, bool isDark, Color accentColor, CartProvider cartProvider) {
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.salePrice;
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                                  ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                                  : [const Color(0xFFFAFAFA), const Color(0xFFF0F0F0)],
                            ),
                          ),
                          child: product.primaryImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.primaryImage,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accentColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[400],
                                    size: 36,
                                  ),
                                )
                              : Icon(Icons.image_outlined, color: Colors.grey[400], size: 36),
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
                      // TODO: Toggle wishlist
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
                      ? _buildPremiumQuantityControl(product, quantity, accentColor, cartProvider)
                      : _buildPremiumAddButton(product, accentColor, cartProvider, hasVariants, variantCount),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4, height: 4,
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
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 10, color: Colors.amber[700]),
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
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 10, color: accentColor),
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
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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

  Widget _buildPremiumAddButton(ProductModel product, Color accentColor, CartProvider cartProvider, bool hasVariants, int variantCount) {
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

  Widget _buildPremiumQuantityControl(ProductModel product, int quantity, Color accentColor, CartProvider cartProvider) {
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
                quantity > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
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


  String _formatCount(int count) {
    if (count >= 100000) {
      return '${(count / 100000).toStringAsFixed(2)} lac';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _buildBlinkitAddButton(ProductModel product, Color accentColor, CartProvider cartProvider) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        cartProvider.addItem(product);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'ADD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlinkitQuantityControl(ProductModel product, int quantity, Color accentColor, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                quantity > 1 ? Icons.remove : Icons.delete_outline,
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
                Icons.add,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridProductCard(ProductModel product, bool isDark, Color accentColor, CartProvider cartProvider) {
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.salePrice;
    final discountPercent = hasDiscount 
        ? ((product.originalPrice! - product.salePrice) / product.originalPrice! * 100).round()
        : 0;
    final isInCart = cartProvider.isInCart(product.id);
    final quantity = cartProvider.getItemQuantity(product.id);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, '/product/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with ADD button
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: CachedNetworkImage(
                      imageUrl: product.primaryImage,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 24),
                      ),
                    ),
                  ),
                  
                  // Discount badge
                  if (hasDiscount)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  
                  // ADD Button
                  Positioned(
                    bottom: 4,
                    right: 4,
                    left: 4,
                    child: isInCart && quantity > 0
                        ? _buildCompactQuantityControl(product, quantity, accentColor, cartProvider)
                        : _buildCompactAddButton(product, accentColor, cartProvider),
                  ),
                ],
              ),
            ),
            
            // Product Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Variant
                    if (product.variants.isNotEmpty)
                      Text(
                        product.variants.first.name,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    // Product Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const Spacer(),
                    
                    // Price
                    Row(
                      children: [
                        Text(
                          '₹${product.salePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 3),
                          Text(
                            '₹${product.originalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCompactAddButton(ProductModel product, Color accentColor, CartProvider cartProvider) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        cartProvider.addItem(product);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accentColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'ADD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactQuantityControl(ProductModel product, int quantity, Color accentColor, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
              padding: const EdgeInsets.all(4),
              child: Icon(
                quantity > 1 ? Icons.remove : Icons.delete_outline,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              cartProvider.updateQuantity(product.id, quantity + 1);
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.add,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSuggestedProductCard(ProductModel product, bool isDark, Color accentColor, CartProvider cartProvider) {
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.salePrice;
    final discountPercent = hasDiscount 
        ? ((product.originalPrice! - product.salePrice) / product.originalPrice! * 100).round()
        : 0;
    final isInCart = cartProvider.isInCart(product.id);
    final quantity = cartProvider.getItemQuantity(product.id);
    
    return Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/product/${product.id}');
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: product.primaryImage,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 100,
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 100,
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                    ),
                  ),
                ),
              ),
              
              // Discount badge
              if (hasDiscount)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$discountPercent% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              
              // ADD Button
              Positioned(
                bottom: 6,
                right: 6,
                child: isInCart && quantity > 0
                    ? _buildQuantityControl(product, quantity, accentColor, cartProvider)
                    : _buildAddButton(product, accentColor, cartProvider),
              ),
            ],
          ),
          
          // Product Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weight/Variant
                  if (product.variants.isNotEmpty)
                    Text(
                      product.variants.first.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  
                  // Product Name
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const Spacer(),
                  
                  // Price Row
                  Row(
                    children: [
                      Text(
                        '₹${product.salePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${product.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(ProductModel product, Color accentColor, CartProvider cartProvider) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        cartProvider.addItem(product);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accentColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'ADD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(ProductModel product, int quantity, Color accentColor, CartProvider cartProvider) {
    return Container(
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
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
              HapticFeedback.selectionClick();
              if (quantity > 1) {
                cartProvider.updateQuantity(product.id, quantity - 1);
              } else {
                cartProvider.removeItem(product.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                quantity > 1 ? Icons.remove : Icons.delete_outline,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              cartProvider.updateQuantity(product.id, quantity + 1);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.add,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFreeDeliveryProgress(double subtotal, bool isDark, Color cardColor, Color accentColor) {
    const freeDeliveryThreshold = 499.0;
    final remaining = (freeDeliveryThreshold - subtotal).clamp(0.0, freeDeliveryThreshold);
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
          color: hasFreeDelivery 
              ? Colors.green.shade200 
              : Colors.amber.shade200,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: Colors.white),
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
                              width: MediaQuery.of(context).size.width * 0.55 * progress,
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
                              left: (MediaQuery.of(context).size.width * 0.55 * progress) - 4,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.orange.shade600, width: 2),
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
            color: hasFreeDelivery ? Colors.green.shade200 : Colors.amber.shade200,
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
                    child: Icon(Icons.local_offer_outlined, size: 14, color: accentColor),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  value: shipping > 0 ? '₹${shipping.toStringAsFixed(0)}' : 'FREE',
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
                
                // Tip if added
                if (_selectedTipAmount > 0) ...[
                  const SizedBox(height: 10),
                  _buildBillRow(
                    emoji: '💝',
                    label: 'Delivery partner tip',
                    value: '₹${_selectedTipAmount.toStringAsFixed(0)}',
                    isDark: isDark,
                  ),
                ],
                
                // Wallet discount
                if (_useWalletBalance && pricing['walletDiscount'] != null && pricing['walletDiscount']! > 0) ...[
                  const SizedBox(height: 10),
                  _buildBillRow(
                    emoji: '👛',
                    label: 'Wallet credits used',
                    value: '-₹${pricing['walletDiscount']!.toStringAsFixed(0)}',
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
                    if (_selectedTipAmount > 0)
                      Text(
                        'Includes ₹${_selectedTipAmount.toStringAsFixed(0)} tip',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor.withValues(alpha: 0.9), accentColor],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${(total + _selectedTipAmount).toStringAsFixed(0)}',
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
  Widget _buildDeliveryInstructions(bool isDark, Color cardColor, Color accentColor) {
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                    color: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
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
                                  : (isDark ? Colors.grey[700] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.mic_rounded,
                              size: 18,
                              color: _isRecording 
                                  ? Colors.white 
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
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
                                      : (_isRecording ? 'Recording...' : 'Add voice note'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isRecording 
                                        ? Colors.red.shade500 
                                        : (isDark ? Colors.white : Colors.black87),
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
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                                    colors: [accentColor.withValues(alpha: 0.9), accentColor],
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
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                              onTap: _isRecording ? _stopRecording : _startRecording,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: _isRecording
                                      ? null
                                      : LinearGradient(
                                          colors: [Colors.red.shade400, Colors.red.shade600],
                                        ),
                                  color: _isRecording ? Colors.grey[300] : null,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: _isRecording ? null : [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                  size: 22,
                                  color: _isRecording ? Colors.red.shade600 : Colors.white,
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
                    fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                ? LinearGradient(colors: [accentColor.withValues(alpha: 0.15), accentColor.withValues(alpha: 0.08)])
                : null,
            color: isSelected ? null : (isDark ? const Color(0xFF252525) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
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
                    color: isSelected ? accentColor : (isDark ? Colors.grey[400] : Colors.grey[700]),
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
        final path = '${dir.path}/delivery_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
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
      {'name': 'Razorpay', 'icon': Icons.payment_rounded, 'subtitle': 'UPI, Cards, Wallets & More'},
      {'name': 'COD', 'icon': Icons.local_shipping_rounded, 'subtitle': 'Cash on Delivery'},
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
                  child: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
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
                      : (isDark ? const Color(0xFF252525) : const Color(0xFFF8F8F8)),
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
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        method['icon'] as IconData,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method['name'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            method['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
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
        await _createOrderInFirestore(address: address, paymentStatus: 'pending');
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
        );
      }
    } catch (e) {
      debugPrint('Order placement error: $e');
      _showSnackBar('Error: ${e.toString()}', isError: true);
      setState(() => _isPlacingOrder = false);
    }
  }

  void _handlePaymentSuccess(String paymentId, String? orderId, String? signature, AddressModel address) async {
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
      final walletProvider = context.read<WalletProvider>();

      final subtotal = cartProvider.subtotal;
      final couponDiscount = couponProvider.calculateDiscount(
        orderAmount: subtotal,
        items: cartProvider.items,
      );
      
      double walletDiscount = 0;
      if (_useWalletBalance) {
        final available = walletProvider.balance;
        final remaining = subtotal - couponDiscount;
        walletDiscount = available > remaining ? remaining : available;
      }
      
      final total = subtotal - couponDiscount - walletDiscount;

      final orderId = OrderModel.generateOrderId();

      final order = OrderModel(
        id: orderId,
        userId: userId,
        orderNumber: OrderModel.generateOrderNumber(),
        items: cartProvider.items,
        deliveryAddress: address,
        subtotal: subtotal,
        discount: couponDiscount,
        deliveryCharge: 0.0,
        tax: 0.0,
        total: total,
        paymentMethod: _selectedPaymentMethod ?? 'cod',
        paymentStatus: paymentStatus,
        orderStatus: 'pending',
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
        couponCode: couponProvider.appliedCoupon?.code,
        createdAt: DateTime.now(),
      );

      final OrderService _orderService = OrderService();
      final createdOrderId = await _orderService.createOrder(order);

      if (createdOrderId == null) {
        throw Exception('Failed to create order on server');
      }

      // Deduct wallet balance if used
      if (_useWalletBalance && walletDiscount > 0) {
        await walletProvider.useWalletForOrder(
          orderId: orderId,
          amount: walletDiscount,
          coinsUsed: 0, // We're using balance, not coins
        );
      }

      await cartProvider.clearCart();
      couponProvider.removeCoupon();

      if (!mounted) return;

      setState(() => _isPlacingOrder = false);
      HapticFeedback.heavyImpact();
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
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
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  // --- Wallet Section ---
  Widget _buildWalletSection(bool isDark, Color cardColor, Color accentColor) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final walletBalance = walletProvider.balance;
        
        if (walletBalance <= 0) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [const Color(0xFF1E3A2F), const Color(0xFF152A22)]
                  : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.green.shade300.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.green.shade200.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('👛', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet Credits',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Available: ₹${walletBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Toggle switch
                    Transform.scale(
                      scale: 0.85,
                      child: Switch.adaptive(
                        value: _useWalletBalance,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _useWalletBalance = value);
                        },
                        activeColor: Colors.green.shade600,
                        activeTrackColor: Colors.green.shade200,
                      ),
                    ),
                  ],
                ),
              ),
              // Info row
              if (_useWalletBalance)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Wallet credits will be applied at checkout',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- Tip Section ---
  Widget _buildTipSection(bool isDark, Color cardColor, Color accentColor) {
    final tipOptions = [20.0, 30.0, 50.0, 0.0]; // 0.0 represents custom
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF3D2E1E), const Color(0xFF2A2117)]
              : [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.shade300.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Premium delivery icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.amber.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🏍️', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tip your delivery partner',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                    Text(
                      '100% goes to your partner 💛',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedTipAmount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${_selectedTipAmount.toInt()} added',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Tip buttons row
          Row(
            children: [
              _buildTipButton('😊', 20, isDark),
              const SizedBox(width: 6),
              _buildTipButton('😄', 30, isDark),
              const SizedBox(width: 6),
              _buildTipButton('🤩', 50, isDark),
              const SizedBox(width: 6),
              _buildCustomTipButton(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipButton(String emoji, double amount, bool isDark) {
    final isSelected = _selectedTipAmount == amount;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedTipAmount = isSelected ? 0 : amount;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600])
                : null,
            color: isSelected ? null : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected 
                  ? Colors.green.shade400 
                  : (isDark ? Colors.grey[600]! : Colors.grey.shade300),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                '₹${amount.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipButton(bool isDark) {
    final isCustomSelected = _selectedTipAmount > 0 && 
        _selectedTipAmount != 20 && 
        _selectedTipAmount != 30 && 
        _selectedTipAmount != 50;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _showCustomTipDialog(isDark);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isCustomSelected 
                ? LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600])
                : null,
            color: isCustomSelected ? null : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCustomSelected 
                  ? Colors.green.shade400 
                  : (isDark ? Colors.grey[600]! : Colors.grey.shade300),
              width: isCustomSelected ? 2 : 1,
            ),
            boxShadow: isCustomSelected ? [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✏️', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                isCustomSelected ? '₹${_selectedTipAmount.toInt()}' : 'Other',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCustomSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomTipDialog(bool isDark) {
    final controller = TextEditingController();
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade600],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('💰', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Enter custom tip',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Input field
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              
              // Quick amounts
              Row(
                children: [
                  _buildQuickTipChip('₹10', 10, controller, isDark),
                  const SizedBox(width: 8),
                  _buildQuickTipChip('₹40', 40, controller, isDark),
                  const SizedBox(width: 8),
                  _buildQuickTipChip('₹100', 100, controller, isDark),
                ],
              ),
              const SizedBox(height: 20),
              
              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(controller.text) ?? 0;
                    Navigator.pop(context);
                    if (amount > 0) {
                      setState(() {
                        _selectedTipAmount = amount;
                      });
                      HapticFeedback.mediumImpact();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Add tip',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTipChip(String label, double amount, TextEditingController controller, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        controller.text = amount.toInt().toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // --- Sticky Bottom Bar ---
  Widget _buildBlinkitBottomBar(double total, bool isDark, Color accentColor, Color cardColor) {
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, _) {
        final address = addressProvider.hasAddresses 
            ? (addressProvider.selectedAddress ?? addressProvider.defaultAddress)
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
                    // TODO: Open address selection bottom sheet
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252525) : const Color(0xFFF8F8F8),
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
                              colors: [accentColor.withValues(alpha: 0.9), accentColor],
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
                                  Text(
                                    hasAddress ? 'Delivering to ${address.addressType ?? 'Home'}' : 'Add delivery address',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ],
                              ),
                              if (hasAddress)
                                Text(
                                  '${address.addressLine1}${address.landmark != null ? ', ${address.landmark}' : ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            color: isDark ? const Color(0xFF252525) : Colors.white,
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
                        onPressed: _isPlacingOrder || !hasAddress
                            ? null
                            : () {
                                _placeOrder(total, address!);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: accentColor.withValues(alpha: 0.5),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _selectedPaymentMethod == 'COD' ? 'Place Order' : 'Pay',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
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
    final shippingFee = subtotal >= freeDeliveryThreshold ? 0.0 : standardDeliveryFee;
    
    final expressDeliveryFee = _expressDeliverySelected ? (shippingInfo.expressDeliveryFee ?? 0.0) : 0.0;
    
    // Calculate wallet discount
    double walletDiscount = 0;
    if (_useWalletBalance) {
      try {
        final walletProvider = context.read<WalletProvider>();
        final availableBalance = walletProvider.balance;
        final remainingAmount = subtotal - couponDiscount + shippingFee + expressDeliveryFee;
        walletDiscount = availableBalance > remainingAmount ? remainingAmount : availableBalance;
      } catch (e) {
        debugPrint('Wallet provider not available: $e');
      }
    }
    
    final finalTotal = subtotal - couponDiscount + shippingFee + expressDeliveryFee - walletDiscount;

    return {
      'subtotal': subtotal,
      'couponDiscount': couponDiscount,
      'bogoValue': bogoValue,
      'flatDiscount': flatDiscount,
      'percentageDiscount': percentageDiscount,
      'shippingFee': shippingFee,
      'expressDeliveryFee': expressDeliveryFee,
      'walletDiscount': walletDiscount,
      'finalTotal': finalTotal < 0 ? 0 : finalTotal,
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
                '₹${cartProvider.subtotal.toStringAsFixed(2)}',
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
                          '+₹${shippingInfo.expressDeliveryFee?.toStringAsFixed(2) ?? '0.00'}',
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
                  '₹${fee?.toStringAsFixed(2) ?? '0.00'}',
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
                    '₹${couponDiscount.toStringAsFixed(2)}',
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
          '₹${value.abs().toStringAsFixed(2)}',
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
            Text('Continue to Checkout • ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
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
