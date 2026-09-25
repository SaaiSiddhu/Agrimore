import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

/// 4-digit or 6-digit OTP / PIN entry component used in Auth OTP verification
/// and Buyer Delivery PIN confirmation.
///
/// Renders visual individual digit cells around a single underlying
/// [TextField] so that:
/// - OS SMS autofill (`AutofillHints.oneTimeCode`) and clipboard paste work
///   natively,
/// - Screen readers announce a single unified OTP field, and
/// - Existing widget tests using `tester.enterText(find.byType(TextField), '4829')`
///   work without modification.
class DeliveryOtpField extends StatefulWidget {
  const DeliveryOtpField({
    super.key,
    required this.controller,
    this.length = 4,
    this.label,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onCompleted,
    this.digitSemanticsLabel,
  });

  final TextEditingController controller;
  final int length;
  final String? label;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final String Function(int index)? digitSemanticsLabel;

  @override
  State<DeliveryOtpField> createState() => _DeliveryOtpFieldState();
}

class _DeliveryOtpFieldState extends State<DeliveryOtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DeliveryOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final text = widget.controller.text;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: t.labelMedium.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DeliverySpace.sm),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(widget.length, (index) {
                  final char = index < text.length ? text[index] : '';
                  final isActiveCell = _focusNode.hasFocus &&
                      (index == text.length ||
                          (text.length == widget.length &&
                              index == widget.length - 1));
                  final Color borderColor;
                  final double strokeWidth;
                  if (hasError) {
                    borderColor = c.danger.solid;
                    strokeWidth = DeliverySize.strokeStrong;
                  } else if (isActiveCell) {
                    borderColor = c.brand;
                    strokeWidth = DeliverySize.strokeFocus;
                  } else if (char.isNotEmpty) {
                    borderColor = c.brandBorder;
                    strokeWidth = DeliverySize.strokeStrong;
                  } else {
                    borderColor = c.borderStrong;
                    strokeWidth = DeliverySize.stroke;
                  }

                  return Expanded(
                    child: Container(
                      height: 56,
                      margin: EdgeInsets.only(
                        right: index < widget.length - 1 ? DeliverySpace.sm : 0,
                      ),
                      decoration: BoxDecoration(
                        color: char.isNotEmpty
                            ? c.brandContainer.withValues(alpha: 0.45)
                            : c.surface,
                        borderRadius: DeliveryRadius.rMd,
                        border: Border.all(
                          color: borderColor,
                          width: strokeWidth,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: t.headlineMedium.tabular.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              // Underlying accessible TextField for keyboard input, paste, and
              // widget tests (`find.byType(TextField)`).
              Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: widget.length,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: widget.label,
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                    if (value.length == widget.length) {
                      widget.onCompleted?.call(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: DeliverySpace.xs),
          Text(
            widget.errorText!,
            style: t.caption.copyWith(color: c.danger.onContainer),
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: DeliverySpace.xs),
          Text(
            widget.helperText!,
            style: t.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}
