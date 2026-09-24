import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Form scope: first-invalid-field focus and the error summary (board 24-07)
// ─────────────────────────────────────────────────────────────────────────────

class _FieldHandle {
  _FieldHandle(this.context, this.node, this.hasError, this.label);
  final BuildContext context;
  final FocusNode node;
  final bool Function() hasError;
  final String Function() label;
}

/// Wrap a [Form] in this to get "move focus to the first invalid field after
/// submit" and a count/list of the fields that need attention.
class SellerFormScope extends StatefulWidget {
  const SellerFormScope({super.key, required this.child});
  final Widget child;

  static SellerFormScopeState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<SellerFormScopeState>();

  @override
  State<SellerFormScope> createState() => SellerFormScopeState();
}

class SellerFormScopeState extends State<SellerFormScope> {
  final List<_FieldHandle> _fields = [];

  void _register(_FieldHandle h) => _fields.add(h);
  void _unregister(FocusNode node) => _fields.removeWhere((f) => f.node == node);

  List<_FieldHandle> _invalidInVisualOrder() {
    final invalid = _fields.where((f) => f.context.mounted && f.hasError()).toList();
    Offset pos(_FieldHandle f) {
      final box = f.context.findRenderObject();
      return box is RenderBox && box.attached ? box.localToGlobal(Offset.zero) : Offset.zero;
    }

    invalid.sort((a, b) {
      final pa = pos(a), pb = pos(b);
      final dy = pa.dy.compareTo(pb.dy);
      return dy != 0 ? dy : pa.dx.compareTo(pb.dx);
    });
    return invalid;
  }

  /// Labels of the fields that currently show an error, top to bottom.
  List<String> get invalidLabels => [for (final f in _invalidInVisualOrder()) f.label()];

  /// Focuses (and scrolls to) the first invalid field. Returns false when none.
  bool focusFirstInvalid() {
    final invalid = _invalidInVisualOrder();
    if (invalid.isEmpty) return false;
    _focusField(invalid.first);
    return true;
  }

  /// Focuses the invalid field with [label] (used by the error summary links).
  void focusLabel(String label) {
    for (final f in _invalidInVisualOrder()) {
      if (f.label() == label) return _focusField(f);
    }
  }

  void _focusField(_FieldHandle f) {
    f.node.requestFocus();
    Scrollable.ensureVisible(f.context, alignment: 0.2, duration: Duration.zero);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Mixin for field states that take part in [SellerFormScope].
mixin _Registers<T extends StatefulWidget> on State<T> {
  FocusNode get fieldNode;
  bool get fieldHasError;
  String get fieldLabel;
  SellerFormScopeState? _scope;

  void registerWithScope() {
    _scope = SellerFormScope.maybeOf(context);
    _scope?._register(_FieldHandle(context, fieldNode, () => fieldHasError, () => fieldLabel));
  }

  void unregisterFromScope() => _scope?._unregister(fieldNode);
}

// ─────────────────────────────────────────────────────────────────────────────
// Label, helper and message
// ─────────────────────────────────────────────────────────────────────────────

/// "Product name *" or "GSTIN (optional)" — a persistent label above a field
/// (board 09). The asterisk is read as "required".
class SellerFieldLabel extends StatelessWidget {
  const SellerFieldLabel({super.key, required this.label, this.required = false, this.optional = false});

  final String label;
  final bool required;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final spans = <InlineSpan>[
      TextSpan(text: label),
      if (required) TextSpan(text: ' *', style: TextStyle(color: c.danger)),
      if (optional) TextSpan(text: ' ${l10n.dsOptional}', style: text.bodyMedium),
    ];
    return Text.rich(
      TextSpan(children: spans),
      style: text.labelLarge,
      semanticsLabel: required ? '$label, ${l10n.dsRequired}' : (optional ? '$label ${l10n.dsOptional}' : label),
    );
  }
}

/// Error line under a field: icon + specific message (boards 05, 09, 13).
class SellerFieldMessage extends StatelessWidget {
  const SellerFieldMessage({super.key, required this.message, this.isError = true, this.icon});

