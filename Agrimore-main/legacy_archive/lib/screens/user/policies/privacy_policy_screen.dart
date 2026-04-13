import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                    '1. Information We Collect',
                    'We collect information you provide directly to us, including:\n\n• Personal information (name, email, phone number)\n• Account credentials\n• Delivery addresses\n• Payment information (processed securely through Razorpay)\n• Order history and preferences\n• Device information and usage data',
                  ),
                  _buildSection(
                    '2. How We Use Your Information',
                    'We use the information we collect to:\n\n• Process and fulfill your orders\n• Send order confirmations and updates\n• Provide customer support\n• Personalize your shopping experience\n• Send promotional communications (with your consent)\n• Improve our services and platform\n• Detect and prevent fraud',
                  ),
                  _buildSection(
                    '3. Information Sharing',
                    'We may share your information with:\n\n• Delivery partners to fulfill orders\n• Payment processors (Razorpay) for transactions\n• Service providers who assist our operations\n• Legal authorities when required by law\n\nWe do not sell your personal information to third parties.',
                  ),
                  _buildSection(
                    '4. Data Security',
                    'We implement industry-standard security measures to protect your personal information, including:\n\n• SSL/TLS encryption for data transmission\n• Secure payment processing through Razorpay\n• Regular security audits\n• Access controls for employee data access\n• Secure data storage with Firebase',
                  ),
                  _buildSection(
                    '5. Cookies and Tracking',
                    'We use cookies and similar technologies to:\n\n• Remember your preferences\n• Analyze usage patterns\n• Improve our services\n• Provide personalized content\n\nYou can manage cookie preferences through your browser settings.',
                  ),
                  _buildSection(
                    '6. Your Rights',
                    'You have the right to:\n\n• Access your personal data\n• Correct inaccurate information\n• Request deletion of your data\n• Opt-out of marketing communications\n• Export your data\n• Withdraw consent at any time',
                  ),
                  _buildSection(
                    '7. Data Retention',
                    'We retain your personal information for as long as your account is active or as needed to provide services. We may retain certain information for legal, accounting, or business purposes even after account deletion.',
                  ),
                  _buildSection(
                    '8. Children\'s Privacy',
                    'Our services are not intended for children under 18 years of age. We do not knowingly collect personal information from children. If you believe we have collected information from a child, please contact us immediately.',
                  ),
                  _buildSection(
                    '9. Third-Party Links',
                    'Our platform may contain links to third-party websites. We are not responsible for the privacy practices of these external sites. We encourage you to read their privacy policies.',
                  ),
                  _buildSection(
                    '10. Changes to Privacy Policy',
                    'We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or via email. Your continued use of our services after changes constitutes acceptance of the updated policy.',
                  ),
                  _buildSection(
                    '11. Contact Us',
                    'For privacy-related inquiries or to exercise your rights, contact us at:\n\nEmail: privacy@agrimore.com\nPhone: +91-XXXXXXXXXX\nAddress: Chennai, Tamil Nadu, India\n\nData Protection Officer: dpo@agrimore.com',
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
          Icon(Icons.privacy_tip_outlined, size: 40, color: Colors.green.shade700),
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
                  'Privacy Policy',
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
