// lib/screens/admin/delivery/rider_money_admin.dart
//
// Phase DLV-4B — pure helpers for the admin Rider Payouts screen. The rate
// bounds MUST match functions/src/delivery/riderPay.ts BOUNDS: the server
// ignores any value outside them and uses its default, so the form refuses
// them here rather than saving a number that silently does nothing.
// Covered by test/rider_money_admin_test.dart.

import 'dart:math';

class RateField {
  final String key;
  final String label;
  final String unit;
  final double min;
  final double max;
  final double defaultValue;
  const RateField(this.key, this.label, this.unit, this.min, this.max, this.defaultValue);
}

/// settings/rider_pay — same keys, bounds and defaults as riderPay.ts.
const riderPayFields = <RateField>[
  RateField('basePay', 'Base pay per delivery', '₹', 0, 500, 25),
  RateField('perKm', 'Pay per km (store → customer)', '₹/km', 0, 100, 6),
  RateField('waitingPerMin', 'Waiting pay', '₹/min', 0, 20, 1),
  RateField('waitingFreeMin', 'Free waiting at the store', 'min', 0, 120, 10),
  RateField('codCashLimit', 'Cash limit for COD orders', '₹', 0, 100000, 2000),
  RateField('maxKm', 'Distance pay stops at', 'km', 1, 100, 25),
];

/// Parses and checks the form. Returns the values to save, or the first error.
({Map<String, double>? values, String? error}) validateRates(Map<String, String> input) {
  final out = <String, double>{};
  for (final f in riderPayFields) {
    final raw = (input[f.key] ?? '').trim();
    final v = double.tryParse(raw);
    if (v == null || !v.isFinite) return (values: null, error: '${f.label}: enter a number');
    if (v < f.min || v > f.max) {
      return (values: null, error: '${f.label}: must be between ${_n(f.min)} and ${_n(f.max)}');
    }
    out[f.key] = v;
  }
  return (values: out, error: null);
}

String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// The rate the server will actually use for [key] given the stored value.
double effectiveRate(String key, Object? stored) {
  final f = riderPayFields.firstWhere((f) => f.key == key);
  final v = stored is num ? stored.toDouble() : null;
  return v != null && v.isFinite && v >= f.min && v <= f.max ? v : f.defaultValue;
}

/// "₹25 + ₹6/km + ₹1/min after 10 min" — the rates as a sentence.
String ratesSummary(Map<String, Object?> stored) {
  double r(String k) => effectiveRate(k, stored[k]);
  return '₹${_n(r('basePay'))} + ₹${_n(r('perKm'))}/km + ₹${_n(r('waitingPerMin'))}/min after '
      '${_n(r('waitingFreeMin'))} min · COD cash limit ₹${_n(r('codCashLimit'))}';
}

/// Why a statement is on hold, for admin.
String holdReasonLabel(String? reason) => switch (reason) {
      'bank_change_pending' => 'On hold — a payout-detail change is waiting for your review',
      'no_bank_details' => 'On hold — the rider has no bank or UPI details',
      _ => 'On hold',
    };

/// A payment reference admin can save (rules: 4–64 characters).
String? paymentReferenceError(String ref) {
  final r = ref.trim();
  if (r.length < 4) return 'Enter the UTR / payment reference (at least 4 characters)';
  if (r.length > 64) return 'Reference is too long (max 64 characters)';
  return null;
}

/// Refusals from recordRiderCashDeposit / reviewRiderBankChange (riderMoney.ts).
String riderMoneyRefusal(String code, String? reason) => switch (reason) {
      'more_than_held' => 'That is more cash than the rider holds.',
      'request_reused' => 'This deposit was already recorded with different details. Check the rider\'s cash before recording again.',
      'bad_request_id' => 'Could not record that. Please try again.',
      'payout_not_pending' => 'This statement is not waiting to be paid — it may already be settled.',
      'bank_change_pending' => 'The rider has a payout-detail change waiting. Review it first.',
      'no_destination' => 'The rider has no payout details for that method.',
      'bad_method' => 'Choose bank or UPI.',
      'bad_amount' => 'Enter an amount greater than zero.',
      'bad_reference' => 'Enter a receipt or reference (2–64 characters).',
      'not_pending' => 'This request has already been reviewed.',
      'bank_review_state' => 'This bank change does not match the rider\'s current payout records. Check the request and account before reviewing it.',
      'not_found' => 'Request not found — it may have been removed.',
      'reason_required' => 'Give a reason for rejecting (3–200 characters).',
      _ => code == 'permission-denied'
          ? 'Only admins can do this.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not complete that. Please try again.',
    };

/// A balance as rupees: the exact integer paise field when the server wrote
/// one (DLV-M1), else the older rupee field.
double accountRupees(Map<String, dynamic> m, String field) {
  final p = m['${field}Paise'];
  if (p is num) return p.toInt() / 100;
  final r = m[field];
  return r is num ? (r.toDouble() * 100).round() / 100 : 0;
}

/// DLV-M1: an idempotency key per deposit. A failed call whose outcome is
/// unknown (no connection, timeout) keeps its key, and recording the same
/// amount and reference for that rider again reuses it — so the server
/// records it once however many times admin retries. Anything else, and any
/// definite answer, starts a new key.
class DepositAttempts {
  DepositAttempts([Random? rng]) : _rng = rng ?? Random.secure();
  final Random _rng;
  final Map<String, ({String requestId, int paise, String reference})> _unsure = {};

  String keyFor(String riderId, int paise, String reference) {
    final u = _unsure[riderId];
    if (u != null && u.paise == paise && u.reference == reference) return u.requestId;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'dep_${List.generate(20, (_) => chars[_rng.nextInt(chars.length)]).join()}';
  }

  void unsure(String riderId, String requestId, int paise, String reference) =>
      _unsure[riderId] = (requestId: requestId, paise: paise, reference: reference);

  void settled(String riderId) => _unsure.remove(riderId);
}

/// An outcome the admin cannot know (the call may or may not have run).
bool outcomeUnknown(String code) =>
    code == 'unavailable' || code == 'deadline-exceeded' || code == 'internal' || code == 'unknown';
