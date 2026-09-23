import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ws_foundation.dart';
import '../ws_tokens.dart';

/// Six-cell one-time-code input (Workspace kit, ADR §7 `WsOtpInput`).
///
/// - One hidden [TextField] owns the value, so paste, SMS autofill
///   (`AutofillHints.oneTimeCode`) and the platform keyboard behave natively;
///   the six cells are a rendering of that value.
/// - [onCompleted] fires once when all digits are present.
/// - [hasError] paints the error state; [digitSemanticsLabel] labels each
///   cell for screen readers (the caller supplies localised copy).
class WsOtpInput extends StatefulWidget {
  const WsOtpInput({
    super.key,
    required this.controller,
    required this.digitSemanticsLabel,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final String Function(int index) digitSemanticsLabel;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<WsOtpInput> createState() => _WsOtpInputState();
}

class _WsOtpInputState extends State<WsOtpInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValue);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant WsOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onValue);
      widget.controller.addListener(_onValue);
    }
  }

  void _onFocus() => setState(() {});

  void _onValue() {
    final v = widget.controller.text;
    widget.onChanged?.call(v);
    if (v.length == widget.length) widget.onCompleted?.call(v);
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValue);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    final value = widget.controller.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? () => _focus.requestFocus() : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final filled = i < value.length;
              final active = _focus.hasFocus && i == value.length.clamp(0, widget.length - 1);
              final Color border = widget.hasError
                  ? t.errorFg
                  : active
                      ? t.primary
                      : filled
                          ? t.inputBorder
                          : t.divider;
              return Semantics(
                container: true,
                label: widget.digitSemanticsLabel(i + 1),
                value: filled ? value[i] : null,
                child: AnimatedContainer(
                  duration: WsMotion.fast,
                  curve: WsMotion.curveStandard,
                  width: WsSize.minTouchTarget,
                  height: WsSize.controlHeight + WsSpace.s4,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.enabled ? t.surface : t.disabledContainer,
                    borderRadius: BorderRadius.circular(WsRadius.input),
                    border: Border.all(
                      color: border,
                      width: active || widget.hasError ? WsSize.focusRing : WsSize.hairline,
                    ),
                  ),
                  child: Text(
                    filled ? value[i] : '',
                    style: text.headlineMedium!.copyWith(fontFeatures: WsType.tabularFigures),
                  ),
                ),
              );
            }),
          ),
          // The real input: invisible, full-size, owns keyboard/paste/autofill.
          Positioned.fill(
            // Invisible but still in the accessibility tree: screen-reader
            // users focus and type into this field; the cells are read-only.
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
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
