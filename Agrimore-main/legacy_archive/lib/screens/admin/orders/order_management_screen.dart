// lib/screens/admin/orders/order_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import 'admin_order_details_screen.dart';
import 'widgets/admin_order_card.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({Key? key}) : super(key: key);

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _filterIndex = 0; // 0=All, 1=Pending, 2=Processing, 3=Shipped, 4=Completed
  bool _selectionMode = false;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false).loadOrders();
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedOrderIds.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      _selectedOrderIds.contains(id)
          ? _selectedOrderIds.remove(id)
          : _selectedOrderIds.add(id);
      if (_selectedOrderIds.isEmpty) _selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedOrderIds.clear();
    });
  }

  Future<void> _bulkCancelOrders(OrderProvider provider) async {
    if (_selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel selected orders'),
        content: Text(
          'Are you sure you want to cancel ${_selectedOrderIds.length} order(s)?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final id in _selectedOrderIds) {
        await provider.cancelOrder(id, 'Cancelled by admin');
      }

      _clearSelection();
      provider.loadOrders();

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Cancelled ${_selectedOrderIds.length} order(s)',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to cancel selected orders');
      }
    }
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var filtered = orders;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        final orderNumber = o.orderNumber?.toLowerCase() ?? '';
        final id = o.id.toLowerCase();
        final name = o.deliveryAddress?.name?.toLowerCase() ?? '';
        final phone = o.deliveryAddress?.phone ?? '';
        return orderNumber.contains(query) ||
            id.contains(query) ||
            name.contains(query) ||
            phone.contains(query);
      }).toList();
    }

    switch (_filterIndex) {
      case 1:
        filtered = filtered.where((o) => o.status == 'pending').toList();
        break;
      case 2:
        filtered = filtered.where((o) => o.status == 'processing').toList();
        break;
      case 3:
        filtered = filtered.where((o) => o.status == 'shipped').toList();
        break;
      case 4:
        filtered = filtered.where((o) => o.status == 'completed').toList();
        break;
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final allOrders = provider.orders;
        final filtered = _filterOrders(allOrders);

        final total = allOrders.length;
        final pending = allOrders.where((o) => o.status == 'pending').length;
        final processing =
            allOrders.where((o) => o.status == 'processing').length;
        final shipped = allOrders.where((o) => o.status == 'shipped').length;
        final completed =
            allOrders.where((o) => o.status == 'completed').length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            title: _selectionMode
                ? Text('${_selectedOrderIds.length} selected')
                : const Text('Order Management'),
            actions: _selectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.cancel_schedule_send_outlined),
                      tooltip: 'Cancel Orders',
                      onPressed: () => _bulkCancelOrders(provider),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel Selection',
                      onPressed: _clearSelection,
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: provider.loadOrders,
                    ),
                  ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSearchAndFilters(),
                  const SizedBox(height: 12),
                  _buildStatsGrid(total, pending, processing, shipped, completed),
                  const SizedBox(height: 12),
                  Expanded(child: _buildContent(provider, filtered)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search orders by ID, name, or phone...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _filterChip(0, 'All'),
            _filterChip(1, 'Pending'),
            _filterChip(2, 'Processing'),
            _filterChip(3, 'Shipped'),
            _filterChip(4, 'Completed'),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(int index, String label) {
    final selected = _filterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterIndex = index),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
    );
  }

  Widget _buildStatsGrid(
      int total, int pending, int processing, int shipped, int completed) {
    final stats = [
      {'title': 'Total', 'value': total, 'icon': Icons.list_alt_rounded, 'color': AppColors.primary},
      {'title': 'Pending', 'value': pending, 'icon': Icons.pending_actions_rounded, 'color': Colors.orange},
      {'title': 'Processing', 'value': processing, 'icon': Icons.sync_rounded, 'color': Colors.blue},
      {'title': 'Shipped', 'value': shipped, 'icon': Icons.local_shipping_rounded, 'color': Colors.teal},
      {'title': 'Completed', 'value': completed, 'icon': Icons.check_circle_rounded, 'color': Colors.green},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats.map((s) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['title'].toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    s['value'].toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContent(OrderProvider provider, List<OrderModel> orders) {
    if (provider.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No orders match your search'
                  : 'No orders found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        provider.loadOrders();
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final order = orders[i];
          final isSelected = _selectedOrderIds.contains(order.id);

          return GestureDetector(
            onLongPress: () => _enterSelectionMode(order.id),
            child: Stack(
              children: [
                AdminOrderCard(
                  order: order,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AdminOrderDetailsScreen(orderId: order.id)),
                  ),
                ),
                if (_selectionMode)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelect(order.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}