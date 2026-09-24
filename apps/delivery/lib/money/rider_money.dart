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

/// A money field as rupees: the exact integer paise the server writes since
/// DLV-M1 (`<field>Paise`), else the older rupee field rounded to the paisa
/// (it could hold 430.70000000000005).
double moneyField(Map<String, dynamic>? m, String field) {
  final p = m?['${field}Paise'];
  if (p is num) return p.toInt() / 100;
  return (_num(m?[field]) * 100).round() / 100;
}

/// Adds rupee amounts in whole paise, so a week of ₹0.10s adds up exactly.
double sumRupees(Iterable<double> amounts) => amounts.fold<int>(0, (s, a) => s + (a * 100).round()) / 100;

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
      total: moneyField(m, 'total'),
      basePay: line('trip_base'),
      distancePay: line('distance'),
      waitingPay: line('waiting'),
      km: _num(m['km']),
      waitMinutes: (m['waitMinutes'] as num?)?.toInt() ?? 0,
      codCollected: moneyField(m, 'codCollected'),
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

  /// Where the money went (markRiderPayoutPaid, DLV-M1): 'bank' or 'upi'.
  final String? paidToMethod;
  final String? paidToAccountLast4;
  final String? paidToUpi;

  /// A week with more than 400 deliveries is split into numbered parts.
  final int part;

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
    this.paidToMethod,
    this.paidToAccountLast4,
    this.paidToUpi,
    this.part = 1,
  });

  factory RiderPayout.fromMap(String id, Map<String, dynamic> m) => RiderPayout(
        id: id,
        weekKey: (m['weekKey'] as String?) ?? '',
        earned: moneyField(m, 'earned'),
        netted: moneyField(m, 'netted'),
        amount: moneyField(m, 'amount'),
        cashHeldAfter: moneyField(m, 'cashHeldAfter'),
        orderCount: (m['orderCount'] as num?)?.toInt() ?? 0,
        status: (m['status'] as String?) ?? 'pending',
        holdReason: m['holdReason'] as String?,
        paymentReference: m['paymentReference'] as String?,
        periodEnd: _date(m['periodEnd']),
        paidAt: _date(m['paidAt']),
        createdAt: _date(m['createdAt']),
        paidToMethod: (m['paidTo'] as Map?)?['method'] as String? ?? m['payoutMethod'] as String?,
        paidToAccountLast4: (m['paidTo'] as Map?)?['accountLast4'] as String?,
        paidToUpi: (m['paidTo'] as Map?)?['upiId'] as String?,
        part: (m['part'] as num?)?.toInt() ?? 1,
      );
}

