import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
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
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildContactCards(context),
              const SizedBox(height: 20),
              _buildContactForm(context),
              const SizedBox(height: 20),
              _buildOfficeInfo(),
              const SizedBox(height: 20),
              _buildSupportHours(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent, size: 60, color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'re Here to Help!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get in touch with our support team for any questions or assistance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCards(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildContactCard(
                icon: Icons.email_outlined,
                title: 'Email Us',
                subtitle: 'support@agrimore.com',
                color: Colors.blue,
                onTap: () => _launchEmail('support@agrimore.com'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildContactCard(
                icon: Icons.phone_outlined,
                title: 'Call Us',
                subtitle: '+91-XXXXXXXXXX',
                color: Colors.green,
                onTap: () => _launchPhone('+91XXXXXXXXXX'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildContactCard(
                icon: Icons.chat_outlined,
                title: 'WhatsApp',
                subtitle: '+91-XXXXXXXXXX',
                color: Colors.teal,
                onTap: () => _launchWhatsApp('+91XXXXXXXXXX'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildContactCard(
                icon: Icons.help_outline,
                title: 'FAQ',
                subtitle: 'Quick answers',
                color: Colors.orange,
                onTap: () {
                  // Navigate to FAQ
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactForm(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.message_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Send us a Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Your Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Subject',
                prefixIcon: const Icon(Icons.subject),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'order', child: Text('Order Related')),
                DropdownMenuItem(value: 'payment', child: Text('Payment Issue')),
                DropdownMenuItem(value: 'delivery', child: Text('Delivery Query')),
                DropdownMenuItem(value: 'refund', child: Text('Refund Request')),
                DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Your Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message sent successfully! We\'ll get back to you soon.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send Message', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Our Office',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.business, 'Agrimore Technologies Pvt. Ltd.'),
            _buildInfoRow(Icons.location_city, 'Chennai, Tamil Nadu, India'),
            _buildInfoRow(Icons.pin_drop, 'PIN: 600XXX'),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportHours() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Support Hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, 'Monday - Saturday'),
            _buildInfoRow(Icons.schedule, '9:00 AM - 9:00 PM IST'),
            _buildInfoRow(Icons.weekend, 'Sunday: 10:00 AM - 6:00 PM IST'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Response time: Within 24 hours',
                      style: TextStyle(fontSize: 13),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
