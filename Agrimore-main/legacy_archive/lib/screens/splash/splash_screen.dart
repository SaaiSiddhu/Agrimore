// lib/screens/splash/splash_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _glowController;
  late AnimationController _rotateController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _navigationComplete = false;

  final List<Particle> _particles = [];
  static const _splashDuration = Duration(milliseconds: 2200); // Reduced from 4s

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 Agrimore Premium Splash Started');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize animations with faster timing
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // Faster
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // Faster
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Faster rotation
    )..repeat();

    // Smooth staggered animations
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

    // Generate optimized particles (reduced count)
    _generateParticles();

    // Start animations
    _primaryController.forward();

    // Load ad only on mobile
    if (!kIsWeb) {
      _loadInterstitialAd();
    }

    // Quick navigation
    Future.delayed(_splashDuration, () {
      if (mounted && !_navigationComplete) {
        if (kIsWeb || !_isAdLoaded) {
          _navigateToNext();
        } else {
          _showAdAndNavigate();
        }
      }
    });
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < 18; i++) {
      // Reduced from 25
      _particles.add(Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1.5,
        speed: random.nextDouble() * 0.7 + 0.3,
        opacity: random.nextDouble() * 0.4 + 0.3,
        hue: i % 2 == 0 ? 140.0 : 45.0, // Green or Yellow
      ));
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-4374614015135326/5155982150',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Interstitial Ad loaded');
          setState(() {
            _interstitialAd = ad;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ Interstitial Ad failed: $error');
          setState(() => _isAdLoaded = false);
        },
      ),
    );
  }

  void _showAdAndNavigate() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _navigateToNext();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _navigateToNext();
        },
      );
      _interstitialAd!.show();
    } else {
      _navigateToNext();
    }
  }

  Future<void> _navigateToNext() async {
    if (!mounted || _navigationComplete) return;
    setState(() => _navigationComplete = true);

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);

      // Quick auth check with timeout
      int attempts = 0;
      while (authProvider.isInitializing && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 50));
        attempts++;
        if (!mounted) return;
      }

      final targetRoute = authProvider.isLoggedIn ? '/main' : '/auth';
      debugPrint('🚀 Navigating to: $targetRoute');

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(targetRoute);
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    _interstitialAd?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFF0F2818), // Deep forest green
              Color(0xFF0A1810),
              Color(0xFF050A08),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Optimized particle system
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: ParticlePainter(_particles, _rotateController.value),
              ),
            ),

            // Rotating halo rings
            AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (context, _) => Center(
                child: Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pulsing ambient glow
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

            // Main content
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
                        // Premium logo with glassmorphism
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFF00E676).withOpacity(0.6),
                                    blurRadius: 80,
                                    spreadRadius: 30,
                                  ),
                                ],
                              ),
                            ),

                            // Glassmorphic ring
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

                            // Logo
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF00E676),
                                    Color(0xFF00C853),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 25,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/icons/app_icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.eco_rounded,
                                    size: 65,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            // Animated shine effect
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

                        // Brand name with holographic effect
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
                          child: const Text(
                            'Agrimore',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.5,
                              height: 1,
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

                        // Tagline
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
                          child: const Text(
                            'Empowering Agriculture',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Modern loading indicator
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
                                      color: const Color(0xFF00E676)
                                          .withOpacity(0.6),
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

            // Version info
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

// Optimized Particle class
class Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double hue;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.hue,
  });
}

// Optimized particle painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update position
      particle.y = (particle.y + particle.speed * 0.008) % 1.0;

      // Create gradient paint for each particle
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            HSLColor.fromAHSL(particle.opacity, particle.hue, 1.0, 0.6)
                .toColor(),
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
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
