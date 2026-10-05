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
// SELLERS (SELLER-DELETE-1) — added after SELLER-RELEASE-1 found that a
// seller's account deletion left their KYC photos (ID proof), bank/UPI
// details and profile behind.
// REFUSE while the seller still has orders to fulfil (orders.sellerId == uid
// not terminal) or AgriMore still owes them money (seller_payouts pending) —
// deleting then would strand buyers or the seller's own settlement.
// HARD DELETE: sellers/{uid}, seller_payout_details/{uid}, sellerRequests/{uid},
// ai_connections/{uid}, seller_ai_rate_limits/{uid}, seller_stats_daily
// (sellerId == uid), users/{uid}/settings/*, and Storage
// seller_documents/{uid}/ (KYC) + sellers/{uid}/storefront/.
// HIDE: products (sellerId == uid) → isActive:false, sellerDeleted:true —
// past orders and reviews still reference them.
// KEEP: orders, invoices, seller_payouts — financial / GST records (invoices
// carry the seller snapshot the law requires to be retained).
//
// Reviews — now anonymised (SELLER-DELETE-1): ACCOUNT-1a added the
// COLLECTION_GROUP index reviews (userId, createdAt), so the caller's reviews
// are found and their userName/userAvatar cleared; the rating stays.
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
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { deleteRiderData, deleteStorageFolder, riderDeletionRefusal } from "../delivery/riderAccountDeletion";
import { payoutBalancePaise } from "../employee/employeePayoutMoney";

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

// employeeCommission.ts pays attributed work even after role removal, and
// reverses previously earned commission on either cancellation status field.
// Such work must resolve while the owner still has a usable account.
const COMMISSION_DELIVERED_STATUSES = new Set(["delivered", "completed"]);
const COMMISSION_REVERSAL_STATUSES = new Set(["cancelled", "refunded", "returned", "rejected"]);

async function requireResolvedAttributedWork(uid: string): Promise<void> {
  // Do not gate on employees/{uid}: legacy partial deletion can remove it.
  const orders = await db.collection("orders").where("employeeUid", "==", uid).get();
  for (const row of orders.docs) {
    const order = row.data();
    const values = [order.orderStatus, order.status].filter(value => value !== undefined);
    if (values.length === 0 || values.some(value => typeof value !== "string" || value.length === 0) ||
        (order.commissionPaid !== undefined && typeof order.commissionPaid !== "boolean") ||
        (order.commissionReversed !== undefined && typeof order.commissionReversed !== "boolean")) {
      throw new functions.https.HttpsError("failed-precondition", "Your attributed order or commission record needs review before deleting your account.");
    }
    const statuses = values.map(value => (value as string).toLowerCase());
    if (statuses.some(status => !COMMISSION_DELIVERED_STATUSES.has(status) && !COMMISSION_REVERSAL_STATUSES.has(status))) {
      throw new functions.https.HttpsError("failed-precondition", "You have attributed orders still in progress. Wait until they are resolved before deleting your account.");
    }
    // Mirror reversal's either-field detection, rather than hiding a pending
    // reversal behind a stale delivered value in the other status field.
    if (statuses.some(status => COMMISSION_REVERSAL_STATUSES.has(status))) {
      if (order.commissionPaid === true && order.commissionReversed !== true) {
        throw new functions.https.HttpsError("failed-precondition", "Your commission reversal is still pending. Wait until it is resolved before deleting your account.");
      }
    } else if (order.commissionPaid !== true) {
      throw new functions.https.HttpsError("failed-precondition", "Your earned commission is still pending. Wait until it is resolved before deleting your account.");
    }
  }
}

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

