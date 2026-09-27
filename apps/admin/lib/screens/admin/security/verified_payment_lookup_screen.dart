// lib/screens/admin/security/verified_payment_lookup_screen.dart
//
// ADMR-53 — verified_payments (functions/src/customer/payment.ts's/
// razorpayOnboardingWebhook.ts's own proof-of-payment record) is a real,
// already-live, already admin-read-permitted (firestore.rules) collection
// with no admin screen reading it at all. Every real consumer reads it by a
// specific, already-known paymentId, never a list query, so this is a
// support/reconciliation lookup, not a browsable feed. Read-only; nothing
// here changes what gets written or when.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class VerifiedPaymentLookupScreen extends StatefulWidget {
  // ADMR-53: an injectable Firestore instance, same pattern ADMR-48/49/51/52
  // established -- defaults to the real FirebaseFirestore.instance,
  // overridable in tests so this screen is testWidgets-testable from day
  // one.
  VerifiedPaymentLookupScreen({super.key, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  State<VerifiedPaymentLookupScreen> createState() => _VerifiedPaymentLookupScreenState();
}

class _VerifiedPaymentLookupScreenState extends State<VerifiedPaymentLookupScreen> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  bool _searched = false;
  VerifiedPaymentRecord? _result;

  Future<void> _lookup() async {
    final paymentId = _controller.text.trim();
    if (paymentId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searched = true;
      _result = null;
    });

    try {
      final doc = await widget._firestore.collection('verified_payments').doc(paymentId).get();
      if (!mounted) return;
      setState(() {
        _result = doc.exists ? VerifiedPaymentRecord.fromMap(doc.data()!, doc.id) : null;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Verified payment lookup: $e');
      if (!mounted) return;
      setState(() {
        _result = null;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verified Payment Lookup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Razorpay Payment ID',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _lookup,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Look Up'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isSearching) const Center(child: CircularProgressIndicator()),
            if (!_isSearching && _searched && _result == null)
              const Text('No verified payment found for that ID.'),
            if (!_isSearching && _result != null) _ResultCard(record: _result!),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.record});
  final VerifiedPaymentRecord record;

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  record.signatureVerified ? Icons.verified_outlined : Icons.help_outline_rounded,
                  color: record.signatureVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  record.isTest ? 'Sandbox / Test Payment' : 'Verified Payment',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row('Payment ID', record.paymentId),
            _row('Order ID', record.orderId),
            _row('User ID', record.userId),
            _row('Status', record.status),
            _row('Amount', record.amount == null ? null : '${record.currency ?? ''} ${record.amount}'),
            _row('Method', record.method),
            _row('Bank', record.bank),
            _row('UPI ID', record.upiId),
            _row('Email', record.email),
            _row('Contact', record.contact),
            _row('Verified At', record.verifiedAt?.toString()),
          ],
        ),
      ),
    );
  }
}
