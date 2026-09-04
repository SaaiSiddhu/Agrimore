// ============================================================
//  Callable: deleteUserData — customer-initiated account deletion
// ============================================================
//
// Phase 17. Replaces the permanently-lost `deleteUserData` orphan (v1,
// live in production, zero invocations ever logged, source unrecoverable
// — see the phase report for the full provenance). Written fresh, as a
// v1 callable (functions.https.onCall from firebase-functions/v1) to
// match the LIVE production function's generation exactly — Firestore has
// no in-place Gen1->Gen2 upgrade, so a v2 rewrite would be undeployable
// in place. Mirrors functions/src/admin/createEmployeeByAdmin.ts's shape
// (module-level db/auth, functions.https.onCall, functions.https.HttpsError).
//
// ------------------------------------------------------------
// WHAT "DELETE MY ACCOUNT" ACTUALLY MEANS HERE — three tiers
// ------------------------------------------------------------
// HARD DELETE — personal data with no retention need once the refusal
// checks below have passed: users/{uid}, addresses (top-level, filtered
// by userId), carts/{uid} + its items subcollection, wishlists/{uid} + its
// items subcollection, users/{uid}/notifications, users/{uid}/recently_viewed,
// employees/{uid} (if the caller is also a Sales Associate — see the
// associate note below), and wallets/{uid} itself (safe to remove outright
// because the refusal check below already guarantees its balance is 0 —
// it is a live-state cache, not the ledger).
//
// ANONYMISE, KEEP THE RECORD — orders where userId == uid: deliveryAddress
// and notes (the only fields that carry this customer's name/phone/address
// — see packages/agrimore_core/lib/models/address_model.dart) are stripped;
// everything else (total, items, commissionPaid/commissionAmount,
// orderMode, employeeUid on that order, timestamps) stays, because sellers
// and any attributed associate still need their financial history intact.
// wallet_transactions, product_credit_ledger, product_credit_balances,
// product_credit_holds, referrals, coupon_redemptions, employee_payouts
// are left COMPLETELY UNTOUCHED, not even a field update: every one of
// these was read at its write site (productCreditLedger.ts, wallet.ts,
// requestEmployeePayout.ts) and none of them carry a free-text customer
// name/phone/address — the uid stored on each is an accounting key, not
// PII, and rewriting it would corrupt a ledger these rules already
// describe as append-only/immutable.
//
// REFUSE, DO NOT PROCEED — a non-zero wallets/{uid}.balance, an order
// (orders.userId == uid) not yet in a terminal status, or a pending
// employees_payouts request. Each throws failed-precondition with a
// specific, actionable message. Nothing is silently deleted around them.
//
// ------------------------------------------------------------
// Associate edge case
// ------------------------------------------------------------
// If employees/{uid} exists, deletion is NOT unconditionally blocked —
// but it is gated by the SAME wallet-balance and pending-payout refusal
// checks above, since a Sales Associate's uncollected commission lives in
// exactly the same wallets/{uid}.balance and employee_payouts collection
// a plain customer's does. Once those pass, employees/{uid} (name, email,
// phone, employeeCode — the same class of personal data as users/{uid})
// is hard-deleted. Orders where employeeUid == uid (i.e. OTHER customers'
// purchases this associate earned commission on) are explicitly NEVER
// touched by this function — they are not this account's data to delete
// or anonymise; the employeeUid reference on them simply stops resolving
// to a live account, exactly like any other foreign key to a deleted
// party in an accounting system.
//
// ------------------------------------------------------------
// Reviews — NOT swept this phase, disclosed, not silent
// ------------------------------------------------------------
// products/{productId}/reviews/{reviewId} carries userName/userAvatar —
// real PII — but finding every review a user has written requires a
// collectionGroup('reviews').where('userId','==',uid) query, and
// firestore.indexes.json has NO collectionGroup-scoped index on `reviews`
// (only two COLLECTION-scoped ones: productId+createdAt and
// userId+createdAt, which do not serve a collectionGroup query). Adding
// one means editing firestore.indexes.json, explicitly out of this
// phase's scope. Running the query anyway would throw in production
// (Admin SDK bypasses security RULES, never index requirements). Left
// unswept, on purpose, disclosed in the phase report — not silently
// skipped.
//
// ------------------------------------------------------------
// device_tokens — does not exist as a collection
// ------------------------------------------------------------
// Grepped firestore.rules and functions/src: no `device_tokens` collection
// anywhere. FCM tokens are fields (`fcmToken`/`fcmTokens`) directly on
// users/{uid} (see auth_provider.dart's _updateFCMToken in every app) —
// hard-deleting the user document already removes them. No separate step
// needed.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
// Modular import for FieldValue specifically: `admin.firestore.FieldValue`
// (the namespace-style static access every other file in this codebase
// uses) was observed, live in the emulator, to read as undefined at the
// exact moment this file's audit-record write called
// `.FieldValue.serverTimestamp()` — a real, reproducible TypeError, not a
// theoretical concern (caught by this phase's own end-to-end emulator
// test). `firebase-admin/firestore`'s modular export does not depend on
// that same namespace-attachment path, so it sidesteps the failure
// entirely. Scoped to this one new file rather than "fixing" the
// namespace-style call everywhere else in functions/src, which is out of
// this phase's scope and not something this phase's testing covered.
import { FieldValue } from "firebase-admin/firestore";

