// lib/screens/admin/delivery/rider_money_admin.dart
//
// Phase DLV-4B — pure helpers for the admin Rider Payouts screen. The rate
// bounds MUST match functions/src/delivery/riderPay.ts BOUNDS: the server
// ignores any value outside them and uses its default, so the form refuses
// them here rather than saving a number that silently does nothing.
// Covered by test/rider_money_admin_test.dart.

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
      'bad_amount' => 'Enter an amount greater than zero.',
      'bad_reference' => 'Enter a receipt or reference (2–64 characters).',
      'not_pending' => 'This request has already been reviewed.',
      'not_found' => 'Request not found — it may have been removed.',
      'reason_required' => 'Give a reason for rejecting (3–200 characters).',
      _ => code == 'permission-denied'
          ? 'Only admins can do this.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not complete that. Please try again.',
    };
