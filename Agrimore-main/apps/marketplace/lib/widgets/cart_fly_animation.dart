// lib/widgets/cart_fly_animation.dart
// Fly-to-cart animation overlay - product image flies from product to cart icon

import 'package:flutter/material.dart';

/// Call [CartFlyAnimationOverlay.triggerFly] from any widget
/// to launch the fly-to-cart animation effect.
class CartFlyAnimationOverlay {
  /// Triggers a product image fly-to-cart animation.
  ///
  /// [context]        – BuildContext (used for Overlay)
  /// [imageUrl]       – product image URL to animate
  /// [startPosition]  – global position where the animation begins (e.g. "Add to Cart" button)
  static void triggerFly({
    required BuildContext context,
    required String imageUrl,
    Offset? startPosition,
    VoidCallback? onComplete,
  }) {
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Cart icon is in the bottom nav. Approximate its position.
    // Index 3 out of 5 tabs → ~78% from left, ~bottom
    final cartTargetX = screenSize.width * 0.78;
    final cartTargetY = screenSize.height - 45;

    final startX = startPosition?.dx ?? screenSize.width / 2;
    final startY = startPosition?.dy ?? screenSize.height * 0.6;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _FlyingItem(
        startX: startX,
        startY: startY,
        endX: cartTargetX,
        endY: cartTargetY,
        imageUrl: imageUrl,
        onComplete: () {
          entry.remove();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _FlyingItem extends StatefulWidget {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String imageUrl;
  final VoidCallback onComplete;

  const _FlyingItem({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnim;
  late Animation<double> _yAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Horizontal – straight from start to end
    _xAnim = Tween<double>(begin: widget.startX, end: widget.endX).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Vertical – arc upward then drop to cart
    _yAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.startY, end: widget.startY - 120)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.startY - 120, end: widget.endY)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_controller);

    // Shrink as it approaches the cart
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Fade out near end
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        return Positioned(
          left: _xAnim.value - 24, // center the 48px image
          top: _yAnim.value - 24,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shopping_bag_outlined,
                            size: 28,
                            color: Colors.green,
                          ),
                        )
                      : const Icon(
                          Icons.shopping_bag_outlined,
                          size: 28,
                          color: Colors.green,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
