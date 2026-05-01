import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'widgets/checkout_steps.dart';
import 'order_success_screen.dart';

// Web-specific Razorpay import
import '../../../services/razorpay_web.dart'
    if (dart.library.io) '../../../services/razorpay_stub.dart';

class PaymentMethodScreen extends StatefulWidget {
  final AddressModel selectedAddress;
  final double total;
  final double deliveryCharge;
  final double tax;

  const PaymentMethodScreen({
    Key? key,
    required this.selectedAddress,
    required this.total,
    this.deliveryCharge = 0.0,
    this.tax = 0.0,
  }) : super(key: key);

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  RazorpayCustomService? _razorpayService;
  RazorpayWebService? _razorpayWebService;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'razorpay';

  // Wallet state
  bool _useWalletBalance = false;
  bool _useCoins = false;
  int _coinsToUse = 0;

  // âœ… NEW: Order notes / special instructions
  final TextEditingController _notesController = TextEditingController();

  // Checkout Step & Subscription state
  int _currentStep = 2; // Step 2: Slots, Step 3: Payment
  String _orderType = 'One Time';
  String _autoFrequency = 'Daily';
  DeliveryTimeSlotModel? _selectedSlot;

  final DeliverySlotService _deliverySlotService = DeliverySlotService();
  List<DeliveryTimeSlotModel> _deliverySlots = [];
  bool _slotsLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePaymentServices();
    _loadDeliverySlots();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _applyCartSubscriptionPrefs());
  }

  Future<void> _loadDeliverySlots() async {
    final list = await _deliverySlotService.fetchSlots();
    if (!mounted) return;
    setState(() {
      _deliverySlots = list.where((s) => s.active).toList();
      _slotsLoading = false;
    });
  }

  void _applyCartSubscriptionPrefs() {
    if (!mounted) return;
    final cart = context.read<CartProvider>();
    final ot = cart.checkoutOrderType;
    final fr = cart.checkoutAutoFrequency;
    if (ot != null) {
      setState(() {
        _orderType = ot;
        if (fr != null) _autoFrequency = fr;
      });
    }
  }

  bool _selectedSlotIsValidNow() {
    final s = _selectedSlot;
    if (s == null) return false;
    return s.containsClock(DateTime.now());
  }

  void _initializePaymentServices() {
    if (kIsWeb) {
      // Initialize web Razorpay
      _razorpayWebService = RazorpayWebService();
      _razorpayWebService!.initialize(
        onSuccess: (paymentId, orderId, signature) {
          _createOrder(
            razorpayPaymentId: paymentId,
            razorpayOrderId: orderId,
            razorpaySignature: signature,
          );
        },
        onFailure: (error) {
          setState(() => _isProcessing = false);
          _showSnackBar('Payment Failed: $error', isError: true);
        },
      );
      return;
    }

    _razorpayService = RazorpayCustomService();

    _razorpayService!.initialize(
      onSuccess: (paymentId, orderId, signature) {
        // Create order with the payment details directly
        _createOrder(
          razorpayPaymentId: paymentId,
          razorpayOrderId: orderId,
          razorpaySignature: signature,
        );
      },
      onFailure: (error) {
        setState(() => _isProcessing = false);
        _showSnackBar('Payment Failed: $error', isError: true);
      },
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('âœ… Payment successful: ${response.paymentId}');
    _createOrder(
      razorpayPaymentId: response.paymentId,
      razorpayOrderId: response.orderId,
      razorpaySignature: response.signature,
    );
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (!mounted) return;

    setState(() => _isProcessing = false);
    _showSnackBar(
      'Payment Failed: ${response.message ?? "Unknown error"}',
      isError: true,
    );
  }

  Future<void> _createOrder({
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    setState(() => _isProcessing = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      if (_selectedSlot != null && !_selectedSlotIsValidNow()) {
        throw Exception('Slot not available');
      }

      final cartProvider = context.read<CartProvider>();
      final couponProvider = context.read<CouponProvider>();

      // Calculate discount properly
      final discount = couponProvider.calculateDiscount(
        orderAmount: cartProvider.subtotal,
        items: cartProvider.items,
      );

      final createdOrders = await _createSellerScopedOrders(
        userId: userId,
        cartProvider: cartProvider,
        couponCode: couponProvider.appliedCoupon?.code,
        discount: discount,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );

      final order = createdOrders.first;

      await cartProvider.clearCart();
      couponProvider.removeCoupon();
      cartProvider.clearCheckoutSubscriptionIntent();

      if (!mounted) return;

      HapticFeedback.heavyImpact();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
        (route) => route.isFirst,
      );
    } catch (e) {
      debugPrint('âŒ Order creation error: $e');
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<List<OrderModel>> _createSellerScopedOrders({
    required String userId,
    required CartProvider cartProvider,
    required double discount,
    required String? couponCode,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    if (cartProvider.items.isEmpty) {
      throw Exception('Cart is empty');
    }

    final db = FirebaseFirestore.instance;
    final sellerGroups = <String, List<CartItemModel>>{};

    for (final item in cartProvider.items) {
      final sellerId = await _resolveSellerIdForItem(item);
      final key = sellerId ?? '';
      sellerGroups.putIfAbsent(key, () => <CartItemModel>[]).add(item);
    }

    final batch = db.batch();
    final orders = <OrderModel>[];
    final baseOrderNumber = OrderModel.generateOrderNumber();
    final totalSubtotal = cartProvider.subtotal;
    final deliverySlotLabel = _selectedSlot != null
        ? '${_selectedSlot!.label} (${_selectedSlot!.start}-${_selectedSlot!.end})'
        : null;

    var index = 0;
    for (final entry in sellerGroups.entries) {
      index++;
      final sellerId = entry.key.isEmpty ? null : entry.key;
      final groupItems = entry.value;
      final groupSubtotal = groupItems.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      final ratio = totalSubtotal > 0
          ? groupSubtotal / totalSubtotal
          : 1 / sellerGroups.length;
      final groupDiscount = _roundMoney(discount * ratio);
      final groupDeliveryCharge = _roundMoney(widget.deliveryCharge * ratio);
      final groupTax = _roundMoney(widget.tax * ratio);
      final groupTotal = _roundMoney(
        groupSubtotal - groupDiscount + groupDeliveryCharge + groupTax,
      );

      final orderRef = db.collection('orders').doc();
      final orderNumber = sellerGroups.length == 1
          ? baseOrderNumber
          : '$baseOrderNumber-$index';

      final order = OrderModel(
        id: orderRef.id,
        userId: userId,
        sellerId: sellerId,
        orderNumber: orderNumber,
        items: groupItems,
        deliveryAddress: widget.selectedAddress,
        subtotal: groupSubtotal,
        discount: groupDiscount,
        deliveryCharge: groupDeliveryCharge,
        tax: groupTax,
        total: groupTotal,
        paymentMethod: _selectedPaymentMethod,
        paymentStatus: _selectedPaymentMethod == 'cod' ? 'pending' : 'paid',
        orderStatus: 'pending',
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
        couponCode: couponCode,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: DateTime.now(),
        orderType: _orderType,
        autoFrequency: _orderType == 'Auto Delivery' ? _autoFrequency : null,
        deliverySlot: deliverySlotLabel,
        deliveryVerificationCode: OrderModel.generateVerificationCode(),
      );

      batch.set(orderRef, order.toMap());
      batch.set(orderRef.collection('timeline').doc(), {
        'status': 'pending',
        'title': 'Order Placed',
        'description': 'Your order has been placed successfully',
        'timestamp': FieldValue.serverTimestamp(),
      });
      orders.add(order);
    }

    if (_orderType == 'Auto Delivery') {
      final nextRunDate = DateTime.now().add(const Duration(days: 1));
      for (final item in cartProvider.items) {
        final subscriptionRef = db.collection('subscriptions').doc();
        batch.set(subscriptionRef, {
          'userId': userId,
          'userName': widget.selectedAddress.name,
          'userPhone': widget.selectedAddress.phone,
          'productId': item.productId,
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'productImage': item.productImage,
          'unit': item.variant ?? 'nos',
          'address': widget.selectedAddress.addressLine1,
          'location': {
            'lat': widget.selectedAddress.latitude,
            'lng': widget.selectedAddress.longitude,
          },
          'frequency': _autoFrequency.toLowerCase(),
          'nextRunDate': Timestamp.fromDate(nextRunDate),
          'deliverySlot': deliverySlotLabel ?? '',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'paymentMethod': _selectedPaymentMethod,
        });
      }
    }

    await batch.commit();
    return orders;
  }

  Future<String?> _resolveSellerIdForItem(CartItemModel item) async {
    try {
      final productId = item.productId.trim();
      if (productId.isEmpty) return null;

      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      final sellerId = productDoc.data()?['sellerId']?.toString().trim();
      return sellerId != null && sellerId.isNotEmpty ? sellerId : null;
    } catch (e) {
      debugPrint('Could not resolve seller for ${item.productId}: $e');
      return null;
    }
  }

  double _roundMoney(double value) => double.parse(value.toStringAsFixed(2));

  Future<void> _proceedToConfirm() async {
    if (_isProcessing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    HapticFeedback.mediumImpact();

    if (_selectedSlot != null && !_selectedSlotIsValidNow()) {
      _showSnackBar('Slot not available', isError: true);
      return;
    }

    if (_selectedPaymentMethod == 'cod') {
      _createOrder();
      return;
    }

    // Web payment using RazorpayWebService
    if (kIsWeb) {
      setState(() => _isProcessing = true);

      final cartProvider = context.read<CartProvider>();
      final couponProvider = context.read<CouponProvider>();
      final discount = couponProvider.calculateDiscount(
        orderAmount: cartProvider.subtotal,
        items: cartProvider.items,
      );
      final finalTotal =
          cartProvider.subtotal - discount + widget.deliveryCharge + widget.tax;

      _razorpayWebService?.openCheckout(
        amount: finalTotal,
        userName: widget.selectedAddress.name,
        userEmail: user.email ?? 'user@example.com',
        userPhone: widget.selectedAddress.phone,
        description: 'Order Payment',
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Calculate final total with discount
    final cartProvider = context.read<CartProvider>();
    final couponProvider = context.read<CouponProvider>();
    final discount = couponProvider.calculateDiscount(
      orderAmount: cartProvider.subtotal,
      items: cartProvider.items,
    );
    final finalTotal =
        cartProvider.subtotal - discount + widget.deliveryCharge + widget.tax;

    _razorpayService?.openAllPaymentMethods(
      amount: finalTotal,
      userName: widget.selectedAddress.name,
      userEmail: user.email ?? "user@example.com",
      userPhone: widget.selectedAddress.phone,
    );
  }

  Future<void> _openInMaps() async {
    final addr = widget.selectedAddress;

    if (addr.latitude != null && addr.longitude != null) {
      final String googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${addr.latitude},${addr.longitude}';

      final Uri uri = Uri.parse(googleMapsUrl);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not open maps', isError: true);
        }
      } catch (e) {
        debugPrint('Error opening maps: $e');
        _showSnackBar('Error opening maps', isError: true);
      }
    } else {
      _showSnackBar('Location coordinates not available', isError: true);
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
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
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

    final cart = context.watch<CartProvider>();
    final coupon = context.watch<CouponProvider>();
    final walletProvider = context.watch<WalletProvider>();

    // Calculate discount with proper parameters
    final subtotal = cart.subtotal;
    final discount = coupon.calculateDiscount(
      orderAmount: subtotal,
      items: cart.items,
    );
    final total = subtotal - discount + widget.deliveryCharge + widget.tax;

    // Calculate wallet/coins discount
    double walletDiscount = 0;
    if (_useWalletBalance && walletProvider.balance > 0) {
      walletDiscount += walletProvider.balance.clamp(0, total);
    }
    if (_useCoins && _coinsToUse > 0) {
      walletDiscount += _coinsToUse.toDouble();
    }
    final finalAmount = (total - walletDiscount).clamp(0.0, total).toDouble();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark, cardColor),
      body: Column(
        children: [
          CheckoutSteps(currentStep: _currentStep),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildAddressCard(isDark, cardColor, accentColor),
                  const SizedBox(height: 12),
                  if (_currentStep == 2) ...[
                    _buildDeliveryPreferences(isDark, cardColor, accentColor),
                    const SizedBox(height: 80),
                  ] else ...[
                    _buildOrderSummaryCard(
                      subtotal: subtotal,
                      discount: discount,
                      total: total,
                      isDark: isDark,
                      cardColor: cardColor,
                      accentColor: accentColor,
                      coupon: coupon,
                      walletDiscount: walletDiscount,
                      finalAmount: finalAmount,
                    ),
                    const SizedBox(height: 12),
                    _buildWalletSection(isDark, cardColor, accentColor, total),
                    const SizedBox(height: 12),
                    _buildPaymentCard(isDark, cardColor, accentColor),
                    const SizedBox(height: 12),
                    _buildOrderNotesCard(isDark, cardColor, accentColor),
                    const SizedBox(height: 12),
                    _buildSecurityBadge(isDark, accentColor),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          if (_currentStep == 2)
            _buildSlotBottomBar(isDark, accentColor, cardColor)
          else
            _buildBottomBar(finalAmount, isDark, accentColor, cardColor),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color cardColor) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      title: Text(
        'Payment Method',
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
            color:
                isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 16,
          ),
        ),
        onPressed: () {
          if (_currentStep == 3) {
            setState(() => _currentStep = 2);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      centerTitle: true,
    );
  }

  Widget _buildAddressCard(bool isDark, Color cardColor, Color accentColor) {
    final addr = widget.selectedAddress;

    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Delivery Address',
      icon: Icons.location_on_rounded,
      accentColor: accentColor,
      trailing: addr.latitude != null && addr.longitude != null
          ? IconButton(
              onPressed: _openInMaps,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: accentColor,
                  size: 18,
                ),
              ),
              tooltip: 'Open in Maps',
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  addr.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Phone
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                addr.phone,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              height: 1,
            ),
          ),

          // Address Line 1
          _buildAddressRow(
            icon: Icons.home_outlined,
            value: addr.addressLine1,
            isDark: isDark,
          ),

          // Address Line 2 (if exists)
          if (addr.addressLine2.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAddressRow(
              icon: Icons.location_city_outlined,
              value: addr.addressLine2,
              isDark: isDark,
              isSecondary: true,
            ),
          ],

          // Landmark (if exists)
          if (addr.landmark != null && addr.landmark!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAddressRow(
              icon: Icons.place_outlined,
              value: 'Near ${addr.landmark}',
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 12),

          // City, State, Zipcode
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLocationChip(
                icon: Icons.location_city,
                label: addr.city,
                isDark: isDark,
              ),
              _buildLocationChip(
                icon: Icons.map_outlined,
                label: addr.state,
                isDark: isDark,
              ),
              _buildLocationChip(
                icon: Icons.pin_drop_outlined,
                label: addr.zipcode,
                isDark: isDark,
              ),
            ],
          ),

          // Country (if not India)
          if (addr.country.isNotEmpty && addr.country != 'India') ...[
            const SizedBox(height: 8),
            _buildLocationChip(
              icon: Icons.flag_outlined,
              label: addr.country,
              isDark: isDark,
            ),
          ],

          // Address Type Badge (if exists)
          if (addr.addressType != null && addr.addressType!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _getAddressTypeColor(addr.addressType!).withOpacity(0.15),
                border: Border.all(
                  color:
                      _getAddressTypeColor(addr.addressType!).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getAddressTypeIcon(addr.addressType!),
                    size: 14,
                    color: _getAddressTypeColor(addr.addressType!),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    addr.addressType!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _getAddressTypeColor(addr.addressType!),
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

  Widget _buildAddressRow({
    required IconData icon,
    required String value,
    required bool isDark,
    bool isSecondary = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isSecondary)
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        if (!isSecondary) const SizedBox(width: 8),
        if (isSecondary) const SizedBox(width: 24),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryPreferences(
      bool isDark, Color cardColor, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Purchase Type
        _buildCardSection(
          isDark: isDark,
          cardColor: cardColor,
          title: 'Purchase Type',
          icon: FontAwesomeIcons.truck,
          accentColor: accentColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSelectionBox(
                      isSelected: _orderType == 'One Time',
                      label: 'One Time Delivery',
                      isDark: isDark,
                      accentColor: accentColor,
                      onTap: () {
                        setState(() {
                          _orderType = 'One Time';
                          _selectedPaymentMethod = 'razorpay';
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSelectionBox(
                      isSelected: _orderType == 'Auto Delivery',
                      label: 'Subscribe (Auto)',
                      isDark: isDark,
                      accentColor: accentColor,
                      onTap: () {
                        setState(() {
                          _orderType = 'Auto Delivery';
                          _selectedPaymentMethod =
                              'cod'; // Only COD or Weekly for Auto
                        });
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                ],
              ),
              if (_orderType == 'Auto Delivery') ...[
                const SizedBox(height: 16),
                Text(
                  'SUBSCRIPTION FREQUENCY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSelectionBox(
                        isSelected: _autoFrequency == 'Daily',
                        label: 'Daily',
                        isDark: isDark,
                        accentColor: accentColor,
                        onTap: () {
                          setState(() => _autoFrequency = 'Daily');
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSelectionBox(
                        isSelected: _autoFrequency == 'Weekly',
                        label: 'Weekly',
                        isDark: isDark,
                        accentColor: accentColor,
                        onTap: () {
                          setState(() => _autoFrequency = 'Weekly');
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Time Slot (admin-managed in Firestore `settings/delivery`)
        _buildCardSection(
          isDark: isDark,
          cardColor: cardColor,
          title: 'Select Time Slot',
          icon: FontAwesomeIcons.clock,
          accentColor: accentColor,
          child: _slotsLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  children: _deliverySlots.map((slot) {
                    final isSelected = _selectedSlot?.id == slot.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedSlot = slot);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withOpacity(0.08)
                              : (isDark ? Colors.grey[850] : Colors.grey[50]!),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? accentColor
                                : (isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[200]!),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(slot.icon,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? accentColor
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slot.displayTimeRange,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : Colors.grey[400]!,
                                  width: isSelected ? 6 : 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSelectionBox({
    required bool isSelected,
    required String label,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.1)
              : (isDark ? Colors.grey[850] : Colors.grey[50]!),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? accentColor
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotBottomBar(bool isDark, Color accentColor, Color cardColor) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _selectedSlot != null
              ? () {
                  if (!_selectedSlotIsValidNow()) {
                    _showSnackBar('Slot not available', isError: true);
                    return;
                  }
                  setState(() => _currentStep = 3);
                  HapticFeedback.lightImpact();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
          label: const Text(
            'Continue to Payment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAddressTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
      case 'work':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _getAddressTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Colors.blue;
      case 'office':
      case 'work':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  Widget _buildOrderSummaryCard({
    required double subtotal,
    required double discount,
    required double total,
    required bool isDark,
    required Color cardColor,
    required Color accentColor,
    required CouponProvider coupon,
    double walletDiscount = 0,
    double finalAmount = 0,
  }) {
    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Price Details',
      icon: Icons.receipt_long_rounded,
      accentColor: accentColor,
      child: Column(
        children: [
          _priceRow("Subtotal", subtotal, isDark),
          if (discount > 0) ...[
            const SizedBox(height: 10),
            _priceRow("Coupon Discount", -discount, isDark,
                color: Colors.green.shade600),
          ],
          if (walletDiscount > 0) ...[
            const SizedBox(height: 10),
            _priceRow("Wallet/Coins", -walletDiscount, isDark,
                color: Colors.amber.shade700),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              height: 1,
            ),
          ),
          _priceRow(
              "Total Amount", finalAmount > 0 ? finalAmount : total, isDark,
              isTotal: true, color: accentColor),

          // Coupon Applied Badge
          if (coupon.appliedCoupon != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.ticket,
                    size: 12,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${coupon.appliedCoupon!.code} Applied',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Savings Badge
          if (discount > 0 || walletDiscount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.piggyBank,
                    size: 12,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You saved â‚¹${(discount + walletDiscount).toStringAsFixed(2)}!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
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

  Widget _buildWalletSection(
      bool isDark, Color cardColor, Color accentColor, double orderTotal) {
    final walletProvider = context.watch<WalletProvider>();

    final balance = walletProvider.balance;
    final coins = walletProvider.coins;
    final maxCoins = walletProvider.maxCoinsUsableForOrder(orderTotal);
    final isWalletEnabled = walletProvider.isWalletEnabled;
    final isCoinsEnabled = walletProvider.isCoinsEnabled;
    final minOrderForCoins = walletProvider.minOrderForCoins;

    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Pay with Wallet',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: accentColor,
      child: Column(
        children: [
          // Wallet Balance Toggle
          if (isWalletEnabled && balance > 0) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _useWalletBalance = !_useWalletBalance);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _useWalletBalance
                      ? accentColor.withOpacity(0.1)
                      : (isDark ? Colors.grey[850] : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _useWalletBalance
                        ? accentColor
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: _useWalletBalance ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Color(0xFF1E3A5F),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Wallet Balance',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'â‚¹${balance.toStringAsFixed(2)} available',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useWalletBalance,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _useWalletBalance = value);
                      },
                      activeColor: accentColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Coins Section
          if (isCoinsEnabled && coins > 0) ...[
            // Show coins toggle if usable
            if (maxCoins > 0) ...[
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _useCoins = !_useCoins;
                    if (_useCoins) {
                      _coinsToUse = maxCoins;
                    } else {
                      _coinsToUse = 0;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _useCoins
                        ? Colors.amber.withOpacity(0.1)
                        : (isDark ? Colors.grey[850] : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _useCoins
                          ? Colors.amber[700]!
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      width: _useCoins ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.monetization_on,
                              color: Colors.amber[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use Coins',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$coins coins available (max $maxCoins usable)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useCoins,
                            onChanged: (value) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _useCoins = value;
                                if (value) {
                                  _coinsToUse = maxCoins;
                                } else {
                                  _coinsToUse = 0;
                                }
                              });
                            },
                            activeColor: Colors.amber[700],
                          ),
                        ],
                      ),

                      // Coins slider when enabled
                      if (_useCoins && maxCoins > 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '1',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _coinsToUse.toDouble(),
                                min: 1,
                                max: maxCoins.toDouble(),
                                divisions: maxCoins - 1,
                                activeColor: Colors.amber[700],
                                inactiveColor: Colors.amber.withOpacity(0.2),
                                onChanged: (value) {
                                  setState(() => _coinsToUse = value.round());
                                },
                              ),
                            ),
                            Text(
                              '$maxCoins',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Using $_coinsToUse coins = â‚¹$_coinsToUse discount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Show message when coins available but order below minimum
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$coins coins available',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Add â‚¹${(minOrderForCoins - orderTotal).toStringAsFixed(0)} more to use coins (min order: â‚¹${minOrderForCoins.toStringAsFixed(0)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // No balance/coins state
          if (balance <= 0 && coins <= 0)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 40,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No wallet balance or coins available',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earn coins by referring friends!',
                    style: TextStyle(
                      fontSize: 12,
                      color: accentColor,
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

  Widget _buildPaymentCard(bool isDark, Color cardColor, Color accentColor) {
    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Payment Method',
      icon: Icons.payment_rounded,
      accentColor: accentColor,
      child: Column(
        children: [
          if (_orderType != 'Auto Delivery') ...[
            // Online Payment Option (Available on both Web and Mobile)
            GestureDetector(
              onTap: () {
                setState(() => _selectedPaymentMethod = 'razorpay');
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedPaymentMethod == 'razorpay'
                      ? accentColor.withOpacity(0.1)
                      : (isDark ? Colors.grey[850] : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedPaymentMethod == 'razorpay'
                        ? accentColor
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: _selectedPaymentMethod == 'razorpay' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.payment_rounded,
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
                                'Pay Online (Razorpay)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'UPI, Cards, Wallets & More',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedPaymentMethod == 'razorpay'
                                  ? accentColor
                                  : (isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[400]!),
                              width: 2,
                            ),
                            color: _selectedPaymentMethod == 'razorpay'
                                ? accentColor
                                : Colors.transparent,
                          ),
                          child: _selectedPaymentMethod == 'razorpay'
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPaymentBadge(
                            FontAwesomeIcons.solidCreditCard, 'Card', isDark),
                        _buildPaymentBadge(
                            FontAwesomeIcons.mobileScreenButton, 'UPI', isDark),
                        _buildPaymentBadge(
                            FontAwesomeIcons.wallet, 'Wallet', isDark),
                        _buildPaymentBadge(
                            FontAwesomeIcons.buildingColumns, 'Bank', isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Cash on Delivery Option
          GestureDetector(
            onTap: () {
              setState(() => _selectedPaymentMethod = 'cod');
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedPaymentMethod == 'cod'
                    ? accentColor.withOpacity(0.1)
                    : (isDark ? Colors.grey[850] : Colors.grey[50]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedPaymentMethod == 'cod'
                      ? accentColor
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: _selectedPaymentMethod == 'cod' ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.handHoldingDollar,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash on Delivery',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pay when you receive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedPaymentMethod == 'cod'
                            ? accentColor
                            : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                        width: 2,
                      ),
                      color: _selectedPaymentMethod == 'cod'
                          ? accentColor
                          : Colors.transparent,
                    ),
                    child: _selectedPaymentMethod == 'cod'
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Removed: Web-only COD notice (now supports online payments on web too)
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon,
              size: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
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
            child: FaIcon(
              FontAwesomeIcons.shieldHalved,
              color: Colors.green.shade700,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Secure Payments',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Encrypted & protected transactions',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
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
    Widget? trailing,
    bool isSelected = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? accentColor
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: isSelected ? 2 : 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: accentColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String title, double value, bool isDark,
      {Color? color, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            fontSize: isTotal ? 15 : 14,
            color: isDark
                ? (isTotal ? Colors.white : Colors.grey[300])
                : (isTotal ? Colors.black87 : Colors.grey[700]),
          ),
        ),
        Text(
          "â‚¹${value.abs().toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            fontSize: isTotal ? 18 : 14,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
      double total, bool isDark, Color accentColor, Color cardColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top:
              BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _proceedToConfirm,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          backgroundColor: accentColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          disabledBackgroundColor: accentColor.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.black : Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedPaymentMethod == "cod"
                        ? Icons.check_circle_rounded
                        : Icons.lock_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedPaymentMethod == "cod"
                        ? "Place Order â€¢ â‚¹${total.toStringAsFixed(2)}"
                        : "Pay â‚¹${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // âœ… NEW: Order Notes / Special Instructions
  Widget _buildOrderNotesCard(bool isDark, Color cardColor, Color accentColor) {
    return _buildCardSection(
      isDark: isDark,
      cardColor: cardColor,
      title: 'Special Instructions',
      icon: Icons.edit_note_rounded,
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add any special instructions for the seller or delivery partner',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLength: 250,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'E.g., "Leave at the gate", "Extra ripe mangoes please"',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    if (kIsWeb) {
      _razorpayWebService?.dispose();
    } else {
      _razorpayService?.dispose();
    }
    super.dispose();
  }
}
