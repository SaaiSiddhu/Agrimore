// lib/screens/user/orders/order_details_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../models/cart_item_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../models/order_model.dart';
import '../../../models/order_timeline_model.dart';
import '../../../app/themes/app_colors.dart';
import '../../../providers/theme_provider.dart';
import 'order_tracking_screen.dart';
import '../cart/cart_screen.dart';
import '../help/help_screen.dart';

import '../../../providers/order_provider.dart';


class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- Toast ---
  bool _showToast = false;
  String _toastMessage = '';
  IconData _toastIcon = Icons.check_circle;
  Color _toastColor = const Color(0xFF2D7D3C);
  Timer? _toastTimer;
  late AnimationController _toastAnimationController;
  late Animation<Offset> _toastSlideAnimation;
  late Animation<double> _toastFadeAnimation;
  late Animation<double> _toastScaleAnimation;
  // --- End Toast ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isInitialized = true;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // --- Toast Animations ---
    _toastAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _toastSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _toastAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _toastFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.easeOut),
    );

    _toastScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.elasticOut),
    );
    // --- End Toast Animations ---

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.loadOrderById(widget.orderId).then((_) {
        if (mounted) {
          _animationController.forward();
        }
      });
    });

    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == 1) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (orderProvider.selectedOrder != null) {
        orderProvider.loadOrderById(orderProvider.selectedOrder!.id);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _animationController.dispose();
    _toastAnimationController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // SHOW TOAST MESSAGE
  // ============================================
  void _showToastMessage(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    _toastTimer?.cancel();

    setState(() {
      _toastMessage = message;
      _toastIcon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;
      _toastColor = isSuccess ? const Color(0xFF2D7D3C) : Colors.red;
      _showToast = true;
    });

    _toastAnimationController.forward();

    _toastTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _toastAnimationController.reverse().then((_) {
          if (mounted) setState(() => _showToast = false);
        });
      }
    });
  }

  // ============================================
  // REORDER LOGIC
  // ============================================
  Future<void> _handleReorder(OrderModel order, bool isDark) async {
    if (order.items.isEmpty) {
      _showToastMessage('No items to reorder', isSuccess: false);
      return;
    }
    // Always show modal for confirmation
    await _showProductSelectionModal(order.items, isDark);
  }

  Future<void> _showProductSelectionModal(List<CartItemModel> items, bool isDark) async {
    final selectedItems = <int>{};
    for (int i = 0; i < items.length; i++) {
      selectedItems.add(i);
    }

    final result = await showModalBottomSheet<List<CartItemModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductSelectionModal(
        items: items,
        initialSelection: selectedItems,
        isDark: isDark,
      ),
    );

    if (result != null && result.isNotEmpty) {
      _addToCartAndNavigate(result);
    }
  }

  void _addToCartAndNavigate(List<CartItemModel> items) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    cartProvider.addOrderItems(items).then((success) {
      if (success) {
        _showToastMessage('✅ Added ${items.length} item${items.length > 1 ? 's' : ''} to cart');

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          }
        });
      } else {
        _showToastMessage('❌ Failed: ${cartProvider.error ?? 'Unknown error'}', isSuccess: false);
      }
    });
  }
  // --- End Reorder Logic ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Stack(
        children: [
          Consumer<OrderProvider>(
            builder: (context, orderProvider, child) {
              if (orderProvider.isLoading && orderProvider.selectedOrder == null) {
                return _buildLoadingState(isDark);
              }

              if (orderProvider.selectedOrder == null) {
                return _buildErrorState(isDark);
              }

              final order = orderProvider.selectedOrder!;

              return Column(
                children: [
                  _buildHeader(isDark, order.orderNumber),
                  if (_isInitialized)
                    _buildTabBar(isDark, accentColor),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _isInitialized
                            ? TabBarView(
                                controller: _tabController,
                                children: [
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    child: _buildItemsTabContent(order, isDark),
                                  ),
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    child: _buildTrackingTabContent(
                                      order,
                                      orderProvider.selectedOrderTimeline ?? [],
                                      isDark,
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    child: _buildPaymentTabContent(order, isDark),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // ============================================
          // TOAST NOTIFICATION
          // ============================================
          if (_showToast)
            SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _toastSlideAnimation,
                child: FadeTransition(
                  opacity: _toastFadeAnimation,
                  child: ScaleTransition(
                    scale: _toastScaleAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_toastColor, _toastColor.withOpacity(0.9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _toastColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_toastIcon, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _toastMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, String orderNumber) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16 + topPadding, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D3A2D),
                  const Color(0xFF3A4D3A),
                ]
              : [
                  const Color(0xFF2D7D3C),
                  const Color(0xFF3DA34E),
                  const Color(0xFF4DB85F),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order #$orderNumber',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // ✅ FIXED: Link to Help Screen and removed const
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HelpScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // ✅ FIXED: Moved color inside decoration
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1
          )
        )
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: accentColor,
        indicatorWeight: 3,
        labelColor: accentColor,
        unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey[500],
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        tabs: const [
          Tab(text: 'Items'),
          Tab(text: 'Tracking'),
          Tab(text: 'Payment'),
        ],
      ),
    );
  }

  Widget _buildItemsTabContent(OrderModel order, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Column(
      children: [
        _buildCardSection(
          title: 'Order Summary',
          icon: Icons.list_alt_rounded,
          isDark: isDark,
          child: _buildOrderStatusOverview(order, isDark),
        ),
        _buildCardSection(
          title: 'Items (${order.items.length})',
          icon: Icons.shopping_bag_outlined,
          isDark: isDark,
          child: Column(
            children: [
              ...order.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < order.items.length - 1 ? 12 : 0,
                  ),
                  child: _buildEnhancedProductItem(item, isDark),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _handleReorder(order, isDark),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Reorder Items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderStatusOverview(OrderModel order, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87
                  ),
                ),
                const SizedBox(height: 4),
                 GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: order.orderNumber));
                    _showToastMessage('✅ Order ID copied to clipboard');
                  },
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 13, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'Copy ID',
                        style: TextStyle(
                          fontSize: 11,
                          color: accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildEnhancedStatusBadge(order.orderStatus),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoItem(
              'Ordered On',
              DateFormat('MMM dd, yyyy').format(order.createdAt),
              Icons.calendar_today_outlined,
              isDark
            ),
            _buildInfoItem(
              'Total Items',
              '${order.items.length} ${order.items.length > 1 ? 'items' : 'item'}',
              Icons.inventory_2_outlined,
              isDark
            ),
            if (order.deliveryDate != null)
              _buildInfoItem(
                'Expected By',
                DateFormat('MMM dd').format(order.deliveryDate!),
                Icons.local_shipping_outlined,
                isDark
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: accentColor),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEnhancedProductItem(CartItemModel item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3C3C3C) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            child: item.productImage.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.productImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.shopping_bag_outlined,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        size: 40,
                      ),
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 40,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF424242) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Qty: ${item.quantity}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[200] : Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildTrackingTabContent(
      OrderModel order, List<OrderTimelineModel> timelineData, bool isDark) {
    final timeline = timelineData.isNotEmpty
        ? timelineData
        : _generateTimelineEvents(order);

    return Column(
      children: [
        _buildCardSection(
          title: 'Delivery Address',
          icon: Icons.location_on_rounded,
          isDark: isDark,
          child: _buildDeliveryAddressContent(order, isDark),
        ),
        _buildCardSection(
          title: 'Order Timeline',
          icon: Icons.timeline_rounded,
          isDark: isDark,
          child: _buildAdvancedTimeline(order, timeline, isDark),
        ),
        _buildCardSection(
          title: 'Track Order',
          icon: Icons.map_outlined,
          isDark: isDark,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingScreen(order: order),
                  ),
                );
              },
              icon: const Icon(Icons.track_changes_rounded, size: 18),
              label: const Text('Track Order Live'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAddressContent(OrderModel order, bool isDark) {
    final address = order.deliveryAddress;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on_rounded,
              color: accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address.fullAddress,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '📞 ${address.phone}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<OrderTimelineModel> _generateTimelineEvents(OrderModel order) {
    final timeline = <OrderTimelineModel>[];
    final baseTime = order.createdAt;

    timeline.add(OrderTimelineModel(
      status: OrderStatus.pending,
      title: 'Order Placed',
      description: 'Your order has been confirmed',
      timestamp: baseTime,
      location: 'Warehouse',
    ));

    if (order.orderStatus.toLowerCase() != 'pending') {
      timeline.add(OrderTimelineModel(
        status: OrderStatus.confirmed,
        title: 'Order Confirmed',
        description: 'Your order is confirmed and being prepared',
        timestamp: baseTime.add(const Duration(hours: 2)),
        location: 'Warehouse',
      ));
    }

    if (['processing', 'shipped', 'outfordelivery', 'delivered']
        .contains(order.orderStatus.toLowerCase())) {
      timeline.add(OrderTimelineModel(
        status: OrderStatus.processing,
        title: 'Processing',
        description: 'Your order is being packed and prepared for shipment',
        timestamp: baseTime.add(const Duration(hours: 4)),
        location: 'Warehouse',
      ));
    }

    if (['shipped', 'outfordelivery', 'delivered']
        .contains(order.orderStatus.toLowerCase())) {
      timeline.add(OrderTimelineModel(
        status: OrderStatus.shipped,
        title: 'Shipped',
        description: 'Your order has been shipped and is on the way',
        timestamp: baseTime.add(const Duration(hours: 8)),
        location: 'In Transit',
      ));
    }

    if (['outfordelivery', 'delivered'].contains(order.orderStatus.toLowerCase())) {
      timeline.add(OrderTimelineModel(
        status: OrderStatus.outForDelivery,
        title: 'Out for Delivery',
        description: 'Your order is out for delivery',
        timestamp: baseTime.add(const Duration(hours: 12)),
        location: 'On the way',
      ));
    }

    if (order.orderStatus.toLowerCase() == 'delivered') {
      timeline.add(OrderTimelineModel(
        status: OrderStatus.delivered,
        title: 'Delivered',
        description: 'Your order has been successfully delivered',
        timestamp: order.deliveryDate ?? DateTime.now(),
        location: 'Delivered at home',
      ));
    }

    return timeline;
  }

  Widget _buildAdvancedTimeline(
      OrderModel order, List<OrderTimelineModel> timeline, bool isDark) {
    
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Column(
      children: List.generate(timeline.length, (index) {
        final event = timeline[index];
        final isLast = index == timeline.length - 1;
        final isCompleted = _isEventCompleted(order, event.status);

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? accentColor
                          : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? accentColor
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 2,
                      ),
                      boxShadow: isCompleted
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      _getTimelineIcon(event.status),
                      color: isCompleted
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      size: 20,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted
                          ? accentColor.withOpacity(0.3)
                          : (isDark ? Colors.grey[700] : Colors.grey[300]),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isCompleted
                              ? (isDark ? accentColor : Colors.black87)
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (event.description.isNotEmpty)
                        Text(
                          event.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(event.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if ((event.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: accentColor.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 13, color: accentColor),
                              const SizedBox(width: 5),
                              Text(
                                event.location ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
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
            ],
          ),
        );
      }),
    );
  }

  bool _isEventCompleted(OrderModel order, OrderStatus status) {
    final orderStatus = order.orderStatus.toLowerCase();
    switch (status) {
      case OrderStatus.pending:
        return true;
      case OrderStatus.confirmed:
        return orderStatus != 'pending';
      case OrderStatus.processing:
        return ['processing', 'shipped', 'outfordelivery', 'delivered']
            .contains(orderStatus);
      case OrderStatus.shipped:
        return ['shipped', 'outfordelivery', 'delivered']
            .contains(orderStatus);
      case OrderStatus.outForDelivery:
        return ['outfordelivery', 'delivered'].contains(orderStatus);
      case OrderStatus.delivered:
        return orderStatus == 'delivered';
      case OrderStatus.cancelled:
        return orderStatus == 'cancelled';
      case OrderStatus.returned:
        return orderStatus == 'returned';
      case OrderStatus.refunded:
        return orderStatus == 'refunded';
    }
  }

  IconData _getTimelineIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.shopping_bag_outlined;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.processing:
        return Icons.autorenew_rounded;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      // ✅ FIXED: Corrected typo from OrderS to OrderStatus
      case OrderStatus.outForDelivery:
        return Icons.two_wheeler_rounded;
      case OrderStatus.delivered:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
      case OrderStatus.returned:
        return Icons.undo_rounded;
      case OrderStatus.refunded:
        return Icons.currency_rupee_rounded;
    }
  }

  Widget _buildPaymentTabContent(OrderModel order, bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    // ✅ FIXED: Logic for "Paid" on Delivery
    final bool isDelivered = order.orderStatus.toLowerCase() == 'delivered';
    final bool isPaid = order.paymentStatus.toLowerCase() == 'paid' || isDelivered;
    final String paymentStatus = isPaid ? 'PAID' : order.paymentStatus.toUpperCase();
    final Color paymentStatusColor = isPaid ? Colors.green[600]! : Colors.orange[600]!;
    final Color paymentStatusBgColor = isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1);
    final Color paymentStatusBorderColor = isPaid ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3);
    final IconData paymentStatusIcon = isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded;

    // ✅ FIXED: 1-Hour Cancel Window
    final bool canCancel = order.orderStatus.toLowerCase() != 'cancelled' &&
                           order.orderStatus.toLowerCase() != 'delivered' &&
                           DateTime.now().difference(order.createdAt).inHours < 1;

    return Column(
      children: [
        _buildCardSection(
          title: 'Price Breakdown',
          icon: Icons.price_check_rounded,
          isDark: isDark,
          child: Column(
            children: [
              _buildPriceDetailRow('Subtotal', order.subtotal, isDark),
              const SizedBox(height: 10),
              _buildPriceDetailRow('Delivery Charge', order.deliveryCharge, isDark),
              const SizedBox(height: 10),
              _buildPriceDetailRow('Tax', order.tax, isDark),
              if (order.discount > 0) ...[
                const SizedBox(height: 10),
                _buildPriceDetailRow('Discount', -order.discount, isDark,
                    isDiscount: true),
              ],
              if (order.couponCode != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.discount_rounded,
                          color: Colors.green[700], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Coupon Applied: ${order.couponCode}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '₹${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildCardSection(
          title: 'Payment Method',
          icon: Icons.payment_rounded,
          isDark: isDark,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getPaymentIcon(order.paymentMethod),
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPaymentMethodDisplay(order.paymentMethod),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status: $paymentStatus',
                      style: TextStyle(
                        fontSize: 12,
                        color: paymentStatusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: paymentStatusBgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: paymentStatusBorderColor,
                  ),
                ),
                child: Icon(
                  paymentStatusIcon,
                  color: paymentStatusColor,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        // ✅ FIXED: Cancel button logic
        if (canCancel)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(order, isDark),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Order (1 Hour Window)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark
  }) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
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
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : Colors.black87
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPriceDetailRow(String label, double amount, bool isDark,
      {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        Text(
          '${isDiscount ? '- ' : ''}₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDiscount ? Colors.green[600] : (isDark ? Colors.white70 : Colors.black87),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedStatusBadge(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: config['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: config['color'].withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'], size: 14, color: config['color']),
          const SizedBox(width: 6),
          Text(
            config['label'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: config['color'],
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'label': 'Pending',
          'color': const Color(0xFFF97316),
          'icon': Icons.schedule_rounded,
        };
      case 'confirmed':
        return {
          'label': 'Confirmed',
          'color': const Color(0xFF3B82F6),
          'icon': Icons.check_circle_outline_rounded,
        };
      case 'processing':
        return {
          'label': 'Processing',
          'color': const Color(0xFFA855F7),
          'icon': Icons.autorenew_rounded,
        };
      case 'shipped':
        return {
          'label': 'Shipped',
          'color': const Color(0xFF6366F1),
          'icon': Icons.local_shipping_outlined,
        };
      case 'outfordelivery':
        return {
          'label': 'Out for Delivery',
          'color': const Color(0xFF8B5CF6),
          'icon': Icons.two_wheeler_rounded,
        };
      case 'delivered':
        return {
          'label': 'Delivered',
          'color': const Color(0xFF10B981),
          'icon': Icons.check_circle_rounded,
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': const Color(0xFFEF4444),
          'icon': Icons.cancel_outlined,
        };
      case 'returned':
        return {
          'label': 'Returned',
          'color': const Color(0xFFEC4899),
          'icon': Icons.undo_rounded,
        };
      case 'refunded':
        return {
          'label': 'Refunded',
          'color': const Color(0xFF06B6D4),
          'icon': Icons.currency_rupee_rounded,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline_rounded,
        };
    }
  }

  String _getPaymentMethodDisplay(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'upi':
        return 'UPI Payment';
      case 'card':
        return 'Card Payment';
      case 'netbanking':
        return 'Net Banking';
      default:
        return method.toUpperCase();
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return Icons.local_atm_rounded;
      case 'upi':
        return Icons.account_balance_wallet_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'netbanking':
        return Icons.account_balance_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  void _showCancelDialog(OrderModel order, bool isDark) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ HEADER
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 30,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cancel Order?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Are you sure you want to cancel this order?',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                     const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Reason for cancellation',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppColors.primaryLight : AppColors.primary)
                        ),
                        prefixIcon: Icon(Icons.info_outline_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              // ✅ ACTIONS
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Go Back',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                             _showToastMessage('⚠️ Please provide a reason', isSuccess: false);
                            return;
                          }
                          Navigator.pop(context);
                          final success = await Provider.of<OrderProvider>(context,
                                  listen: false)
                              .cancelOrder(order.id, reason);
                          if (success && mounted) {
                            _showToastMessage('✅ Order cancelled successfully');
                            Navigator.pop(context);
                          } else {
                            _showToastMessage('❌ Failed to cancel order', isSuccess: false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel Order',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Order Details...',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 50,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Order Not Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This order could not be loaded.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// This delegate is correctly implemented and does not need theme changes.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final Widget child;

  _TabBarDelegate({
    required this.tabController,
    required this.child,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.tabController != tabController ||
        oldDelegate.child != child;
  }
}

// ✅✅✅ START: Copied from orders_screen.dart for Reorder Functionality ✅✅✅

// ✅ ENHANCED THEME-AWARE PRODUCT SELECTION MODAL
class _ProductSelectionModal extends StatefulWidget {
  final List<CartItemModel> items;
  final Set<int> initialSelection;
  final bool isDark;

  const _ProductSelectionModal({
    required this.items,
    required this.initialSelection,
    required this.isDark,
  });

  @override
  State<_ProductSelectionModal> createState() => _ProductSelectionModalState();
}

class _ProductSelectionModalState extends State<_ProductSelectionModal> {
  late Set<int> selectedItems;
  double _totalPrice = 0;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    selectedItems = Set.from(widget.initialSelection);
    _calculateTotals();
  }

  void _calculateTotals() {
    _totalPrice = 0;
    _totalItems = 0;
    for (int i in selectedItems) {
      final item = widget.items[i];
      _totalPrice += (item.price) * (item.quantity);
      _totalItems += (item.quantity as num).toInt();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isDark ? AppColors.primaryLight : AppColors.primary;
    
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Items to Reorder',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: widget.isDark ? Colors.white : Colors.grey[900],
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${selectedItems.length} of ${widget.items.length} items',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: widget.isDark ? Colors.grey[800] : Colors.grey[200], height: 1),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = selectedItems.contains(index);

                    return _ProductSelectionItem(
                      item: item,
                      isSelected: isSelected,
                      isDark: widget.isDark,
                      accentColor: accentColor,
                      onToggle: () {
                        setState(() {
                          if (isSelected) {
                            selectedItems.remove(index);
                          } else {
                            selectedItems.add(index);
                          }
                          _calculateTotals();
                        });
                      },
                    );
                  },
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  border: Border(
                    top: BorderSide(color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5)
                    )
                  ]
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  // This padding respects the keyboard when it slides up
                  16 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withOpacity(0.15),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₹${_totalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              '$_totalItems items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark ? const Color(0xFF121212) : Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(
                                color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedItems.isEmpty
                                ? null
                                : () {
                                    final selected = selectedItems
                                        .map((i) => widget.items[i])
                                        .toList();
                                    Navigator.pop(context, selected);
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14.5),
                              backgroundColor: accentColor,
                              foregroundColor: widget.isDark ? const Color(0xFF121212) : Colors.white,
                              disabledBackgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                              shadowColor: accentColor.withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_checkout_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add to Cart',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
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
            ],
          ),
        );
      },
    );
  }
}

class _ProductSelectionItem extends StatelessWidget {
  final CartItemModel item;
  final bool isSelected;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onToggle;

  const _ProductSelectionItem({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.08)
                : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]),
            border: Border.all(
              color: isSelected
                  ? accentColor.withOpacity(0.4)
                  : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) => onToggle(),
                activeColor: accentColor,
                checkColor: isDark ? const Color(0xFF121212) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3C3C3C) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 0.8,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (item.productImage ?? '').isNotEmpty
                      ? Image.network(
                          item.productImage ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                              size: 22,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.grey[900],
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF424242) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Qty: ${item.quantity}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[200] : Colors.grey[700],
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
        ),
      ),
    );
  }
}
// ✅✅✅ END: Copied code for Reorder Functionality ✅✅✅