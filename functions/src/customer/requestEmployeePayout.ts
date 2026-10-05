// ============================================================
//  Callable: requestEmployeePayout — Employee-initiated wallet withdrawal
// ============================================================
//
// Debits the requesting employee's wallet immediately (not on admin
// approval) to prevent the same balance being requested twice while a
// request is pending — mirrors employeeCommission.ts's transactional style
// (db.runTransaction, tx.get/tx.set, FieldValue.increment()).
//
// Writes an `employee_payouts` document with the exact field names
// apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart (Phase 3)
// already expects: employeeId, amount, status, createdAt.
//
// ADMR-43: a fresh Firestore auto-ID on every call meant a retry after an
// ambiguous failure (a dropped connection, a timeout — the client cannot
// tell whether the server already committed) had no way to land on the
// SAME request: it would debit the wallet and create a second payout row
// a second time. requestId is now required and IS the (actor-scoped) doc
// id, mirroring riderExceptions.ts's/riderIncidents.ts's own
// `${actorId}_${requestId}` idempotency-key convention — a retry with the
// same requestId reads the existing document inside the transaction and
// returns its original result instead of debiting again.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { isExactMoneyAmount } from "../common/paymentIntegrity";
import { payoutBalancePaise, payoutAmountFromPaise } from "../employee/employeePayoutMoney";

const REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;

export const requestEmployeePayout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }

  const uid = context.auth.uid;
  const requestedAmount = data?.amount;
  if (!isExactMoneyAmount(requestedAmount)) {
    throw new functions.https.HttpsError("invalid-argument", "amount must be a positive number");
  }
  const amount = Math.round(requestedAmount * 100) / 100;
  const requestId = String(data?.requestId || "").trim();
  if (!REQUEST_ID.test(requestId)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "requestId is required (client-generated, one per payout request, for idempotency)"
    );
  }

  const db = admin.firestore();

  const employeeRef = db.collection("employees").doc(uid);
  const walletRef = db.collection("wallets").doc(uid);
  const walletTransactionRef = db.collection("wallet_transactions").doc();
  const payoutRef = db.collection("employee_payouts").doc(`${uid}_${requestId}`);

  return db.runTransaction(async (tx) => {
    // ADMR-79: read INSIDE the transaction, not before it — the destination
    // snapshot below must come from the same consistent read as the balance
    // check, or an admin-approved bank/UPI change landing in the gap between
    // an outside-transaction read and this transaction's commit could freeze
    // this request to a destination that was already stale the moment it was
    // written (mirrors sellerWallet.ts/riderMoney.ts's own established "all
    // reads before all writes inside one runTransaction" convention).
    const [walletSnap, existingPayout, employeeSnap] = await Promise.all([
      tx.get(walletRef),
      tx.get(payoutRef),
      tx.get(employeeRef),
    ]);
    if (!employeeSnap.exists || employeeSnap.data()?.status !== "approved") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only approved employees can request a payout"
      );
    }
    const employeeData = employeeSnap.data() ?? {};
    const payoutMethod = employeeData.payoutMethod ?? null;
    const accountNumber = employeeData.accountNumber ?? null;
    const upiId = employeeData.upiId ?? null;

    if (existingPayout.exists) {
      const prior = existingPayout.data()!;
      if (prior.employeeId !== uid || !isExactMoneyAmount(prior.amount)) {
        throw new functions.https.HttpsError("failed-precondition", "Payout details need review");
      }
      // This requestId was already used for a DIFFERENT amount — never
      // silently return a stale cached result for a mismatched request
      // (mirrors adminUpdateOrderStatus's own mismatch-rejection, ADMR-38).
      if (Math.round(prior.amount * 100) !== Math.round(amount * 100)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "This requestId was already used for a different amount — retry with a new requestId."
        );
      }
      // Idempotent replay — the SAME request already succeeded. Return
      // its original result; never debit the wallet a second time.
      return {
        success: true,
        payoutId: payoutRef.id,
        amount: prior.amount as number,
        alreadyApplied: true,
      };
    }

    const currentPaise = payoutBalancePaise(walletSnap.data()?.balance ?? 0);
    if (currentPaise === null) {
      throw new functions.https.HttpsError("failed-precondition", "Wallet balance needs review");
    }
    const amountPaise = Math.round(amount * 100);
    if (amountPaise > currentPaise) {
      throw new functions.https.HttpsError("failed-precondition", "Insufficient balance");
    }

    const balanceAfter = payoutAmountFromPaise(currentPaise - amountPaise);
    if (balanceAfter === null) {
      throw new functions.https.HttpsError("failed-precondition", "Wallet balance needs review");
    }

    tx.set(
      walletRef,
      {
        balance: balanceAfter,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(walletTransactionRef, {
      walletId: uid,
      userId: uid,
      type: "debit",
      // No dedicated TransactionSource value exists for payouts. This phase's
      // explicit scope permits touching only UserModel in packages/agrimore_core
      // ("the only shared-package touch") — extending the WalletTransactionModel
      // enum is deliberately out of scope here. 'adjustment' is the closest
      // existing fit for a non-order, non-referral wallet debit; flagged in the
      // completion report as a tradeoff for the owner to weigh in on.
      source: "adjustment",
      amount,
      coins: 0,
      balanceAfter,
      coinsAfter: walletSnap.data()?.coins ?? 0,
      orderId: null,
      description: "Employee payout request",
      referenceId: payoutRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: null,
      metadata: { payoutId: payoutRef.id },
    });

    tx.set(payoutRef, {
      employeeId: uid,
      amount,
      status: "requested",
      // Snapshot the destination at request time (same rationale as
      // walletTransactionRef's balanceAfter/coinsAfter above): apps/employee's
      // payout_history_screen.dart and payout_details_screen.dart read these
      // exact field names directly off this document with no live join, so a
      // later change to the associate's registered payout account must not
      // silently rewrite where an already-completed payout appears to have
      // gone.
      payoutMethod,
      accountNumber,
      upiId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, payoutId: payoutRef.id, amount };
  });
});