/// The rider's running account.
class RiderAccount {
  final double cashHeld;
  final double earningsUnsettled;
  final String? bankChangePending;
  const RiderAccount({this.cashHeld = 0, this.earningsUnsettled = 0, this.bankChangePending});
  factory RiderAccount.fromMap(Map<String, dynamic>? m) => RiderAccount(
        cashHeld: moneyField(m, 'cashHeld'),
        earningsUnsettled: moneyField(m, 'earningsUnsettled'),
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

/// The last four digits of an account number, for "sent to ••1234".
String? accountLast4(String? number) {
  final d = (number ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length < 4 ? null : d.substring(d.length - 4);
}

/// Start of "today" in India time, as a UTC instant — the server's week and
/// the rider's day are both Indian calendar days.
DateTime istDayStart(DateTime now) {
  final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(ist.year, ist.month, ist.day).subtract(const Duration(hours: 5, minutes: 30));
}

/// Pay earned today (India time) among [earnings].
double earnedSince(Iterable<RiderEarning> earnings, DateTime since) =>
    sumRupees(earnings.where((e) => e.createdAt != null && !e.createdAt!.isBefore(since)).map((e) => e.total));

/// Where a statement is, from the rider's side. A statement being made is not
/// money sent: only [paid] means the Agrimore team has transferred it.
enum PayoutStage { paid, awaitingTransfer, heldForReview, heldNoDetails, nothingToPay, unknown }

PayoutStage payoutStage(RiderPayout p) => switch (p.status) {
      'paid' => PayoutStage.paid,
      'pending' => PayoutStage.awaitingTransfer,
      'on_hold' => p.holdReason == 'bank_change_pending' ? PayoutStage.heldForReview : PayoutStage.heldNoDetails,
      'nothing_to_pay' => PayoutStage.nothingToPay,
      _ => PayoutStage.unknown,
    };

/// The last day a statement covers (the Sunday before periodEnd, Monday 00:00
/// IST), as an Indian calendar date; null for a statement without periodEnd.
DateTime? payoutWeekEnding(RiderPayout p) {
  final end = p.periodEnd;
  if (end == null) return null;
  final sunday = end.toUtc().add(const Duration(hours: 5, minutes: 30)).subtract(const Duration(days: 1));
  return DateTime(sunday.year, sunday.month, sunday.day);
}

/// What is wrong with a bank-change form (the server checks again).
enum BankFormProblem { empty, holderName, accountDigits, ifsc, upi }

BankFormProblem? bankFormProblem({String? name, String? account, String? ifsc, String? upi}) {
  final n = name?.trim() ?? '', a = (account ?? '').replaceAll(RegExp(r'\s'), ''), i = (ifsc ?? '').trim().toUpperCase();
  final u = (upi ?? '').trim().toLowerCase();
  final anyBank = n.isNotEmpty || a.isNotEmpty || i.isNotEmpty;
  if (!anyBank && u.isEmpty) return BankFormProblem.empty;
  if (anyBank) {
    if (n.length < 2) return BankFormProblem.holderName;
    if (!RegExp(r'^\d{9,18}$').hasMatch(a)) return BankFormProblem.accountDigits;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(i)) return BankFormProblem.ifsc;
  }
  if (u.isNotEmpty && !RegExp(r'^[a-z0-9._-]{2,256}@[a-z]{2,64}$').hasMatch(u)) return BankFormProblem.upi;
  return null;
}

/// Why requestRiderBankChange did not go through.
enum BankChangeFailure { alreadyPending, invalid, network, other }

/// One page of a statement's deliveries.
class StatementPage {
  const StatementPage(this.lines, this.cursor, this.hasMore);
  final List<RiderEarning> lines;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
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

  /// Only answers the server has confirmed: when the backend is slow the web
  /// SDK goes offline and reports an uncached document as missing, which
  /// would read as "no cash with you" / "no payout details" (DLV-4B).
  static bool _known(DocumentSnapshot<Map<String, dynamic>> s) => s.exists || !s.metadata.isFromCache;

  Stream<RiderAccount> account() => _db
      .collection('rider_accounts')
      .doc(riderId)
      .snapshots()
      .where(_known)
      .map((s) => RiderAccount.fromMap(s.data()));

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
      .where(_known)
      .map((s) {
    final d = s.data() ?? const {};
    return (
      maskedAccount: maskAccount(d['bankAccountNumber'] as String?),
      ifsc: d['ifscCode'] as String?,
      upiId: (d['upiId'] as String?)?.isNotEmpty == true ? d['upiId'] as String : null,
      holder: d['accountHolderName'] as String?,
    );
  });

  /// DLV-N1: this rider's pay for one order, or null when there is none yet.
  /// A missing document reads as permission-denied under the owner-only rule.
  Future<RiderEarning?> earningFor(String orderId) async {
    try {
      final d = await _db.collection('rider_earnings').doc(orderId).get();
      final m = d.data();
      return m == null || m['riderId'] != riderId ? null : RiderEarning.fromMap(d.id, m);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') return null;
      rethrow;
    }
  }

  /// A statement's deliveries, newest first, a page at a time (index:
  /// rider_earnings riderId + statementId + createdAt desc).
  Future<StatementPage> statementLines(String statementId,
      {DocumentSnapshot<Map<String, dynamic>>? after, int pageSize = statementPageSize}) async {
    Query<Map<String, dynamic>> q = _db
        .collection('rider_earnings')
        .where('riderId', isEqualTo: riderId)
        .where('statementId', isEqualTo: statementId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);
    if (after != null) q = q.startAfterDocument(after);
    final s = await q.get();
    return StatementPage(s.docs.map((d) => RiderEarning.fromMap(d.id, d.data())).toList(),
        s.docs.isEmpty ? after : s.docs.last, s.docs.length == pageSize);
  }

  static const int statementPageSize = 50;

  /// The COD cash limit the server enforces on offers (riderMoneySummary);
  /// null when it could not be read — the card then shows the cash alone.
  static Future<double?> codCashLimit() async {
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('riderMoneySummary').call<Map<String, dynamic>>();
      final v = r.data['codCashLimit'];
      return v is num ? v.toDouble() : null;
    } catch (e) {
      debugPrint('riderMoneySummary: $e');
      return null;
    }
  }

  /// requestRiderBankChange; null when sent. Check [bankFormProblem] first.
  static Future<BankChangeFailure?> requestBankChange({String? name, String? account, String? ifsc, String? upi}) async {
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
      if (reason == 'already_pending') return BankChangeFailure.alreadyPending;
      if (reason != null && reason.startsWith('invalid_')) return BankChangeFailure.invalid;
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') return BankChangeFailure.network;
      return BankChangeFailure.other;
    } catch (e) {
      debugPrint('requestRiderBankChange: $e');
      return BankChangeFailure.other;
    }
  }
}
