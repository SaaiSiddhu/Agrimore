import 'package:flutter/material.dart';

class ShippingPolicyScreen extends StatelessWidget {
  const ShippingPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Policy'),
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
                  _buildSection(
                    '1. Shipping Coverage',
                    'We currently deliver agricultural products across India. Delivery availability may vary based on your location. Enter your pincode during checkout to confirm delivery availability to your area.',
                  ),
                  _buildDeliveryTable(),
                  _buildSection(
                    '2. Processing Time',
                    'Orders are processed within 1-2 business days after payment confirmation. Processing time may vary during peak seasons or promotional periods. You will receive a notification once your order is shipped.',
                  ),
                  _buildSection(
                    '3. Delivery Partners',
                    'We partner with reliable logistics providers to ensure safe and timely delivery of your agricultural products. Tracking information will be shared via SMS and email once your order is dispatched.',
                  ),
                  _buildSection(
                    '4. Shipping Charges',
                    '• Orders above ₹500: FREE delivery\n• Orders below ₹500: ₹40-₹100 depending on location\n• Express delivery: Additional charges may apply\n• Remote areas: Additional charges may apply\n\nExact shipping charges are calculated at checkout based on your location and order value.',
                  ),
                  _buildSection(
                    '5. Order Tracking',
                    'Track your order status through:\n\n• Agrimore app - Orders section\n• SMS notifications\n• Email updates\n• Delivery partner\'s tracking link\n\nContact our support team if you need assistance with tracking.',
                  ),
                  _buildSection(
                    '6. Delivery Instructions',
                    '• Ensure someone is available at the delivery address\n• Verify product condition before accepting delivery\n• Sign the delivery receipt after inspection\n• Report any damage or discrepancy immediately\n• Keep packaging for returns if needed',
                  ),
                  _buildSection(
                    '7. Failed Delivery',
                    'If delivery fails due to incorrect address or unavailability:\n\n• First attempt: Re-delivery scheduled next business day\n• Second attempt: Contact from delivery partner\n• Third attempt: Order returned to warehouse\n\nAdditional delivery charges may apply for re-delivery.',
                  ),
                  _buildSection(
                    '8. Perishable Items',
                    'For fresh produce and perishable items:\n\n• Delivered in temperature-controlled packaging\n• Priority delivery within 24-48 hours\n• Inspect immediately upon delivery\n• Report quality issues within 24 hours',
                  ),
                  _buildSection(
                    '9. Bulk Orders',
                    'For bulk/wholesale orders:\n\n• Special delivery arrangements available\n• Discounted shipping rates\n• Direct farm-to-door delivery options\n• Contact us for custom shipping solutions',
                  ),
                  _buildSection(
                    '10. Contact for Shipping Queries',
                    'For shipping-related questions:\n\nEmail: shipping@agrimore.com\nPhone: +91-XXXXXXXXXX\nWhatsApp: +91-XXXXXXXXXX\n\nSupport Hours: 9 AM - 9 PM IST',
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
          Icon(Icons.local_shipping_outlined, size: 40, color: Colors.green.shade700),
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
                  'Shipping Policy',
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

  Widget _buildDeliveryTable() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Delivery Zone', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          _buildTableRow('Metro Cities (Chennai, Bangalore, Mumbai, Delhi)', '2-4 days'),
          _buildTableRow('Tier 2 Cities', '4-6 days'),
          _buildTableRow('Tier 3 Cities & Towns', '5-7 days'),
          _buildTableRow('Rural & Remote Areas', '7-10 days'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String zone, String timeline) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(zone, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Text(timeline, style: const TextStyle(fontSize: 13, color: Colors.green)),
          ),
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
