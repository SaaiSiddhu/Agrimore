import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

enum SplashAnimationType {
  customer,
  seller,
  delivery,
  admin,
}

class PremiumSplashScreen extends StatefulWidget {
  final String appName;
  final String tagline;
  final String logoPath;
  final SplashAnimationType animationType;
  final Future<void> Function(BuildContext context)? onNavigation;
  final Duration duration;

  const PremiumSplashScreen({
    Key? key,
    required this.appName,
    required this.tagline,
    this.logoPath = 'assets/icons/app_icon.png',
    this.animationType = SplashAnimationType.customer,
    this.onNavigation,
    this.duration = const Duration(milliseconds: 2200),
  }) : super(key: key);

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _glowController;
  late AnimationController _rotateController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  bool _navigationComplete = false;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 Premium Splash Started for ${widget.appName}');
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializeControllers();
    _generateParticles();

    _primaryController.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_navigationComplete) {
        _navigateToNext();
      }
    });
  }

  void _initializeControllers() {
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowController.repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _rotateController.repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _primaryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _primaryController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _primaryController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _rotateAnimation =
        Tween<double>(begin: 0, end: 2 * math.pi).animate(_rotateController);
  }

  void _generateParticles() {
    final random = math.Random();
    final isDelivery = widget.animationType == SplashAnimationType.delivery;
    final isSeller = widget.animationType == SplashAnimationType.seller;
    
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1.5,
        speed: isDelivery 
            ? random.nextDouble() * 2.0 + 1.0 // Fast horizontal for delivery
            : isSeller 
                ? random.nextDouble() * 1.5 + 0.5 // Upward moving for seller
                : random.nextDouble() * 0.7 + 0.3, // Normal float
        opacity: random.nextDouble() * 0.4 + 0.3,
        hue: widget.animationType == SplashAnimationType.admin
            ? (i % 2 == 0 ? 210.0 : 200.0) // Blue theme for admin
            : (i % 2 == 0 ? 140.0 : 45.0), // Green/Gold for others
      ));
    }
  }

  Future<void> _navigateToNext() async {
    if (!mounted || _navigationComplete) return;
    setState(() => _navigationComplete = true);

    try {
      if (widget.onNavigation != null) {
        await widget.onNavigation!(context);
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    } finally {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1810),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFF0F2818),
              Color(0xFF0A1810),
              Color(0xFF050A08),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _ParticlePainter(_particles, _rotateController.value, widget.animationType),
              ),
            ),
            AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (context, _) => Center(
                child: Transform.rotate(
                  angle: widget.animationType == SplashAnimationType.admin 
                      ? -_rotateAnimation.value // reverse rotation for admin gear
                      : _rotateAnimation.value,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: widget.animationType == SplashAnimationType.admin 
                          ? BoxShape.rectangle 
                          : BoxShape.circle,
                      borderRadius: widget.animationType == SplashAnimationType.admin 
                          ? BorderRadius.circular(40) 
                          : null,
                      border: Border.all(
                        color: (widget.animationType == SplashAnimationType.admin 
                                ? const Color(0xFF00B0FF) 
                                : const Color(0xFF00E676)).withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) => Center(
                child: Container(
                  width: 350 + (_glowController.value * 80),
                  height: 350 + (_glowController.value * 80),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00E676)
                            .withOpacity(0.25 * (1 - _glowController.value)),
                        const Color(0xFF76FF03)
                            .withOpacity(0.15 * (1 - _glowController.value)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.animationType == SplashAnimationType.admin
                                            ? const Color(0xFF00B0FF)
                                            : const Color(0xFF00E676))
                                        .withOpacity(0.6),
                                    blurRadius: 80,
                                    spreadRadius: 30,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 25,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.8, end: 1.0),
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Image.asset(
                                    widget.logoPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.eco_rounded,
                                      size: 65,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _primaryController,
                              builder: (context, _) {
                                if (_primaryController.value < 0.8) {
                                  return ClipOval(
                                    child: Container(
                                      width: 130,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white
                                                .withOpacity(0.5 * (1 - _primaryController.value)),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 42),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00E676),
                              Color(0xFFFFEA00),
                              Color(0xFF00E676),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ).createShader(bounds),
                          child: Text(
                            widget.appName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.5,
                              height: 1.1,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 6),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00E676).withValues(alpha: 0.15),
                                const Color(0xFF00C853).withOpacity(0.1),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFF00E676).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.tagline,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: const Color(0xFF00E676),
                                strokeWidth: 3,
                                backgroundColor:
                                    const Color(0xFF00E676).withValues(alpha: 0.15),
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF00E676),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: const Column(
                  children: [
                    Text(
                      'v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white24,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PREMIUM EDITION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF00E676),
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double hue;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.hue,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final SplashAnimationType animationType;

  _ParticlePainter(this.particles, this.progress, this.animationType);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      if (animationType == SplashAnimationType.delivery) {
        // Fast horizontal lines
        particle.x = (particle.x + particle.speed * 0.015) % 1.0;
      } else if (animationType == SplashAnimationType.seller) {
        // Upward moving lines (growth)
        particle.y = (particle.y - particle.speed * 0.01) % 1.0;
        if (particle.y < 0) particle.y += 1.0;
      } else {
        // Normal floating down
        particle.y = (particle.y + particle.speed * 0.008) % 1.0;
      }

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            HSLColor.fromAHSL(particle.opacity, particle.hue, 1.0, 0.6).toColor(),
            HSLColor.fromAHSL(0.0, particle.hue, 1.0, 0.5).toColor(),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(particle.x * size.width, particle.y * size.height),
            radius: particle.size,
          ),
        );

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