/** Seller-side personal data (SELLER-DELETE-1). Safe to re-run. */
async function deleteSellerData(uid: string): Promise<{ wasSeller: boolean; hardDeleted: number; hiddenProducts: number; deletedFiles: number }> {
  const [sellerSnap, requestSnap, statsSnap, settingsSnap, productsSnap] = await Promise.all([
    db.collection("sellers").doc(uid).get(),
    db.collection("sellerRequests").doc(uid).get(),
    db.collection("seller_stats_daily").where("sellerId", "==", uid).get(),
    db.collection("users").doc(uid).collection("settings").get(),
    db.collection("products").where("sellerId", "==", uid).get(),
  ]);
  const refs: FirebaseFirestore.DocumentReference[] = [
    db.collection("sellers").doc(uid),
    db.collection("seller_payout_details").doc(uid),
    db.collection("sellerRequests").doc(uid),
    db.collection("ai_connections").doc(uid),
    db.collection("seller_ai_rate_limits").doc(uid),
    ...statsSnap.docs.map((d) => d.ref),
    ...settingsSnap.docs.map((d) => d.ref),
  ];
  // KYC/storefront objects FIRST, while seller role documents still prove
  // which owned prefixes must be swept. A Storage failure must retain these
  // markers; otherwise a retry would treat the account as a non-seller.
  const wasSeller = sellerSnap.exists || requestSnap.exists;
  let deletedFiles = 0;
  if (wasSeller) {
    const bucket = admin.storage().bucket();
    for (const prefix of [`seller_documents/${uid}/`, `sellers/${uid}/storefront/`]) {
      const [files] = await bucket.getFiles({ prefix });
      await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
      deletedFiles += files.length;
    }
  }
  await deleteRefsInChunks(refs);

  for (let i = 0; i < productsSnap.docs.length; i += BATCH_CHUNK_SIZE) {
    const batch = db.batch();
    for (const d of productsSnap.docs.slice(i, i + BATCH_CHUNK_SIZE)) {
      batch.update(d.ref, { isActive: false, sellerDeleted: true, updatedAt: FieldValue.serverTimestamp() });
    }
    await batch.commit();
  }

  return { wasSeller, hardDeleted: refs.length, hiddenProducts: productsSnap.size, deletedFiles };
}

/** Clears the author's name/avatar on every review they wrote; ratings stay. */
async function anonymizeReviews(uid: string): Promise<number> {
  let snap: FirebaseFirestore.QuerySnapshot;
  try {
    // Served by the COLLECTION_GROUP index reviews (userId, createdAt DESC).
    snap = await db.collectionGroup("reviews").where("userId", "==", uid).orderBy("createdAt", "desc").get();
  } catch (e) {
    // Without this query, personal review fields cannot be confirmed removed.
    // Keep the profile/Auth marker so an index or transient failure can be retried.
    console.error(`Review anonymisation could not be confirmed for ${uid}`, e);
    throw new functions.https.HttpsError("failed-precondition", "Account data could not be confirmed. Please try again.");
  }
  for (let i = 0; i < snap.docs.length; i += BATCH_CHUNK_SIZE) {
    const batch = db.batch();
    for (const d of snap.docs.slice(i, i + BATCH_CHUNK_SIZE)) {
      batch.update(d.ref, { userName: "Deleted user", userAvatar: "" });
    }
    await batch.commit();
  }
  return snap.size;
}

/** Only a private, timestamped own audit can certify completed Firestore deletion. */
function validDeletionAudit(value: FirebaseFirestore.DocumentData | undefined, uid: string, authTime: number): boolean {
  if (!value || value.uid !== uid || !(value.deletedAt instanceof Timestamp) ||
      !Number.isSafeInteger(value.anonymizedReviewsCount) || value.anonymizedReviewsCount < 0) return false;
  const completedAt = value.deletedAt.toMillis();
  return Number.isFinite(completedAt) && completedAt >= authTime * 1000 && completedAt <= Date.now();
}

