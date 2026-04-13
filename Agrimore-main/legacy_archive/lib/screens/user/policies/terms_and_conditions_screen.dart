import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
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
                    '1. Acceptance of Terms',
                    'By accessing and using the Agrimore mobile application and website, you accept and agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use our services.',
                  ),
                  _buildSection(
                    '2. Use of Services',
                    'Agrimore provides an agricultural e-commerce platform connecting farmers and buyers. You agree to use our services only for lawful purposes and in accordance with these terms. You must be at least 18 years old to create an account and make purchases.',
                  ),
                  _buildSection(
                    '3. Account Registration',
                    'To access certain features, you must register for an account. You agree to provide accurate, current, and complete information during registration and to update such information to keep it accurate. You are responsible for maintaining the confidentiality of your account credentials.',
                  ),
                  _buildSection(
                    '4. Product Listings',
                    'All products listed on Agrimore are subject to availability. We reserve the right to limit quantities, refuse orders, or discontinue products at any time. Product images are for illustration purposes and actual products may vary slightly.',
                  ),
                  _buildSection(
                    '5. Pricing and Payments',
                    'All prices are listed in Indian Rupees (INR) and are inclusive of applicable taxes unless otherwise stated. We accept payments through Razorpay, UPI, and other authorized payment methods. Order confirmation is subject to payment verification.',
                  ),
                  _buildSection(
                    '6. Order Processing',
                    'Once an order is placed, you will receive a confirmation email/notification. We reserve the right to cancel orders due to pricing errors, stock unavailability, or suspected fraudulent activity.',
                  ),
                  _buildSection(
                    '7. Intellectual Property',
                    'All content on Agrimore, including logos, images, text, and software, is protected by intellectual property laws. You may not reproduce, distribute, or create derivative works without our express written permission.',
                  ),
                  _buildSection(
                    '8. User Conduct',
                    'You agree not to:\n• Upload false or misleading information\n• Attempt to gain unauthorized access to our systems\n• Use the platform for fraudulent activities\n• Harass or abuse other users\n• Violate any applicable laws or regulations',
                  ),
                  _buildSection(
                    '9. Limitation of Liability',
                    'Agrimore shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of our services. Our total liability shall not exceed the amount paid by you for the specific transaction.',
                  ),
                  _buildSection(
                    '10. Modifications',
                    'We reserve the right to modify these Terms and Conditions at any time. Continued use of our services after changes constitutes acceptance of the modified terms.',
                  ),
                  _buildSection(
                    '11. Governing Law',
                    'These terms shall be governed by and construed in accordance with the laws of India. Any disputes shall be subject to the exclusive jurisdiction of courts in Chennai, Tamil Nadu.',
                  ),
                  _buildSection(
                    '12. Contact Information',
                    'For questions regarding these Terms and Conditions, please contact us at:\n\nEmail: support@agrimore.com\nPhone: +91-XXXXXXXXXX\nAddress: Chennai, Tamil Nadu, India',
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
          Icon(Icons.description_outlined, size: 40, color: Colors.green.shade700),
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
                  'Terms and Conditions',
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
