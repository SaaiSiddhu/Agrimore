// lib/money/rider_money.dart
//
// Phase DLV-4B — the rider's money as the server records it (DLV-4A,
// functions/src/delivery/riderMoney.ts): pay per delivered order
// (rider_earnings), cash held from COD orders (rider_accounts), weekly
// statements (rider_payouts) and bank-change requests. Replaces the numbers
// this app used to invent (order_provider.dart _deliveryEarningFor: the
// order's delivery charge or ₹15). Rules: a rider reads only their own.
//
// Queries avoid composite indexes on purpose: equality filters only
// (riderId, and statementId == null for "not yet in a statement"), sorted
// here. Pure parts are covered by test/rider_money_test.dart.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:agrimore_ui/agrimore_ui.dart' show AgFormat;

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : v is DateTime ? v : null;

/// One delivered order's pay.
class RiderEarning {
  final String orderId;
  final String? orderNumber;
  final double total;
  final double basePay;
  final double distancePay;
  final double waitingPay;
  final double km;
  final int waitMinutes;
  final double codCollected;
  final String? statementId;
  final DateTime? createdAt;

  const RiderEarning({
    required this.orderId,
    this.orderNumber,
    required this.total,
    this.basePay = 0,
    this.distancePay = 0,
    this.waitingPay = 0,
    this.km = 0,
    this.waitMinutes = 0,
    this.codCollected = 0,
    this.statementId,
    this.createdAt,
  });

  factory RiderEarning.fromMap(String id, Map<String, dynamic> m) {
    double line(String type) {
      final lines = m['lines'];
      if (lines is! List) return 0;
      return lines.whereType<Map>().where((l) => l['type'] == type).fold(0.0, (s, l) => s + _num(l['amount']));
    }

    return RiderEarning(
      orderId: (m['orderId'] as String?) ?? id,
      orderNumber: m['orderNumber'] as String?,
      total: _num(m['total']),
      basePay: line('trip_base'),
      distancePay: line('distance'),
      waitingPay: line('waiting'),
      km: _num(m['km']),
      waitMinutes: (m['waitMinutes'] as num?)?.toInt() ?? 0,
      codCollected: _num(m['codCollected']),
      statementId: m['statementId'] as String?,
      createdAt: _date(m['createdAt']),
    );
  }
}

/// A weekly statement.
class RiderPayout {
  final String id;
  final String weekKey;
  final double earned;
  final double netted;
  final double amount;
  final double cashHeldAfter;
  final int orderCount;
  final String status;
  final String? holdReason;
  final String? paymentReference;
  final DateTime? periodEnd;
  final DateTime? paidAt;
  final DateTime? createdAt;

  const RiderPayout({
    required this.id,
    required this.weekKey,
    required this.earned,
    required this.netted,
    required this.amount,
    required this.cashHeldAfter,
    required this.orderCount,
    required this.status,
    this.holdReason,
    this.paymentReference,
    this.periodEnd,
    this.paidAt,
    this.createdAt,
  });

  factory RiderPayout.fromMap(String id, Map<String, dynamic> m) => RiderPayout(
        id: id,
        weekKey: (m['weekKey'] as String?) ?? '',
        earned: _num(m['earned']),
        netted: _num(m['netted']),
        amount: _num(m['amount']),
        cashHeldAfter: _num(m['cashHeldAfter']),
        orderCount: (m['orderCount'] as num?)?.toInt() ?? 0,
        status: (m['status'] as String?) ?? 'pending',
        holdReason: m['holdReason'] as String?,
        paymentReference: m['paymentReference'] as String?,
        periodEnd: _date(m['periodEnd']),
        paidAt: _date(m['paidAt']),
        createdAt: _date(m['createdAt']),
      );
}

/// The rider's running account.
class RiderAccount {
  final double cashHeld;
  final double earningsUnsettled;
  final String? bankChangePending;
  const RiderAccount({this.cashHeld = 0, this.earningsUnsettled = 0, this.bankChangePending});
  factory RiderAccount.fromMap(Map<String, dynamic>? m) => RiderAccount(
        cashHeld: _num(m?['cashHeld']),
        earningsUnsettled: _num(m?['earningsUnsettled']),
        bankChangePending: (m?['bankChangePending'] as String?)?.isNotEmpty == true ? m!['bankChangePending'] as String : null,
      );
}

/// A bank-detail change the rider asked for.
class BankChangeRequest {
  final String id;
  final String status;
  final String? rejectionReason;
  final String? maskedAccount;
  final String? upiId;
  final DateTime? createdAt;
  const BankChangeRequest({required this.id, required this.status, this.rejectionReason, this.maskedAccount, this.upiId, this.createdAt});
  factory BankChangeRequest.fromMap(String id, Map<String, dynamic> m) => BankChangeRequest(
        id: id,
        status: (m['status'] as String?) ?? 'pending',
        rejectionReason: m['rejectionReason'] as String?,
        maskedAccount: maskAccount(m['bankAccountNumber'] as String?),
        upiId: m['upiId'] as String?,
        createdAt: _date(m['createdAt']),
      );
}

// ── pure helpers ──

/// Masked account number (house style), or null for none.
String? maskAccount(String? number) =>
    (number ?? '').trim().isEmpty ? null : AgFormat.maskAccount(number!);

/// Rupees in the house style (AgFormat).
String rupees(double v) => AgFormat.rupees(v);

/// Start of "today" in India time, as a UTC instant — the server's week and
/// the rider's day are both Indian calendar days.
DateTime istDayStart(DateTime now) {
  final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(ist.year, ist.month, ist.day).subtract(const Duration(hours: 5, minutes: 30));
}

