// lib/screens/user/orders/orders_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/order_provider.dart';
// import '../../../providers/cart_provider.dart'; // No longer needed
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/delivery_tracking_service.dart';
import 'order_details_screen.dart';
import 'live_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  
  final List<String> _filters = ['All', 'Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
  
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
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isDark),
              _buildEnhancedFilterBar(isDark),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Consumer<OrderProvider>(
                      builder: (context, orderProvider, child) {
                        if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
                          return _buildShimmerLoading(isDark);
                        }

                        if (orderProvider.error != null && orderProvider.orders.isEmpty) {
                          return _buildErrorState(orderProvider.error!, isDark);
                        }

                        if (orderProvider.orders.isEmpty) {
                          return _buildEmptyState(isDark);
                        }

                        final filteredOrders = _selectedFilter == 'All'
                            ? orderProvider.orders
                            : orderProvider.orders
                                .where((o) => o.orderStatus.toLowerCase() == _selectedFilter.toLowerCase())
                                .toList();

                        return RefreshIndicator(
                          onRefresh: () async {
                            Provider.of<OrderProvider>(context, listen: false).loadOrders();
                          },
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          child: filteredOrders.isEmpty
                              ? _buildNoResultsState(isDark)
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  itemCount: filteredOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    return _OrderCard(
                                      order: order,
                                      index: index,
                                      isDark: isDark,
                                      onTap: () => _navigateToDetails(order),
                                    );
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
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

  // ✅ REBUILT: Header now has back button and centered title
  Widget _buildHeader(bool isDark) {
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
          // Back Button
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
          // Centered Title
          const Text(
            'My Orders',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          // Spacer to keep title centered
          Container(
            width: 40,
            height: 40,
            color: Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(
            _filters.length,
            (index) {
              final filter = _filters[index];
              final isSelected = _selectedFilter == filter;
              final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
              
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 12 : 6,
                  right: index == _filters.length - 1 ? 12 : 6,
                  top: 4,
                  bottom: 4
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? (isDark ? const Color(0xFF121212) : Colors.white) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 50,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No $_selectedFilter Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any orders with this status',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 250,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 60,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Start shopping to see your orders here',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, color: isDark ? const Color(0xFF121212) : Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Start Shopping',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF121212) : Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Unable to Load Orders',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.grey[900],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          Container(
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red[700]!.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Provider.of<OrderProvider>(context, listen: false).loadOrders();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 240, // Adjusted height for new layout
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  void _navigateToDetails(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(orderId: order.id),
      ),
    );
  }
}

// ✅ ENHANCED THEME-AWARE ORDER CARD
class _OrderCard extends StatefulWidget {
  final OrderModel order;
  final int index;
  final bool isDark;
  final VoidCallback onTap;
  // final VoidCallback onReorder; // ✅ REMOVED

  const _OrderCard({
    required this.order,
    required this.index,
    required this.isDark,
    required this.onTap,
    // required this.onReorder, // ✅ REMOVED
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationsInitialized = true;

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted && _animationsInitialized) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animationsInitialized) {
      return const SizedBox.shrink();
    }

    final accentColor = widget.isDark ? AppColors.primaryLight : AppColors.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Order #${widget.order.orderNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(widget.order.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusBadge(status: widget.order.orderStatus),
                    ],
                  ),
                ),

                // ✅ NEW: ETA Banner for active orders
                if (_isActiveOrder(widget.order.orderStatus))
                  _buildETABanner(accentColor),

                // Product section
                if (widget.order.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCarouselView(widget.order.items.take(6).toList(), widget.order.items.length > 6),
                        const SizedBox(height: 16),
                        Divider(color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!, height: 1),
                        const SizedBox(height: 16),

                        // Bottom section with total and buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${widget.order.total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: widget.isDark ? Colors.white : Colors.black87,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                            // ✅ REMOVED REORDER BUTTON, Details button will align right
                            _buildDetailsButton(accentColor),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No items in this order',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDark ? Colors.grey[600] : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ REMOVED _buildReorderButton

  Widget _buildDetailsButton(Color accentColor) {
    return ElevatedButton(
      onPressed: widget.onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
        backgroundColor: accentColor,
        foregroundColor: widget.isDark ? const Color(0xFF121212) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
        shadowColor: accentColor.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Text(
            'Details',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 10,
            color: widget.isDark ? const Color(0xFF121212) : Colors.white,
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Check if order is active (in transit)
  bool _isActiveOrder(String status) {
    final activeStatuses = ['confirmed', 'processing', 'shipped', 'out_for_delivery'];
    return activeStatuses.contains(status.toLowerCase());
  }

  // ✅ NEW: ETA Banner with Track Live button
  Widget _buildETABanner(Color accentColor) {
    final trackingService = DeliveryTrackingService();
    final etaMinutes = _getEstimatedETA(widget.order.orderStatus);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Animated delivery icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          
          // ETA info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackingService.formatETAWithPrefix(etaMinutes),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trackingService.getStatusMessage(widget.order.orderStatus),
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Track Live button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LiveTrackingScreen(
                    orderId: widget.order.id,
                    initialOrder: widget.order,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: widget.isDark ? const Color(0xFF121212) : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Track',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? const Color(0xFF121212) : Colors.white,
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

  // ✅ NEW: Get simulated ETA based on status
  int _getEstimatedETA(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 25;
      case 'processing':
        return 18;
      case 'shipped':
        return 12;
      case 'out_for_delivery':
        return 8;
      default:
        return 15;
    }
  }

  // ✅ FIXED: Always use carousel, removed grid view
  Widget _buildCarouselView(List<CartItemModel> itemsToShow, bool hasMore) {
    return SizedBox(
      height: 120, // ✅ FIXED: Set height for square images
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 0),
        itemCount: hasMore ? itemsToShow.length + 1 : itemsToShow.length,
        itemBuilder: (context, index) {
          if (index == itemsToShow.length && hasMore) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildMoreCounterCarouselCard(widget.order.items.length - itemsToShow.length),
            );
          }

          final item = itemsToShow[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              // ✅ FIXED: Set width and height for square images
              width: 120,
              height: 120,
              child: _buildProductCard(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(CartItemModel item) {
    return Container(
      width: 120,  // ✅ FIXED: Explicit width
      height: 120, // ✅ FIXED: Explicit height
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 0.8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (item.productImage ?? '').isNotEmpty
                ? Image.network(
                    item.productImage ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                        size: 28,
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                      size: 28,
                    ),
                  ),
          ),
          if (item.quantity > 1)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Text(
                  '×${item.quantity}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreCounterCarouselCard(int moreCount) {
    final accentColor = widget.isDark ? AppColors.primaryLight : AppColors.primary;
    return Container(
      width: 120, // ✅ FIXED: Set width and height for square images
      height: 120,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.grey[700]! : Colors.grey[200]!, width: 0.8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+$moreCount',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'more items',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: config['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: config['color'].withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'],
            size: 13,
            color: config['color'],
          ),
          const SizedBox(width: 6),
          Text(
            config['label'],
            style: TextStyle(
              fontSize: 11,
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
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline_rounded,
        };
    }
  }
}

// ✅ REMOVED _ProductSelectionModal
// ✅ REMOVED _ProductSelectionItem