import 'package:flutter/material.dart';

import '../tokens/delivery_tokens.dart';

/// Single-border keyboard focus system (Phases 02, 08, 09, 32).
///
/// Every interactive control shows focus by thickening and recolouring its own
/// single border (`strokeAlignInside`, 2 dp `#C2410C` in light mode, `#FDBA74`
/// in dark mode; 3 dp when the resting state already has a 2 dp active border).
/// Never draws a second outer ring or halo.
bool deliveryShowsFocus(Set<WidgetState> states) =>
    states.contains(WidgetState.focused) &&
    !states.contains(WidgetState.disabled);

WidgetStateProperty<BorderSide?> deliveryOutline(
  BuildContext context, {
  required Color focusRing,
  BorderSide normal = BorderSide.none,
}) {
  return WidgetStateProperty.resolveWith((states) {
    if (deliveryShowsFocus(states) &&
        DeliveryFocusTracker.isKeyboard(context)) {
      return BorderSide(
        color: focusRing,
        width: DeliverySize.focus,
        strokeAlign: BorderSide.strokeAlignInside,
      );
    }
    return normal;
  });
}

/// Tracks keyboard/accessibility focus on a custom control so its own single
/// border updates when focused.
class DeliveryFocusTracker extends StatefulWidget {
  const DeliveryFocusTracker({
    super.key,
    required this.builder,
    this.focusNode,
  });

  final FocusNode? focusNode;
  final Widget Function(BuildContext context, bool focused, FocusNode node)
      builder;

  static bool isKeyboard(BuildContext context) =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  State<DeliveryFocusTracker> createState() => _DeliveryFocusTrackerState();
}

class _DeliveryFocusTrackerState extends State<DeliveryFocusTracker> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant DeliveryFocusTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _own)?.removeListener(_onFocusChange);
      _node.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _node.hasFocus, _node);
}
