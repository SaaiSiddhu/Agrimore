import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// SELLER-MONEY-1: settles seller payouts. `seller_payouts` rows are created
/// server-side when an order is delivered (sellerNotifications.ts) — before
/// this screen nothing ever marked them paid, so sellers saw every payout as
/// pending forever. firestore.rules allow exactly one admin transition here:
/// pending → paid with a payment reference; amounts are immutable.
class SellerPayoutsScreen extends StatefulWidget {
  const SellerPayoutsScreen({super.key});

  @override
  State<SellerPayoutsScreen> createState() => _SellerPayoutsScreenState();
}

class _SellerPayoutsScreenState extends State<SellerPayoutsScreen> {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _status = 'pending';
  final Map<String, Map<String, dynamic>?> _sellers = {};
  final Map<String, Map<String, dynamic>?> _payoutDetails = {};

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  Future<void> _loadSeller(String sellerId) async {
    if (_sellers.containsKey(sellerId)) return;
    _sellers[sellerId] = null;
    try {
      final results = await Future.wait([
        _db.collection('sellers').doc(sellerId).get(),
        _db.collection('seller_payout_details').doc(sellerId).get(),
      ]);
      if (!mounted) return;
      setState(() {
        _sellers[sellerId] = results[0].data();
        _payoutDetails[sellerId] = results[1].data();
      });
    } catch (e) {
      debugPrint('Seller lookup failed: $e');
    }
  }

  String _destination(Map<String, dynamic>? d) {
    if (d == null) return 'No payout account on file';
    if (d['payoutMethod'] == 'upi' && (d['upiId'] ?? '').toString().isNotEmpty) {
      return 'UPI ${d['upiId']}';
    }
    final acct = (d['accountNumber'] ?? '').toString();
    return '${d['bankName'] ?? 'Bank'} · ${AgFormat.maskAccount(acct)} · ${d['ifsc'] ?? ''}';
  }

  Future<void> _markPaid(String payoutId, Map<String, dynamic> payout) async {
    final ref = TextEditingController();
    final details = _payoutDetails[payout['sellerId']];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark payout as paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AgFormat.rupees(_num(payout['netAmount'] ?? payout['amount']))} to '
                '${_sellers[payout['sellerId']]?['shopName'] ?? payout['sellerId']}'),
            const SizedBox(height: 4),
            Text(_destination(details), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ref,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'UTR / payment reference',
                helperText: 'Required — shown to the seller',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark paid')),
        ],
      ),
    );
    final reference = ref.text.trim();
    ref.dispose();
    if (confirmed != true) return;
    if (reference.length < 4) {
      if (mounted) SnackbarHelper.showError(context, 'Enter the UTR / payment reference');
      return;
    }
    try {
      await _db.collection('seller_payouts').doc(payoutId).update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentReference': reference,
        'paidBy': FirebaseAuth.instance.currentUser?.uid,
        // firestore.rules accept only these two values.
        'payoutMethod': details?['payoutMethod'] == 'upi' ? 'upi' : 'bank',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) SnackbarHelper.showSuccess(context, 'Payout marked as paid');
    } catch (e) {
      debugPrint('Mark paid failed: $e');
      if (mounted) {
        SnackbarHelper.showError(
            context, "Couldn't mark this payout paid. It may already be settled — refresh and try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Payouts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'paid', label: Text('Paid')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('seller_payouts')
                  .where('status', isEqualTo: _status)
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('Seller payouts load failed: ${snap.error}');
                  return const Center(child: Text("Couldn't load payouts. Check your connection and try again."));
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text(_status == 'pending' ? 'No pending payouts' : 'No paid payouts yet'));
                }
                final total = docs.fold<double>(0, (a, d) => a + _num(d.data()['netAmount'] ?? d.data()['amount']));
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${docs.length} payouts · ${AgFormat.rupees(total)}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final doc in docs) _tile(doc.id, doc.data()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String id, Map<String, dynamic> p) {
    final sellerId = (p['sellerId'] ?? '').toString();
    _loadSeller(sellerId);
    final seller = _sellers[sellerId];
    final created = p['createdAt'];
    final paidRef = (p['paymentReference'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(seller?['shopName']?.toString() ?? sellerId,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(AgFormat.rupees(_num(p['netAmount'] ?? p['amount'])),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Order ${p['orderNumber'] ?? p['orderId']} · gross ${AgFormat.rupees(_num(p['grossAmount']))}'
                ' · commission ${AgFormat.rupees(_num(p['commissionAmount']))}'
                '${created is Timestamp ? ' · ${AgFormat.date(created.toDate())}' : ''}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(_destination(_payoutDetails[sellerId]), style: const TextStyle(fontSize: 12))),
                if ((_payoutDetails[sellerId]?['accountNumber'] ?? _payoutDetails[sellerId]?['upiId']) != null)
                  IconButton(
                    tooltip: 'Copy payout details',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      final d = _payoutDetails[sellerId]!;
                      Clipboard.setData(ClipboardData(
                        text: d['payoutMethod'] == 'upi'
                            ? '${d['upiId']}'
                            : '${d['accountHolder'] ?? ''} ${d['accountNumber'] ?? ''} ${d['ifsc'] ?? ''}',
                      ));
                    },
                  ),
              ],
            ),
            if (_status == 'pending')
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => _markPaid(id, p), child: const Text('Mark paid')),
              )
            else if (paidRef.isNotEmpty)
              Text('Ref $paidRef', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
