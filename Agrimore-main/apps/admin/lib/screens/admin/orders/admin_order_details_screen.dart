// lib/screens/admin/orders/admin_order_details_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/themes/admin_colors.dart';
import '../../../providers/order_provider.dart';
import '../delivery/order_assignment_screen.dart';

import 'widgets/order_status_updater.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailsScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  bool _loadingInvoice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false)
            .loadOrderById(widget.orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AdminColors.primary),
                  const SizedBox(height: 16),
                  Text('Loading order...', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final OrderModel? order = orderProvider.selectedOrder;
          if (order == null) return _emptyState();

          return CustomScrollView(
            slivers: [
              // Premium Header
              _buildSliverHeader(order),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status update card
                      OrderStatusUpdater(order: order),
                      const SizedBox(height: 12),
                      // Assign Delivery Partner button
                      if (order.orderStatus.toLowerCase() == 'processing' || 
                          order.orderStatus.toLowerCase() == 'confirmed')
                        _buildAssignPartnerButton(order),
                      const SizedBox(height: 16),
                      // Quick stats row
                      _buildQuickStats(order),
                      const SizedBox(height: 16),
                      // Customer & Delivery section
                      _buildSectionTitle('Customer & Delivery', Icons.person_rounded),
                      const SizedBox(height: 12),
                      _buildCustomerCard(order),
                      const SizedBox(height: 16),
                      // Order items
                      _buildSectionTitle('Order Items', Icons.shopping_bag_rounded),
                      const SizedBox(height: 12),
                      _buildItemsCard(order),
                      const SizedBox(height: 16),
                      // Price breakdown
                      _buildSectionTitle('Price Breakdown', Icons.receipt_long_rounded),
                      const SizedBox(height: 12),
                      _buildPricingCard(order),
                      const SizedBox(height: 16),
                      // Payment details
                      _buildSectionTitle('Payment Details', Icons.payment_rounded),
                      const SizedBox(height: 12),
                      _buildPaymentCard(order),
                      const SizedBox(height: 16),
                      // Timeline
                      _buildSectionTitle('Order Timeline', Icons.timeline_rounded),
                      const SizedBox(height: 12),
                      _buildTimelineCard(orderProvider),
                      const SizedBox(height: 24),
                      // Action buttons
                      _buildActionButtons(order),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms);
        },
      ),
    );
  }

  // =========================
  // Sliver Header
  // =========================
  Widget _buildSliverHeader(OrderModel order) {
    final statusColor = _statusColor(order.orderStatus);
    
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: AdminColors.primary,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
          ),
          onPressed: () {
            Provider.of<OrderProvider>(context, listen: false)
                .loadOrderById(widget.orderId);
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AdminColors.primary,
                AdminColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.orderNumber ?? order.id.substring(0, 8)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy • hh:mm a').format(order.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order.orderStatus.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Copy order ID
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Order ID copied'),
                          backgroundColor: AdminColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white.withOpacity(0.8), size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'ID: ${order.id}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontFamily: 'monospace',
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
      ),
    );
  }

  // =========================
  // Quick Stats Row
  // =========================
  Widget _buildQuickStats(OrderModel order) {
    return Row(
      children: [
        Expanded(child: _statTile(
          '${order.items.length}',
          'Items',
          Icons.shopping_bag_outlined,
          AdminColors.primary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _statTile(
          '₹${order.total.toStringAsFixed(0)}',
          'Total',
          Icons.currency_rupee_rounded,
          Colors.green,
        )),
        const SizedBox(width: 12),
        Expanded(child: _statTile(
          order.paymentStatus.toUpperCase(),
          'Payment',
          order.paymentStatus.toLowerCase() == 'paid' 
              ? Icons.check_circle_outline_rounded 
              : Icons.pending_outlined,
          order.paymentStatus.toLowerCase() == 'paid' ? Colors.green : Colors.orange,
        )),
      ],
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  // =========================
  // Section Title
  // =========================
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AdminColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AdminColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // =========================
  // Assign Partner Button
  // =========================
  Widget _buildAssignPartnerButton(OrderModel order) {
    final hasPartner = order.deliveryPartnerId != null && order.deliveryPartnerId!.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasPartner 
            ? [Colors.green.shade400, Colors.green.shade600]
            : [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (hasPartner ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderAssignmentScreen(order: order),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasPartner ? Icons.check_circle_rounded : Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPartner ? 'Delivery Partner Assigned' : 'Assign Delivery Partner',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPartner 
                          ? 'Tap to reassign or view partner'
                          : 'Choose an online partner for this order',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // Customer Card
  // =========================
  Widget _buildCustomerCard(OrderModel order) {
    final a = order.deliveryAddress;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Customer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AdminColors.primary, AdminColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      a.name.isNotEmpty ? a.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            a.phone,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quickActionButton(Icons.phone_rounded, Colors.green, () => _callCustomer(a.phone)),
                    const SizedBox(width: 8),
                    _quickActionButton(FontAwesomeIcons.whatsapp, Colors.green.shade600, () => _openWhatsApp(a.phone)),
                    const SizedBox(width: 8),
                    _quickActionButton(Icons.copy_rounded, Colors.grey, () {
                      Clipboard.setData(ClipboardData(text: a.phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Phone copied'), backgroundColor: AdminColors.primary),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: Colors.grey.shade100),
          // Delivery address
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.fullAddress,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _launchGoogleMaps(order),
                  icon: const Icon(Icons.map_rounded, color: Colors.blue),
                  tooltip: 'Open in Maps',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // =========================
  // Items Card
  // =========================
  Widget _buildItemsCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...order.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Product image
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.productImage != null && item.productImage.isNotEmpty
                              ? Image.network(
                                  item.productImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                              : Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Colors.grey.shade400,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Product details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // ✅ NEW: Display variant if present
                            if (item.variant != null && item.variant!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                ),
                                child: Text(
                                  item.variant!,
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Qty: ${item.quantity}',
                                    style: TextStyle(
                                      color: AdminColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '₹${item.price.toStringAsFixed(0)} each',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Item total
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < order.items.length - 1)
                  Divider(height: 1, color: Colors.grey.shade100),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // =========================
  // Pricing Card
  // =========================
  Widget _buildPricingCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _priceRow('Subtotal', order.subtotal),
            const SizedBox(height: 12),
            _priceRow('Delivery Charges', order.deliveryCharge),
            const SizedBox(height: 12),
            _priceRow('Tax', order.tax),
            if ((order.discount ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _priceRow('Discount', -(order.discount ?? 0), isDiscount: true),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AdminColors.primary,
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

  Widget _priceRow(String label, double amount, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}₹${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDiscount ? Colors.green.shade700 : Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  // =========================
  // Payment Card
  // =========================
  Widget _buildPaymentCard(OrderModel order) {
    final isPaid = order.paymentStatus.toLowerCase() == 'paid';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Payment status banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                      color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaid ? 'Payment Received' : 'Payment Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _friendlyPaymentMethod(order.paymentMethod),
                          style: TextStyle(
                            fontSize: 12,
                            color: isPaid ? Colors.green.shade600 : Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.paymentStatus.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order.razorpayOrderId != null && order.razorpayOrderId!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Razorpay ID:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.razorpayOrderId ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.razorpayOrderId ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Razorpay ID copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================
  // Timeline Card
  // =========================
  Widget _buildTimelineCard(OrderProvider orderProvider) {
    final timeline = orderProvider.selectedOrderTimeline ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: timeline.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.timeline_rounded, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No timeline events yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: timeline.length,
                itemBuilder: (context, i) {
                  final ev = timeline[i];
                  final isFirst = i == 0;
                  final isLast = i == timeline.length - 1;
                  
                  return TimelineTile(
                    isFirst: isFirst,
                    isLast: isLast,
                    beforeLineStyle: LineStyle(
                      color: AdminColors.primary.withOpacity(0.2),
                      thickness: 2,
                    ),
                    afterLineStyle: LineStyle(
                      color: AdminColors.primary.withOpacity(0.2),
                      thickness: 2,
                    ),
                    indicatorStyle: IndicatorStyle(
                      width: 36,
                      height: 36,
                      indicator: Container(
                        decoration: BoxDecoration(
                          color: isFirst ? AdminColors.primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst ? AdminColors.primary : AdminColors.primary.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _timelineIcon(ev.status),
                            color: isFirst ? Colors.white : AdminColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    endChild: Padding(
                      padding: const EdgeInsets.only(left: 14, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ev.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AdminColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ev.statusDisplayName,
                                  style: TextStyle(
                                    color: AdminColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ev.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMM d, yyyy • hh:mm a').format(ev.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // =========================
  // Action Buttons
  // =========================
  Widget _buildActionButtons(OrderModel order) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loadingInvoice
                ? null
                : () => _exportInvoice(order, preview: true, share: false),
            icon: _loadingInvoice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.visibility_rounded, size: 20),
            label: const Text('Preview Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadingInvoice
                ? null
                : () => _exportInvoice(order, preview: false, share: true),
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.primary,
              side: BorderSide(color: AdminColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // Empty State
  // =========================
  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 60, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order not found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'The order may have been deleted',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );

  // =========================
  // Utilities
  // =========================
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.deepPurple;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _timelineIcon(dynamic status) {
    final s = (status ?? '').toString().toLowerCase();
    switch (s) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'processing':
        return Icons.autorenew_rounded;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'outfordelivery':
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _friendlyPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'upi':
        return 'UPI Payment';
      case 'card':
        return 'Credit/Debit Card';
      case 'netbanking':
        return 'Net Banking';
      default:
        return method.toUpperCase();
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchGoogleMaps(OrderModel order) async {
    final a = order.deliveryAddress;
    Uri uri;
    if (a.latitude != null && a.longitude != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a.fullAddress)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // =========================
  // Invoice Export (kept from original)
  // =========================
  Future<void> _exportInvoice(OrderModel order, {bool preview = false, bool share = false}) async {
    setState(() => _loadingInvoice = true);

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INVOICE', style: pw.TextStyle(font: fontBold, fontSize: 28)),
                    pw.SizedBox(height: 4),
                    pw.Text('Agrimore', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Order #${order.orderNumber ?? order.id.substring(0, 8)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.SizedBox(height: 4),
                    pw.Text(DateFormat('dd MMM yyyy').format(order.createdAt),
                        style: pw.TextStyle(font: font, fontSize: 11)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            // Customer info
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bill To:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text(order.deliveryAddress.name, style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text(order.deliveryAddress.phone, style: pw.TextStyle(font: font, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Text(order.deliveryAddress.fullAddress, style: pw.TextStyle(font: font, fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            // Items table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Price', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                  ],
                ),
                ...order.items.map((item) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.productName, style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item.quantity}', style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${item.price.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${(item.price * item.quantity).toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10))),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
            // Totals
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Subtotal:', style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text('Rs.${order.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 11)),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Delivery:', style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text('Rs.${order.deliveryCharge.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 11)),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Tax:', style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text('Rs.${order.tax.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 11)),
                    ]),
                    pw.Divider(),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('TOTAL:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      pw.Text('Rs.${order.total.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      if (preview) {
        await Printing.layoutPdf(onLayout: (_) => bytes);
      } else if (share) {
        await Printing.sharePdf(bytes: bytes, filename: 'invoice_${order.orderNumber ?? order.id}.pdf');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating invoice: $e')),
      );
    } finally {
      setState(() => _loadingInvoice = false);
    }
  }
}