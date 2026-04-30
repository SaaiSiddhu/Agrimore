import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  String _shopName = 'My Shop';
  String _userName = 'Seller';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Get user data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      _userName = userData['name'] ?? 'Seller';
      _shopName = (userData['sellerProfile'] as Map<String, dynamic>?)?['shopName'] ?? 'My Shop';

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // Products
      final productsSnap = await FirebaseFirestore.instance
          .collection('products').where('sellerId', isEqualTo: uid).get();

      // Orders
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders').where('sellerId', isEqualTo: uid).get();

      double todayRevenue = 0, totalRevenue = 0;
      int todayOrders = 0, pendingOrders = 0, deliveredOrders = 0, acceptedOrders = 0;
      final allOrders = <Map<String, dynamic>>[];

      for (final d in ordersSnap.docs) {
        final data = {'id': d.id, ...d.data()};
        allOrders.add(data);
        final amt = (data['totalAmount'] as num?)?.toDouble() ?? 0;

        if (data['status'] == 'delivered') {
          totalRevenue += amt;
          deliveredOrders++;
          final orderDate = (data['createdAt'] as Timestamp?)?.toDate();
          if (orderDate != null && orderDate.isAfter(todayStart)) todayRevenue += amt;
        }
        if (data['status'] == 'placed') pendingOrders++;
        if (data['status'] == 'accepted') acceptedOrders++;

        final orderDate = (data['createdAt'] as Timestamp?)?.toDate();
        if (orderDate != null && orderDate.isAfter(todayStart)) todayOrders++;
      }

      allOrders.sort((a, b) {
        final aT = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bT = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bT.compareTo(aT);
      });

      setState(() {
        _stats = {
          'todayRevenue': todayRevenue,
          'todayOrders': todayOrders,
          'totalRevenue': totalRevenue,
          'totalOrders': ordersSnap.size,
          'totalProducts': productsSnap.size,
          'pendingOrders': pendingOrders,
          'deliveredOrders': deliveredOrders,
          'acceptedOrders': acceptedOrders,
        };
        _recentOrders = allOrders.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Seller dashboard error: $e');
      setState(() => _loading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return '🌅 Good Morning';
    if (h < 17) return '☀️ Good Afternoon';
    return '🌙 Good Evening';
  }

  static const Map<String, Color> _statusColors = {
    'placed': Color(0xFF3B82F6),
    'accepted': Color(0xFF8B5CF6),
    'out for delivery': Color(0xFFF59E0B),
    'delivered': Color(0xFF16A34A),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    final days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateStr = '${days[now.weekday]}, ${now.day} ${months[now.month]}';

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text('🏪 $_shopName',
                      style: const TextStyle(color: Color(0xFF145A32), fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A843)))
                : RefreshIndicator(
                    onRefresh: _fetchStats,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Welcome Banner
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF145A32),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(_greeting.split(' ').first, style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_greeting.substring(_greeting.indexOf(' ') + 1) + ',',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                                    Text('$_userName!',
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: const Text('🟢 Active', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Today Stats
                        Row(
                          children: [
                            _todayCard('₹${(_stats['todayRevenue'] ?? 0.0).toStringAsFixed(0)}', 'Today Revenue',
                                Icons.currency_rupee, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
                            const SizedBox(width: 12),
                            _todayCard('${_stats['todayOrders'] ?? 0}', 'Today Orders',
                                Icons.shopping_cart, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats Grid
                        _statsGrid(),
                        const SizedBox(height: 16),

                        // Status Summary
                        Row(
                          children: [
                            _statusCard('⏳', '${_stats['pendingOrders'] ?? 0}', 'Pending', const Color(0xFFF59E0B)),
                            const SizedBox(width: 10),
                            _statusCard('✅', '${_stats['acceptedOrders'] ?? 0}', 'Accepted', const Color(0xFF8B5CF6)),
                            const SizedBox(width: 10),
                            _statusCard('🎉', '${_stats['deliveredOrders'] ?? 0}', 'Delivered', const Color(0xFF10B981)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Recent Orders
                        const Text('📋 Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        const SizedBox(height: 12),
                        if (_recentOrders.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              children: const [
                                Text('📭', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 8),
                                Text('No orders yet', style: TextStyle(color: Color(0xFF6B7280), fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )
                        else
                          ..._recentOrders.map(_buildOrderCard),

                        // Revenue Note
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('💡 Revenue Info', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w800, fontSize: 13)),
                              SizedBox(height: 4),
                              Text(
                                'Revenue is counted only after an order is marked as "Delivered". Pending and accepted orders are not included.',
                                style: TextStyle(color: Color(0xFF92400E), fontSize: 12, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(String value, String label, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid() {
    final items = [
      {'label': 'Total Revenue', 'val': '₹${(_stats['totalRevenue'] ?? 0.0).toStringAsFixed(0)}', 'icon': Icons.trending_up, 'color': const Color(0xFF10B981), 'bg': const Color(0xFFECFDF5)},
      {'label': 'Total Orders', 'val': '${_stats['totalOrders'] ?? 0}', 'icon': Icons.shopping_cart, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)},
      {'label': 'Products', 'val': '${_stats['totalProducts'] ?? 0}', 'icon': Icons.inventory_2, 'color': const Color(0xFF8B5CF6), 'bg': const Color(0xFFF5F3FF)},
      {'label': 'Delivered', 'val': '${_stats['deliveredOrders'] ?? 0}', 'icon': Icons.check_circle, 'color': const Color(0xFF16A34A), 'bg': const Color(0xFFF0FDF4)},
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((c) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 44) / 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: c['bg'] as Color, borderRadius: BorderRadius.circular(14)),
                  child: Icon(c['icon'] as IconData, color: c['color'] as Color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(c['val'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(c['label'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'placed') as String;
    final color = _statusColors[status] ?? const Color(0xFF6B7280);
    final products = o['products'] as List<dynamic>? ?? [];
    final amt = (o['totalAmount'] as num?)?.toDouble() ?? 0;
    final id = (o['id'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o['userName'] ?? 'Customer',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                Text('#${id.length > 6 ? id.substring(0, 6).toUpperCase() : id} • ${products.length} items',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${amt.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
