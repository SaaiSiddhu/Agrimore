import 'package:flutter/material.dart';

import '../theme/delivery_focus.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_motion.dart';
import '../tokens/delivery_tokens.dart';

/// Shared interactive visual-state surface for custom Delivery components.
///
/// Handles hover, press, keyboard focus ring, and disabled opacity with
/// motion that respects [MediaQuery.disableAnimationsOf].
class DeliveryInteractive extends StatefulWidget {
  const DeliveryInteractive({
    super.key,
    required this.onTap,
    this.onLongPress,
    required this.builder,
    this.borderRadius = DeliveryRadius.rMd,
    this.semanticButton = false,
    this.semanticLabel,
    this.enabled = true,
    this.focusPadding = EdgeInsets.zero,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget Function(
    BuildContext context, {
    required bool hovered,
    required bool pressed,
    required bool focused,
    required bool enabled,
  }) builder;
  final BorderRadius borderRadius;
  final bool semanticButton;
  final String? semanticLabel;
  final bool enabled;
  final EdgeInsetsGeometry focusPadding;

  @override
  State<DeliveryInteractive> createState() => _DeliveryInteractiveState();
}

class _DeliveryInteractiveState extends State<DeliveryInteractive> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _active =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final showFocus = _focused && DeliveryFocusTracker.isKeyboard(context);
    Widget child = FocusableActionDetector(
      enabled: _active,
      mouseCursor:
          _active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _active ? widget.onTap : null,
        onLongPress: _active ? widget.onLongPress : null,
        onTapDown: _active ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _active ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _active ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed && !context.reduceMotion ? 0.985 : 1.0,
          duration: context.motion(DeliveryMotion.fast),
          curve: DeliveryMotion.standard,
          child: Container(
            padding: widget.focusPadding,
            decoration: showFocus
                ? BoxDecoration(
                    borderRadius: widget.borderRadius,
                    border: Border.all(
                      color: c.focusRing,
                      width: DeliverySize.strokeFocus,
                    ),
                  )
                : null,
            child: widget.builder(
              context,
              hovered: _hovered,
              pressed: _pressed,
              focused: showFocus,
              enabled: _active,
            ),
          ),
        ),
      ),
    );
    if (widget.semanticLabel != null || widget.semanticButton) {
      child = Semantics(
        button: widget.semanticButton,
        enabled: _active,
        label: widget.semanticLabel,
        child: child,
      );
    }
    return child;
  }
}

/// Shimmer-free accessible skeleton block. Pulses gently between `surfaceMuted`
/// and `surfaceSubtle`; holds steady when animations are disabled.
class DeliverySkeleton extends StatefulWidget {
  const DeliverySkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = DeliveryRadius.rSm,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<DeliverySkeleton> createState() => _DeliverySkeletonState();
}

class _DeliverySkeletonState extends State<DeliverySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: DeliveryMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0.4;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(c.surfaceMuted, c.border, _ctrl.value * 0.65),
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

/// Centered loading state with accessible progress indicator and optional label.
class DeliveryLoadingState extends StatelessWidget {
  const DeliveryLoadingState({
    super.key,
    this.label,
    this.subtitle,
  });

  final String? label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeliverySpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.brand, strokeWidth: 3),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(height: DeliverySpace.md),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textSecondary),
              ),
            ],
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: DeliverySpace.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

