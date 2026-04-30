import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionSetupScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final int qty;
  final Map<String, dynamic>? variant;

  const SubscriptionSetupScreen({
    Key? key,
    required this.product,
    required this.qty,
    this.variant,
  }) : super(key: key);

  @override
  State<SubscriptionSetupScreen> createState() => _SubscriptionSetupScreenState();
}

class _SubscriptionSetupScreenState extends State<SubscriptionSetupScreen> {
  bool _loading = false;
  String _frequency = 'weekly';
  String _slot = 'Morning (7 AM - 9 AM)';

  double get _activePrice {
    if (widget.variant != null) {
      return (widget.variant!['discountPrice'] ?? widget.variant!['price'] ?? 0).toDouble();
    }
    return (widget.product['discountPrice'] ?? widget.product['price'] ?? 0).toDouble();
  }

  Future<void> _handleSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user data
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    if (userData['defaultAddress'] == null || userData['location'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a delivery address in your profile first'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final nextRun = DateTime.now().add(const Duration(days: 1));
      final nextRunFormatted = DateTime(nextRun.year, nextRun.month, nextRun.day, 7);

      final productName = widget.variant != null
          ? '${widget.product['name']} (${widget.variant!['label']})'
          : widget.product['name'] ?? '';

      final images = widget.product['images'] as List<dynamic>? ?? [];

      await FirebaseFirestore.instance.collection('subscriptions').add({
        'userId': user.uid,
        'userName': userData['name'] ?? '',
        'userPhone': userData['phone'] ?? '',
        'productId': widget.product['id'] ?? '',
        'productName': productName,
        'productImage': images.isNotEmpty ? images[0] : '',
        'price': _activePrice,
        'quantity': widget.qty,
        'unit': widget.product['unit'] ?? 'nos',
        'frequency': _frequency,
        'deliverySlot': _slot,
        'address': userData['defaultAddress'],
        'location': userData['location'],
        'isActive': true,
        'nextRunDate': nextRunFormatted.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription Active! 🎉 First delivery tomorrow $_slot'),
          backgroundColor: const Color(0xFF145A32),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
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
                  child: Text('Setup Delivery', textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD4A843), fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.repeat, color: Color(0xFF145A32), size: 24),
                            const SizedBox(width: 10),
                            const Text('Auto-Delivery Setup',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Subscribe to get ${widget.product['name']} delivered to your door based on your chosen schedule.',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 20),

                        // Frequency
                        const Text('Delivery Frequency',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _freqOption('Daily', 'daily'),
                            const SizedBox(width: 10),
                            _freqOption('Weekly', 'weekly'),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Slot
                        const Text('Preferred Delivery Slot',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                        const SizedBox(height: 12),
                        _slotOption('Morning (7 AM - 9 AM)'),
                        const SizedBox(height: 10),
                        _slotOption('Evening (5 PM - 7 PM)'),
                        const SizedBox(height: 24),

                        // Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF3F4F6)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Order Summary',
                                  style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('Item: ${widget.qty}x ${widget.product['name']}',
                                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                              const SizedBox(height: 4),
                              const Text('Pay on Delivery / Wallet per cycle',
                                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                              const SizedBox(height: 8),
                              Text('₹${(_activePrice * widget.qty).toStringAsFixed(0)} / delivery',
                                  style: const TextStyle(color: Color(0xFF145A32), fontWeight: FontWeight.w900, fontSize: 18)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Subscribe button
                  GestureDetector(
                    onTap: _loading ? null : _handleSubscribe,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x4DD4A843), blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: _loading
                          ? const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(color: Color(0xFF145A32), strokeWidth: 2.5))
                          : const Text('Confirm Subscription',
                              style: TextStyle(color: Color(0xFF145A32), fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _freqOption(String label, String value) {
    final isActive = _frequency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _frequency = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? const Color(0xFF145A32) : const Color(0xFFE5E7EB), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF145A32) : const Color(0xFF6B7280),
              )),
        ),
      ),
    );
  }

  Widget _slotOption(String slotTime) {
    final isActive = _slot == slotTime;
    return GestureDetector(
      onTap: () => setState(() => _slot = slotTime),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? const Color(0xFF145A32) : const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: isActive ? const Color(0xFF145A32) : const Color(0xFF9CA3AF)),
            const SizedBox(width: 12),
            Text(slotTime,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? const Color(0xFF145A32) : const Color(0xFF374151),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}
