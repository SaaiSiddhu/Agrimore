import 'package:agrimore_core/agrimore_core.dart';

/// Phase 16B-3, Defect 1 — the ONE place that turns the authoritative
/// top-level `feeAmount`/`currency` (from `getAssociateOnboardingConfig`)
/// into display text. Shared by `onboarding_info_sections.dart` (header
/// badge, summary card) AND `onboarding_payment_step.dart` (the CTA button
/// label) specifically so there is only one formatting rule to keep in
/// sync — a second, independently-written copy is exactly how the payment
/// step's CTA button ended up still saying "₹500" the first time this
/// defect was fixed (caught during Workstream 5 eye-verification: the
/// header and summary card correctly showed ₹750, but the button a
/// visitor actually taps to pay still read "Complete Registration — ₹500",
/// sourced from `copy.summaryCard.ctaLabel`, a THIRD static-string
/// location Workstream 1 had not touched).
///
/// Returns null — render no fee text at all — when `feeAmount` is not a
/// usable positive number, or when a non-INR `currency` is present
/// (`PriceFormatter` is INR-only). Never falls back to a copy-sourced
/// string: see this file's callers for why.
String? authoritativeFeeText(num? feeAmount, String? currency) {
  if (feeAmount == null) return null;
  final value = feeAmount.toDouble();
  if (!value.isFinite || value <= 0) return null;
  if (currency != null && currency.toUpperCase() != 'INR') return null;
  final hasFraction = value != value.roundToDouble();
  return hasFraction ? PriceFormatter.formatPrice(value) : PriceFormatter.formatPriceInt(value);
}
