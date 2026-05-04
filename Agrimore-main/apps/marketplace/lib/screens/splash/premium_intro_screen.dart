import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium animated intro screen for Agrimore
/// Uses the actual customer_logo.png with cinematic animations
class PremiumIntroScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PremiumIntroScreen({Key? key, required this.onComplete})
      : super(key: key);

  @override
  State<PremiumIntroScreen> createState() => _PremiumIntroScreenState();
}

class _PremiumIntroScreenState extends State<PremiumIntroScreen>
    with TickerProviderStateMixin {
  // Master timeline controllers
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _taglineController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _exitController;

  // Logo animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoGlow;

  // Text animations
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;

  // Tagline animations
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  // Shimmer
  late Animation<double> _shimmerPosition;

  // Exit
  late Animation<double> _exitScale;
  late Animation<double> _exitOpacity;

  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initAnimations();
    _startSequence();
  }

  void _initAnimations() {
    // Logo: scale up from 0 with bounce
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Title text: slide up + fade in
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Tagline: slide up + fade in
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );

    // Shimmer sweep across logo
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Particle burst
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Exit: scale up + fade out
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );
  }

  Future<void> _startSequence() async {
    // Phase 1: Logo appears (0-1.2s)
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    // Phase 2: Title text (0.8s after logo starts)
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    // Phase 3: Tagline (0.3s after title)
    await Future.delayed(const Duration(milliseconds: 300));
    _taglineController.forward();

    // Phase 4: Shimmer sweep
    await Future.delayed(const Duration(milliseconds: 400));
    _shimmerController.forward();

    // Phase 5: Particle burst
    setState(() => _showParticles = true);
    _particleController.forward();

    // Phase 6: Hold for a moment
    await Future.delayed(const Duration(milliseconds: 1200));

    // Phase 7: Exit transition
    if (mounted) {
      _exitController.forward().then((_) {
        if (mounted) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          widget.onComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) {
        return Opacity(
          opacity: _exitOpacity.value,
          child: Transform.scale(
            scale: _exitScale.value,
            child: child,
          ),
        );
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            // Rich dark gradient with green undertones
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A1F0D), // Very dark green
                Color(0xFF0D2818), // Dark forest
                Color(0xFF122D1B), // Forest green dark
                Color(0xFF0A1A10), // Almost black green
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background radial glow
              _buildBackgroundGlow(),

              // Particle effects
              if (_showParticles) _buildParticles(),

              // Main content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Animated Logo
                  _buildAnimatedLogo(),

                  const SizedBox(height: 28),

                  // Animated Title
                  _buildAnimatedTitle(),

                  const SizedBox(height: 10),

                  // Animated Tagline
                  _buildAnimatedTagline(),

                  const Spacer(flex: 2),

                  // Bottom branding
                  _buildBottomBranding(),

                  const SizedBox(height: 40),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return AnimatedBuilder(
      animation: _logoGlow,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          child: Container(
            width: 300 + (100 * _logoGlow.value),
            height: 300 + (100 * _logoGlow.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2E7D32).withOpacity(0.15 * _logoGlow.value),
                  const Color(0xFF1B5E20).withOpacity(0.08 * _logoGlow.value),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _shimmerController]),
      builder: (context, child) {
        return Opacity(
          opacity: _logoOpacity.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  // Primary green glow
                  BoxShadow(
                    color: const Color(0xFF4CAF50)
                        .withOpacity(0.3 * _logoGlow.value),
                    blurRadius: 40 * _logoGlow.value,
                    spreadRadius: 5 * _logoGlow.value,
                  ),
                  // Secondary warm glow
                  BoxShadow(
                    color: const Color(0xFFFFB300)
                        .withOpacity(0.15 * _logoGlow.value),
                    blurRadius: 60 * _logoGlow.value,
                    spreadRadius: 2 * _logoGlow.value,
                  ),
                  // Hard shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Logo image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/icons/customer_logo.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Center(
                          child: Text('🌱',
                              style: TextStyle(fontSize: 60)),
                        ),
                      ),
                    ),
                  ),

                  // Shimmer overlay
                  if (_shimmerController.isAnimating ||
                      _shimmerController.isCompleted)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment(
                                _shimmerPosition.value - 1, -0.3),
                            end: Alignment(_shimmerPosition.value, 0.3),
                            colors: const [
                              Colors.transparent,
                              Color(0x40FFFFFF),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(
                          width: 140,
                          height: 140,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),

                  // Border ring
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFF4CAF50)
                            .withOpacity(0.3 + (0.2 * _logoGlow.value)),
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return SlideTransition(
          position: _titleSlide,
          child: Opacity(
            opacity: _titleOpacity.value,
            child: ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFF66BB6A), // Light green
                    Color(0xFFFFFFFF), // White
                    Color(0xFFFDD835), // Gold
                  ],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: const Text(
                'AgriMore',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  height: 1.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTagline() {
    return AnimatedBuilder(
      animation: _taglineController,
      builder: (context, child) {
        return SlideTransition(
          position: _taglineSlide,
          child: Opacity(
            opacity: _taglineOpacity.value,
            child: const Text(
              'Empowering Farmers, Connecting Markets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xAAFFFFFF),
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ParticlePainter(
            progress: _particleController.value,
            center: Offset(
              MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height * 0.38,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBranding() {
    return AnimatedBuilder(
      animation: _taglineController,
      builder: (context, child) {
        return Opacity(
          opacity: _taglineOpacity.value * 0.5,
          child: Column(
            children: [
              // Divider line
              Container(
                width: 60,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF4CAF50).withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fresh • Local • Trusted',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0x66FFFFFF),
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for particle burst effect
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Offset center;
  final Random _random = Random(42); // Fixed seed for consistent particles

  _ParticlePainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    const particleCount = 24;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi + _random.nextDouble() * 0.5;
      final maxRadius = 80.0 + _random.nextDouble() * 120;
      final radius = maxRadius * progress;
      final particleSize = (3.0 + _random.nextDouble() * 3) * (1 - progress);

      if (particleSize <= 0) continue;

      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;

      final opacity = (1 - progress).clamp(0.0, 1.0);

      // Alternate between green and gold particles
      final color = i % 3 == 0
          ? Color(0xFF4CAF50).withOpacity(opacity * 0.7)
          : i % 3 == 1
              ? Color(0xFFFDD835).withOpacity(opacity * 0.5)
              : Color(0xFFFFFFFF).withOpacity(opacity * 0.3);

      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
