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

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

export const requestEmployeePayout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }

  const uid = context.auth.uid;
  const amount = Number(data?.amount);
  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "amount must be a positive number");
  }

  const db = admin.firestore();

  const employeeSnap = await db.collection("employees").doc(uid).get();
  if (!employeeSnap.exists || employeeSnap.data()?.status !== "approved") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only approved employees can request a payout"
    );
  }

  const walletRef = db.collection("wallets").doc(uid);
  const walletTransactionRef = db.collection("wallet_transactions").doc();
  const payoutRef = db.collection("employee_payouts").doc();

  await db.runTransaction(async (tx) => {
    const walletSnap = await tx.get(walletRef);
    const currentBalance = (walletSnap.data()?.balance as number | undefined) ?? 0;

    if (amount > currentBalance) {
      throw new functions.https.HttpsError("failed-precondition", "Insufficient balance");
    }

    const balanceAfter = currentBalance - amount;

    tx.set(
      walletRef,
      {
        balance: admin.firestore.FieldValue.increment(-amount),
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true, payoutId: payoutRef.id, amount };
});
