import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/associate_application_service.dart' as service;

/// Phase 16B, Workstream 1 — the OPTIONAL "Associate Code" input.
///
/// Why this exists: `createOrder` (functions/src/customer/createOrder.ts) has
/// accepted an `employeeCode` on B2C orders since Phase 16D-2 and resolves it
/// server-side, but no client ever sent one — so no ordinary retail purchase
/// could ever be attributed to a Sales Associate. This is the field that
/// closes that gap.
///
/// Shared by BOTH marketplace checkout surfaces that call the `createOrder`
/// callable — `payment_method_screen.dart` (the full checkout) and
/// `mobile_cart_screen.dart` (the cart's quick checkout) — so the two can
/// never drift in copy, casing rules, or length cap. It lives under
/// `screens/user/checkout/widgets/` rather than in `packages/agrimore_ui`
/// deliberately: it is marketplace-only, and putting it in a shared package
/// would push it onto four apps that have no use for it.
///
/// INVARIANTS THIS WIDGET MUST KEEP (locked decisions D2/D3):
///   * It can NEVER block or fail a purchase. The Apply button below only
///     ever produces informational feedback ("code applied" / "not
///     recognised") — it is never a `Form` validator, nothing it shows
///     disables the pay button, and a customer who never taps Apply (or
///     never opens this field at all) reaches payment exactly as before.
///   * It NEVER decides whether attribution happens. `createOrder.ts`
///     re-resolves the code independently at order time — Apply's
///     verifyAssociateCode call is advisory UI feedback only, using the same
///     resolution rules so the checkmark is truthful, but it is not the
///     thing that actually grants attribution.
///   * It NEVER shows another associate's code, a name, or any associate
///     list — a customer only ever sees what they themselves typed, plus a
///     valid/not-recognised state with no identifying detail in it.
///   * It makes no earnings claim, states no figure, and implies no income.
///
/// This widget is used for B2C only. B2B keeps its own separate, REQUIRED
/// "Employee ID *" field on both screens, unchanged by this phase.
class AssociateCodeField extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color accentColor;

  /// Compact layout for the cart's quick-checkout bottom bar, where vertical
  /// space is scarce and the pay button is inches away; the full checkout
  /// screen uses the roomier layout with the longer explanation.
  final bool dense;

  /// When true, configures the field as a required Employee ID field for B2B
  /// orders with an Apply button and B2B-specific feedback.
  final bool isB2B;

  const AssociateCodeField({
    super.key,
    required this.controller,
    required this.isDark,
    required this.accentColor,
    this.dense = false,
    this.isB2B = false,
  });

  static const String label = 'Associate Code (optional)';
  static const String hint = 'e.g. RAME07';

  static const String b2bLabel = 'Employee ID *';
  static const String b2bHint = 'Enter sales employee code';

  static const String longHelper =
      'Helped by an AgriMore Sales Associate? Enter their code and tap Apply '
      'so this order is recorded against them. Leave it blank if not — your '
      'order and your total are the same either way.';

  static const String b2bLongHelper =
      'Wholesale orders require a verified Sales Employee Code. Enter the code '
      'and tap Apply to verify and attribute this bulk order.';

  static const String shortHelper =
      'Optional — records this order against your Sales Associate.';

  static const String b2bShortHelper =
      'Required for wholesale / bulk orders.';

  /// Generated codes are 6 characters (`EmployeeModel.generateEmployeeCode`:
  /// a 4-letter name prefix + a 2-digit sequence). 20 leaves generous room
  /// for any longer code an admin might assign by hand without letting the
  /// field accept arbitrary volumes of text.
  static const int maxCodeLength = 20;

  /// Input FORMATTING only — never validation, and never anything that can
  /// reject a submission:
  ///   * whitespace is dropped as typed, so a pasted " RAME07 " becomes
  ///     "RAME07" in front of the customer rather than silently at send time;
  ///   * input is upper-cased because every stored code is upper-case
  ///     (`generateEmployeeCode` upper-cases the name prefix and the rest are
  ///     digits) while `createOrder.ts` deliberately does NOT case-normalise —
  ///     so without this, a customer typing "rame07" would silently fail to
  ///     attribute. This can only ever turn a non-match into a match; it can
  ///     never cause a wrong associate to be credited, and the server still
  ///     re-resolves whatever arrives;
  ///   * length is capped so the field cannot be used as a text dump.
  static final List<TextInputFormatter> inputFormatters = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          newValue.copyWith(text: newValue.text.toUpperCase()),
    ),
    LengthLimitingTextInputFormatter(maxCodeLength),
  ];

  @override
  State<AssociateCodeField> createState() => _AssociateCodeFieldState();
}

enum _CheckState {
  idle,
  checking,
  valid,
  notRecognized,
  selfCode,
  notActive,
  checkFailed,
  unauthenticated,
}

class _AssociateCodeFieldState extends State<AssociateCodeField> {
  _CheckState _state = _CheckState.idle;
  String? _lastCheckedCode;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // A stale "✓ Applied" state left over after the customer edits the code
  // post-Apply would be actively misleading — drop back to idle the moment
  // the text no longer matches what was actually checked.
  void _onTextChanged() {
    if (widget.controller.text.trim() != _lastCheckedCode &&
        _state != _CheckState.idle &&
        _state != _CheckState.checking) {
      setState(() => _state = _CheckState.idle);
    }
  }

  Future<void> _handleApply() async {
    final code = widget.controller.text.trim();
    if (code.isEmpty || _state == _CheckState.checking) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _state = _CheckState.checking);

