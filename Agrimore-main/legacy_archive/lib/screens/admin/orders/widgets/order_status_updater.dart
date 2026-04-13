import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../providers/order_provider.dart';

class OrderStatusUpdater extends StatefulWidget {
  final dynamic order;

  const OrderStatusUpdater({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderStatusUpdater> createState() => _OrderStatusUpdaterState();
}

class _OrderStatusUpdaterState extends State<OrderStatusUpdater> {
  late String _selectedStatus;
  final TextEditingController _trackingController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.orderStatus.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Order Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildStatusSelector(),
          const SizedBox(height: 16),
          _buildTrackingInput(),
          const SizedBox(height: 12),
          _buildLocationInput(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Update Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    final statuses = [
      'pending',
      'confirmed',
      'processing',
      'shipped',
      'delivered',
      'cancelled'
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final isSelected = _selectedStatus == status;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? _getStatusColor(status).withValues(alpha: 0.15)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? _getStatusColor(status)
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? _getStatusColor(status)
                    : Colors.grey[600],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrackingInput() {
    return TextFormField(
      controller: _trackingController,
      decoration: InputDecoration(
        labelText: 'Tracking Number (Optional)',
        hintText: 'e.g., 1234567890ABC',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.local_shipping_rounded),
      ),
    );
  }

  Widget _buildLocationInput() {
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: 'Current Location (Optional)',
        hintText: 'e.g., Warehouse, In Transit',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.location_on_rounded),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context) async {
    try {
      final orderProvider =
          Provider.of<OrderProvider>(context, listen: false);

      // Update order status
      await orderProvider.updateOrderStatus(
        widget.order.id,
        _selectedStatus,
        description:
            'Status updated to ${_selectedStatus.toUpperCase()}.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Order status updated'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
