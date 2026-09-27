import 'package:cloud_firestore/cloud_firestore.dart';

/// ADMR-52: a real, already-written `rider_cash_ledger/{entryId}` document
/// (functions/src/delivery/riderMoney.ts's own header: "every change to
/// cashHeld") — one of three types: a COD delivery (cash_collected), an
/// admin-recorded deposit, or cash netted against a weekly payout
/// statement. firestore.rules already grants admin read on this collection;
/// this is a read-only visibility model, nothing here changes what gets
/// written or when.
class RiderCashLedgerEntry {
  final String entryId;
  final String riderId;
  final String type; // cash_collected | deposit | netted_against_payout
  final int amountPaise;
  final DateTime? at;

  // type == cash_collected
  final String? orderId;

  // type == deposit
  final String? reference;
  final String? recordedBy;

  // type == netted_against_payout
  final String? statementId;

  const RiderCashLedgerEntry({
    required this.entryId,
    required this.riderId,
    required this.type,
    required this.amountPaise,
    this.at,
    this.orderId,
    this.reference,
    this.recordedBy,
    this.statementId,
  });

  double get amount => amountPaise / 100.0;

  String get typeLabel {
    switch (type) {
      case 'cash_collected':
        return 'Cash collected (COD)';
      case 'deposit':
        return 'Cash deposited';
      case 'netted_against_payout':
        return 'Netted against payout';
      default:
        return type;
    }
  }

  factory RiderCashLedgerEntry.fromMap(Map<String, dynamic> map, String entryId) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    int amountPaise() {
      final paise = map['amountPaise'];
      if (paise is num) return paise.round();
      final rupees = map['amount'];
      if (rupees is num) return (rupees * 100).round();
      return 0;
    }

    return RiderCashLedgerEntry(
      entryId: entryId,
      riderId: (map['riderId'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'cash_collected',
      amountPaise: amountPaise(),
      at: parseTs(map['at']),
      orderId: map['orderId'] as String?,
      reference: map['reference'] as String?,
      recordedBy: map['recordedBy'] as String?,
      statementId: map['statementId'] as String?,
    );
  }
}
