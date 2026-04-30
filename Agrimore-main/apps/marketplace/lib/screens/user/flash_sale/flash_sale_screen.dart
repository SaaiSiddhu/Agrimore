import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({Key? key}) : super(key: key);

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  int _hours = 2, _minutes = 45, _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _seconds--;
        if (_seconds < 0) {
          _seconds = 59;
          _minutes--;
        }
        if (_minutes < 0) {
          _minutes = 59;
          _hours--;
        }
        if (_hours < 0) {
          _hours = 0;
          _minutes = 0;
          _seconds = 0;
        }
      });
    });
  }

  Future<void> _loadProducts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .limit(8)
          .get();
      setState(() {
        _products = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading flash sale: $e');
      setState(() => _loading = false);
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Amber Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20, left: 16, right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36),
              ),
              boxShadow: [BoxShadow(color: Color(0x4DF59E0B), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: Colors.white, size: 22)),
                    ),
                    const Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Flash Sale', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 38),
                  ],
                ),
                const SizedBox(height: 20),
                // Countdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Ends in  ',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    _timerBox(_pad(_hours), 'HRS'),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(':', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    _timerBox(_pad(_minutes), 'MIN'),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(':', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    _timerBox(_pad(_seconds), 'SEC'),
                  ],
                ),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, i) => _buildProductCard(_products[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _timerBox(String value, String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final discountPrice = (p['discountPrice'] as num?)?.toDouble() ?? (price * 0.7);
    final flashDiscount = ((price - discountPrice) / price * 100).round().clamp(0, 50);
    final flashPrice = (price * (1 - flashDiscount / 100)).round();
    final images = p['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] as String : '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product/${p['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFEF3C7)),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 40, color: Color(0xFFD4A843)))),
                          )
                        : const Center(child: Icon(Icons.image, size: 40, color: Color(0xFFD4A843))),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text('$flashDiscount%',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('₹$flashPrice',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                const SizedBox(width: 8),
                Text('₹${price.toInt()}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), decoration: TextDecoration.lineThrough)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('ADD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}
