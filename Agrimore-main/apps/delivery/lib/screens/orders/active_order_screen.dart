// lib/screens/orders/active_order_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/order_provider.dart';

class ActiveOrderScreen extends StatelessWidget {
  final OrderModel order;
  
  const ActiveOrderScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.orderNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(colorScheme),
            const SizedBox(height: 20),
            
            // Customer Info
            _buildSection(
              'Customer',
              Icons.person_outline_rounded,
              colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.deliveryAddress.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (order.deliveryAddress.phone != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _callCustomer(),
                          icon: Icon(Icons.call, size: 16),
                          label: Text('Call'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _navigateToAddress(),
                          icon: Icon(Icons.navigation, size: 16),
                          label: Text('Navigate'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Delivery Address
            _buildSection(
              'Delivery Address',
              Icons.location_on_outlined,
              colorScheme,
              child: Text(
                order.deliveryAddress.fullAddress,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Order Items
            _buildSection(
              'Items (${order.items.length})',
              Icons.shopping_bag_outlined,
              colorScheme,
              child: Column(
                children: order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Payment Info
            _buildSection(
              'Payment',
              Icons.payment_outlined,
              colorScheme,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.paymentMethod.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${order.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Action Buttons
            _buildActionButtons(context, colorScheme),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCard(ColorScheme colorScheme) {
    final statusText = _getStatusText(order.orderStatus);
    final statusColor = _getStatusColor(order.orderStatus, colorScheme);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(order.orderStatus),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                Text(
                  _getStatusDescription(order.orderStatus),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, IconData icon, ColorScheme colorScheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    final status = order.orderStatus;
    
    if (status == 'picked_up') {
      return FilledButton(
        onPressed: () => _updateStatus(context, 'out_for_delivery'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Start Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
    }
    
    if (status == 'out_for_delivery') {
      return FilledButton(
        onPressed: () => _markDelivered(context),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Mark as Delivered', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
    }
    
    return const SizedBox.shrink();
  }
  
  void _updateStatus(BuildContext context, String status) async {
    HapticFeedback.mediumImpact();
    final orderProvider = context.read<DeliveryOrderProvider>();
    await orderProvider.updateOrderStatus(order.id, status, 'Status updated by delivery partner');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated'), backgroundColor: Colors.green),
      );
    }
  }
  
  void _markDelivered(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delivery'),
        content: Text('Are you sure the order has been delivered?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(context, 'delivered');
              Navigator.pop(context);
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }
  
  void _callCustomer() async {
    final phone = order.deliveryAddress.phone;
    if (phone != null) {
      final url = Uri.parse('tel:$phone');
      if (await canLaunchUrl(url)) launchUrl(url);
    }
  }
  
  void _navigateToAddress() async {
    final address = order.deliveryAddress;
    if (address.latitude != null && address.longitude != null) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${address.latitude},${address.longitude}');
      if (await canLaunchUrl(url)) launchUrl(url);
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'picked_up': return 'Picked Up';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': return 'Delivered';
      default: return status;
    }
  }
  
  String _getStatusDescription(String status) {
    switch (status) {
      case 'picked_up': return 'Navigate to customer location';
      case 'out_for_delivery': return 'On the way to customer';
      case 'delivered': return 'Order completed';
      default: return '';
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'picked_up': return Icons.inventory_2_rounded;
      case 'out_for_delivery': return Icons.delivery_dining_rounded;
      case 'delivered': return Icons.check_circle_rounded;
      default: return Icons.pending_rounded;
    }
  }
  
  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'picked_up': return Colors.orange;
      case 'out_for_delivery': return colorScheme.primary;
      case 'delivered': return Colors.green;
      default: return colorScheme.outline;
    }
  }
}