export const deleteUserData = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }
  // The uid comes from context.auth ONLY. This callable never reads a uid,
  // email, or phone out of `data` — accepting a client-supplied identifier
  // here would make this an account-takeover primitive (S-invariant).
  const uid = context.auth.uid;
  // This hint constrains the action; it never selects the deletion target.
  if (data?.expectedOwnerId !== undefined && data.expectedOwnerId !== uid) {
    throw new functions.https.HttpsError("permission-denied", "Account action does not belong to this account");
  }

  // Callable SDK production verification does not check revocation by default.
  // Recheck the principal using the verified auth_time, never client data.
  const authTime = context.auth.token.auth_time;
  if (!Number.isSafeInteger(authTime) || authTime < 0) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in again before deleting your account.");
  }
  let principal: admin.auth.UserRecord;
  try {
    principal = await auth.getUser(uid);
  } catch (error) {
    if ((error as { code?: string }).code === "auth/user-not-found") {
      // A previously verified token may return its own completed receipt only.
      // It cannot start/resume deletion, run financial queries, or perform writes.
      const [profile, audit] = await Promise.all([
        db.collection("users").doc(uid).get(),
        db.collection("account_deletion_audit").doc(uid).get(),
      ]);
      if (!profile.exists && validDeletionAudit(audit.data(), uid, authTime)) {
        return { success: true, alreadyDeleted: true, hardDeletedDocCount: 0, anonymizedOrdersCount: 0, wasAssociate: false };
      }
    }
    throw new functions.https.HttpsError("unauthenticated", "Sign in again before deleting your account.");
  }
  const validAfter = principal.tokensValidAfterTime === undefined ? 0 : Date.parse(principal.tokensValidAfterTime);
  if (principal.uid !== uid || principal.disabled || !Number.isFinite(validAfter) || authTime < Math.floor(validAfter / 1000)) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in again before deleting your account.");
  }

  // ============================================================
  // REFUSAL CHECKS — read-only, run on every call (including a retried
  // call after Firestore data is already gone — see the idempotency note
  // below for why re-running these is harmless).
  // ============================================================
  const walletRef = db.collection("wallets").doc(uid);
  const walletSnap = await walletRef.get();
  const balancePaise = walletSnap.exists ? payoutBalancePaise(walletSnap.data()?.balance) : 0;
  if (balancePaise === null || balancePaise < 0) {
    throw new functions.https.HttpsError("failed-precondition", "Your wallet balance needs review before deleting your account.");
  }
  const balance = balancePaise / 100;
  if (balancePaise > 0) {
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
  const pendingPayoutCount = pendingPayoutsSnap.docs.filter((d) => {
    const value = d.data().status;
    const status = typeof value === "string" ? value.toLowerCase() : "";
    if (!PENDING_PAYOUT_STATUSES.has(status) && !["paid", "rejected"].includes(status)) {
      throw new functions.https.HttpsError("failed-precondition", "Your payout record needs review before deleting your account.");
    }
    return PENDING_PAYOUT_STATUSES.has(status);
  }).length;
  if (pendingPayoutCount > 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "You have a pending payout request. Wait until it is paid before deleting your account."
    );
  }

  // Read-only refusal before any role/personal cleanup. This snapshot guard
  // does not replace the outstanding shared lifecycle barrier for new writers.
  await requireResolvedAttributedWork(uid);

  // Seller refusals (SELLER-DELETE-1).
  const [sellerOrdersSnap, sellerPayoutsSnap] = await Promise.all([
    db.collection("orders").where("sellerId", "==", uid).get(),
    db.collection("seller_payouts").where("sellerId", "==", uid).get(),
  ]);
  const openSellerOrders = sellerOrdersSnap.docs.filter(
    (d) => !TERMINAL_ORDER_STATUSES.has(String(d.data().orderStatus || "").toLowerCase())
  ).length;
  if (openSellerOrders > 0) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `You have ${openSellerOrders} order${openSellerOrders === 1 ? "" : "s"} from buyers still to fulfil. ` +
        "Deliver or cancel them before deleting your account."
    );
  }
  const unsettled = sellerPayoutsSnap.docs.filter((row) => {
    const value = row.data().status;
    const status = typeof value === "string" ? value.toLowerCase() : "";
    if (!["pending", "requested", "paid"].includes(status)) {
      throw new functions.https.HttpsError("failed-precondition", "Your seller settlement record needs review before deleting your account.");
    }
    return status !== "paid";
  });
  if (unsettled.length > 0) {
    // Unsettled state itself blocks deletion: zero, malformed or negative rows
    // cannot cancel one another or stand in for confirmed settlement.
    let owedPaise = 0;
    for (const row of unsettled) {
      const d = row.data();
      const amount = payoutBalancePaise(Object.prototype.hasOwnProperty.call(d, "netAmount") ? d.netAmount : d.amount);
      if (amount === null || amount < 0 || !Number.isSafeInteger(owedPaise + amount)) {
        throw new functions.https.HttpsError("failed-precondition", "Your seller settlement record needs review before deleting your account.");
      }
      owedPaise += amount;
    }
    throw new functions.https.HttpsError(
      "failed-precondition",
      owedPaise > 0
        ? `AgriMore still owes you Rs ${(owedPaise / 100).toFixed(2)} in settlements. Wait until it is paid before deleting your account.`
        : "You have a seller settlement waiting for review. Wait until it is resolved before deleting your account."
    );
  }

  // Rider refusals (DLV-A2): an assigned order, customers' cash still held,
  // or pay still owed. Stable reason in details for the rider app.
  const riderRefusal = await riderDeletionRefusal(db, uid);
  if (riderRefusal) {
    throw new functions.https.HttpsError("failed-precondition", riderRefusal.message, { reason: riderRefusal.reason });
  }

  // ============================================================
  // A missing profile alone is not completion evidence (legacy partial failures
  // may have deleted it early). Skip only with a durable private audit as well;
  // otherwise rerun the idempotent personal-data sweep.
  // ============================================================
  const userSnap = await db.collection("users").doc(uid).get();
  const auditRef = db.collection("account_deletion_audit").doc(uid);
  const priorAudit = userSnap.exists ? undefined : (await auditRef.get()).data();
  const alreadyDeletedFirestore = !userSnap.exists && validDeletionAudit(priorAudit, uid, authTime);
  let hardDeletedCount = 0;
  let anonymizedOrdersCount = 0;
  let wasAssociate = false;

  if (!alreadyDeletedFirestore) {
    // Seller data and reviews FIRST: users/{uid} is the idempotency marker,
    // so anything that must happen has to happen before it is deleted —
    // otherwise a retry after a partial failure would skip it.
    const seller = await deleteSellerData(uid);
    const rider = await deleteRiderData(db, uid, deleteStorageFolder);
    const anonymizedReviewsCount = await anonymizeReviews(uid);

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

    // orders.userId == uid only — orders.employeeUid == uid (other
    // customers' purchases this account earned commission on, if it was
    // also an associate) are deliberately never touched here.
    const orderRefs = ordersSnap.docs.map((d) => d.ref);
    await anonymizeOrdersInChunks(orderRefs);
    anonymizedOrdersCount = orderRefs.length;

    await deleteRefsInChunks(hardDeleteRefs);
    hardDeletedCount = hardDeleteRefs.length + 2; // Final wallet/profile commit below.

    // Audit record — Cloud-Functions-only by construction: this is a
    // brand-new collection with no matching firestore.rules block, and
    // Firestore default-denies any path with no rule at all, so it is
    // unreachable from any client SDK without needing a rules change
    // (firestore.rules is explicitly out of scope this phase). Contains
    // ONLY counts/booleans — no name, email, phone, or address, which
    // would defeat the deletion this record is documenting.
    await auditRef.set({
      uid,
      deletedAt: FieldValue.serverTimestamp(),
      hardDeletedDocCount: hardDeletedCount + seller.hardDeleted,
      anonymizedOrdersCount,
      wasAssociate,
      wasSeller: seller.wasSeller,
      hiddenProductsCount: seller.hiddenProducts,
      deletedFilesCount: seller.deletedFiles + rider.deletedFiles,
      wasRider: rider.wasRider,
      riderHardDeletedDocCount: rider.hardDeleted,
      riderAnonymizedOrdersCount: rider.anonymizedOrders,
      anonymizedReviewsCount,
    });
  }

  // Recheck inside the SAME transaction that removes wallet and profile.
  // Earlier zero/refusal snapshots cannot justify deleting a later refund.
  // Also run on partial-deletion retries; a missing profile alone skips no money check.
  await db.runTransaction(async tx => {
    const [currentWallet, currentProfile, currentAudit] = await Promise.all([
      tx.get(walletRef), tx.get(userSnap.ref), tx.get(auditRef),
    ]);
    if (!validDeletionAudit(currentAudit.data(), uid, authTime)) {
      throw new functions.https.HttpsError("failed-precondition", "Account data could not be confirmed. Please try again.");
    }
    const currentPaise = currentWallet.exists ? payoutBalancePaise(currentWallet.data()?.balance) : 0;
    if (currentPaise !== 0) {
      throw new functions.https.HttpsError("failed-precondition", "Your wallet balance changed. Review it before deleting your account.");
    }
    tx.delete(walletRef);
    tx.delete(currentProfile.ref);
  });

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
