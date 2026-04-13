import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../providers/sponsored_banner_provider.dart';

class SponsoredBanner extends StatefulWidget {
  const SponsoredBanner({Key? key}) : super(key: key);

  @override
  State<SponsoredBanner> createState() => _SponsoredBannerState();
}

class _SponsoredBannerState extends State<SponsoredBanner>
    with TickerProviderStateMixin {
  late AnimationController _glossController;
  late AnimationController _pressController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();

    _glossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _glossController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SponsoredBannerProvider>(
      builder: (context, sponsoredProvider, child) {
        final banners = sponsoredProvider.activeSponsoredBanners;

        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: banners.map((banner) => _buildBanner(context, banner)).toList(),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, dynamic banner) {
    final Color bgColor = _hexToColor(banner.colorHex);

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        return Transform(
          alignment: FractionalOffset.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_tiltAnimation.value)
            ..scale(_scaleAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, '/product/${banner.productId}');
        },
        onTapCancel: () => _pressController.reverse(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      bgColor.withValues(alpha: 0.7),
                      bgColor.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PatternPainter(color: Colors.white.withOpacity(0.04)),
                      ),
                    ),
                    _buildGlossEffect(_glossController),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(
                              imageUrl: banner.imageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.white.withOpacity(0.25),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.white.withOpacity(0.25),
                                child: const Icon(Icons.broken_image, size: 32, color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  banner.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      )
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  banner.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                // PROFESSIONAL SPONSORED LABEL
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white30, width: 0.8),
                                  ),
                                  child: const Text(
                                    "SPONSORED PRODUCT",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 20,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlossEffect(AnimationController controller) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset((controller.value * 300) - 150, 0),
              child: Transform.rotate(
                angle: -0.4,
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _hexToColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return AppColors.primary;
    }
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 40.0;
    for (double i = -spacing; i < size.width + spacing; i += spacing) {
      for (double j = -spacing; j < size.height + spacing; j += spacing) {
        canvas.drawCircle(Offset(i, j), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
