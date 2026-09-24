import 'package:flutter/material.dart';

import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';

/// Single-border keyboard focus — the owner's rule (brief §6, board 24-02;
/// decisions D2): focus makes the control's OWN outline heavier and stronger in
/// colour. Never a second outline, an offset ring, a halo, a glow or a gap.
/// The stroke is drawn inside the boundary, so geometry never changes.

/// Whether a focused control should show its keyboard focus now. Focus that
/// arrives through touch (autofocus, a dialog opening) stays invisible; the
/// indicator appears as soon as the user navigates with a keyboard.
bool sellerKeyboardFocusVisible() => FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// [states] contains focus AND the keyboard is in use.
bool sellerShowsFocus(Set<WidgetState> states) =>
    states.contains(WidgetState.focused) && sellerKeyboardFocusVisible();

/// The outline of a bordered control (card, row, chip, field, nav item) for
/// its state: resting [rest] (may be transparent), focused = focus colour at
/// [SellerSize.focus].
BorderSide sellerOutline(
  SellerColors c, {
  required bool focused,
  Color? rest,
  double restWidth = SellerSize.hairline,
  Color? focusColor,
  double focusWidth = SellerSize.focus,
}) {
  if (focused) {
    return BorderSide(color: focusColor ?? c.focus, width: focusWidth, strokeAlign: BorderSide.strokeAlignInside);
  }
  return BorderSide(color: rest ?? c.border, width: restWidth, strokeAlign: BorderSide.strokeAlignInside);
}

/// Tracks keyboard-visible focus for custom controls built on [Focus] /
/// [InkWell]: rebuilds when focus or the highlight mode changes.
class SellerFocusTracker extends StatefulWidget {
  const SellerFocusTracker({super.key, required this.builder, this.focusNode});

  final Widget Function(BuildContext context, bool focusVisible, FocusNode node) builder;
  final FocusNode? focusNode;

  @override
  State<SellerFocusTracker> createState() => _SellerFocusTrackerState();
}

class _SellerFocusTrackerState extends State<SellerFocusTracker> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'SellerFocusTracker'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_changed);
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void didUpdateWidget(covariant SellerFocusTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _own)?.removeListener(_changed);
      _node.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _modeChanged(FocusHighlightMode _) => _changed();

  @override
  void dispose() {
    _node.removeListener(_changed);
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _node.hasFocus && sellerKeyboardFocusVisible(), _node);
}
