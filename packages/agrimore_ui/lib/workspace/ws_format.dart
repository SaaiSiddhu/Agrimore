import 'package:intl/intl.dart';

/// The one place Workspace screens format numbers, money, dates and
/// sensitive identifiers (ADR §11). Screens never construct `NumberFormat`
/// or `DateFormat` themselves.
///
/// Money is Indian: `₹` with lakh/crore digit grouping (`₹1,23,456.00`).
/// Human-language strings (relative times, "Today") belong to each app's
/// localisation files, not here.
abstract final class AgFormat {
  AgFormat._();

  static final NumberFormat _rupees = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final NumberFormat _rupeesWhole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final NumberFormat _count = NumberFormat.decimalPattern('en_IN');
  static final NumberFormat _oneDecimal = NumberFormat('0.#', 'en_IN');

  /// `₹1,23,456.00`
  static String rupees(num amount) => _rupees.format(amount);

  /// `₹1,23,456` — for KPI tiles and chart labels where paise are noise.
  static String rupeesWhole(num amount) => _rupeesWhole.format(amount);

  /// `₹999` · `₹45.6K` · `₹1.2L` · `₹3.4Cr` — Indian compact notation.
  static String rupeesCompact(num amount) {
    final sign = amount < 0 ? '-' : '';
    final a = amount.abs();
    if (a >= 10000000) return '$sign₹${_oneDecimal.format(a / 10000000)}Cr';
    if (a >= 100000) return '$sign₹${_oneDecimal.format(a / 100000)}L';
    if (a >= 1000) return '$sign₹${_oneDecimal.format(a / 1000)}K';
    return '$sign${_rupeesWhole.format(a)}';
  }

  /// `1,23,456`
  static String count(num value) => _count.format(value);

  /// Signed percentage change, one decimal: `+12.5%`, `-3%`, `0%`.
  static String percentDelta(num fraction) {
    final pct = fraction * 100;
    final body = _oneDecimal.format(pct.abs());
    if (pct > 0) return '+$body%';
    if (pct < 0) return '-$body%';
    return '0%';
  }

  /// `26 Sep`
  static String dayMonth(DateTime d) => DateFormat('d MMM').format(d);

  /// `26 Sep 2026`
  static String date(DateTime d) => DateFormat('d MMM y').format(d);

  /// `10:02 am`
  static String time(DateTime d) => DateFormat('h:mm a').format(d).toLowerCase();

  /// `26 Sep, 10:02 am`
  static String dateTime(DateTime d) => '${dayMonth(d)}, ${time(d)}';

  /// Non-breaking space: a phone or account number never wraps mid-number.
  static const String nbsp = '\u00A0';

  /// `+91 98••• ••321` — shows the first 2 and last 3 national digits, joined
  /// with non-breaking spaces. Anything that is not a 10-digit Indian mobile
  /// number is masked entirely.
  static String maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final national = digits.length >= 10 ? digits.substring(digits.length - 10) : '';
    if (national.length != 10) return '••••••••••';
    return '+91$nbsp${national.substring(0, 2)}•••$nbsp••${national.substring(7)}';
  }

  /// `•••• 4821` — bank account numbers after entry.
  static String maskAccount(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    if (digits.length < 4) return '••••';
    return '••••$nbsp${digits.substring(digits.length - 4)}';
  }
}
