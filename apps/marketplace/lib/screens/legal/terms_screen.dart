// ============================================================
//  AGRIMORE - TERMS AND CONDITIONS SCREEN
// ============================================================

import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
            backgroundColor: AppColors.primary,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, const Color(0xFF059669)],
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
                            child: const Icon(Icons.article_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text('Terms & Conditions', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
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
                _buildSection('1', 'Platform Nature', 
                  'Agrimore acts only as a facilitator platform. Agrimore does not manufacture, store, or directly sell any products. All products are listed and supplied by independent sellers.',
                  Icons.hub_rounded, isDark),
                _buildSection('2', 'Seller Responsibility',
                  'The quality, price, availability, expiry date, packaging, and delivery of products are the sole responsibility of the respective sellers. Agrimore does not take direct responsibility for seller-related issues.',
                  Icons.storefront_rounded, isDark),
                _buildSection('3', 'User Responsibility',
                  'Users must provide accurate and truthful information during registration and while placing orders. Any misuse, false information, fraud, or illegal activity may result in account suspension or termination.',
                  Icons.person_rounded, isDark),
                _buildSection('4', 'Orders and Services',
                  'Orders placed through Agrimore are fulfilled by local sellers or delivery partners. Delivery timelines may vary depending on location, product type, and external conditions.',
                  Icons.shopping_bag_rounded, isDark),
                _buildSection('5', 'Returns and Complaints',
                  'In case of damaged, defective, expired, or incorrect products, users must raise a complaint within 24 hours of delivery. Return or replacement approval is subject to seller verification and policy.',
                  Icons.autorenew_rounded, isDark),
                _buildSection('6', 'Payments',
                  'Product prices and applicable delivery charges are displayed before order confirmation. Refunds, if applicable, will be processed according to the seller\'s refund policy and payment method used.',
                  Icons.payment_rounded, isDark),
                _buildSection('7', 'Service Modifications',
                  'Agrimore reserves the right to modify, update, suspend, or discontinue any part of the platform or services without prior notice.',
                  Icons.settings_rounded, isDark),
                _buildSection('8', 'Legal Use',
                  'Users are prohibited from engaging in unlawful activities, misuse of the platform, or actions that cause harm to others or the platform.',
                  Icons.gavel_rounded, isDark),
                _buildSection('9', 'Disclaimer',
                  'Agrimore is a technology-enabled marketplace platform. Agrimore shall not be held responsible for product quality, seller performance, delivery delays, or disputes between users and sellers.',
                  Icons.info_rounded, isDark),
                _buildSection('10', 'Acceptance',
                  'By accessing or using the Agrimore App or Website, users fully agree and accept these Terms and Conditions.',
                  Icons.check_circle_rounded, isDark),
                const SizedBox(height: 32),
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
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.handshake_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to Agrimore', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text('By using our App or Website, you agree to these terms.', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
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
                  gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              ),
              Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(content, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildContactCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          const Text('Questions?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Contact us at support@agrimore.in', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
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
