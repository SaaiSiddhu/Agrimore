// lib/money/money_text.dart
//
// Phase DLV-M1 — the rider's money in words (lib/l10n): one mapping from the
// typed states in rider_money.dart to the strings both money screens show.
import 'package:agrimore_ui/agrimore_ui.dart' show AgFormat;

import '../l10n/app_localizations.dart';
import 'rider_money.dart';

String payoutStageText(AppLocalizations l, RiderPayout p) => switch (payoutStage(p)) {
      PayoutStage.paid => p.paymentReference == null ? l.stagePaidNoRef : l.stagePaid(p.paymentReference!),
      PayoutStage.awaitingTransfer => l.stageAwaiting,
      PayoutStage.heldForReview => l.stageHeldReview,
      PayoutStage.heldNoDetails => l.stageHeldNoDetails,
      PayoutStage.nothingToPay => p.cashHeldAfter > 0 ? l.stageNothingCash(AgFormat.rupees(p.cashHeldAfter)) : l.stageNothing,
      PayoutStage.unknown => l.stageUnknown(p.status),
    };

String payoutTitle(AppLocalizations l, RiderPayout p) {
  final end = payoutWeekEnding(p);
  if (end == null) return p.weekKey;
  final date = AgFormat.dayMonth(end);
  return p.part > 1 ? l.moneyWeekEndingPart(date, p.part) : l.moneyWeekEnding(date);
}

/// Where a paid statement's money went, or null when not recorded (paid
/// before DLV-M1 bound the destination).
String? payoutDestinationText(AppLocalizations l, RiderPayout p) {
  if (p.paidToMethod == 'upi' && p.paidToUpi != null) return l.statementSentToUpi(p.paidToUpi!);
  if (p.paidToMethod == 'bank' && p.paidToAccountLast4 != null) return l.statementSentToBank(p.paidToAccountLast4!);
  return null;
}

String bankProblemText(AppLocalizations l, BankFormProblem p) => switch (p) {
      BankFormProblem.empty => l.bankProblemEmpty,
      BankFormProblem.holderName => l.bankProblemHolder,
      BankFormProblem.accountDigits => l.bankProblemAccount,
      BankFormProblem.ifsc => l.bankProblemIfsc,
      BankFormProblem.upi => l.bankProblemUpi,
    };

String bankFailureText(AppLocalizations l, BankChangeFailure f) => switch (f) {
      BankChangeFailure.alreadyPending => l.bankFailAlreadyPending,
      BankChangeFailure.invalid => l.bankFailInvalid,
      BankChangeFailure.network => l.authNetwork,
      BankChangeFailure.other => l.bankFailOther,
    };

/// "Base ₹25.00 · 4.05 km ₹24.30 · Waiting 7 min ₹7.00". Two decimals on the
/// km: pay is worked out on the km as stored (4.05 km × ₹6 = ₹24.30), and
/// "4.0 km ₹24.30" would not add up for the rider.
String earningBreakdown(AppLocalizations l, RiderEarning e) => [
      l.moneyLineBase(AgFormat.rupees(e.basePay)),
      if (e.km > 0) l.moneyLineDistance(e.km.toStringAsFixed(2), AgFormat.rupees(e.distancePay)),
      if (e.waitMinutes > 0) l.moneyLineWaiting(e.waitMinutes, AgFormat.rupees(e.waitingPay)),
    ].join(' · ');
