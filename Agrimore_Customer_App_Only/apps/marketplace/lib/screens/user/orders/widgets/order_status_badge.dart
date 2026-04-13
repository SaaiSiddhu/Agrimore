import 'package:flutter/material.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const OrderStatusBadge({
    Key? key,
    required this.status,
    this.compact = false,
  }) : super(key: key);

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA500); // Orange
      case 'confirmed':
        return const Color(0xFF2196F3); // Blue
      case 'processing':
        return const Color(0xFF9C27B0); // Purple
      case 'shipped':
        return const Color(0xFF00BCD4); // Cyan
      case 'delivered':
        return const Color(0xFF4CAF50); // Green
      case 'cancelled':
        return const Color(0xFFF44336); // Red
      case 'refunded':
        return const Color(0xFFFF6F00); // Deep Orange
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'processing':
        return Icons.hourglass_bottom_rounded;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.done_all_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'refunded':
        return Icons.money_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusLabel() {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final label = _getStatusLabel();

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
