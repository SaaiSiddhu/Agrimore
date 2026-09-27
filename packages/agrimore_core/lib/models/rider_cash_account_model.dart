/// ADMR-36: a real, already-written `rider_accounts/{riderId}` document
/// (functions/src/delivery/riderMoney.ts's own `balanceFields`) — the
/// rider's own current outstanding cash liability across every order,
/// not specific to any one of them. Read-only visibility model; nothing
/// here writes back (the existing `RiderPayoutsScreen`'s Cash tab is the
/// real deposit-recording surface, not duplicated here).
class RiderCashAccountRecord {
  final String riderId;
  final double cashHeld;

  const RiderCashAccountRecord({
    required this.riderId,
    required this.cashHeld,
  });

  /// Mirrors riderMoney.ts's own `accountPaise`/`balanceFields`: the paise
  /// field is authoritative since DLV-M1 (whole-paise transactions, no
  /// float drift); an account written before that migration has only the
  /// rupee field, read here as a fallback.
  factory RiderCashAccountRecord.fromMap(Map<String, dynamic> map, String riderId) {
    final paise = map['cashHeldPaise'];
    final cashHeld = paise is num
        ? paise.toDouble() / 100
        : (map['cashHeld'] as num?)?.toDouble() ?? 0.0;
    return RiderCashAccountRecord(riderId: riderId, cashHeld: cashHeld);
  }
}
