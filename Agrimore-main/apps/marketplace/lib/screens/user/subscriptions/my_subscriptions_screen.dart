import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({Key? key}) : super(key: key);

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    FirebaseFirestore.instance
        .collection('subscriptions')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      setState(() {
        _subscriptions = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    }, onError: (e) {
      debugPrint('Subscriptions error: $e');
      setState(() => _loading = false);
    });
  }

  Future<void> _toggleStatus(String id, bool current) async {
    try {
      await FirebaseFirestore.instance.collection('subscriptions').doc(id).update({'isActive': !current});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleCancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text('Are you sure you want to completely cancel and delete this auto-delivery subscription?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel It'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('subscriptions').doc(id).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20, left: 16, right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF145A32),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
              boxShadow: [BoxShadow(color: Color(0x40145A32), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: Color(0xFFD4A843), size: 24)),
                ),
                const Expanded(
                  child: Text('My Subscriptions', textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD4A843), fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF145A32)))
                : _subscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.repeat, color: Color(0xFF9CA3AF), size: 48),
                            SizedBox(height: 20),
                            Text('You have no active auto-deliveries.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _subscriptions.length,
                        itemBuilder: (context, i) => _buildSubCard(_subscriptions[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCard(Map<String, dynamic> sub) {
    final isActive = sub['isActive'] == true;
    final freq = (sub['frequency'] ?? 'weekly').toString().toUpperCase();
    final isDaily = freq == 'DAILY';
    final nextRun = sub['nextRunDate'] as String? ?? '';
    DateTime? nextDate;
    try { nextDate = DateTime.parse(nextRun); } catch (_) {}
    final isDue = isActive && nextDate != null && nextDate.isBefore(DateTime.now());

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub['productName'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                      const SizedBox(height: 2),
                      Text('${sub['quantity'] ?? 1}x • ₹${sub['price'] ?? 0} per drop',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDaily ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(freq,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                          color: isDaily ? const Color(0xFFB45309) : const Color(0xFF1D4ED8))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Next delivery
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                const Text('Next Delivery: ', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                Text(
                  nextDate != null
                      ? '${nextDate.day}/${nextDate.month}/${nextDate.year} ${(sub['deliverySlot'] ?? '').toString().split(' ').first}'
                      : 'N/A',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: isDue ? const Color(0xFFEF4444) : const Color(0xFF374151)),
                ),
              ],
            ),
            // Actions
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.only(top: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
              child: Row(
                children: [
                  if (isDue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('DUE NOW', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  const Spacer(),
                  // Pause/Resume
                  GestureDetector(
                    onTap: () => _toggleStatus(sub['id'], isActive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isActive ? Icons.pause : Icons.play_arrow,
                              size: 14, color: isActive ? const Color(0xFF374151) : const Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(isActive ? 'Pause' : 'Resume',
                              style: const TextStyle(color: Color(0xFF374151), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel
                  GestureDetector(
                    onTap: () => _handleCancel(sub['id']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                          SizedBox(width: 6),
                          Text('Cancel', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
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
}