  final String message;
  final bool isError;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = isError ? c.danger : c.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: SellerSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError || icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: SellerSpace.s2),
              child: ExcludeSemantics(child: Icon(icon ?? SellerIcons.error, size: SellerIconSize.sm, color: color)),
            ),
            const SizedBox(width: SellerSpace.s6),
          ],
          Expanded(child: Text(message, style: context.text.bodySmall!.copyWith(color: color))),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required bool hasError,
  String? hint,
  Widget? prefix,
  Widget? suffix,
  String? suffixText,
  bool showCounter = false,
}) {
  final c = context.colors;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(SellerRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    counterText: showCounter ? null : '',
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minHeight: SellerSize.control),
    suffixIcon: suffix,
    suffixText: suffixText,
    suffixStyle: context.text.bodyLarge!.copyWith(color: c.textSecondary),
    enabledBorder: hasError ? border(c.danger, SellerSize.hairline) : null,
    focusedBorder: hasError ? border(c.danger, SellerSize.focus) : null,
  );
}

/// A text segment inside the field's start: "+91 |", "₹ |" (boards 09, 16-01).
class _Segment extends StatelessWidget {
  const _Segment(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: SellerSpace.s16, end: SellerSpace.s12),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: context.text.bodyLarge!.copyWith(color: c.textPrimary)),
            const SizedBox(width: SellerSpace.s12),
            VerticalDivider(width: SellerSize.hairline, thickness: SellerSize.hairline, color: c.border, indent: SellerSpace.s12, endIndent: SellerSpace.s12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text field
// ─────────────────────────────────────────────────────────────────────────────

/// The seller text field (board 09): persistent label above, "*" or
/// "(optional)", helper text, a specific error with an icon, prefix segments
/// ("+91", "₹"), unit suffix ("kg"), password show/hide. Works inside a
/// [Form] (its [validator] runs on submit) and a [SellerFormScope].
class SellerTextField extends StatefulWidget {
  const SellerTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.required = false,
    this.optional = false,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.showCounter = false,
    this.maxLines = 1,
    this.minLines,
    this.obscure = false,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.fieldKey,
    this.tabular = false,
    this.autovalidateMode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// An error from outside the form (e.g. the server said the code is wrong).
  final String? errorText;

  /// Returns a specific message, or null when valid.
  final String? Function(String value)? validator;
  final bool required;
  final bool optional;
  final String? prefixText;
  final String? suffixText;
  final IconData? prefixIcon;

  /// Widget at the end of the field (a clear button, a spinner).
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool showCounter;
  final int? maxLines;
  final int? minLines;

  /// Secret input with a show/hide toggle (password, API key).
  final bool obscure;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  /// Key of the inner [TextField] (tests).
  final Key? fieldKey;
  final bool tabular;
  final AutovalidateMode? autovalidateMode;

  @override
  State<SellerTextField> createState() => _SellerTextFieldState();
}

class _SellerTextFieldState extends State<SellerTextField> with _Registers<SellerTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownNode;
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  bool _hidden = true;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());

  @override
  FocusNode get fieldNode => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: widget.label));

  @override
  bool get fieldHasError => widget.errorText != null || (_fieldKey.currentState?.hasError ?? false);

  @override
  String get fieldLabel => widget.label;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unregisterFromScope();
    registerWithScope();
  }

  @override
  void dispose() {
    unregisterFromScope();
    _ownController?.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return FormField<String>(
      key: _fieldKey,
      validator: widget.validator == null ? null : (_) => widget.validator!(_controller.text),
      autovalidateMode: widget.autovalidateMode,
      builder: (field) {
        final error = widget.errorText ?? field.errorText;
        Widget? suffix = widget.trailing;
        if (widget.obscure) {
          suffix = IconButton(
            tooltip: _hidden ? l10n.showPassword : l10n.hidePassword,
            icon: Icon(_hidden ? SellerIcons.eye : SellerIcons.eyeOff, size: SellerIconSize.md),
            onPressed: () => setState(() => _hidden = !_hidden),
          );
        } else if (error != null && suffix == null) {
          suffix = ExcludeSemantics(child: Icon(SellerIcons.error, color: c.danger, size: SellerIconSize.md));
        }
        Widget? prefix;
        if (widget.prefixText != null) {
          prefix = _Segment(widget.prefixText!);
        } else if (widget.prefixIcon != null) {
          prefix = Padding(
            padding: const EdgeInsetsDirectional.only(start: SellerSpace.s12, end: SellerSpace.s8),
            child: Icon(widget.prefixIcon, size: SellerIconSize.md),
          );
        }
        var style = context.text.bodyLarge!;
        if (widget.tabular) style = style.tabular;
        return MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SellerFieldLabel(label: widget.label, required: widget.required, optional: widget.optional),
              const SizedBox(height: SellerSpace.s6),
              TextField(
                key: widget.fieldKey,
                controller: _controller,
                focusNode: fieldNode,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                autofocus: widget.autofocus,
                obscureText: widget.obscure && _hidden,
                enableSuggestions: !widget.obscure,
                autocorrect: !widget.obscure,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                maxLength: widget.maxLength,
                maxLines: widget.obscure ? 1 : widget.maxLines,
                minLines: widget.minLines,
                autofillHints: widget.autofillHints,
                textCapitalization: widget.textCapitalization,
                style: style,
                decoration: _fieldDecoration(
                  context,
                  hasError: error != null,
                  hint: widget.hint,
                  prefix: prefix,
                  suffix: suffix,
                  suffixText: widget.suffixText,
                  showCounter: widget.showCounter,
                ),
                onChanged: (v) {
                  field.didChange(v);
                  widget.onChanged?.call(v);
                },
                onSubmitted: widget.onSubmitted,
              ),
              if (error != null)
                SellerFieldMessage(message: error)
              else if (widget.helper != null)
                SellerFieldMessage(message: widget.helper!, isError: false),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select (dropdown)
// ─────────────────────────────────────────────────────────────────────────────

/// One option of a [SellerSelectField].
@immutable
class SellerOption<T> {
  const SellerOption(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Dropdown with a persistent label and the same error line as text fields
/// (board 09 "dropdown opens a list"). Keyboard focus thickens the field border.
class SellerSelectField<T> extends StatefulWidget {
  const SellerSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
    this.validator,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.prefixIcon,
  });

  final String label;
  final List<SellerOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String? helper;
  final String? Function(T? value)? validator;
  final bool required;
  final bool optional;
  final bool enabled;
  final IconData? prefixIcon;

  @override
  State<SellerSelectField<T>> createState() => _SellerSelectFieldState<T>();
}

class _SellerSelectFieldState<T> extends State<SellerSelectField<T>> with _Registers<SellerSelectField<T>> {
  final FocusNode _node = FocusNode(debugLabel: 'SellerSelectField');
  final _fieldKey = GlobalKey<FormFieldState<T>>();

  @override
  FocusNode get fieldNode => _node;

  @override
  bool get fieldHasError => _fieldKey.currentState?.hasError ?? false;

  @override
  String get fieldLabel => widget.label;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unregisterFromScope();
    registerWithScope();
  }

  @override
  void dispose() {
    unregisterFromScope();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FormField<T>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator == null ? null : (_) => widget.validator!(widget.value),
      builder: (field) {
        final error = field.errorText;
        return MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SellerFieldLabel(label: widget.label, required: widget.required, optional: widget.optional),
              const SizedBox(height: SellerSpace.s6),
              SellerFocusTracker(
                focusNode: _node,
                builder: (context, focused, node) => InputDecorator(
                  isFocused: focused,
                  isEmpty: widget.value == null,
                  decoration: _fieldDecoration(
                    context,
                    hasError: error != null,
                    hint: widget.hint,
                    prefix: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: SellerIconSize.md),
                  ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s4)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      focusNode: node,
                      value: widget.value,
                      isExpanded: true,
                      isDense: false,
                      hint: widget.hint == null ? null : Text(widget.hint!, style: context.text.bodyLarge!.copyWith(color: c.textTertiary)),
                      icon: Icon(SellerIcons.chevronDown, size: SellerIconSize.md, color: c.textSecondary),
                      dropdownColor: c.raised,
                      borderRadius: BorderRadius.circular(SellerRadius.control),
                      style: context.text.bodyLarge,
                      focusColor: Colors.transparent,
                      items: [
                        for (final o in widget.options)
                          DropdownMenuItem<T>(
                            value: o.value,
                            child: Row(children: [
                              if (o.icon != null) ...[
                                Icon(o.icon, size: SellerIconSize.md, color: c.primary),
                                const SizedBox(width: SellerSpace.s8),
                              ],
                              Flexible(child: Text(o.label, overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                      ],
                      onChanged: widget.enabled
                          ? (v) {
                              field.didChange(v);
                              widget.onChanged(v);
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              if (error != null)
                SellerFieldMessage(message: error)
              else if (widget.helper != null)
                SellerFieldMessage(message: widget.helper!, isError: false),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Picker field (date, time, anything opened in a sheet or dialog)
// ─────────────────────────────────────────────────────────────────────────────

/// A field-shaped button that opens a picker: icon + value (or placeholder) +
/// chevron (board 09 "date/time rows"; 22-05 opens/closes; 23-03 quiet hours).
class SellerPickerField extends StatelessWidget {
  const SellerPickerField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.icon,
    this.error,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.showLabel = true,
  });

  final String label;
  final VoidCallback onTap;
  final String? value;
  final String? placeholder;
  final IconData? icon;
  final String? error;
  final bool required;
  final bool optional;
  final bool enabled;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final hasValue = value != null && value!.isNotEmpty;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel) ...[
            SellerFieldLabel(label: label, required: required, optional: optional),
            const SizedBox(height: SellerSpace.s6),
          ],
          SellerFocusTracker(
            builder: (context, focused, node) {
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SellerRadius.control),
                side: sellerOutline(
                  c,
                  focused: focused,
                  rest: error != null ? c.danger : (enabled ? c.controlBorder : c.disabledFill),
                  focusColor: error != null ? c.danger : null,
                ),
              );
              return Semantics(
                button: true,
                label: showLabel ? null : label,
                value: hasValue ? value : placeholder,
                child: Material(
                  color: enabled ? c.surface : c.disabledFill,
                  shape: shape,
                  child: InkWell(
                    focusNode: node,
                    onTap: enabled ? onTap : null,
                    customBorder: shape,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: SellerSize.control),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s12),
                        child: Row(
                          children: [
                            if (icon != null) ...[
                              ExcludeSemantics(child: Icon(icon, size: SellerIconSize.md, color: c.textSecondary)),
                              const SizedBox(width: SellerSpace.s12),
                            ],
                            Expanded(
                              child: ExcludeSemantics(
                                child: Text(
                                  hasValue ? value! : (placeholder ?? ''),
                                  style: text.bodyLarge!.copyWith(color: hasValue ? c.textPrimary : c.textTertiary).tabular,
                                ),
                              ),
                            ),
                            ExcludeSemantics(child: Icon(SellerIcons.chevronRight, size: SellerIconSize.md, color: c.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (error != null) SellerFieldMessage(message: error!),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slider field
// ─────────────────────────────────────────────────────────────────────────────

/// "Delivery radius — 10 km" with a slider (boards 09, 16-03, 18-07). The
/// slider row's own outline shows keyboard focus; arrow keys adjust.
class SellerSliderField extends StatelessWidget {
  const SellerSliderField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.divisions,
    this.minLabel,
    this.maxLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final String? minLabel;
  final String? maxLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return SellerFocusTracker(
      builder: (context, focused, node) => Container(
        padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s4, vertical: SellerSpace.s4),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SellerRadius.control),
            side: sellerOutline(c, focused: focused, rest: Colors.transparent),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8),
                child: Row(children: [
                  Expanded(child: Text(label, style: text.labelLarge)),
                  Text(valueLabel, style: text.titleSmall!.copyWith(color: c.primary).tabular),
                ]),
              ),
            ),
            Semantics(
              label: label,
              child: Slider(
                focusNode: node,
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                label: valueLabel,
                semanticFormatterCallback: (_) => valueLabel,
                onChanged: onChanged,
              ),
            ),
            if (minLabel != null || maxLabel != null)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8),
                  child: Row(children: [
                    Text(minLabel ?? '', style: text.bodySmall),
                    const Spacer(),
                    Text(maxLabel ?? '', style: text.bodySmall),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice rows: radio, checkbox, switch — one focus stop per row
// ─────────────────────────────────────────────────────────────────────────────

/// Radio option row. [card] = bordered option card (board 20-05 validity);
/// otherwise a plain list row (board 17-06 reasons). The row is the one
/// focusable control and is announced as a radio in a group.
class SellerChoiceRow<T> extends StatelessWidget {
  const SellerChoiceRow({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.icon,
    this.card = false,
    this.enabled = true,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool card;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final selected = value == groupValue;
    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(card ? SellerRadius.card : SellerRadius.control),
          side: sellerOutline(
            c,
            focused: focused,
            rest: card ? (selected ? c.primary : c.border) : Colors.transparent,
            restWidth: card && selected ? SellerSize.focus : SellerSize.hairline,
          ),
        );
        return Semantics(
          inMutuallyExclusiveGroup: true,
          checked: selected,
          enabled: enabled,
          label: subtitle == null ? title : '$title, $subtitle',
          excludeSemantics: true,
          onTap: enabled ? () => onChanged(value) : null,
          child: Material(
            color: card && selected ? c.primarySubtle : (card ? c.surface : Colors.transparent),
            shape: shape,
            child: InkWell(
              focusNode: node,
              onTap: enabled ? () => onChanged(value) : null,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: SellerSize.touchTarget),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: card ? SellerSpace.s16 : SellerSpace.s8, vertical: SellerSpace.s8),
                  child: Row(
                    children: [
                      _RadioDot(selected: selected, enabled: enabled),
                      const SizedBox(width: SellerSpace.s12),
                      if (icon != null) ...[
                        Icon(icon, size: SellerIconSize.md, color: c.textSecondary),
                        const SizedBox(width: SellerSpace.s12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: text.bodyLarge!.copyWith(fontWeight: card ? SellerType.semibold : null)),
                            if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
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

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.enabled});
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ring = !enabled ? c.disabledText : (selected ? c.primary : c.controlBorder);
    return Container(
      width: SellerIconSize.md,
      height: SellerIconSize.md,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: SellerSize.focus)),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: SellerSpace.s8 + SellerSpace.s2,
              height: SellerSpace.s8 + SellerSpace.s2,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
            )
          : null,
    );
  }
}

/// Checkbox row (consent, multi-select). The row is the focusable control.
class SellerCheckRow extends StatelessWidget {
  const SellerCheckRow({super.key, required this.value, required this.onChanged, required this.title, this.subtitle, this.titleWidget});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String? subtitle;

  /// Rich title (e.g. with a link); [title] stays the accessible name.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SellerRadius.control),
          side: sellerOutline(c, focused: focused, rest: Colors.transparent),
        );
        return Semantics(
          checked: value,
          label: title,
          excludeSemantics: true,
          onTap: () => onChanged(!value),
          child: Material(
            color: Colors.transparent,
            shape: shape,
            child: InkWell(
              focusNode: node,
              onTap: () => onChanged(!value),
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: SellerSize.touchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8, vertical: SellerSpace.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: SellerIconSize.md,
                        height: SellerIconSize.md,
                        margin: const EdgeInsets.only(top: SellerSpace.s2),
                        decoration: BoxDecoration(
                          color: value ? c.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(SellerRadius.xs),
                          border: Border.all(color: value ? c.primary : c.controlBorder, width: SellerSize.focus),
                        ),
                        child: value ? Icon(SellerIcons.check, size: SellerIconSize.sm, color: c.onPrimary) : null,
                      ),
                      const SizedBox(width: SellerSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleWidget ?? Text(title, style: text.bodyLarge),
                            if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
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

/// Setting row with a switch: "Orders — New orders and order updates" (boards
/// 23-02, 24-03). One focus stop and one announcement: "Orders, switch, on".
class SellerSwitchRow extends StatelessWidget {
  const SellerSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.bordered = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool bordered;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final active = enabled && onChanged != null;
    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(bordered ? SellerRadius.card : SellerRadius.control),
          side: sellerOutline(c, focused: focused, rest: bordered ? c.border : Colors.transparent),
        );
        return Semantics(
          toggled: value,
          enabled: active,
          label: subtitle == null ? title : '$title, $subtitle',
          excludeSemantics: true,
          onTap: active ? () => onChanged!(!value) : null,
          child: Material(
            color: bordered ? c.surface : Colors.transparent,
            shape: shape,
            child: InkWell(
              focusNode: node,
              onTap: active ? () => onChanged!(!value) : null,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: SellerSize.touchTarget + SellerSpace.s8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s8),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: SellerIconSize.lg, color: c.textSecondary),
                        const SizedBox(width: SellerSpace.s16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: text.titleSmall),
                            if (subtitle != null) Text(subtitle!, style: text.bodyMedium),
                          ],
                        ),
                      ),
                      const SizedBox(width: SellerSpace.s12),
                      ExcludeFocus(
                        child: Switch(value: value, onChanged: active ? onChanged : null),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Error summary (board 24-07)
// ─────────────────────────────────────────────────────────────────────────────

/// "1 field needs attention · Stock quantity" — shown at the top of a form after
/// a failed submit; each label moves focus to its field.
class SellerFormErrorSummary extends StatelessWidget {
  const SellerFormErrorSummary({super.key, required this.labels, required this.onSelect});

  final List<String> labels;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final text = context.text;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SellerSpace.s16),
        decoration: BoxDecoration(
          color: c.dangerContainer,
          borderRadius: BorderRadius.circular(SellerRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(SellerIcons.error, color: c.danger, size: SellerIconSize.lg)),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).dsFieldsNeedAttention(labels.length), style: text.titleSmall),
                  for (final l in labels)
                    TextButton(
                      onPressed: () => onSelect(l),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        foregroundColor: c.danger,
                        textStyle: text.labelLarge!.copyWith(decoration: TextDecoration.underline),
                      ),
                      child: Text(l),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