const db = admin.firestore();
const auth = admin.auth();

// Matches OrderModel.isDelivered's terminal-state shape (see
// employeeCommission.ts's identical DELIVERED_EQUIVALENT_STATUSES set)
// plus 'cancelled' — the three states an order can sit in forever with
// nothing further expected to happen to it.
const TERMINAL_ORDER_STATUSES = new Set(["delivered", "completed", "cancelled"]);

// employee_payouts.status values that represent money not yet settled —
// mirrors requestEmployeePayout.ts, which writes status:"requested" and
// leaves admin-side "paid" as the only other real value seen in
// apps/admin's payout management screen.
const PENDING_PAYOUT_STATUSES = new Set(["requested", "pending"]);

// Firestore batched writes cap at 500 operations. 450 leaves headroom for
// any other write this callable might add later without silently
// approaching the hard limit.
const BATCH_CHUNK_SIZE = 450;

async function deleteRefsInChunks(refs: FirebaseFirestore.DocumentReference[]): Promise<void> {
  for (let i = 0; i < refs.length; i += BATCH_CHUNK_SIZE) {
    const batch = db.batch();
    for (const ref of refs.slice(i, i + BATCH_CHUNK_SIZE)) {
      batch.delete(ref);
    }
    await batch.commit();
  }
}

async function anonymizeOrdersInChunks(
  refs: FirebaseFirestore.DocumentReference[]
): Promise<void> {
  for (let i = 0; i < refs.length; i += BATCH_CHUNK_SIZE) {
    const batch = db.batch();
    for (const ref of refs.slice(i, i + BATCH_CHUNK_SIZE)) {
      batch.update(ref, { deliveryAddress: null, notes: "" });
    }
    await batch.commit();
  }
}

