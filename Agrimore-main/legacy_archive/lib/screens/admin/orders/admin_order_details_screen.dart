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

import '../../../app/themes/app_colors.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
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
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Provider.of<OrderProvider>(context, listen: false)
                  .loadOrderById(widget.orderId);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final OrderModel? order = orderProvider.selectedOrder;
          if (order == null) return _emptyState();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _orderHeaderCard(order),
                const SizedBox(height: 12),
                _orderStatsCard(order),
                const SizedBox(height: 12),
                // Keep status updater (admin UI)
                OrderStatusUpdater(order: order),
                const SizedBox(height: 12),
                _customerCard(order),
                const SizedBox(height: 12),
                _locationCard(order),
                const SizedBox(height: 12),
                _itemsCard(order),
                const SizedBox(height: 12),
                _pricingCard(order),
                const SizedBox(height: 12),
                _paymentCard(order),
                const SizedBox(height: 12),
                _timelineCard(orderProvider),
                const SizedBox(height: 24),
                // Bottom actions row: Invoice (preview & download)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadingInvoice
                            ? null
                            : () => _exportInvoice(order,
                                preview: true, share: false),
                        icon: _loadingInvoice
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.remove_red_eye_rounded,
                                size: 18),
                        label: const Text('Preview Invoice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _loadingInvoice
                          ? null
                          : () => _exportInvoice(order,
                              preview: false, share: true),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download / Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms);
        },
      ),
    );
  }

  // =========================
  // Empty state
  // =========================
  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Order not found',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      );

  // =========================
  // Header Card (compact, with logo)
  // =========================
  Widget _orderHeaderCard(OrderModel order) {
    final statusColor = _statusColor(order.orderStatus);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Logo + company info
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/logo_icon.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.agriculture_rounded, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  const Text('Agrimore',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('17/354 J Kandha Samy Nagar, Vinayagapuram,\nNaragingapuram (PO), Attur (TK), Salem (DT), 636108',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Text('Phone: +91 8610787151  •  Email: saai.siddharth.t@gmail.com',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),

            // Small order actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: order.orderNumber));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Order ID copied'),
                      backgroundColor: AppColors.primary,
                    ));
                  },
                  icon: Icon(Icons.copy_rounded, color: AppColors.primary),
                  tooltip: 'Copy Order ID',
                ),
                const SizedBox(height: 4),
                Text('Order #${order.orderNumber ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEE, MMM d • hh:mm a').format(order.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // Stats Row
  // =========================
  Widget _orderStatsCard(OrderModel order) {
    return Row(
      children: [
        Expanded(
            child: _statCard(
                icon: Icons.shopping_bag_rounded,
                label: 'Items',
                value: '${order.items.length}',
                color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
                icon: Icons.info_rounded,
                label: 'Status',
                value: order.orderStatus.toUpperCase(),
                color: _statusColor(order.orderStatus))),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
                icon: Icons.payment_rounded,
                label: 'Payment',
                value: order.paymentStatus.toUpperCase(),
                color: order.paymentStatus.toLowerCase() == 'paid'
                    ? Colors.green
                    : Colors.orange)),
      ],
    );
  }

  Widget _statCard(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 6))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).moveY(begin: 6, end: 0);
  }

  // =========================
  // Customer Card (compact)
  // =========================
  Widget _customerCard(OrderModel order) {
    final a = order.deliveryAddress;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(a.name.isNotEmpty ? a.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(a.phone, style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    Text(a.fullAddress,
                        style: TextStyle(color: Colors.grey[700], height: 1.3),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            PopupMenuButton<int>(
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 1, child: Text('Copy Phone')),
                const PopupMenuItem(value: 2, child: Text('Open WhatsApp')),
              ],
              onSelected: (v) {
                if (v == 1) {
                  Clipboard.setData(ClipboardData(text: a.phone));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Phone copied'),
                      backgroundColor: AppColors.primary));
                } else {
                  _openWhatsApp(a.phone);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // Location Card (compact + shows payment mode & status instead of big map area)
  // =========================
  Widget _locationCard(OrderModel order) {
    final a = order.deliveryAddress;
    final hasCoords = a.latitude != null && a.longitude != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded,
                color: AppColors.primary.withValues(alpha: 0.9)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Location',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(a.fullAddress,
                      style: TextStyle(color: Colors.grey[800], height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // compact representation for payment method + status
                Text(_friendlyPaymentMethod(order.paymentMethod),
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: order.paymentStatus.toLowerCase() == 'paid'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: order.paymentStatus.toLowerCase() == 'paid'
                              ? Colors.green.shade200
                              : Colors.orange.shade200)),
                  child: Text(order.paymentStatus.toUpperCase(),
                      style: TextStyle(
                          color: order.paymentStatus.toLowerCase() == 'paid'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                const SizedBox(height: 8),
                IconButton(
                    onPressed: () => _launchGoogleMaps(order),
                    icon: const Icon(Icons.map_rounded, color: Colors.blue)),
                IconButton(
                    onPressed: () {
                      if (hasCoords) {
                        _copyCoords(a.latitude!, a.longitude!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Coordinates not available')));
                      }
                    },
                    icon: const Icon(Icons.copy_rounded))
              ],
            )
          ],
        ),
      ),
    );
  }

  // =========================
  // Items Card
  // =========================
  Widget _itemsCard(OrderModel order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items (${order.items.length})',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Column(
              children: order.items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.productImage != null &&
                                      item.productImage.isNotEmpty
                                  ? Image.network(item.productImage,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover, errorBuilder:
                                          (_, __, ___) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child:
                                            const Icon(Icons.shopping_bag),
                                      );
                                    })
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.shopping_bag),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      _smallBadge('Qty: ${item.quantity}',
                                          color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text('₹${item.price.toStringAsFixed(0)}'),
                                    ]),
                                  ]),
                            ),
                            Text(
                                '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ))
                  .toList(),
            )
          ],
        ),
      ),
    );
  }

  // =========================
  // Pricing Card
  // =========================
  Widget _pricingCard(OrderModel order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Price Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _priceRow('Subtotal', order.subtotal),
          const SizedBox(height: 8),
          _priceRow('Delivery', order.deliveryCharge),
          const SizedBox(height: 8),
          _priceRow('Tax', order.tax),
          if ((order.discount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _priceRow('Discount', -(order.discount ?? 0), isDiscount: true),
          ],
          const Divider(height: 22),
          _priceRow('Total', order.total, isTotal: true),
        ]),
      ),
    );
  }

  Widget _priceRow(String label, double amount,
      {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 15 : 13,
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.grey[800])),
          Text(
            '${isDiscount ? '-' : ''}₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: isTotal ? 16 : 13,
                fontWeight: FontWeight.w700,
                color: isDiscount
                    ? Colors.green[700]
                    : (isTotal ? AppColors.primary : Colors.grey[900])),
          ),
        ],
      ),
    );
  }

  // =========================
  // Payment Card (detailed)
  // =========================
  Widget _paymentCard(OrderModel order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payment Information',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Method', style: TextStyle(color: Colors.grey[700]))),
              Text(_friendlyPaymentMethod(order.paymentMethod),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Status', style: TextStyle(color: Colors.grey[700]))),
              _smallBadge(order.paymentStatus.toUpperCase(),
                  color: order.paymentStatus.toLowerCase() == 'paid'
                      ? Colors.green.shade700
                      : Colors.orange.shade700),
            ],
          ),
          if (order.razorpayOrderId != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text('Razorpay ID', style: TextStyle(color: Colors.grey[700]))),
              Flexible(child: Text(order.razorpayOrderId ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(onPressed: () {
                Clipboard.setData(ClipboardData(text: order.razorpayOrderId ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Razorpay ID copied')));
              }, icon: const Icon(Icons.copy_rounded, size: 18)),
            ]),
          ],
        ]),
      ),
    );
  }

  // =========================
  // Timeline Card
  // =========================
  Widget _timelineCard(OrderProvider orderProvider) {
    final timeline = orderProvider.selectedOrderTimeline ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Order Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No timeline events', style: TextStyle(color: Colors.grey[600]))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timeline.length,
              itemBuilder: (context, i) {
                final ev = timeline[i];
                final isFirst = i == 0;
                final isLast = i == timeline.length - 1;
                final evColor = isFirst ? AppColors.primary : Colors.grey.shade700;
                return TimelineTile(
                  isFirst: isFirst,
                  isLast: isLast,
                  beforeLineStyle: LineStyle(color: evColor.withValues(alpha: 0.2), thickness: 3),
                  afterLineStyle: LineStyle(color: evColor.withValues(alpha: 0.2), thickness: 3),
                  indicatorStyle: IndicatorStyle(
                    width: 38,
                    height: 38,
                    indicator: Container(
                      decoration: BoxDecoration(
                        color: isFirst ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Center(child: Icon(_timelineIcon(ev.status), color: isFirst ? Colors.white : AppColors.primary, size: 18)),
                    ),
                  ),
                  endChild: Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        children: [
                          Expanded(child: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                            child: Text(ev.statusDisplayName, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ev.description, style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 6),
                      Text(DateFormat('dd MMM yyyy • hh:mm a').format(ev.timestamp), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ]),
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }

  // =========================
  // Utilities
  // =========================
  Widget _smallBadge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Color _statusColor(String s) => _getStatusColor(s);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.deepPurple;
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

  IconData _timelineIcon(dynamic status) {
    final statusStr = (status ?? '').toString().toLowerCase();
    switch (statusStr) {
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
    switch ((method ?? '').toString().toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'netbanking':
        return 'Netbanking';
      default:
        return (method ?? '').toString().toUpperCase();
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot make call')));
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // Use wa.me format — ensure phone includes country code (e.g. 91xxxxxxxxxx)
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open WhatsApp')));
    }
  }

  Future<void> _launchGoogleMaps(OrderModel order) async {
    final a = order.deliveryAddress;
    final hasCoords = a.latitude != null && a.longitude != null;
    final url = hasCoords
        ? 'https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}'
        : 'https://www.google.com/maps/search/${Uri.encodeComponent(a.fullAddress)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open Google Maps');
    }
  }

  void _copyCoords(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat,$lng'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinates copied')));
  }

  void _showSnack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // =========================
  // Invoice generation & export
  // =========================
  Future<void> _exportInvoice(OrderModel order, {required bool preview, required bool share}) async {
    setState(() => _loadingInvoice = true);
    try {
      final pdfBytes = await _generateInvoicePdf(order);

      // Preview
      if (preview) {
        await Printing.layoutPdf(onLayout: (format) => pdfBytes);
      }

      // Share / Download (share sheet + save a temp file)
      if (share) {
        final filename = 'invoice_${order.orderNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        // Attempt to save to temporary directory
        try {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(pdfBytes);
          // open share sheet (this lets user save to downloads or other apps)
          await Printing.sharePdf(bytes: pdfBytes, filename: filename);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved temp copy: ${file.path}')));
        } catch (e) {
          // fallback to share without file
          await Printing.sharePdf(bytes: pdfBytes, filename: 'invoice.pdf');
        }
      }
    } catch (e) {
      _showSnack('Failed to generate invoice: $e');
    } finally {
      if (mounted) setState(() => _loadingInvoice = false);
    }
  }

  Future<Uint8List> _generateInvoicePdf(OrderModel order) async {
    final pdf = pw.Document();

    // Try to load a unicode-capable font so ₹ prints correctly.
    // Tries multiple paths for robustness — please ensure you have one of these fonts
    // added to your project assets and declared in pubspec.yaml:
    //
    // assets/fonts/NotoSans-Regular.ttf
    // assets/fonts/NotoSans-Regular.otf
    // assets/fonts/Inter-Regular.ttf
    // assets/fonts/Noto_Sans-Regular.ttf
    //
    // If none of the above present, the code will try PdfGoogleFonts fallback.
    Uint8List? ttfBytes;
    final fontPaths = [
      'assets/fonts/NotoSans-Regular.ttf',
      'assets/fonts/NotoSans-Regular.otf',
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Regular.otf',
      'assets/fonts/Noto_Sans-Regular.ttf'
    ];
    for (final p in fontPaths) {
      try {
        final bd = await rootBundle.load(p);
        ttfBytes = bd.buffer.asUint8List();
        if (ttfBytes.isNotEmpty) break;
      } catch (_) {
        // try next
      }
    }

    pw.Font baseFont;
    if (ttfBytes != null) {
      baseFont = pw.Font.ttf(ttfBytes.buffer.asByteData());
    } else {
      // As an additional fallback use PdfGoogleFonts where available
      try {
        // Note: PdfGoogleFonts is available in pdf/printing packages and provides fonts at runtime.
        baseFont = await PdfGoogleFonts.notoSansRegular(); // may throw if not available
      } catch (_) {
        // final fallback: helvetica
        baseFont = pw.Font.helvetica();
      }
    }

    // Load logo image (optional) for header
    pw.MemoryImage? logoImage;
    try {
      final logoBd = await rootBundle.load('assets/icons/logo_icon.png');
      logoImage = pw.MemoryImage(logoBd.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    // Company / supplier details
    final supplierName = 'Agrimore';
    final supplierAddress =
        '17/354 J Kandha Samy Nagar, Vinayagapuram,\nNaragingapuram (PO), Attur (TK), Salem (DT), 636108';
    final supplierPhone = '+91 8610787151';
    final supplierEmail = 'saai.siddharth.t@gmail.com';
    final preparedBy = 'Agrimore';

    final customer = order.deliveryAddress;
    final items = order.items ?? [];

    // Money format helper
    String money(double val) => '₹' + val.toStringAsFixed(2);

    // QR data: prefer lat,lng (if available) otherwise unique order URL or order ID
    String qrData;
    if ((customer.latitude != null && customer.longitude != null)) {
      qrData = '${customer.latitude},${customer.longitude}';
    } else {
      // fallback: a tracking URL (replace with your real tracking endpoint if you have one)
      qrData = 'https://agroconnect.example/track/${order.orderNumber}';
    }

    // Build PDF page(s)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return [
            // Header row: logo + company + order badge
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  if (logoImage != null) pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
                  pw.SizedBox(width: 10),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(supplierName,
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green800)),
                        pw.SizedBox(height: 4),
                        pw.Text(supplierAddress,
                            style: pw.TextStyle(font: baseFont, fontSize: 9)),
                        pw.SizedBox(height: 6),
                        pw.Text('Phone: $supplierPhone',
                            style: pw.TextStyle(font: baseFont, fontSize: 9)),
                        pw.Text('Email: $supplierEmail',
                            style: pw.TextStyle(font: baseFont, fontSize: 9)),
                      ])
                ]),
                // Order badge
                pw.Container(
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                      color: PdfColors.grey100),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('ORDER',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 8,
                                color: PdfColors.grey700)),
                        pw.SizedBox(height: 6),
                        pw.Text(order.orderNumber ?? '',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(
                            DateFormat('dd MMM yyyy • hh:mm a')
                                .format(order.createdAt),
                            style: pw.TextStyle(font: baseFont, fontSize: 9)),
                      ]),
                )
              ],
            ),
            pw.SizedBox(height: 12),

            // Shipping label section (ship to + QR)
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // left: ship to block (compact)
                  pw.Expanded(
                    flex: 7,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SHIP TO:',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(customer.name ?? '',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(customer.fullAddress ?? '',
                            style: pw.TextStyle(font: baseFont, fontSize: 10)),
                        pw.SizedBox(height: 8),
                        pw.Text('Phone: ${customer.phone ?? ''}',
                            style: pw.TextStyle(font: baseFont, fontSize: 10)),
                      ],
                    ),
                  ),

                  // right: payment info + QR (compact)
                  pw.SizedBox(width: 12),
                  pw.Container(
                    width: 160,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payment Info',
                            style: pw.TextStyle(
                                font: baseFont,
                                fontSize: 9,
                                color: PdfColors.grey700)),
                        pw.SizedBox(height: 6),
                        // payment method & status + item count
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(_friendlyPaymentMethod(order.paymentMethod),
                                    style: pw.TextStyle(
                                        font: baseFont,
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 4),
                                pw.Text(order.paymentStatus ?? '',
                                    style: pw.TextStyle(font: baseFont, fontSize: 9)),
                                pw.SizedBox(height: 4),
                                pw.Text('Items: ${items.length}',
                                    style:
                                        pw.TextStyle(font: baseFont, fontSize: 9)),
                              ]),
                        ),
                        pw.SizedBox(height: 10),
                        // QR code
                        pw.Center(
                          child: pw.Column(children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              width: 110,
                              height: 110,
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text('Scan for location',
                                style: pw.TextStyle(
                                    font: baseFont, fontSize: 8, color: PdfColors.grey600))
                          ]),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // Items table with colored header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Items', style: pw.TextStyle(font: baseFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Invoice # ${order.orderNumber}', style: pw.TextStyle(font: baseFont, fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 8),

            pw.Table.fromTextArray(
              headers: ['#', 'Product', 'Qty', 'Price', 'Total'],
              data: [
                for (int i = 0; i < items.length; i++)
                  [
                    (i + 1).toString(),
                    items[i].productName ?? '',
                    (items[i].quantity ?? 1).toString(),
                    money(items[i].price ?? 0.0),
                    money((items[i].price ?? 0.0) * (items[i].quantity ?? 1)),
                  ],
              ],
              headerStyle: pw.TextStyle(font: baseFont, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.black),
              headerDecoration: pw.BoxDecoration(color: PdfColors.green800),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.8),
              },
            ),

            pw.SizedBox(height: 12),

            // Price summary (right aligned)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _pdfPriceRow(baseFont, 'Subtotal', money(order.subtotal ?? 0.0)),
                      pw.Divider(),
                      _pdfPriceRow(baseFont, 'Delivery', money(order.deliveryCharge ?? 0.0)),
                      _pdfPriceRow(baseFont, 'Tax', money(order.tax ?? 0.0)),
                      if ((order.discount ?? 0) > 0) _pdfPriceRow(baseFont, 'Discount', '-${money(order.discount ?? 0.0)}'),
                      pw.Divider(),
                      _pdfPriceRow(baseFont, 'TOTAL', money(order.total ?? 0.0), isBold: true),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Notes & prepared by
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Notes', style: pw.TextStyle(font: baseFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text(order.notes ?? '', style: pw.TextStyle(font: baseFont, fontSize: 9)),
                  ]),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  width: 140,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Prepared by', style: pw.TextStyle(font: baseFont, fontSize: 9)),
                    pw.SizedBox(height: 6),
                    pw.Text(preparedBy, style: pw.TextStyle(font: baseFont, fontSize: 11, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfPriceRow(pw.Font baseFont, String title, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: baseFont, fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(font: baseFont, fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}