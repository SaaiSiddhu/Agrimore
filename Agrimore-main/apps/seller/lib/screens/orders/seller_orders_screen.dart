// lib/screens/orders/seller_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:intl/intl.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';
import 'seller_order_detail_screen.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<SellerAuthProvider>();
      if (auth.currentUser != null) {
        context.read<SellerOrderProvider>().loadSellerOrders(auth.currentUser!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Order Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final auth = context.read<SellerAuthProvider>();
              if (auth.currentUser != null) {
                context.read<SellerOrderProvider>().loadSellerOrders(auth.currentUser!.uid);
              }
            },
          ),
        ],
      ),
      body: Consumer<SellerOrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2D7D3C)));
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final auth = context.read<SellerAuthProvider>();
                      if (auth.currentUser != null) {
                        provider.loadSellerOrders(auth.currentUser!.uid);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Stats Row
              _buildStatsRow(provider, isDark),
              const SizedBox(height: 8),
              // Filter Chips
              _buildFilterChips(provider, isDark),
              const SizedBox(height: 8),
              // Orders List
              Expanded(
                child: provider.orders.isEmpty
                    ? _buildEmptyState(provider.selectedFilter)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.orders.length,
                        itemBuilder: (context, index) {
                          return _buildOrderCard(provider.orders[index], isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(SellerOrderProvider provider, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D7D3C), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2D7D3C).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Total', provider.totalOrders.toString(), Icons.receipt_long),
          _buildMiniStatDivider(),
          _buildMiniStat('Pending', provider.pendingOrders.toString(), Icons.pending_actions),
          _buildMiniStatDivider(),
          _buildMiniStat('Revenue', '₹${provider.totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildMiniStatDivider() {
    return Container(width: 1, height: 40, color: Colors.white24);
  }

  Widget _buildFilterChips(SellerOrderProvider provider, bool isDark) {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': provider.totalOrders},
      {'key': 'pending', 'label': 'Pending', 'count': provider.pendingOrders},
      {'key': 'processing', 'label': 'Processing', 'count': provider.processingOrders},
      {'key': 'shipped', 'label': 'Shipped', 'count': provider.shippedOrders},
      {'key': 'delivered', 'label': 'Delivered', 'count': provider.deliveredOrders},
      {'key': 'cancelled', 'label': 'Cancelled', 'count': provider.cancelledOrders},
    ];

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = provider.selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${f['label']} (${f['count']})'),
              selected: isSelected,
              onSelected: (_) => provider.setFilter(f['key'] as String),
              selectedColor: const Color(0xFF2D7D3C).withOpacity(0.2),
              checkmarkColor: const Color(0xFF2D7D3C),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2D7D3C) : null,
              ),
              side: BorderSide(color: isSelected ? const Color(0xFF2D7D3C) : Colors.grey.shade300),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isDark) {
    final statusColor = _getStatusColor(order.orderStatus);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SellerOrderDetailScreen(order: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order number + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.getStatusDisplay(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Items preview
              ...order.items.take(2).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                            image: item.productImage.isNotEmpty
                                ? DecorationImage(image: NetworkImage(item.productImage), fit: BoxFit.cover)
                                : null,
                          ),
                          child: item.productImage.isEmpty ? const Icon(Icons.image, size: 16, color: Colors.grey) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${item.productName} × ${item.quantity}',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
              if (order.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${order.items.length - 2} more items',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const Divider(height: 20),
              // Footer: date + total + action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text(
                    '₹${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D7D3C)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            filter == 'all' ? 'No orders yet' : 'No $filter orders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when customers purchase your products',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'shipped':
      case 'out_for_delivery':
      case 'outfordelivery':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
