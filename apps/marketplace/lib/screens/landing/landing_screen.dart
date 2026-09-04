// ============================================================
//  AGRIMORE - PREMIUM EDGE-TO-EDGE LANDING SCREEN
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final PageController _testimonialController = PageController(viewportFraction: 0.75);
  Timer? _testimonialTimer;
  int _currentTestimonialIndex = 0;
  bool _isScrolled = false;
  
  late AnimationController _heroController;
  late AnimationController _floatController;
  
  late Animation<Offset> _heroSlide;
  late Animation<double> _badgeFade;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _buttonsFade;

  @override
  void initState() {
    super.initState();
    
    _scrollController.addListener(() {
      setState(() => _isScrolled = _scrollController.offset > 50);
    });
    
    _heroController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));
    _badgeFade = CurvedAnimation(parent: _heroController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _titleFade = CurvedAnimation(parent: _heroController, curve: const Interval(0.1, 0.5, curve: Curves.easeOut));
    _subtitleFade = CurvedAnimation(parent: _heroController, curve: const Interval(0.2, 0.6, curve: Curves.easeOut));
    _buttonsFade = CurvedAnimation(parent: _heroController, curve: const Interval(0.3, 0.7, curve: Curves.easeOut));
    
    _heroController.forward();
    
    // Auto-scroll testimonials
    _startTestimonialAutoScroll();
  }

  void _startTestimonialAutoScroll() {
    _testimonialTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_testimonialController.hasClients) {
        _currentTestimonialIndex = (_currentTestimonialIndex + 1) % 5;
        _testimonialController.animateToPage(
          _currentTestimonialIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroController.dispose();
    _floatController.dispose();
    _testimonialController.dispose();
    _testimonialTimer?.cancel();
    super.dispose();
  }

  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF6EE7B7)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Become a Seller', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Join our growing community of sellers.\nSign up and start listing your products today!', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280), fontSize: 15, height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w > 1200;
    final isTablet = w > 768;
    final isMobile = w <= 768;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(isDesktop, isTablet, isMobile)),
              SliverToBoxAdapter(child: _buildStats(isMobile)),
              SliverToBoxAdapter(child: _buildProblemSection(isMobile)),
              SliverToBoxAdapter(child: _buildHowItWorks(isMobile)),
              SliverToBoxAdapter(child: _buildBenefits(isMobile)),
              SliverToBoxAdapter(child: _buildTestimonials(isMobile)),
              SliverToBoxAdapter(child: _buildCTA(isMobile)),
              SliverToBoxAdapter(child: _buildFooter(isMobile)),
            ],
          ),
          
          // Fixed Navigation
          _buildNav(isTablet),
        ],
      ),
    );
  }

  // ============================================
  // NAVIGATION
  // ============================================
  Widget _buildNav(bool isTablet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _isScrolled ? Colors.white : Colors.transparent,
        boxShadow: _isScrolled ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 2))] : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20, vertical: 12),
          child: Row(
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/icons/logo_icon.png', fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF34D399)]), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Agrimore', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _isScrolled ? const Color(0xFF166534) : const Color(0xFF166534))),
                ],
              ),
              const Spacer(),
              // Nav Links (desktop)
              if (isTablet) ...[
                _navLink('Why Us'),
                _navLink('How It Works'),  
                _navLink('Benefits'),
                const SizedBox(width: 20),
              ],
              // CTA Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                  gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF059669)]),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 12, vertical: isTablet ? 12 : 10),
                      child: Text(isTablet ? 'Start Shopping' : 'Shop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: isTablet ? 14 : 13)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navLink(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: _isScrolled ? const Color(0xFF374151) : const Color(0xFF374151), fontSize: 14)),
    );
  }

  // ============================================
  // HERO SECTION
  // ============================================
  Widget _buildHero(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5), Colors.white],
        ),
      ),
      child: Stack(
        children: [
          // Grid pattern
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          
          // Floating blobs
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              top: 80 + (_floatController.value * 20),
              right: isMobile ? 20 : 100,
              child: Container(width: isMobile ? 80 : 150, height: isMobile ? 80 : 150, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.primary.withValues(alpha: 0.1), Colors.transparent]))),
            ),
          ),
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              bottom: 100 - (_floatController.value * 15),
              left: isMobile ? 20 : 80,
              child: Container(width: isMobile ? 60 : 100, height: isMobile ? 60 : 100, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFFFBBF24).withValues(alpha: 0.15), Colors.transparent]))),
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 24 : 64, 120, isMobile ? 24 : 64, 80),
            child: isDesktop 
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: _buildHeroContent(isMobile)),
                    const SizedBox(width: 80),
                    Expanded(flex: 4, child: _buildHeroVisual()),
                  ],
                )
              : _buildHeroContent(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroContent(bool isMobile) {
    return SlideTransition(
      position: _heroSlide,
      child: Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Badge
          FadeTransition(
            opacity: _badgeFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)],
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('Now serving Theni District', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          
          // Title
          FadeTransition(
            opacity: _titleFade,
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'From Farm to\n'),
                TextSpan(text: 'Your Doorstep', style: TextStyle(color: AppColors.primary)),
              ]),
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: TextStyle(fontSize: isMobile ? 36 : 52, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.5, color: const Color(0xFF111827)),
            ),
          ),
          const SizedBox(height: 20),
          
          // Subtitle
          FadeTransition(
            opacity: _subtitleFade,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                'Connect with local farmers & sellers. Fresh products, fair prices, no middlemen.',
                textAlign: isMobile ? TextAlign.center : TextAlign.left,
                style: const TextStyle(fontSize: 17, color: Color(0xFF6B7280), height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 36),
          
          // Buttons
          FadeTransition(
            opacity: _buttonsFade,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
              children: [
                _primaryBtn('Start Selling', Icons.storefront_rounded, _showComingSoon),
                _secondaryBtn('Shop Now', () => Navigator.pushNamed(context, '/login')),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Trust badges
          FadeTransition(
            opacity: _buttonsFade,
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
              children: [
                _trustBadge(Icons.verified_user_rounded, 'Verified Sellers'),
                _trustBadge(Icons.local_shipping_rounded, 'Fast Delivery'),
                _trustBadge(Icons.shield_rounded, 'Secure Payments'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _secondaryBtn(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1F2937),
          side: const BorderSide(color: Color(0xFF1F2937), width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }

  Widget _trustBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildHeroVisual() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatController.value * 10),
        child: Container(
          height: 480,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary.withValues(alpha: 0.08), const Color(0xFFFEF3C7).withValues(alpha: 0.5)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20))],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_iphone_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text('App Preview', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.3), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Positioned(top: 30, left: 16, child: _floatingProductCard('🥬', 'Fresh Spinach', '₹25', const Color(0xFFDCFCE7))),
              Positioned(bottom: 60, right: 16, child: _floatingProductCard('🍯', 'Organic Honey', '₹180', const Color(0xFFFEF3C7))),
              Positioned(top: 140, right: 30, child: _floatingProductCard('🍅', 'Tomatoes', '₹40/kg', const Color(0xFFFEE2E2))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingProductCard(String emoji, String name, String price, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(price, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // STATS - EDGE TO EDGE
  // ============================================
  Widget _buildStats(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.primary, const Color(0xFF059669)],
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 32 : 48, horizontal: isMobile ? 16 : 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (isMobile) {
            // 2x2 grid on mobile
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _statItem('500+', 'Local Sellers', Icons.store_rounded, true)),
                    Expanded(child: _statItem('10K+', 'Customers', Icons.people_rounded, true)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _statItem('50K+', 'Orders', Icons.local_shipping_rounded, true)),
                    Expanded(child: _statItem('₹2Cr+', 'Earnings', Icons.trending_up_rounded, true)),
                  ],
                ),
              ],
            );
          }
          // Single row on desktop
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem('500+', 'Local Sellers', Icons.store_rounded, false),
              _statItem('10K+', 'Happy Customers', Icons.people_rounded, false),
              _statItem('50K+', 'Orders Delivered', Icons.local_shipping_rounded, false),
              _statItem('₹2Cr+', 'Seller Earnings', Icons.trending_up_rounded, false),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String number, String label, IconData icon, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: isMobile ? 18 : 24),
        SizedBox(height: isMobile ? 4 : 8),
        Text(number, style: TextStyle(fontSize: isMobile ? 22 : 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        SizedBox(height: isMobile ? 1 : 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: isMobile ? 11 : 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ============================================
  // PROBLEM SECTION
  // ============================================
  Widget _buildProblemSection(bool isMobile) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 72, horizontal: isMobile ? 16 : 64),
      child: Column(
        children: [
          _sectionTag('THE PROBLEM'),
          const SizedBox(height: 12),
          Text('The Middleman Problem', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, letterSpacing: -0.5), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text('Small sellers lose profits, customers overpay, and communities suffer.', style: TextStyle(color: const Color(0xFF6B7280), fontSize: isMobile ? 14 : 16), textAlign: TextAlign.center),
          ),
          SizedBox(height: isMobile ? 24 : 48),
          // Cards Grid - 2x2 on mobile
          LayoutBuilder(
            builder: (ctx, constraints) {
              if (isMobile) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _problemCard('💸', 'Unfair Prices', 'Farmers sell at rock-bottom prices.', const Color(0xFFFEF2F2), cardWidth, isMobile)),
                        const SizedBox(width: 12),
                        Expanded(child: _problemCard('📈', 'Higher Costs', 'Intermediaries inflate prices.', const Color(0xFFFEF3C7), cardWidth, isMobile)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _problemCard('👀', 'No Visibility', 'Home businesses lack access.', const Color(0xFFEFF6FF), cardWidth, isMobile)),
                        const SizedBox(width: 12),
                        Expanded(child: _problemCard('🏪', 'Platform Giants', 'Can\'t compete with big apps.', const Color(0xFFF5F3FF), cardWidth, isMobile)),
                      ],
                    ),
                  ],
                );
              }
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _problemCard('💸', 'Unfair Seller Prices', 'Farmers sell at rock-bottom prices to middlemen.', const Color(0xFFFEF2F2), 280, false),
                  _problemCard('📈', 'Higher Customer Costs', 'Multiple intermediaries inflate final prices.', const Color(0xFFFEF3C7), 280, false),
                  _problemCard('👀', 'No Visibility', 'Home businesses lack marketplace access.', const Color(0xFFEFF6FF), 280, false),
                  _problemCard('🏪', 'Platform Giants', 'Local sellers can\'t compete with big apps.', const Color(0xFFF5F3FF), 280, false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 11, letterSpacing: 1.5)),
    );
  }

  Widget _problemCard(String emoji, String title, String desc, Color bg, double width, bool isMobile) {
    return Container(
      width: isMobile ? null : (width > 300 ? 280 : width),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 36 : 48, height: isMobile ? 36 : 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 10 : 12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: Center(child: Text(emoji, style: TextStyle(fontSize: isMobile ? 18 : 24))),
          ),
          SizedBox(height: isMobile ? 10 : 16),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 14 : 17)),
          SizedBox(height: isMobile ? 4 : 6),
          Text(desc, style: TextStyle(color: const Color(0xFF6B7280), fontSize: isMobile ? 12 : 14, height: 1.3)),
        ],
      ),
    );
  }

  // ============================================
  // HOW IT WORKS
  // ============================================
  Widget _buildHowItWorks(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF9FAFB),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 72, horizontal: isMobile ? 16 : 64),
      child: Column(
        children: [
          _sectionTag('HOW IT WORKS'),
          const SizedBox(height: 12),
          Text('Simple. Direct. Effective.', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, letterSpacing: -0.5), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Get started in minutes.', style: TextStyle(color: const Color(0xFF6B7280), fontSize: isMobile ? 14 : 16), textAlign: TextAlign.center),
          SizedBox(height: isMobile ? 24 : 48),
          // Steps - 2x2 on mobile
          LayoutBuilder(
            builder: (ctx, constraints) {
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _stepCard('1', Icons.app_registration_rounded, 'Register', 'Sign up in 2 min', const Color(0xFFDCFCE7), true)),
                        const SizedBox(width: 12),
                        Expanded(child: _stepCard('2', Icons.inventory_2_rounded, 'List Products', 'Set your prices', const Color(0xFFFEF3C7), true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _stepCard('3', Icons.shopping_cart_rounded, 'Order Direct', 'Buy from sellers', const Color(0xFFE0E7FF), true)),
                        const SizedBox(width: 12),
                        Expanded(child: _stepCard('4', Icons.local_shipping_rounded, 'Deliver Local', 'Fast delivery', const Color(0xFFFCE7F3), true)),
                      ],
                    ),
                  ],
                );
              }
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _stepCard('1', Icons.app_registration_rounded, 'Register', 'Sign up in 2 min', const Color(0xFFDCFCE7), false),
                  _stepCard('2', Icons.inventory_2_rounded, 'List Products', 'Set your prices', const Color(0xFFFEF3C7), false),
                  _stepCard('3', Icons.shopping_cart_rounded, 'Order Direct', 'Buy from sellers', const Color(0xFFE0E7FF), false),
                  _stepCard('4', Icons.local_shipping_rounded, 'Deliver Local', 'Fast delivery', const Color(0xFFFCE7F3), false),
                  _stepCard('5', Icons.celebration_rounded, 'Everyone Wins', 'Fair earnings', const Color(0xFFDCFCE7), false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stepCard(String num, IconData icon, String title, String desc, Color bg, bool isMobile) {
    return Container(
      width: isMobile ? null : 180,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Container(
            width: isMobile ? 28 : 36, height: isMobile ? 28 : 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF059669)]),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(num, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isMobile ? 13 : 16))),
          ),
          SizedBox(height: isMobile ? 10 : 16),
          Container(
            width: isMobile ? 36 : 48, height: isMobile ? 36 : 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(isMobile ? 10 : 12)),
            child: Icon(icon, color: const Color(0xFF374151), size: isMobile ? 18 : 24),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 13 : 15)),
          SizedBox(height: isMobile ? 2 : 4),
          Text(desc, style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isMobile ? 11 : 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ============================================
  // BENEFITS
  // ============================================
  Widget _buildBenefits(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.primary, const Color(0xFF047857)],
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 72, horizontal: isMobile ? 16 : 64),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
            child: const Text('WHY AGRIMORE', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 11, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 12),
          Text('Built for the Community', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5), textAlign: TextAlign.center),
          SizedBox(height: isMobile ? 24 : 48),
          // 2x3 grid on mobile
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _benefitCard(Icons.home_rounded, 'Local First', 'Small & home businesses', true)),
                    const SizedBox(width: 12),
                    Expanded(child: _benefitCard(Icons.savings_rounded, 'Low Fees', 'Keep more earnings', true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _benefitCard(Icons.handshake_rounded, 'Community', 'Money stays local', true)),
                    const SizedBox(width: 12),
                    Expanded(child: _benefitCard(Icons.balance_rounded, 'Fair Pricing', 'Transparent prices', true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _benefitCard(Icons.woman_rounded, 'Women First', 'Women entrepreneurs', true)),
                    const SizedBox(width: 12),
                    Expanded(child: _benefitCard(Icons.fitness_center_rounded, 'Employment', 'Stable opportunities', true)),
                  ],
                ),
              ],
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _benefitCard(Icons.home_rounded, 'Local Sellers First', 'Prioritizing small & home businesses', false),
                _benefitCard(Icons.savings_rounded, 'Low Fees', 'Sellers keep more earnings', false),
                _benefitCard(Icons.handshake_rounded, 'Community Commerce', 'Money stays in your area', false),
                _benefitCard(Icons.balance_rounded, 'Fair Pricing', 'Transparent for everyone', false),
                _benefitCard(Icons.woman_rounded, 'Women Empowerment', 'Supporting women entrepreneurs', false),
                _benefitCard(Icons.fitness_center_rounded, 'Self-Employment', 'Creating stable opportunities', false),
              ],
            ),
        ],
      ),
    );
  }

  Widget _benefitCard(IconData icon, String title, String desc, bool isMobile) {
    return Container(
      width: isMobile ? null : 300,
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================
  // TESTIMONIALS
  // ============================================
  Widget _buildTestimonials(bool isMobile) {
    final testimonials = [
      {'name': 'Lakshmi S.', 'role': 'Home Baker', 'quote': 'My business grew 3x thanks to Agrimore!', 'emoji': '👩‍🍳'},
      {'name': 'Rajan K.', 'role': 'Farmer', 'quote': 'Finally getting fair prices for my produce.', 'emoji': '👨‍🌾'},
      {'name': 'Priya M.', 'role': 'Customer', 'quote': 'Fresh veggies at amazing prices. Love it!', 'emoji': '👩'},
      {'name': 'Suresh V.', 'role': 'Seller', 'quote': 'Best platform for local sellers. Highly recommend!', 'emoji': '👨‍💼'},
      {'name': 'Anitha R.', 'role': 'Home Chef', 'quote': 'My homemade pickles reach more customers now!', 'emoji': '👩‍🍳'},
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF9FAFB),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 40 : 72),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 64),
            child: Text('Loved by Our Community', style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, letterSpacing: -0.5), textAlign: TextAlign.center),
          ),
          SizedBox(height: isMobile ? 20 : 40),
          // Auto-scrolling PageView carousel
          SizedBox(
            height: isMobile ? 140 : 180,
            child: PageView.builder(
              controller: _testimonialController,
              itemCount: testimonials.length,
              onPageChanged: (index) {
                setState(() => _currentTestimonialIndex = index);
              },
              itemBuilder: (context, index) {
                final t = testimonials[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
                  child: _testimonialCard(t['name']!, t['role']!, t['quote']!, t['emoji']!, isMobile),
                );
              },
            ),
          ),
          SizedBox(height: isMobile ? 12 : 20),
          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(testimonials.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentTestimonialIndex == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentTestimonialIndex == index ? AppColors.primary : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _testimonialCard(String name, String role, String quote, String emoji, bool isMobile) {
    return Container(
      width: isMobile ? 220 : 300,
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: isMobile ? 36 : 48, height: isMobile ? 36 : 48,
                decoration: const BoxDecoration(color: Color(0xFFE5E7EB), shape: BoxShape.circle),
                child: Center(child: Text(emoji, style: TextStyle(fontSize: isMobile ? 18 : 24))),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isMobile ? 13 : 15)),
                  Text(role, style: TextStyle(color: AppColors.primary, fontSize: isMobile ? 11 : 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 16),
          Expanded(
            child: Text('"$quote"', style: TextStyle(fontSize: isMobile ? 12 : 14, color: const Color(0xFF6B7280), height: 1.4, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Row(children: List.generate(5, (_) => Icon(Icons.star_rounded, color: const Color(0xFFFBBF24), size: isMobile ? 14 : 18))),
        ],
      ),
    );
  }

  // ============================================
  // CTA
  // ============================================
  Widget _buildCTA(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)]),
      ),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 40 : 72, horizontal: isMobile ? 16 : 64),
      child: Column(
        children: [
          Text('Ready to Get Started?', style: TextStyle(fontSize: isMobile ? 22 : 32, fontWeight: FontWeight.w800, letterSpacing: -0.5), textAlign: TextAlign.center),
          SizedBox(height: isMobile ? 8 : 12),
          Text('Join thousands in your community.', style: TextStyle(color: const Color(0xFF6B7280), fontSize: isMobile ? 14 : 16), textAlign: TextAlign.center),
          SizedBox(height: isMobile ? 20 : 32),
          if (isMobile)
            Column(
              children: [
                _ctaButton('Become a Seller', Icons.storefront_rounded, true, _showComingSoon),
                const SizedBox(height: 10),
                _ctaButton('Start Shopping', null, false, () => Navigator.pushNamed(context, '/login')),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _primaryBtn('Become a Seller', Icons.storefront_rounded, _showComingSoon),
                _secondaryBtn('Start Shopping', () => Navigator.pushNamed(context, '/login')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _ctaButton(String text, IconData? icon, bool isPrimary, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isPrimary ? LinearGradient(colors: [AppColors.primary, const Color(0xFF059669)]) : null,
          border: isPrimary ? null : Border.all(color: const Color(0xFF1F2937), width: 2),
          boxShadow: isPrimary ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: isPrimary ? Colors.white : const Color(0xFF1F2937), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(text, style: TextStyle(color: isPrimary ? Colors.white : const Color(0xFF1F2937), fontWeight: FontWeight.w700, fontSize: 14)),
                  if (isPrimary) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // FOOTER
  // ============================================
  Widget _buildFooter(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.all(isMobile ? 32 : 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF34D399)]), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Agrimore', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Text('© 2025 Agrimore. Made with ❤️ in Tamil Nadu', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        ],
      ),
    );
  }
}

// Grid pattern painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 50.0;
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
