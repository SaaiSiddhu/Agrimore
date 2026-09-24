import 'package:intl/intl.dart';

/// The one place seller screens format money, numbers, dates and sensitive
/// identifiers (board 05 "amounts / IDs & dates"). Screens never build a
/// `NumberFormat` or `DateFormat` themselves. Human phrases ("2 hours ago",
/// "Today") come from the localisation files, not from here.
abstract final class SellerFormat {
  static final NumberFormat _rupeesPaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _rupeesWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final NumberFormat _count = NumberFormat.decimalPattern('en_IN');
  static final NumberFormat _oneDecimal = NumberFormat('0.#', 'en_IN');

  /// Indian grouping; paise shown only when present: `₹1,24,500` · `₹64.50`.
  /// Negative amounts (deductions) keep a real minus sign: `−₹29`.
  static String money(num amount) {
    final paise = (amount * 100).round();
    final whole = paise % 100 == 0;
    final body = (whole ? _rupeesWhole : _rupeesPaise).format(paise.abs() / 100);
    return paise < 0 ? '−$body' : body;
  }

  /// Always two decimals — statements and invoices.
  static String moneyExact(num amount) {
    final body = _rupeesPaise.format(amount.abs());
    return amount < 0 ? '−$body' : body;
  }

  /// Whole rupees for KPI tiles and chart axes: `₹14,000`.
  static String moneyWhole(num amount) {
    final body = _rupeesWhole.format(amount.abs());
    return amount < 0 ? '−$body' : body;
  }

  /// Compact Indian notation for chart axes: `₹999` · `₹45.6K` · `₹1.2L` · `₹3.4Cr`.
  static String moneyCompact(num amount) {
    final sign = amount < 0 ? '−' : '';
    final a = amount.abs();
    if (a >= 10000000) return '$sign₹${_oneDecimal.format(a / 10000000)}Cr';
    if (a >= 100000) return '$sign₹${_oneDecimal.format(a / 100000)}L';
    if (a >= 1000) return '$sign₹${_oneDecimal.format(a / 1000)}K';
    return '$sign${_rupeesWhole.format(a)}';
  }

  /// `1,23,456`
  static String count(num value) => _count.format(value);

  /// Whole-percent: `40%`.
  static String percent(num fraction) => '${(fraction * 100).round()}%';

  /// Signed change for comparisons: `+25%`, `−25%`, `0%` (whole percent).
  static String percentChange(num fraction) {
    final pct = (fraction * 100).round();
    if (pct > 0) return '+$pct%';
    if (pct < 0) return '−${pct.abs()}%';
    return '0%';
  }

  /// `4.5`
  static String rating(num value) => value.toStringAsFixed(1);

  /// `24 Sep`
  static String dayMonth(DateTime d) => DateFormat('d MMM', 'en').format(d);

  /// `24 Sep 2026`
  static String date(DateTime d) => DateFormat('d MMM y', 'en').format(d);

  /// `September 2026`
  static String monthYear(DateTime d) => DateFormat('MMMM y', 'en').format(d);

  /// `10:30 AM`
  static String time(DateTime d) => DateFormat('h:mm a', 'en').format(d);

  /// `24 Sep 2026, 10:30 AM`
  static String dateTime(DateTime d) => '${date(d)}, ${time(d)}';

  /// `Mon`
  static String weekdayShort(DateTime d) => DateFormat('E', 'en').format(d);

  /// `18 – 24 Sep 2026` (same month) or `28 Aug – 3 Sep 2026`.
  static String dateRange(DateTime from, DateTime to) {
    if (from.year == to.year && from.month == to.month) {
      return '${from.day} – ${date(to)}';
    }
    if (from.year == to.year) return '${dayMonth(from)} – ${date(to)}';
    return '${date(from)} – ${date(to)}';
  }

  /// The rupee sign for currency field prefixes (board 05 "₹ prefix segment").
  static const String rupeeSymbol = '₹';

  /// Non-breaking space: a masked number never wraps.
  static const String nbsp = ' ';

  /// `+91 ••••••1234` (board 16-02): only the last four digits of an Indian
  /// mobile number are shown; anything else is masked entirely.
  static String maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final national = digits.length >= 10 ? digits.substring(digits.length - 10) : '';
    if (national.length != 10) return '••••••••••';
    return '+91$nbsp••••••${national.substring(6)}';
  }

  /// `•••• 4821` (board 19-02).
  static String maskAccount(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s'), '');
    if (digits.length < 4) return '••••';
    return '••••$nbsp${digits.substring(digits.length - 4)}';
  }

  /// `ka•••••@bank` (board 19-02): first two characters of the handle.
  static String maskUpi(String raw) {
    final value = raw.trim();
    final at = value.indexOf('@');
    if (at <= 0) return '•••••';
    final handle = value.substring(0, at);
    final visible = handle.length <= 2 ? handle.substring(0, 1) : handle.substring(0, 2);
    return '$visible•••••${value.substring(at)}';
  }

  /// Initials for an avatar fallback: `Kaveri Fresh` → `KF`.
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    String first(String p) => String.fromCharCode(p.runes.first);
    return (first(parts.first) + (parts.length > 1 ? first(parts[1]) : '')).toUpperCase();
  }
}
