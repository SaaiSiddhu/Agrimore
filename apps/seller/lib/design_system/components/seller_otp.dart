import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_motion.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

/// Six code boxes over ONE real text field (board 16-02). The field owns the
/// keyboard, paste and SMS autofill (`oneTimeCode`); screen readers meet a
/// single labelled field ("Verification code, 6 digits") rather than six
/// fragments. The box awaiting the next digit shows the focus border; an
/// error turns every box's own border red — one border, never a second ring.
class SellerOtpInput extends StatefulWidget {
  const SellerOtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<SellerOtpInput> createState() => _SellerOtpInputState();
}

class _SellerOtpInputState extends State<SellerOtpInput> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());
  String _last = '';

  @override
  void initState() {
    super.initState();
    _last = widget.controller.text;
    widget.controller.addListener(_onValue);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant SellerOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onValue);
      widget.controller.addListener(_onValue);
      _last = widget.controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _own)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() => setState(() {});

  void _onValue() {
    final v = widget.controller.text;
    if (v == _last) return;
    _last = v;
    widget.onChanged?.call(v);
    if (v.length == widget.length) widget.onCompleted?.call(v);
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValue);
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final value = widget.controller.text;
    final scaler = MediaQuery.textScalerOf(context);
    final boxHeight = scaler.scale(SellerSize.control + SellerSpace.s8).clamp(SellerSize.control + SellerSpace.s8, SellerSize.control * 2.5);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: SellerSize.touchTarget * widget.length + SellerSpace.s8 * (widget.length - 1)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _focus.requestFocus : null,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: SellerSpace.s8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: context.motion(SellerMotion.fast),
                        curve: SellerMotion.standardCurve,
                        height: boxHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.enabled ? c.surface : c.disabledFill,
                          borderRadius: BorderRadius.circular(SellerRadius.control),
                          border: Border.all(
                            color: widget.hasError
                                ? c.danger
                                : (_isActive(i, value) ? c.focus : (widget.enabled ? c.controlBorder : c.disabledFill)),
                            width: _isActive(i, value) ? SellerSize.focus : SellerSize.hairline,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Text(
                          i < value.length ? value[i] : '',
                          style: text.headlineMedium!.copyWith(color: widget.enabled ? c.textPrimary : c.disabledText).tabular,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // The real input: invisible and full size, still in the
            // accessibility tree — the boxes above are its picture.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  showCursor: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.dsOtpFieldLabel(widget.length),
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isActive(int i, String value) =>
      widget.enabled && _focus.hasFocus && i == value.length.clamp(0, widget.length - 1);
}
