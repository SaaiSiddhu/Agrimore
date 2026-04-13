// lib/screens/admin/orders/order_management_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:intl/intl.dart';
import '../../../app/themes/admin_colors.dart';
import '../../../providers/order_provider.dart';

// Conditional import for web download
import 'web_download_stub.dart' if (dart.library.html) 'web_download_impl.dart' as web_download;

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
  int _filterIndex = 0; // 0=All, 1=Pending, 2=Processing, 3=Shipped, 4=Completed, 5=Cancelled
  bool _showSuggestions = false;
  final FocusNode _searchFocusNode = FocusNode();
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

  void _selectAll(List<OrderModel> orders) {
    setState(() {
      _selectionMode = true;
      _selectedOrderIds.addAll(orders.map((o) => o.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedOrderIds.clear();
    });
  }

  // Bulk update status
  Future<void> _bulkUpdateStatus(OrderProvider provider, String newStatus) async {
    if (_selectedOrderIds.isEmpty) return;

    final statusName = newStatus.substring(0, 1).toUpperCase() + newStatus.substring(1);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update to $statusName'),
        content: Text(
          'Update ${_selectedOrderIds.length} order(s) to "$statusName"?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primary),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final id in _selectedOrderIds) {
        await provider.updateOrderStatus(id, newStatus);
      }
      _clearSelection();
      provider.loadOrders();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Updated ${_selectedOrderIds.length} order(s)');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update orders');
      }
    }
  }

  Future<void> _bulkCancelOrders(OrderProvider provider) async {
    if (_selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Orders'),
        content: Text(
          'Cancel ${_selectedOrderIds.length} order(s)? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        SnackbarHelper.showSuccess(context, 'Cancelled ${_selectedOrderIds.length} order(s)');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to cancel orders');
      }
    }
  }

  // Export to CSV
  void _exportToCSV(List<OrderModel> orders) {
    if (orders.isEmpty) {
      SnackbarHelper.showError(context, 'No orders to export');
      return;
    }

    // Build CSV content
    final List<String> headers = [
      'Order ID',
      'Order Number',
      'Customer Name',
      'Phone',
      'Address',
      'Status',
      'Total',
      'Items Count',
      'Created At',
    ];

    final List<List<String>> rows = orders.map((order) {
      return [
        order.id,
        order.orderNumber ?? '',
        order.deliveryAddress?.name ?? '',
        order.deliveryAddress?.phone ?? '',
        order.deliveryAddress?.fullAddress ?? '',
        order.status,
        order.total.toStringAsFixed(2),
        order.items.length.toString(),
        DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
      ];
    }).toList();

    // Convert to CSV string
    final csvContent = StringBuffer();
    csvContent.writeln(headers.join(','));
    for (final row in rows) {
      csvContent.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
    }

    if (kIsWeb) {
      // Web download using conditional import
      final bytes = utf8.encode(csvContent.toString());
      final filename = 'orders_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      web_download.downloadFile(bytes, filename);
    } else {
      // Mobile - show message (could implement share functionality later)
      SnackbarHelper.showInfo(context, 'CSV export is only available on web');
      return;
    }

    SnackbarHelper.showSuccess(context, 'Exported ${orders.length} orders to CSV');
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
      case 5:
        filtered = filtered.where((o) => o.status == 'cancelled').toList();
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
        final processing = allOrders.where((o) => o.status == 'processing').length;
        final shipped = allOrders.where((o) => o.status == 'shipped').length;
        final completed = allOrders.where((o) => o.status == 'completed').length;
        final cancelled = allOrders.where((o) => o.status == 'cancelled').length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              children: [
                // Premium Header Section
                _buildHeader(provider, filtered, allOrders, total, pending, processing, shipped, completed, cancelled),
                // Content
                Expanded(child: _buildContent(provider, filtered)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(OrderProvider provider, List<OrderModel> filtered, List<OrderModel> allOrders,
      int total, int pending, int processing, int shipped, int completed, int cancelled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selection mode header
          if (_selectionMode) ...[
            _buildSelectionHeader(provider),
          ] else ...[
            // Normal mode - Search row with actions
            _buildSearchRow(provider, filtered, allOrders),
          ],
          const SizedBox(height: 14),
          // Filter tabs with counts
          _buildFilterTabs(total, pending, processing, shipped, completed, cancelled),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(OrderProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _clearSelection,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_selectedOrderIds.length} selected',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Bulk actions - compact buttons
          _buildCompactAction(Icons.check_circle, 'Done', Colors.green, 
              () => _bulkUpdateStatus(provider, 'completed')),
          const SizedBox(width: 8),
          _buildCompactAction(Icons.local_shipping, 'Ship', Colors.teal,
              () => _bulkUpdateStatus(provider, 'shipped')),
          const SizedBox(width: 8),
          _buildCompactAction(Icons.cancel, 'Cancel', Colors.red,
              () => _bulkCancelOrders(provider)),
        ],
      ),
    );
  }

  Widget _buildCompactAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow(OrderProvider provider, List<OrderModel> filtered, List<OrderModel> allOrders) {
    // Generate search suggestions from orders
    final suggestions = <String>[];
    for (final order in allOrders) {
      if (order.orderNumber != null && order.orderNumber!.isNotEmpty) {
        suggestions.add(order.orderNumber!);
      }
      if (order.deliveryAddress?.name != null && order.deliveryAddress!.name!.isNotEmpty) {
        suggestions.add(order.deliveryAddress!.name!);
      }
      if (order.deliveryAddress?.phone != null && order.deliveryAddress!.phone!.isNotEmpty) {
        suggestions.add(order.deliveryAddress!.phone!);
      }
    }
    
    // Filter suggestions based on current query
    final filteredSuggestions = _searchQuery.isEmpty 
        ? <String>[] 
        : suggestions.toSet().where((s) => s.toLowerCase().contains(_searchQuery.toLowerCase())).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Search bar with autocomplete
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: _showSuggestions && filteredSuggestions.isNotEmpty
                      ? Border.all(color: AdminColors.primary.withOpacity(0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 46,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                            _showSuggestions = value.isNotEmpty;
                          });
                        },
                        onTap: () {
                          if (_searchQuery.isNotEmpty) {
                            setState(() => _showSuggestions = true);
                          }
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by order ID, name, phone...',
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: AdminColors.primary, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _showSuggestions = false;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    // Autocomplete suggestions
                    if (_showSuggestions && filteredSuggestions.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          children: filteredSuggestions.map((suggestion) {
                            return InkWell(
                              onTap: () {
                                _searchController.text = suggestion;
                                setState(() {
                                  _searchQuery = suggestion;
                                  _showSuggestions = false;
                                });
                                _searchFocusNode.unfocus();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey.shade100),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      suggestion.contains(RegExp(r'^\d'))
                                          ? Icons.tag_rounded
                                          : Icons.person_outline_rounded,
                                      size: 16,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        suggestion,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.north_west, size: 14, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Action buttons
            _buildIconButton(Icons.select_all_rounded, 'Select All', () => _selectAll(filtered)),
            const SizedBox(width: 8),
            _buildIconButton(Icons.download_rounded, 'Export CSV', () => _exportToCSV(filtered)),
            const SizedBox(width: 8),
            _buildIconButton(Icons.refresh_rounded, 'Refresh', provider.loadOrders),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AdminColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AdminColors.primary, size: 20),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(int total, int pending, int processing, int shipped, int completed, int cancelled) {
    final filters = [
      {'index': 0, 'label': 'All', 'count': total, 'color': AdminColors.primary},
      {'index': 1, 'label': 'Pending', 'count': pending, 'color': Colors.orange},
      {'index': 2, 'label': 'Processing', 'count': processing, 'color': Colors.blue},
      {'index': 3, 'label': 'Shipped', 'count': shipped, 'color': Colors.teal},
      {'index': 4, 'label': 'Completed', 'count': completed, 'color': Colors.green},
      {'index': 5, 'label': 'Cancelled', 'count': cancelled, 'color': Colors.red},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final isSelected = _filterIndex == f['index'];
          final color = f['color'] as Color;
          
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = f['index'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.25) : color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${f['count']}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(OrderProvider provider, List<OrderModel> orders) {
    if (provider.isLoading && orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AdminColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading orders...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No orders match your search'
                  : 'No orders found',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : 'Orders will appear here when customers place them',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AdminColors.primary,
      onRefresh: () async {
        provider.loadOrders();
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final order = orders[i];
          final isSelected = _selectedOrderIds.contains(order.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onLongPress: () => _enterSelectionMode(order.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: AdminColors.primary, width: 2)
                      : null,
                ),
                child: Stack(
                  children: [
                    AdminOrderCard(
                      order: order,
                      onTap: _selectionMode
                          ? () => _toggleSelect(order.id)
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminOrderDetailsScreen(orderId: order.id),
                                ),
                              ),
                    ),
                    if (_selectionMode)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AdminColors.primary : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AdminColors.primary : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.check,
                              size: 18,
                              color: isSelected ? Colors.white : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}