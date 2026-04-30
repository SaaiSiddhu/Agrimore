// lib/screens/orders/seller_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:intl/intl.dart';
import '../../providers/seller_order_provider.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const SellerOrderDetailScreen({super.key, required this.order});

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final order = widget.order;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final statusColor = _getStatusColor(order.orderStatus);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(order, statusColor, isDark),
            const SizedBox(height: 16),

            // Customer Info
            _buildSectionCard(
              'Customer',
              Icons.person_outline,
              isDark,
              children: [
                _buildInfoRow('Name', order.deliveryAddress.name.isNotEmpty
                    ? order.deliveryAddress.name
                    : 'Customer'),
                _buildInfoRow('Phone', order.deliveryAddress.phone.isNotEmpty
                    ? order.deliveryAddress.phone
                    : 'N/A'),
                _buildInfoRow('Address', order.deliveryAddress.fullAddress.isNotEmpty
                    ? order.deliveryAddress.fullAddress
                    : 'No address provided'),
              ],
            ),
            const SizedBox(height: 16),

            // Order Items
            _buildSectionCard(
              'Items (${order.items.length})',
              Icons.shopping_bag_outlined,
              isDark,
              children: order.items.map((item) => _buildItemRow(item, isDark)).toList(),
            ),
            const SizedBox(height: 16),

            // Payment Summary
            _buildSectionCard(
              'Payment Summary',
              Icons.receipt_long_outlined,
              isDark,
              children: [
                _buildPriceRow('Subtotal', order.subtotal),
                if (order.discount > 0) _buildPriceRow('Discount', -order.discount, isDiscount: true),
                _buildPriceRow('Delivery', order.deliveryCharge),
                if (order.tax > 0) _buildPriceRow('Tax', order.tax),
                const Divider(height: 16),
                _buildPriceRow('Total', order.total, isBold: true),
                const SizedBox(height: 8),
                _buildInfoRow('Payment', order.paymentMethod.toUpperCase()),
                _buildInfoRow('Payment Status', order.paymentStatus),
              ],
            ),
            const SizedBox(height: 16),

            // Order Info
            _buildSectionCard(
              'Order Info',
              Icons.info_outline,
              isDark,
              children: [
                _buildInfoRow('Order Date', dateStr),
                if (order.orderType != null) _buildInfoRow('Type', order.orderType!),
                if (order.deliverySlot != null) _buildInfoRow('Delivery Slot', order.deliverySlot!),
                if (order.notes != null && order.notes!.isNotEmpty)
                  _buildInfoRow('Notes', order.notes!),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (!order.isDelivered && !order.isCancelled)
              _buildActionButtons(order),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(OrderModel order, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(order.orderStatus), color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.getStatusDisplay(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.items.length} items • ₹${order.total.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2D7D3C)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItemModel item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              image: item.productImage.isNotEmpty
                  ? DecorationImage(image: NetworkImage(item.productImage), fit: BoxFit.cover)
                  : null,
            ),
            child: item.productImage.isEmpty ? const Icon(Icons.image, size: 20, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Qty: ${item.quantity}${item.variant != null ? ' • ${item.variant}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Text('₹${(item.price * item.quantity).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.grey[700])),
          Text(
            '${isDiscount ? '-' : ''}₹${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? Colors.green : (isBold ? const Color(0xFF2D7D3C) : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel order) {
    final nextStatus = _getNextStatus(order.orderStatus);
    if (nextStatus == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Primary action
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D7D3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: _isUpdating ? null : () => _updateStatus(order.id, nextStatus),
            icon: _isUpdating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_getNextStatusIcon(nextStatus)),
            label: Text(_getNextStatusLabel(nextStatus), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        // Cancel button (only for pending/confirmed)
        if (order.orderStatus == 'pending' || order.orderStatus == 'confirmed')
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isUpdating ? null : () => _confirmCancel(order.id),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();

    final success = await context.read<SellerOrderProvider>().updateOrderStatus(orderId, newStatus);

    setState(() => _isUpdating = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Order updated to ${_getNextStatusLabel(newStatus)}'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _confirmCancel(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, Keep')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(orderId, 'cancelled');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String? _getNextStatus(String current) {
    switch (current.toLowerCase()) {
      case 'pending': return 'confirmed';
      case 'confirmed': return 'processing';
      case 'processing': return 'shipped';
      case 'shipped': return 'out_for_delivery';
      case 'out_for_delivery':
      case 'outfordelivery': return 'delivered';
      default: return null;
    }
  }

  String _getNextStatusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Confirm Order';
      case 'processing': return 'Start Processing';
      case 'shipped': return 'Mark as Shipped';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': return 'Mark Delivered';
      default: return 'Update';
    }
  }

  IconData _getNextStatusIcon(String status) {
    switch (status) {
      case 'confirmed': return Icons.check_circle_outline;
      case 'processing': return Icons.precision_manufacturing;
      case 'shipped': return Icons.local_shipping_outlined;
      case 'out_for_delivery': return Icons.delivery_dining;
      case 'delivered': return Icons.done_all;
      default: return Icons.update;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.pending_actions;
      case 'confirmed': return Icons.check_circle_outline;
      case 'processing': return Icons.precision_manufacturing;
      case 'shipped': return Icons.local_shipping;
      case 'out_for_delivery':
      case 'outfordelivery': return Icons.delivery_dining;
      case 'delivered':
      case 'completed': return Icons.done_all;
      case 'cancelled': return Icons.cancel;
      default: return Icons.info_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'processing': return Colors.indigo;
      case 'shipped':
      case 'out_for_delivery':
      case 'outfordelivery': return Colors.purple;
      case 'delivered':
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}
