import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/order_model.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import 'order_status_badge.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback? onTrack;

  const OrderCard({
    Key? key,
    required this.order,
    required this.onTap,
    this.onTrack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    OrderStatusBadge(
                      status: order.orderStatus,
                      compact: true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Items count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7D3C).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2D7D3C).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '${order.itemCount} item${order.itemCount > 1 ? 's' : ''} • ₹${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D7D3C),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Actions
                if (order.orderStatus != 'delivered' &&
                    order.orderStatus != 'cancelled')
                  InkWell(
                    onTap: onTrack,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF2D7D3C),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Track Order',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2D7D3C),
                            ),
                          ),
                        ],
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
}
