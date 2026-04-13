// lib/screens/chat/widgets/order_card_renderer.dart
import 'package:flutter/material.dart';
import 'package:agroconnect/models/chat_message.dart';

class OrderCardRenderer extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onOrderTap;

  const OrderCardRenderer({
    Key? key,
    required this.message,
    required this.onOrderTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!message.hasOrders) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Your Recent Orders',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...message.orders!.map((order) => _buildOrderCard(context, order)),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final orderNumber = order['orderNumber']?.toString() ?? orderId;
    final status = order['orderStatus']?.toString() ?? 'unknown';
    final total = order['totalAmount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onOrderTap(orderId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'shipped':
      case 'processing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
