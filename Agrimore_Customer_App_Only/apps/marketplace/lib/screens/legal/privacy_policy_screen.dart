// ============================================================
//  AGRIMORE - PRIVACY POLICY SCREEN
// ============================================================

import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF6366F1),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Pattern
                    Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                    // Content
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text('Privacy Policy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Last updated: December 2024', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildIntroCard(isDark),
                const SizedBox(height: 20),
                _buildSection('1', 'Information We Collect', 
                  'Agrimore may collect the following information from users for service purposes:\n\n• Name\n• Mobile number\n• Address\n• Order details and usage information\n\nThis information is collected only to provide services and ensure smooth delivery.',
                  Icons.folder_rounded, isDark),
                _buildSection('2', 'Use of Information',
                  'The information collected is used for:\n\n• Processing orders\n• Delivering products\n• Customer support\n• Improving service quality and user experience\n\nUser information is used only for legitimate business purposes.',
                  Icons.analytics_rounded, isDark),
                _buildSection('3', 'Information Sharing',
                  'Agrimore does not sell or share personal information with third parties.\n\nInformation may be shared only with:\n\n• Sellers and delivery partners for order fulfillment\n• Legal authorities if required by law',
                  Icons.share_rounded, isDark),
                _buildSection('4', 'Data Security',
                  'Agrimore takes appropriate measures to protect user data from unauthorized access, misuse, loss, or disclosure. All reasonable security practices are followed to safeguard information.',
                  Icons.security_rounded, isDark),
                _buildSection('5', 'User Rights',
                  'Users have the right to:\n\n• Access their personal information\n• Request corrections or updates\n• Request deletion of data, subject to legal requirements\n\nUsers may contact Agrimore support for any privacy-related concerns.',
                  Icons.admin_panel_settings_rounded, isDark),
                _buildSection('6', 'Children\'s Privacy',
                  'Agrimore does not knowingly collect personal information from individuals under the age of 18.',
                  Icons.child_care_rounded, isDark),
                _buildSection('7', 'Policy Updates',
                  'This Privacy Policy may be updated from time to time. Any changes will be communicated through the App or Website.',
                  Icons.update_rounded, isDark),
                _buildSection('8', 'User Consent',
                  'By using the Agrimore App or Website, users agree and consent to this Privacy Policy.',
                  Icons.verified_user_rounded, isDark),
                const SizedBox(height: 24),
                _buildNoteCard(isDark),
                const SizedBox(height: 24),
                _buildContactCard(isDark),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1A6366F1), Color(0x0D8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x336366F1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x266366F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Privacy Matters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text('We value and respect the privacy of our users.', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String number, String title, String content, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              ),
              Icon(icon, color: const Color(0xFF6366F1).withValues(alpha: 0.6), size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(content, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF92400E))),
                const SizedBox(height: 6),
                Text('Agrimore is a technology-enabled marketplace platform. User data is handled responsibly and used strictly in accordance with this Privacy Policy.', 
                  style: TextStyle(color: const Color(0xFF92400E).withValues(alpha: 0.8), fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.mail_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          const Text('Privacy Concerns?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Contact us at privacy@agrimore.in', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
