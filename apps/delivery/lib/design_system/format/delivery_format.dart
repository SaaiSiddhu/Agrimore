import 'package:intl/intl.dart';

/// Unified formatting for Indian rupees (`₹`), distances (`km` / `m`), dates,
/// times, and masked identifiers in the Delivery Partner app (Phase 05).
abstract final class DeliveryFormat {
  static final NumberFormat _rupeesPaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _rupeesWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final NumberFormat _count = NumberFormat.decimalPattern('en_IN');

  /// Non-breaking space so masked identifiers never wrap mid-token.
  static const String nbsp = '\u00A0';

  /// Formats Indian rupees (`₹1,250` when whole, `₹55.46` with paise).
  /// Negative values use a true minus sign (`− ₹400`).
  static String money(num amount) {
    final paise = (amount * 100).round();
    final whole = paise % 100 == 0;
    final body = (whole ? _rupeesWhole : _rupeesPaise).format(paise.abs() / 100);
    return paise < 0 ? '− $body' : body;
  }

  /// Always formats with two decimal places (`₹1,200.00`, `− ₹400.00`).
  static String moneyExact(num amount) {
    final paise = (amount * 100).round();
    final body = _rupeesPaise.format(paise.abs() / 100);
    return paise < 0 ? '− $body' : body;
  }

  /// Whole rupees (`₹450`).
  static String moneyWhole(num amount) {
    final body = _rupeesWhole.format(amount.abs().round());
    return amount < 0 ? '− $body' : body;
  }

  static String rupees(num amount) => moneyExact(amount);
  static String rupeesWhole(num amount) => moneyWhole(amount);

  /// Indian digit grouping (`1,23,456`).
  static String count(num value) => _count.format(value);

  /// `24 Sep`
  static String dayMonth(DateTime d) => DateFormat('d MMM', 'en').format(d);

  /// `24 Sep 2026`
  static String date(DateTime d) => DateFormat('d MMM y', 'en').format(d);

  /// `10:30 AM`
  static String time(DateTime d) => DateFormat('h:mm a', 'en').format(d);

  /// `24 Sep 2026, 10:30 AM`
  static String dateTime(DateTime d) => '${date(d)}, ${time(d)}';

  /// An inclusive calendar-day range: `14 – 20 Sep 2026` when [start] and
  /// [endInclusive] share a month and year, `28 Sep – 3 Oct 2026` across a
  /// month boundary, `28 Dec 2026 – 3 Jan 2027` across a year boundary.
  static String dateRange(DateTime start, DateTime endInclusive) {
    if (start.year == endInclusive.year && start.month == endInclusive.month) {
      return '${start.day} – ${date(endInclusive)}';
    }
    if (start.year == endInclusive.year) {
      return '${dayMonth(start)} – ${date(endInclusive)}';
    }
    return '${date(start)} – ${date(endInclusive)}';
  }

  /// Masks an Indian mobile number (`+91 •••••• 3210`).
  static String maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final national = digits.length >= 10 ? digits.substring(digits.length - 10) : '';
    if (national.length != 10) return '••••••••••';
    return '+91 •••••• ${national.substring(6)}';
  }

  /// Masks a bank account or generic identifier (`•••• 9012`).
  static String maskTail(String? raw) {
    if (raw == null) return '';
    final clean = raw.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '';
    final tail = clean.length <= 4 ? clean : clean.substring(clean.length - 4);
    return '•••• $tail';
  }

  /// Masks a 12-digit Aadhaar number (`XXXX XXXX 0123`).
  static String maskAadhaar(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return 'XXXX XXXX XXXX';
    return 'XXXX XXXX ${digits.substring(digits.length - 4)}';
  }

  /// Masks a UPI handle (`ra***@okaxis`).
  static String maskUpi(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final value = raw.trim();
    final at = value.indexOf('@');
    if (at <= 0) return value;
    final user = value.substring(0, at);
    final head = user.length <= 2 ? user : '${user.substring(0, 2)}***';
    return '$head${value.substring(at)}';
  }

  /// Initials for avatar fallback (`Arjun Kumar` → `AK`).
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'R';
    String first(String p) => String.fromCharCode(p.runes.first);
    return (first(parts.first) + (parts.length > 1 ? first(parts[1]) : '')).toUpperCase();
  }
}
