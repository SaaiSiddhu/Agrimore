import 'package:flutter/material.dart';

class CancellationRefundScreen extends StatelessWidget {
  const CancellationRefundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancellation & Refunds'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade700,
              Colors.green.shade50,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildCancellationSection(),
                  const SizedBox(height: 24),
                  _buildRefundSection(),
                  const SizedBox(height: 24),
                  _buildRefundTimeline(),
                  const SizedBox(height: 24),
                  _buildSection(
                    '1. Order Cancellation',
                    'You can cancel your order before it is shipped:\n\n• Go to "My Orders" in the app\n• Select the order you want to cancel\n• Click "Cancel Order" button\n• Select cancellation reason\n• Confirm cancellation\n\nFull refund will be initiated for cancelled orders.',
                  ),
                  _buildSection(
                    '2. Cancellation Window',
                    '• Before dispatch: Free cancellation\n• After dispatch: Contact support\n• In transit: May not be possible\n• Delivered: Not applicable (use return policy)',
                  ),
                  _buildSection(
                    '3. Non-Cancellable Orders',
                    'The following orders cannot be cancelled:\n\n• Personalized/customized products\n• Perishable items already packed\n• Orders already out for delivery\n• Flash sale or special promotion items (as specified)',
                  ),
                  _buildSection(
                    '4. Return Policy',
                    'Return eligible items within 7 days of delivery:\n\n• Item must be unused and in original packaging\n• Include all accessories and tags\n• Provide order ID and reason for return\n• Schedule pickup through the app',
                  ),
                  _buildSection(
                    '5. Return Process',
                    '1. Open "My Orders" and select the order\n2. Click "Return Item"\n3. Select return reason and upload photos\n4. Schedule pickup or drop-off\n5. Pack item securely\n6. Refund initiated after quality check',
                  ),
                  _buildSection(
                    '6. Non-Returnable Items',
                    'The following items cannot be returned:\n\n• Fresh produce and perishables\n• Seeds and plantations (after opening)\n• Fertilizers and pesticides (opened)\n• Items damaged by user\n• Items without original packaging',
                  ),
                  _buildSection(
                    '7. Refund Methods',
                    'Refunds are processed to the original payment method:\n\n• UPI: 24-48 hours\n• Debit/Credit Card: 5-7 business days\n• Net Banking: 5-7 business days\n• Wallet: 24 hours\n• Cash on Delivery: Bank transfer (3-5 days)',
                  ),
                  _buildSection(
                    '8. Partial Refunds',
                    'Partial refunds may apply for:\n\n• Damaged items (partial value)\n• Missing items (refund for missing items only)\n• Used items (based on condition assessment)\n• Promotional discounts (adjusted refund)',
                  ),
                  _buildSection(
                    '9. Damaged/Defective Products',
                    'For damaged or defective items:\n\n• Report within 24 hours of delivery\n• Upload clear photos of damage\n• Full refund or replacement offered\n• No return shipping charges\n• Priority processing',
                  ),
                  _buildSection(
                    '10. Contact for Refund Queries',
                    'For cancellation and refund assistance:\n\nEmail: refunds@agrimore.com\nPhone: +91-XXXXXXXXXX\nIn-app: Help & Support\n\nRefund queries are resolved within 48 hours.',
                  ),
                  const SizedBox(height: 16),
                  _buildLastUpdated(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.policy_outlined, size: 40, color: Colors.green.shade700),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agrimore',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Cancellation & Refund Policy',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Cancellation Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint('Cancel anytime before shipment'),
          _buildBulletPoint('100% refund on cancelled orders'),
          _buildBulletPoint('Instant cancellation through app'),
        ],
      ),
    );
  }

  Widget _buildRefundSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_rupee, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Refund Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint('7-day return window'),
          _buildBulletPoint('Refund to original payment method'),
          _buildBulletPoint('Free pickup for returns'),
        ],
      ),
    );
  }

  Widget _buildRefundTimeline() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timeline, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Refund Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          _buildTimelineRow('UPI', '24-48 hours', Icons.account_balance_wallet),
          _buildTimelineRow('Cards', '5-7 business days', Icons.credit_card),
          _buildTimelineRow('Net Banking', '5-7 business days', Icons.account_balance),
          _buildTimelineRow('Wallet', '24 hours', Icons.wallet),
          _buildTimelineRow('COD', '3-5 business days', Icons.money),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String method, String duration, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(method)),
          Text(
            duration,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.update, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Last Updated: December 2024',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
