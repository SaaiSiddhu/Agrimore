// lib/screens/earnings/seller_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_order_provider.dart';

class SellerEarningsScreen extends StatefulWidget {
  const SellerEarningsScreen({super.key});

  @override
  State<SellerEarningsScreen> createState() => _SellerEarningsScreenState();
}

class _SellerEarningsScreenState extends State<SellerEarningsScreen> {
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = true;
  double _pendingPayout = 0;
  double _totalPaid = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayouts());
  }

  Future<void> _loadPayouts() async {
    final auth = context.read<SellerAuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('seller_payouts')
          .where('sellerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      double pending = 0;
      double paid = 0;
      final list = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        list.add(data);
        final amt = (data['netAmount'] ?? data['amount'] ?? 0).toDouble();
        if (data['status'] == 'paid') {
          paid += amt;
        } else {
          pending += amt;
        }
      }

      if (mounted) {
        setState(() {
          _payouts = list;
          _pendingPayout = pending;
          _totalPaid = paid;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading payouts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D7D3C)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue summary from order provider
                  Consumer<SellerOrderProvider>(
                    builder: (context, orderProvider, _) {
                      return _buildRevenueSummary(orderProvider, isDark);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Payout cards
                  _buildPayoutCards(isDark),
                  const SizedBox(height: 24),
                  // Payout history
                  _buildPayoutHistory(isDark),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildRevenueSummary(SellerOrderProvider orderProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D7D3C), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2D7D3C).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Revenue', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '₹${orderProvider.totalRevenue.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildRevMini('Today', '₹${orderProvider.todayRevenue.toStringAsFixed(0)}', Icons.today),
              const SizedBox(width: 16),
              _buildRevMini('Orders', orderProvider.deliveredOrders.toString(), Icons.check_circle),
              const SizedBox(width: 16),
              _buildRevMini('Pending', orderProvider.pendingOrders.toString(), Icons.pending_actions),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevMini(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildPayoutCard('Pending Payout', _pendingPayout, Icons.schedule, Colors.orange, isDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPayoutCard('Total Paid', _totalPaid, Icons.account_balance, Colors.green, isDark),
        ),
      ],
    );
  }

  Widget _buildPayoutCard(String title, double amount, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutHistory(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payout History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_payouts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No payouts yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Payouts will appear here once your orders are delivered',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_payouts.length, (i) {
            final p = _payouts[i];
            final status = (p['status'] ?? 'pending') as String;
            final statusColor = status == 'paid' ? Colors.green : (status == 'processing' ? Colors.orange : Colors.grey);
            final amount = (p['netAmount'] ?? p['amount'] ?? 0).toDouble();
            final commission = (p['commissionAmount'] ?? 0).toDouble();
            final ts = p['createdAt'];
            String dateStr = 'N/A';
            if (ts is Timestamp) {
              dateStr = DateFormat('dd MMM yyyy').format(ts.toDate());
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'paid' ? Icons.check_circle : Icons.schedule,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (commission > 0)
                          Text('Commission: ₹${commission.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
