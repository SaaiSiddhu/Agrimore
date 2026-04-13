import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/order_provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/order_timeline.dart';
import 'widgets/tracking_map.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;

  const TrackOrderScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

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
      context.read<OrderProvider>().loadOrderById(widget.orderId);
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
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
                  expandedHeight: 120,
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
                            const Color(0xFF4DB85F).withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
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
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
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
                                child: Text(
                                  'Track Order',
                                  style: AppTextStyles.headlineSmall
                                      .copyWith(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
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

                // ============================================
                // CONTENT
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

                      final order = orderProvider.selectedOrder;

                      if (order == null) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'Order not found',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order header
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2D7D3C)
                                        .withValues(alpha: 0.05),
                                    const Color(0xFF3DA34E)
                                        .withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF2D7D3C)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              order
                                                  .orderNumber,
                                              style: AppTextStyles
                                                  .headlineSmall
                                                  .copyWith(
                                                fontWeight:
                                                    FontWeight
                                                        .w900,
                                                fontSize:
                                                    16,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              DateFormat(
                                                'MMM dd, yyyy • hh:mm a',
                                              ).format(order
                                                  .createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors
                                                    .grey[600],
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        OrderStatusBadge(
                                          status: order
                                              .orderStatus,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Live tracking
                            Text(
                              '📍 Live Tracking',
                              style: AppTextStyles
                                  .titleLarge
                                  .copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),

                            TrackingMap(
                              address: order.deliveryAddress
                                  .fullAddress,
                              city: order.deliveryAddress
                                  .city,
                              state: order.deliveryAddress
                                  .state,
                              zipCode: order
                                  .deliveryAddress
                                  .zipCode,
                            ),

                            const SizedBox(height: 24),

                            // Expected delivery
                            Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2D7D3C)
                                        .withValues(alpha: 0.05),
                                    const Color(0xFF3DA34E)
                                        .withValues(alpha: 0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF2D7D3C)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration:
                                          BoxDecoration(
                                        gradient:
                                            LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF2D7D3C,
                                            ),
                                            const Color(
                                              0xFF3DA34E,
                                            ),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons
                                            .calendar_today_rounded,
                                        color:
                                            Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            'Expected Delivery',
                                            style: AppTextStyles
                                                .bodyMedium
                                                .copyWith(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              fontSize: 12,
                                              color: Colors
                                                  .grey[600],
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 4,
                                          ),
                                          Text(
                                            order.deliveryDate !=
                                                    null
                                                ? DateFormat(
                                                  'MMM dd, yyyy',
                                                ).format(order
                                                    .deliveryDate!)
                                                : 'To be updated',
                                            style: AppTextStyles
                                                .bodyMedium
                                                .copyWith(
                                              fontWeight:
                                                  FontWeight
                                                      .w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Timeline
                            Text(
                              'Delivery Updates',
                              style: AppTextStyles
                                  .titleLarge
                                  .copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (orderProvider
                                .isLoadingTimeline)
                              Center(
                                child:
                                    CircularProgressIndicator(
                                  color: const Color(
                                    0xFF2D7D3C,
                                  ),
                                ),
                              )
                            else
                              OrderTimeline(
                                timeline: orderProvider
                                    .selectedOrderTimeline,
                              ),

                            const SizedBox(height: 30),
                          ],
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
}