/// Pay earned today (India time) among [earnings].
double earnedSince(Iterable<RiderEarning> earnings, DateTime since) =>
    earnings.where((e) => e.createdAt != null && !e.createdAt!.isBefore(since)).fold(0.0, (s, e) => s + e.total);

/// What a statement's status means to a rider.
String payoutStatusLabel(RiderPayout p) {
  switch (p.status) {
    case 'paid':
      return p.paymentReference == null ? 'Paid' : 'Paid · Ref ${p.paymentReference}';
    case 'pending':
      return 'Being paid';
    case 'on_hold':
      return p.holdReason == 'bank_change_pending'
          ? 'On hold — your new payout details are being checked'
          : 'On hold — add your bank or UPI details';
    case 'nothing_to_pay':
      return p.cashHeldAfter > 0
          ? 'Nothing to pay — cash you hold covered it (${rupees(p.cashHeldAfter)} still with you)'
          : 'Nothing to pay';
    default:
      return p.status;
  }
}

/// The week a statement covers, e.g. "Week ending 20 Sep".
String payoutWeekLabel(RiderPayout p) {
  final end = p.periodEnd;
  if (end == null) return p.weekKey;
  // periodEnd is Monday 00:00 IST; the last day covered is the Sunday before.
  final sunday = end.toUtc().add(const Duration(hours: 5, minutes: 30)).subtract(const Duration(days: 1));
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return 'Week ending ${sunday.day} ${m[sunday.month - 1]}';
}

/// Client-side check before sending a bank change (the server validates again).
String? bankFormError({String? name, String? account, String? ifsc, String? upi}) {
  final n = name?.trim() ?? '', a = (account ?? '').replaceAll(RegExp(r'\s'), ''), i = (ifsc ?? '').trim().toUpperCase();
  final u = (upi ?? '').trim().toLowerCase();
  final anyBank = n.isNotEmpty || a.isNotEmpty || i.isNotEmpty;
  if (!anyBank && u.isEmpty) return 'Enter bank details or a UPI ID';
  if (anyBank) {
    if (n.length < 2) return 'Enter the account holder name';
    if (!RegExp(r'^\d{9,18}$').hasMatch(a)) return 'Account number should be 9–18 digits';
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(i)) return 'IFSC looks wrong (e.g. SBIN0001234)';
  }
  if (u.isNotEmpty && !RegExp(r'^[a-z0-9._-]{2,256}@[a-z]{2,64}$').hasMatch(u)) return 'UPI ID looks wrong (e.g. name@okaxis)';
  return null;
}

// ── streams and calls ──

class RiderMoneyService {
  RiderMoneyService(this.riderId, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final String riderId;
  final FirebaseFirestore _db;

  /// Pay not yet in a statement (this week's), newest first.
  Stream<List<RiderEarning>> unsettledEarnings() => _db
      .collection('rider_earnings')
      .where('riderId', isEqualTo: riderId)
      .where('statementId', isNull: true)
      .snapshots()
      .map((s) => s.docs.map((d) => RiderEarning.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  Stream<RiderAccount> account() =>
      _db.collection('rider_accounts').doc(riderId).snapshots().map((s) => RiderAccount.fromMap(s.data()));

  /// Statements, newest first.
  Stream<List<RiderPayout>> payouts() => _db
      .collection('rider_payouts')
      .where('riderId', isEqualTo: riderId)
      .snapshots()
      .map((s) => s.docs.map((d) => RiderPayout.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  /// The latest bank-change request, if any.
  Stream<BankChangeRequest?> latestBankChange() => _db
      .collection('rider_bank_change_requests')
      .where('riderId', isEqualTo: riderId)
      .snapshots()
      .map((s) {
    final all = s.docs.map((d) => BankChangeRequest.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return all.isEmpty ? null : all.first;
  });

  /// The payout destination on file (the rider may read their own profile).
  Stream<({String? maskedAccount, String? ifsc, String? upiId, String? holder})> payoutDetails() => _db
      .collection('delivery_partners')
      .doc(riderId)
      .snapshots()
      .map((s) {
    final d = s.data() ?? const {};
    return (
      maskedAccount: maskAccount(d['bankAccountNumber'] as String?),
      ifsc: d['ifscCode'] as String?,
      upiId: (d['upiId'] as String?)?.isNotEmpty == true ? d['upiId'] as String : null,
      holder: d['accountHolderName'] as String?,
    );
  });

  /// requestRiderBankChange; returns null or a sentence to show.
  static Future<String?> requestBankChange({String? name, String? account, String? ifsc, String? upi}) async {
    final local = bankFormError(name: name, account: account, ifsc: ifsc, upi: upi);
    if (local != null) return local;
    try {
      await FirebaseFunctions.instance.httpsCallable('requestRiderBankChange').call<Map<String, dynamic>>({
        if ((name ?? '').trim().isNotEmpty) 'accountHolderName': name!.trim(),
        if ((account ?? '').trim().isNotEmpty) 'bankAccountNumber': account!.replaceAll(RegExp(r'\s'), ''),
        if ((ifsc ?? '').trim().isNotEmpty) 'ifscCode': ifsc!.trim().toUpperCase(),
        if ((upi ?? '').trim().isNotEmpty) 'upiId': upi!.trim().toLowerCase(),
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('requestRiderBankChange: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (reason == 'already_pending') return 'A change is already waiting for review.';
      if (reason != null && reason.startsWith('invalid_')) return 'Please check the details and try again.';
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') return 'No internet connection. Try again.';
      return 'Could not send the change. Please try again.';
    } catch (e) {
      debugPrint('requestRiderBankChange: $e');
      return 'Could not send the change. Please try again.';
    }
  }
}