    try {
      // 1. Check if the code is the current logged-in user's own associate code
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          final employeeDoc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(currentUser.uid)
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 1));
          if (employeeDoc.exists) {
            final myCode = employeeDoc
                .data()?['employeeCode']
                ?.toString()
                .toUpperCase();
            if (myCode != null && myCode.isNotEmpty && myCode == code.toUpperCase()) {
              if (!mounted) return;
              _lastCheckedCode = code;
              setState(() => _state = _CheckState.selfCode);
              HapticFeedback.selectionClick();
              return;
            }
          }
        } catch (_) {
          // Non-critical, fall back to backend callable check
        }
      }

      final details = await service.verifyAssociateCodeDetails(code);
      if (!mounted) return;
      _lastCheckedCode = code;
      if (details.valid) {
        setState(() => _state = _CheckState.valid);
      } else if (details.reason == 'self') {
        setState(() => _state = _CheckState.selfCode);
      } else if (details.reason == 'not_active') {
        // In B2B mode, status == 'approved' is all that createOrder.ts requires
        // (onboarding fee is B2C only). Since verifyAssociateCode matched
        // status == 'approved', it's valid for B2B.
        if (widget.isB2B) {
          setState(() => _state = _CheckState.valid);
        } else {
          setState(() => _state = _CheckState.notActive);
        }
      } else if (details.reason == 'error') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          setState(() => _state = _CheckState.unauthenticated);
        } else {
          setState(() => _state = _CheckState.checkFailed);
        }
      } else {
        setState(() => _state = _CheckState.notRecognized);
      }
      HapticFeedback.selectionClick();
    } catch (_) {
      // Network/auth hiccup — never presented as "invalid". The order can
      // still be placed either way; createOrder.ts re-resolves the code
      // independently regardless of whether this check ever ran.
      if (!mounted) return;
      setState(() => _state = _CheckState.checkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accentColor = widget.accentColor;

    final field = TextField(
      controller: widget.controller,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      inputFormatters: AssociateCodeField.inputFormatters,
      onSubmitted: (_) => _handleApply(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: widget.isB2B ? AssociateCodeField.b2bLabel : AssociateCodeField.label,
        hintText: widget.isB2B ? AssociateCodeField.b2bHint : AssociateCodeField.hint,
        isDense: widget.dense,
        prefixIcon: Icon(Icons.badge_outlined, size: widget.dense ? 20 : 22),
        filled: true,
        fillColor: isDark ? const Color(0xFF252525) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
    );

    final applyButton = _buildApplyButton(isDark, accentColor);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        applyButton,
      ],
    );

    final feedback = _buildFeedback(isDark, accentColor);

    if (widget.dense) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          if (feedback != null) ...[
            const SizedBox(height: 6),
            feedback,
          ] else ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                widget.isB2B
                    ? AssociateCodeField.b2bShortHelper
                    : AssociateCodeField.shortHelper,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isB2B
              ? AssociateCodeField.b2bLongHelper
              : AssociateCodeField.longHelper,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        row,
        if (feedback != null) ...[
          const SizedBox(height: 10),
          feedback,
        ],
      ],
    );
  }

  Widget _buildApplyButton(bool isDark, Color accentColor) {
    final height = widget.dense ? 46.0 : 52.0;
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: _state == _CheckState.checking ? null : _handleApply,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          disabledBackgroundColor: accentColor.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _state == _CheckState.checking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Apply',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  // Purely informational — never rendered as an error, never anything the
  // pay button reads. "Not recognised" and "couldn't check" are worded to
  // reassure, not alarm, since the order proceeds identically either way.
  Widget? _buildFeedback(bool isDark, Color accentColor) {
    switch (_state) {
      case _CheckState.valid:
        return _FeedbackChip(
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade600,
          text: widget.isB2B
              ? 'Employee ID applied successfully.'
              : 'Code applied — this order will support your Sales Associate.',
        );
      case _CheckState.selfCode:
        return _FeedbackChip(
          icon: Icons.error_outline_rounded,
          color: Colors.red.shade700,
          text: widget.isB2B
              ? 'You cannot attribute a B2B order to your own Employee ID.'
              : 'This is your own Associate Code. Self-attribution is not eligible for commission, but you can still place your order.',
        );
      case _CheckState.notActive:
        return _FeedbackChip(
          icon: Icons.info_outline_rounded,
          color: Colors.orange.shade700,
          text: widget.isB2B
              ? 'Employee is not active yet.'
              : 'Associate is not active yet — you can still place your order.',
        );
      case _CheckState.notRecognized:
        return _FeedbackChip(
          icon: widget.isB2B ? Icons.cancel_outlined : Icons.info_outline_rounded,
          color: widget.isB2B ? Colors.red.shade700 : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
          text: widget.isB2B
              ? 'Employee ID not recognised or not approved.'
              : 'Code not recognised — you can still place your order.',
        );
      case _CheckState.checkFailed:
        return _FeedbackChip(
          icon: Icons.wifi_off_rounded,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
          text: widget.isB2B
              ? "Couldn't verify employee code right now. You can still proceed if the code is correct."
              : "Couldn't check right now — you can still place your order.",
        );
      case _CheckState.unauthenticated:
        return _FeedbackChip(
          icon: Icons.info_outline_rounded,
          color: Colors.orange.shade700,
          text: 'Please sign in to verify this code.',
        );
      case _CheckState.idle:
      case _CheckState.checking:
        return null;
    }
  }
}

class _FeedbackChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FeedbackChip({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}
