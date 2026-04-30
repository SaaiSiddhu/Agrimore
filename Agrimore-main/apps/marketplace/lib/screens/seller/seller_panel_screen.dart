import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/seller_provider.dart';
import '../../app/routes.dart';
import 'seller_dashboard_screen.dart';
import 'seller_apply_screen.dart';

/// Seller Panel - Bottom tab navigation for sellers
class SellerPanelScreen extends StatefulWidget {
  const SellerPanelScreen({Key? key}) : super(key: key);

  @override
  State<SellerPanelScreen> createState() => _SellerPanelScreenState();
}

class _SellerPanelScreenState extends State<SellerPanelScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SellerProvider>().checkSellerStatus();
    });
  }

  final List<Widget> _screens = const [
    SellerDashboardScreen(),
    // Seller Products and Orders can be added here later
    // For now we show the dashboard
    _SellerProductsPlaceholder(),
    _SellerOrdersPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerProvider>(
      builder: (context, sp, _) {
        if (sp.isLoading && sp.sellerStatus == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!sp.isApproved) {
          return _SellerAccessPlaceholder(status: sp.sellerStatus);
        }
        return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.dashboard, 'Dashboard'),
                _navItem(1, Icons.inventory_2, 'Products'),
                _navItem(2, Icons.shopping_bag, 'Orders'),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF145A32).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF145A32) : const Color(0xFF9CA3AF), size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? const Color(0xFF145A32) : const Color(0xFF9CA3AF),
                )),
          ],
        ),
      ),
    );
  }
}

class _SellerAccessPlaceholder extends StatelessWidget {
  final String? status;

  const _SellerAccessPlaceholder({this.status});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    return Scaffold(
      appBar: AppBar(title: const Text('Seller access')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                size: 64,
                color: isRejected ? Colors.redAccent : const Color(0xFF145A32),
              ),
              const SizedBox(height: 16),
              Text(
                isRejected
                    ? 'Your seller application was not approved.'
                    : isPending
                        ? 'Your seller application is pending admin approval.'
                        : 'Seller access requires registration and approval.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.sellerApply),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF145A32),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: Text(isPending ? 'View application' : 'Seller registration'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerProductsPlaceholder extends StatefulWidget {
  const _SellerProductsPlaceholder({Key? key}) : super(key: key);

  @override
  State<_SellerProductsPlaceholder> createState() => _SellerProductsPlaceholderState();
}

class _SellerProductsPlaceholderState extends State<_SellerProductsPlaceholder> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: uid)
          .get();
      setState(() {
        _products = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Seller products error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Products', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF145A32),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_products.length} items',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF145A32)))
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.inventory_2, size: 64, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 16),
                            Text('No Products Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                            SizedBox(height: 8),
                            Text('Your listed products will appear here', style: TextStyle(color: Color(0xFF6B7280))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            final name = p['name'] ?? 'Unnamed Product';
                            final price = (p['salePrice'] as num?)?.toDouble() ?? (p['price'] as num?)?.toDouble() ?? 0;
                            final stock = p['stock'] ?? 0;
                            final isActive = p['isActive'] ?? true;
                            final variants = (p['variants'] as List<dynamic>?)
                                    ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
                                    .toList() ??
                                [];
                            final merged = ProductModel.mergeImageSources(
                              Map<String, dynamic>.from(p),
                              variants,
                            );
                            final imageUrl = merged.isNotEmpty ? merged.first : null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  // Product Image
                                  Container(
                                    width: 56, height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                      image: imageUrl != null
                                          ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: imageUrl == null
                                        ? const Icon(Icons.image, color: Color(0xFF9CA3AF), size: 24)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('₹${price.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: stock > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                stock > 0 ? 'Stock: $stock' : 'Out of stock',
                                                style: TextStyle(
                                                  fontSize: 10, fontWeight: FontWeight.w700,
                                                  color: stock > 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status
                                  Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SellerOrdersPlaceholder extends StatefulWidget {
  const _SellerOrdersPlaceholder({Key? key}) : super(key: key);

  @override
  State<_SellerOrdersPlaceholder> createState() => _SellerOrdersPlaceholderState();
}

class _SellerOrdersPlaceholderState extends State<_SellerOrdersPlaceholder> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  static const Map<String, Color> _statusColors = {
    'placed': Color(0xFF3B82F6),
    'accepted': Color(0xFF8B5CF6),
    'out for delivery': Color(0xFFF59E0B),
    'delivered': Color(0xFF16A34A),
    'cancelled': Color(0xFFEF4444),
  };

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _orders = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Seller orders error: $e');
      // Fallback without orderBy if index is missing
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .where('sellerId', isEqualTo: uid)
            .get();
        setState(() {
          _orders = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _orders.sort((a, b) {
            final aT = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bT = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bT.compareTo(aT);
          });
          _loading = false;
        });
      } catch (e2) {
        debugPrint('Seller orders fallback error: $e2');
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated to ${newStatus.toUpperCase()}'),
            backgroundColor: const Color(0xFF145A32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF145A32),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_orders.length} orders',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF145A32)))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shopping_bag, size: 64, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 16),
                            Text('No Orders Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                            SizedBox(height: 8),
                            Text('Orders from customers will appear here', style: TextStyle(color: Color(0xFF6B7280))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final o = _orders[index];
                            final status = (o['status'] ?? 'placed') as String;
                            final color = _statusColors[status] ?? const Color(0xFF6B7280);
                            final products = o['products'] as List<dynamic>? ?? [];
                            final amt = (o['totalAmount'] as num?)?.toDouble() ?? 0;
                            final id = (o['id'] ?? '').toString();
                            final customerName = o['userName'] ?? o['customerName'] ?? 'Customer';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Order header
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(customerName,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                                            const SizedBox(height: 2),
                                            Text('#${id.length > 6 ? id.substring(0, 6).toUpperCase() : id} • ${products.length} items',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('₹${amt.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(status.toUpperCase(),
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Action buttons
                                  if (status == 'placed' || status == 'accepted') ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.only(top: 12),
                                      decoration: const BoxDecoration(
                                        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                                      ),
                                      child: Row(
                                        children: [
                                          if (status == 'placed') ...[
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => _updateOrderStatus(o['id'], 'accepted'),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF145A32),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => _updateOrderStatus(o['id'], 'cancelled'),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w700)),
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (status == 'accepted')
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => _updateOrderStatus(o['id'], 'out for delivery'),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF59E0B),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Text('Ship Order', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

