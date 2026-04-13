import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'widgets/empty_orders.dart';
import 'widgets/order_card.dart';
import 'order_details_screen.dart';
import 'track_order_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ============================================
                // HEADER
                // ============================================
                SliverAppBar(
                  expandedHeight: 140,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF2D7D3C),
                            const Color(0xFF3DA34E),
                            const Color(0xFF4DB85F).withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Orders',
                                          style: AppTextStyles.headlineSmall
                                              .copyWith(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Track and manage your orders',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ============================================
                // FILTERS
                // ============================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All Orders'),
                          const SizedBox(width: 8),
                          _buildFilterChip('pending', 'Pending'),
                          const SizedBox(width: 8),
                          _buildFilterChip('delivered', 'Delivered'),
                          const SizedBox(width: 8),
                          _buildFilterChip('cancelled', 'Cancelled'),
                        ],
                      ),
                    ),
                  ),
                ),

                // ============================================
                // ORDERS LIST
                // ============================================
                SliverToBoxAdapter(
                  child: Consumer<OrderProvider>(
                    builder: (context, orderProvider, child) {
                      if (orderProvider.isLoading) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                color: const Color(0xFF2D7D3C),
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        );
                      }

                      final orders = _getFilteredOrders(orderProvider);

                      if (orders.isEmpty) {
                        return EmptyOrders(
                          onShopNow: () {
                            Navigator.pop(context);
                          },
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: List.generate(
                            orders.length,
                            (index) {
                              final order = orders[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: OrderCard(
                                  order: order,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OrderDetailsScreen(
                                          orderId: order.id,
                                        ),
                                      ),
                                    );
                                  },
                                  onTrack: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TrackOrderScreen(
                                          orderId: order.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2D7D3C), Color(0xFF3DA34E)],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: Colors.grey[300]!,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2D7D3C).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  List _getFilteredOrders(OrderProvider provider) {
    switch (_selectedFilter) {
      case 'pending':
        return provider.pendingOrders;
      case 'delivered':
        return provider.completedOrders;
      case 'cancelled':
        return provider.cancelledOrders;
      default:
        return provider.orders;
    }
  }
}
