import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';
import 'order_detail_screen.dart';

enum _OrderModeFilter { all, b2b, retail }

/// Dedicated Orders screen for Sales Associates.
///
/// Streams orders attributed to this associate (`orders.employeeUid == uid`),
/// ordered by `createdAt` descending, bounded by `_pageSize` pagination.
/// Supports search filtering and mode filtering (All, B2B, Retail).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _pageSize = 20;
  _OrderModeFilter _modeFilter = _OrderModeFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: SaTokens.pageBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Attributed Orders'),
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: SaTokens.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: SaTokens.space16,
              vertical: SaTokens.space12,
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search order number...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(SaIcons.x, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SaTokens.space12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: SaTokens.space8),

                // Mode Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Orders', _OrderModeFilter.all),
                      const SizedBox(width: SaTokens.space8),
                      _buildFilterChip('B2B Orders', _OrderModeFilter.b2b),
                      const SizedBox(width: SaTokens.space8),
                      _buildFilterChip('Retail Orders', _OrderModeFilter.retail),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SaTokens.divider),

          // Orders Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('employeeUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(_pageSize)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SaTokens.space24),
                      child: Text('Error loading orders: ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs;

                // Client-side filtering for search & mode
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data();
                  final orderNum =
                      (data['orderNumber']?.toString() ?? doc.id).toLowerCase();

                  if (_searchQuery.isNotEmpty &&
                      !orderNum.contains(_searchQuery)) {
                    return false;
                  }

                  final rawMode = data['orderMode'];
                  final normMode = rawMode is String
                      ? rawMode.trim().toUpperCase()
                      : '';

                  if (_modeFilter == _OrderModeFilter.b2b && normMode != 'B2B') {
                    return false;
                  }
                  if (_modeFilter == _OrderModeFilter.retail &&
                      normMode != 'B2C') {
                    return false;
                  }

                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SaTokens.space32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: SaTokens.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              SaIcons.shoppingBag,
                              size: 32,
                              color: SaTokens.primary,
                            ),
                          ),
                          const SizedBox(height: SaTokens.space16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No orders match "$_searchQuery"'
                                : 'No attributed orders found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: SaTokens.space4),
                          Text(
                            'Orders placed with your associate code will appear here.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final reachedPageLimit = allDocs.length >= _pageSize;

                return ListView.builder(
                  padding: const EdgeInsets.all(SaTokens.space16),
                  itemCount: filteredDocs.length + (reachedPageLimit ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredDocs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: SaTokens.space16,
                        ),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _pageSize += 20),
                            child: const Text('Load more orders'),
                          ),
                        ),
                      );
                    }

                    final doc = filteredDocs[index];
                    final d = doc.data();
                    return _buildOrderCard(context, doc.id, d);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _OrderModeFilter filter) {
    final selected = _modeFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _modeFilter = filter);
      },
      selectedColor: SaTokens.primarySubtle,
      backgroundColor: SaTokens.surface,
      labelStyle: TextStyle(
        fontSize: SaTokens.fsLabel,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? SaTokens.primary : SaTokens.textSecondary,
      ),
      side: BorderSide(
        color: selected ? SaTokens.primary : SaTokens.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final orderNumber = data['orderNumber']?.toString() ?? docId;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final status = (data['orderStatus'] ?? 'pending').toString().toLowerCase();
    final rawMode = data['orderMode'];
    final normMode = rawMode is String ? rawMode.trim().toUpperCase() : null;
    final isDelivered = status == 'delivered' || status == 'completed';
    final isCancelled = status == 'cancelled';

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    final commissionPaid = data['commissionPaid'] == true;
    final commissionAmount = (data['commissionAmount'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: SaTokens.space12),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: docId,
                orderData: data,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(SaTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: order number + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$orderNumber',
                    style: const TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: SaTokens.textPrimary,
                    ),
                  ),
                  _buildStatusBadge(status, isDelivered, isCancelled),
                ],
              ),
              const SizedBox(height: SaTokens.space8),

              // Details row: Mode + Date + Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (normMode != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: normMode == 'B2B'
                                ? SaTokens.primarySubtle
                                : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            normMode == 'B2B' ? 'B2B' : 'Retail',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: normMode == 'B2B'
                                  ? SaTokens.primary
                                  : Colors.purple.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: SaTokens.space8),
                      ],
                      if (createdAt != null)
                        Text(
                          SaFormatters.formatDate(createdAt),
                          style: const TextStyle(
                            fontSize: SaTokens.fsCaption,
                            color: SaTokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    SaFormatters.formatCurrency(total),
                    style: const TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: SaTokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SaTokens.space8),

              // Commission indicator row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SaTokens.space8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: commissionPaid
                      ? SaTokens.successBg
                      : SaTokens.pageBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      commissionPaid
                          ? SaIcons.circleCheck
                          : Icons.schedule_rounded,
                      size: 13,
                      color: commissionPaid
                          ? SaTokens.successFg
                          : SaTokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      commissionPaid && commissionAmount != null
                          ? 'Commission ${SaFormatters.formatCurrency(commissionAmount)} credited'
                          : (isDelivered
                              ? 'Commission processing'
                              : 'Commission pending delivery'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: commissionPaid
                            ? SaTokens.successFg
                            : SaTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String status,
    bool isDelivered,
    bool isCancelled,
  ) {
    Color bg = SaTokens.warningBg;
    Color fg = SaTokens.warningFg;

    if (isDelivered) {
      bg = SaTokens.successBg;
      fg = SaTokens.successFg;
    } else if (isCancelled) {
      bg = SaTokens.errorBg;
      fg = SaTokens.errorFg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
