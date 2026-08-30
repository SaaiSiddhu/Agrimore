import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///   * It can NEVER block or fail a purchase. There is no validator, no
///     `Form`, no error state, and nothing the pay button reads. A customer
///     with no code reaches payment in exactly the taps they did before this
///     field existed.
///   * It NEVER decides whether attribution happens. The server re-resolves
///     the code independently; an unrecognised code silently yields no
///     attribution and the order is still created.
///   * It NEVER shows another associate's code, and never any associate list
///     — a customer only ever sees what they themselves typed.
///   * It makes no earnings claim, states no figure, and implies no income.
///
/// This widget is used for B2C only. B2B keeps its own separate, REQUIRED
/// "Employee ID *" field on both screens, unchanged by this phase.
class AssociateCodeField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color accentColor;

  /// Compact layout for the cart's quick-checkout bottom bar, where vertical
  /// space is scarce and the pay button is inches away; the full checkout
  /// screen uses the roomier layout with the longer explanation.
  final bool dense;

  const AssociateCodeField({
    super.key,
    required this.controller,
    required this.isDark,
    required this.accentColor,
    this.dense = false,
  });

  static const String label = 'Associate Code (optional)';
  static const String hint = 'e.g. RAME07';

  static const String longHelper =
      'Helped by an AgriMore Sales Associate? Enter their code so this order '
      'is recorded against them. Leave it blank if not — your order and your '
      'total are the same either way.';

  static const String shortHelper =
      'Optional — records this order against your Sales Associate.';

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
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: dense ? shortHelper : null,
        helperMaxLines: 2,
        helperStyle: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        isDense: dense,
        prefixIcon: Icon(Icons.badge_outlined, size: dense ? 20 : 22),
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

    if (dense) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          longHelper,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        field,
      ],
    );
  }
}
