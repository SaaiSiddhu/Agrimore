import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

/// Accessible text field with visible top label, optional helper text, inline
/// error message, and optional prefix/suffix slots.
///
/// Uses [TextFormField] under the hood so existing form validation and widget
/// tests (`find.widgetWithText(TextFormField, ...)`) continue to work.
class DeliveryTextField extends StatelessWidget {
  const DeliveryTextField({
    super.key,
    this.fieldKey,
    this.controller,
    this.initialValue,
    this.focusNode,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final Key? fieldKey;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return TextFormField(
      key: fieldKey,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      style: t.bodyLarge.copyWith(
        color: enabled ? c.textPrimary : c.textDisabled,
      ),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: DeliveryIconSize.md, color: c.iconMuted)
            : null,
        prefixText: prefixText,
        suffixIcon: suffix,
      ),
    );
  }
}

/// Password input with accessible show/hide toggle.
class DeliveryPasswordField extends StatefulWidget {
  const DeliveryPasswordField({
    super.key,
    this.fieldKey,
    this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const [AutofillHints.password],
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.showLabel = 'Show password',
    this.hideLabel = 'Hide password',
  });

  final Key? fieldKey;
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String showLabel;
  final String hideLabel;

  @override
  State<DeliveryPasswordField> createState() => _DeliveryPasswordFieldState();
}

class _DeliveryPasswordFieldState extends State<DeliveryPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DeliveryTextField(
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      obscureText: _obscured,
      prefixIcon: DeliveryIcons.lock,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffix: IconButton(
        tooltip: _obscured ? widget.showLabel : widget.hideLabel,
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? DeliveryIcons.eye : DeliveryIcons.eyeOff,
          size: DeliveryIconSize.md,
          color: c.iconMuted,
        ),
      ),
    );
  }
}

/// Tabular INR currency input field with `₹` prefix.
class DeliveryCurrencyField extends StatelessWidget {
  const DeliveryCurrencyField({
    super.key,
    this.fieldKey,
    this.controller,
    required this.label,
    this.hint = '0',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  final Key? fieldKey;
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return DeliveryTextField(
      fieldKey: fieldKey,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      prefixText: '₹ ',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}
