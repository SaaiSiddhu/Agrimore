// lib/screens/admin/orders/widgets/admin_order_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class AdminOrderCard extends StatelessWidget {
  final dynamic order;
  final VoidCallback onTap;

  const AdminOrderCard({
    Key? key,
    required this.order,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(order.orderStatus);
    final isPaid = order.paymentStatus.toLowerCase() == 'paid';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.97),
              Colors.white.withOpacity(0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          backgroundBlendMode: BlendMode.overlay,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Gradient Header Strip with motion feel
              Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusConfig['color'].withValues(alpha: 0.9),
                      statusConfig['color'].withValues(alpha: 0.4),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ).animate().shimmer(duration: 1800.ms),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header Row ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Info
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order #${order.orderNumber}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a')
                                  .format(order.createdAt),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        _buildStatusChip(statusConfig),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1.2),
                    const SizedBox(height: 16),

                    // ─── Customer + Items Row ───────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(
                          icon: Icons.person_outline_rounded,
                          title: "Customer",
                          value: order.deliveryAddress.name,
                        ),
                        _buildChip(
                          '${order.items.length} Items',
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1.2),
                    const SizedBox(height: 16),

                    // ─── Total + Payment ────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(
                          icon: Icons.currency_rupee_rounded,
                          title: "Total Amount",
                          value: '₹${order.total.toStringAsFixed(2)}',
                          bold: true,
                        ),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: 300.ms,
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPaid
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                              ),
                              child: Icon(
                                isPaid
                                    ? Icons.verified_rounded
                                    : Icons.pending_actions_rounded,
                                size: 18,
                                color: isPaid
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildChip(
                              isPaid ? 'PAID' : 'PENDING',
                              isPaid
                                  ? Colors.green.withOpacity(0.12)
                                  : Colors.orange.withOpacity(0.12),
                              isPaid
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ],
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
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .moveY(begin: 16, end: 0, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1));
  }

  // ───────────────────────────────
  // 🧩 Helper Widgets
  // ───────────────────────────────

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    bool bold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 15 : 13.5,
                fontWeight:
                    bold ? FontWeight.w800 : FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String text, Color bgColor, Color textColor) {
    return AnimatedContainer(
      duration: 300.ms,
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> config) {
    return AnimatedContainer(
      duration: 300.ms,
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: config['color'].withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: config['color'].withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'], size: 14, color: config['color']),
          const SizedBox(width: 6),
          Text(
            config['label'],
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: config['color'],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────
  // 🎨 Status Configuration
  // ───────────────────────────────
  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'label': 'Pending',
          'color': Colors.orange,
          'icon': Icons.schedule_rounded,
        };
      case 'confirmed':
        return {
          'label': 'Confirmed',
          'color': Colors.blue,
          'icon': Icons.check_circle_outline_rounded,
        };
      case 'processing':
        return {
          'label': 'Processing',
          'color': Colors.deepPurple,
          'icon': Icons.autorenew_rounded,
        };
      case 'shipped':
        return {
          'label': 'Shipped',
          'color': Colors.indigo,
          'icon': Icons.local_shipping_outlined,
        };
      case 'delivered':
        return {
          'label': 'Delivered',
          'color': Colors.green,
          'icon': Icons.check_circle_rounded,
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': Colors.red,
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