export const deleteUserData = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }
  // The uid comes from context.auth ONLY. This callable never reads a uid,
  // email, or phone out of `data` — accepting a client-supplied identifier
  // here would make this an account-takeover primitive (S-invariant).
  const uid = context.auth.uid;

  // ============================================================
  // REFUSAL CHECKS — read-only, run on every call (including a retried
  // call after Firestore data is already gone — see the idempotency note
  // below for why re-running these is harmless).
  // ============================================================
  const walletSnap = await db.collection("wallets").doc(uid).get();
  const balance = (walletSnap.data()?.balance as number | undefined) ?? 0;
  if (balance > 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `You still have a wallet balance of Rs ${balance.toFixed(2)}. Withdraw or spend it before deleting your account.`
    );
  }

  const ordersSnap = await db.collection("orders").where("userId", "==", uid).get();
  const inFlightCount = ordersSnap.docs.filter(
    (d) => !TERMINAL_ORDER_STATUSES.has(String(d.data().orderStatus || "").toLowerCase())
  ).length;
  if (inFlightCount > 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `You have ${inFlightCount} order${inFlightCount === 1 ? "" : "s"} still in progress. ` +
        "Wait until they are delivered or cancelled before deleting your account."
    );
  }

  const pendingPayoutsSnap = await db
    .collection("employee_payouts")
    .where("employeeId", "==", uid)
    .get();
  const pendingPayoutCount = pendingPayoutsSnap.docs.filter((d) =>
    PENDING_PAYOUT_STATUSES.has(String(d.data().status || "").toLowerCase())
  ).length;
  if (pendingPayoutCount > 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "You have a pending payout request. Wait until it is paid before deleting your account."
    );
  }

  // ============================================================
  // IDEMPOTENCY: if users/{uid} is already gone, a previous call already
  // did the Firestore work — skip straight to the (also-idempotent) Auth
  // deletion below rather than throwing on a retried/duplicated client
  // call.
  // ============================================================
  const userSnap = await db.collection("users").doc(uid).get();
  const alreadyDeletedFirestore = !userSnap.exists;
  let hardDeletedCount = 0;
  let anonymizedOrdersCount = 0;
  let wasAssociate = false;

  if (!alreadyDeletedFirestore) {
    const [addressesSnap, cartItemsSnap, wishlistItemsSnap, notificationsSnap, recentlyViewedSnap, employeeSnap] =
      await Promise.all([
        db.collection("addresses").where("userId", "==", uid).get(),
        db.collection("carts").doc(uid).collection("items").get(),
        db.collection("wishlists").doc(uid).collection("items").get(),
        db.collection("users").doc(uid).collection("notifications").get(),
        db.collection("users").doc(uid).collection("recently_viewed").get(),
        db.collection("employees").doc(uid).get(),
      ]);

    wasAssociate = employeeSnap.exists;

    const hardDeleteRefs: FirebaseFirestore.DocumentReference[] = [
      db.collection("users").doc(uid),
      db.collection("wallets").doc(uid),
      db.collection("carts").doc(uid),
      db.collection("wishlists").doc(uid),
      ...addressesSnap.docs.map((d) => d.ref),
      ...cartItemsSnap.docs.map((d) => d.ref),
      ...wishlistItemsSnap.docs.map((d) => d.ref),
      ...notificationsSnap.docs.map((d) => d.ref),
      ...recentlyViewedSnap.docs.map((d) => d.ref),
    ];
    if (wasAssociate) {
      hardDeleteRefs.push(employeeSnap.ref);
    }

    await deleteRefsInChunks(hardDeleteRefs);
    hardDeletedCount = hardDeleteRefs.length;

    // orders.userId == uid only — orders.employeeUid == uid (other
    // customers' purchases this account earned commission on, if it was
    // also an associate) are deliberately never touched here.
    const orderRefs = ordersSnap.docs.map((d) => d.ref);
    await anonymizeOrdersInChunks(orderRefs);
    anonymizedOrdersCount = orderRefs.length;

    // Audit record — Cloud-Functions-only by construction: this is a
    // brand-new collection with no matching firestore.rules block, and
    // Firestore default-denies any path with no rule at all, so it is
    // unreachable from any client SDK without needing a rules change
    // (firestore.rules is explicitly out of scope this phase). Contains
    // ONLY counts/booleans — no name, email, phone, or address, which
    // would defeat the deletion this record is documenting.
    await db.collection("account_deletion_audit").doc(uid).set({
      uid,
      deletedAt: FieldValue.serverTimestamp(),
      hardDeletedDocCount: hardDeletedCount,
      anonymizedOrdersCount,
      wasAssociate,
    });
  }

  // ============================================================
  // Auth user deletion — ALWAYS last, and always attempted (even on a
  // retried call where Firestore work was skipped above), so a failure
  // here after a first call's Firestore work already succeeded is
  // recoverable by simply calling again, and a fully-completed prior call
  // is idempotent (auth/user-not-found is treated as success, not an
  // error).
  // ============================================================
  try {
    await auth.deleteUser(uid);
  } catch (e: unknown) {
    const err = e as { code?: string };
    if (err.code !== "auth/user-not-found") {
      console.error(`deleteUserData: Firestore data removed for ${uid} but Auth deletion failed`, e);
      throw new functions.https.HttpsError(
        "internal",
        "Your data was removed, but your account sign-in could not be fully deleted. Please contact support."
      );
    }
  }

  return {
    success: true,
    alreadyDeleted: alreadyDeletedFirestore,
    hardDeletedDocCount: hardDeletedCount,
    anonymizedOrdersCount,
    wasAssociate,
  };
});
