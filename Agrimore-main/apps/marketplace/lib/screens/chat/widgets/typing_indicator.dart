// lib/screens/chat/widgets/typing_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class TypingIndicator extends HookWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Hook for Animation ---
    // Replaces StatefulWidget, State, initState, dispose
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // --- Themed Colors ---
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = colorScheme.surfaceContainerHighest;
    final shadowColor = colorScheme.shadow.withValues(alpha: 0.05);
    final dotColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index < 2 ? 6 : 0),
            child: _buildDot(controller, index, dotColor),
          );
        }),
      ),
    );
  }
}

// Extracted from class for cleanliness
Widget _buildDot(AnimationController controller, int index, Color color) {
  return AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      // Stagger the animation for each dot
      final value = (controller.value + (index * 0.25)) % 1.0;
      
      // Create a "bounce" effect (0 -> 1 -> 0)
      final curveValue = Curves.easeInOut.transform(
        value < 0.5 ? value * 2 : (1 - value) * 2,
      );

      return Transform.scale(
        scale: 0.9 + (curveValue * 0.3), // Scale from 0.9 to 1.2
        child: Opacity(
          opacity: 0.4 + (curveValue * 0.6), // Opacity from 0.4 to 1.0
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    },
  );
}