import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/order_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false)
          .loadOrderById(widget.order.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Track Order',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoadingTimeline) {
            return Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final timeline = orderProvider.selectedOrderTimeline;
          final order = orderProvider.selectedOrder ?? widget.order;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildOrderHeader(order),
                const SizedBox(height: 12),
                _buildProgressIndicator(order),
                const SizedBox(height: 12),
                if (timeline.isNotEmpty) _buildEstimatedDelivery(order),
                const SizedBox(height: 12),
                _buildTimeline(timeline),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // BUILD ORDER HEADER
  // ============================================
  Widget _buildOrderHeader(OrderModel order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(order.orderStatus),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  color: Colors.grey[600], size: 16),
              const SizedBox(width: 8),
              Text(
                'Ordered on ${DateFormat('MMM dd, yyyy').format(order.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
          if (order.deliveryDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_shipping_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Expected by ${DateFormat('MMM dd, yyyy').format(order.deliveryDate!)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================
  // BUILD PROGRESS INDICATOR
  // ============================================
  Widget _buildProgressIndicator(OrderModel order) {
    final steps = _getOrderSteps(order.orderStatus);
    final currentStep = _getCurrentStep(order.orderStatus);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Progress',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              steps.length,
              (index) => Expanded(
                child: _buildProgressStep(
                  icon: steps[index]['icon'],
                  label: steps[index]['label'],
                  isCompleted: index < currentStep,
                  isActive: index == currentStep,
                  isLast: index == steps.length - 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // BUILD SINGLE PROGRESS STEP
  // ============================================
  Widget _buildProgressStep({
    required IconData icon,
    required String label,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                color: isCompleted ? AppColors.primary : Colors.grey[300],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted || isActive ? AppColors.primary : Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted || isActive
                      ? AppColors.primary
                      : Colors.grey[400]!,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  height: 3,
                  color: isCompleted ? AppColors.primary : Colors.grey[300],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isActive || isCompleted ? FontWeight.w700 : FontWeight.w500,
            color: isActive || isCompleted ? AppColors.primary : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ============================================
  // BUILD ESTIMATED DELIVERY
  // ============================================
  Widget _buildEstimatedDelivery(OrderModel order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated Delivery',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (order.deliveryDate != null)
                    Text(
                      DateFormat('MMM dd, yyyy').format(order.deliveryDate!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Text(
                      'Delivery date TBA',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // BUILD TIMELINE
  // ============================================
  Widget _buildTimeline(List<OrderTimelineModel> timeline) {
    if (timeline.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.timeline_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No tracking information yet',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Check back soon for updates',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Timeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeline.length,
            itemBuilder: (context, index) {
              final event = timeline[index];
              final isFirst = index == 0;

              return TimelineTile(
                isFirst: isFirst,
                isLast: index == timeline.length - 1,
                beforeLineStyle: LineStyle(
                  color: AppColors.primary.withOpacity(0.5),
                  thickness: 2,
                ),
                indicatorStyle: IndicatorStyle(
                  width: 40,
                  height: 40,
                  indicator: Container(
                    decoration: BoxDecoration(
                      color: isFirst ? AppColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _getStatusIcon(event.status),
                        color: isFirst ? Colors.white : AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                endChild: Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFirst ? Colors.grey[50] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFirst
                            ? AppColors.primary.withOpacity(0.2)
                            : Colors.grey[200]!,
                        width: isFirst ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                event.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                event.statusDisplayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        // ✅ ADDED: Show tracking number if available
                        if (event.trackingNumber != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.blue[200]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_rounded,
                                    size: 14, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tracking: ${event.trackingNumber}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // ✅ ADDED: Show location if available
                        if (event.location != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(event.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // BUILD STATUS BADGE
  // ============================================
  Widget _buildStatusBadge(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config['color'].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'], size: 14, color: config['color']),
          const SizedBox(width: 4),
          Text(
            config['label'],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: config['color'],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // HELPER FUNCTIONS
  // ============================================
  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'label': 'Pending',
          'color': Colors.orange,
          'icon': Icons.schedule_rounded
        };
      case 'confirmed':
        return {
          'label': 'Confirmed',
          'color': Colors.blue,
          'icon': Icons.check_circle_outline_rounded
        };
      case 'processing':
        return {
          'label': 'Processing',
          'color': Colors.purple,
          'icon': Icons.autorenew_rounded
        };
      case 'shipped':
        return {
          'label': 'Shipped',
          'color': Colors.indigo,
          'icon': Icons.local_shipping_outlined
        };
      case 'delivered':
        return {
          'label': 'Delivered',
          'color': Colors.green,
          'icon': Icons.check_circle_rounded
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': Colors.red,
          'icon': Icons.cancel_outlined
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline_rounded
        };
    }
  }

  List<Map<String, dynamic>> _getOrderSteps(String status) {
    return [
      {'icon': Icons.shopping_cart_rounded, 'label': 'Placed'},
      {'icon': Icons.check_circle_outline_rounded, 'label': 'Confirmed'},
      {'icon': Icons.local_shipping_outlined, 'label': 'Shipped'},
      {'icon': Icons.home_rounded, 'label': 'Delivered'},
    ];
  }

  int _getCurrentStep(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'confirmed':
      case 'processing':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.processing:
        return Icons.autorenew_rounded;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining_rounded;
      case OrderStatus.delivered:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
      case OrderStatus.returned:
        return Icons.keyboard_return_rounded;
      case OrderStatus.refunded:
        return Icons.currency_rupee_rounded;
    }
  }
}
