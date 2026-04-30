import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({Key? key}) : super(key: key);

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;
  String? _appliedCode;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('coupons').get();
      setState(() {
        _coupons = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching coupons: $e');
      setState(() => _loading = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon code "$code" copied!'),
        backgroundColor: const Color(0xFF145A32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              bottom: 20,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF145A32),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              boxShadow: [
                BoxShadow(color: Color(0x40145A32), blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: Color(0xFFD4A843), size: 22)),
                ),
                const Expanded(
                  child: Text('Offers & Coupons', textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFD4A843), fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 38),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF145A32)))
                : RefreshIndicator(
                    onRefresh: _fetchCoupons,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      children: [
                        // Banner
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0x1ED4A843),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x4DD4A843)),
                          ),
                          child: Row(
                            children: [
                              const Text('🎉', style: TextStyle(fontSize: 40)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Save Big Today!',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                                    SizedBox(height: 4),
                                    Text('Apply coupons at checkout to save more',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_coupons.isEmpty)
                          Center(
                            child: Column(
                              children: const [
                                SizedBox(height: 40),
                                Text('🏷️', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('No Coupons Yet',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                                SizedBox(height: 6),
                                Text('Check back later for exciting offers!',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                              ],
                            ),
                          )
                        else
                          ..._coupons.map((coupon) => _buildCouponCard(coupon)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    final code = coupon['code'] ?? 'CODE';
    final isApplied = _appliedCode == code;
    final discount = coupon['discount'] ?? '0%';
    final description = coupon['description'] ?? '';
    final minOrder = coupon['minOrder'] ?? 0;
    final usedCount = coupon['usedCount'] ?? 0;
    final maxUses = coupon['maxUses'] ?? 1;

    String expiryStr = 'N/A';
    if (coupon['expiry'] is Timestamp) {
      final dt = (coupon['expiry'] as Timestamp).toDate();
      expiryStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5, style: BorderStyle.solid),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Code + Discount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _copyCode(code),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x0F145A32),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x26145A32), style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(code,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF145A32), letterSpacing: 1)),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 14, color: Color(0xFF145A32)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(10)),
                child: Text('$discount OFF',
                    style: const TextStyle(color: Color(0xFF145A32), fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4)),
          ],
          const SizedBox(height: 12),
          // Meta
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_offer, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('Min ₹$minOrder', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.access_time, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('Expires $expiryStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
              Text('$usedCount/$maxUses used',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFD4A843), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          // Apply button
          GestureDetector(
            onTap: () => setState(() => _appliedCode = code),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isApplied ? const Color(0xFF145A32) : const Color(0x1A145A32),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                isApplied ? '✓ Applied' : 'Apply',
                style: TextStyle(
                  color: isApplied ? const Color(0xFFD4A843) : const Color(0xFF145A32),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
