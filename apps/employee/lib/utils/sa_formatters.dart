// ignore_for_file: public_member_api_docs

import 'package:agrimore_core/agrimore_core.dart';
import 'package:intl/intl.dart';

/// Content formatting conventions for AgriMore Sales Associate.
///
/// Implements the content conventions specified on canonical board 02:
/// - Currency: Indian number grouping with two decimals (e.g. ₹1,25,000.00)
///   via [PriceFormatter.formatPrice].
/// - Date: Day-month-year with abbreviated month (e.g. 18 Sep 2026).
/// - Phone: Masked mobile number with country code (e.g. +91 •••••• 4321).
abstract final class SaFormatters {
  SaFormatters._();

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  /// Formats a monetary amount into canonical rupee currency representation.
  /// Example: 12500 -> `₹12,500.00`.
  static String formatCurrency(num amount) {
    return PriceFormatter.formatPrice(amount.toDouble());
  }

  /// Formats a [DateTime] into canonical date representation (`18 Sep 2026`).
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formats a 10-digit Indian phone number with masking.
  /// Example: `9876544321` or `+919876544321` -> `+91 •••••• 4321`.
  static String formatMaskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final last4 = digits.substring(digits.length - 4);
    return '+91 •••••• $last4';
  }

  /// Masks an account number showing only the last 4 digits.
  /// Example: `Account ending 4321`.
  static String formatMaskedAccount(String accountNumber) {
    final digits = accountNumber.replaceAll(RegExp(r'\s'), '');
    if (digits.length <= 4) return 'Account ending $digits';
    final last4 = digits.substring(digits.length - 4);
    return 'Account ending $last4';
  }
}
