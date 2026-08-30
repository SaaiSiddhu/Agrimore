// ============================================================
//  Product Credit expiry and reconciliation
//  (Phase B: benefit ledger & accrual engine)
// ============================================================
//
// expireProductCredits (scheduled) appends an EXPIRY entry for every
// CREDIT entry past its expiresAt that hasn't already been expired.
// reconcileProductCreditBalances (admin callable) recomputes each
// projection from the full ledger and reports drift — correcting it, when
// found, via an explicit ADJUSTMENT ledger entry (D4: never silently
// overwrite the projection).
//
// Idempotency choice for expiry (Workstream 6 asks this to be stated
// explicitly): a QUERY for an existing EXPIRY entry whose relatedEntryId
// points at the original CREDIT entry, read inside the same transaction
// before any write — not a marker field on the original entry, and not a
// separate anchor collection. This keeps the ledger truly append-only with
// zero update() calls ever, even from Cloud Functions, and needs no extra
// schema (mirrors createOrder.ts's own transactional query-then-decide
// pattern for coupon/employee lookups).

import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { auditEntry, resolveIsAdmin } from "../admin/complianceGate";
import { appendLedgerEntry, toProjectionFields } from "./productCreditLedger";

const MAX_EXPIRY_ENTRIES_PER_RUN = 500;

async function expireOneCreditEntry(
  db: admin.firestore.Firestore,
  creditEntryRef: FirebaseFirestore.DocumentReference
): Promise<"expired" | "skipped"> {
  return db.runTransaction(async (tx) => {
    // All reads before all writes.
    const [existingExpirySnap, creditSnap] = await Promise.all([
      tx.get(
        db
          .collection("product_credit_ledger")
          .where("relatedEntryId", "==", creditEntryRef.id)
          .where("type", "==", "EXPIRY")
          .limit(1)
      ),
      tx.get(creditEntryRef),
    ]);

    // Idempotency: already expired — never expire the same credit twice.
    if (!existingExpirySnap.empty) return "skipped";
    if (!creditSnap.exists) return "skipped";

    const credit = creditSnap.data()!;
    if (credit.type !== "CREDIT") return "skipped";

    const expiresAt = (credit.expiresAt as admin.firestore.Timestamp | undefined)?.toDate();
    if (!expiresAt || expiresAt > new Date()) return "skipped";

    const projectionRef = db.collection("product_credit_balances").doc(credit.customerId);
    const projectionSnap = await tx.get(projectionRef);
    const currentProjection = toProjectionFields(projectionSnap.data());

    // Never expire more than what's still actually available — a credit
    // that was partially/fully redeemed (Phase C) must not drive
    // `available` negative. appendLedgerEntry's own guard is the real
    // enforcement; capping here just avoids throwing on the common case
    // where some of the credit was already spent.
    const amountToExpire = Math.min(credit.amount, currentProjection.available);
    if (amountToExpire <= 0) return "skipped";

    appendLedgerEntry(tx, db, {
      customerId: credit.customerId,
      enrollmentId: credit.enrollmentId ?? "",
      type: "EXPIRY",
      amount: amountToExpire,
      currentProjection,
      relatedEntryId: creditEntryRef.id,
      description: `Expired Product Credit from period ${credit.period ?? creditEntryRef.id}`,
      metadata: { originalAmount: credit.amount },
    });

    return "expired";
  });
}

export const expireProductCredits = functions.pubsub
  .schedule("every day 03:30")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const dueSnap = await db
      .collection("product_credit_ledger")
      .where("type", "==", "CREDIT")
      .where("expiresAt", "<=", now)
      .limit(MAX_EXPIRY_ENTRIES_PER_RUN + 1)
      .get();

    const truncated = dueSnap.size > MAX_EXPIRY_ENTRIES_PER_RUN;
    const docs = truncated ? dueSnap.docs.slice(0, MAX_EXPIRY_ENTRIES_PER_RUN) : dueSnap.docs;
    if (truncated) {
      console.warn(
        `[ProductCreditExpiry] Hit the ${MAX_EXPIRY_ENTRIES_PER_RUN}-entry cap — ` +
          `${dueSnap.size - MAX_EXPIRY_ENTRIES_PER_RUN} entr(ies) NOT processed this run; ` +
          "each remains due and will be picked up on a later run."
      );
    }

    let expired = 0;
    let skipped = 0;
    for (const doc of docs) {
      const outcome = await expireOneCreditEntry(db, doc.ref);
      if (outcome === "expired") expired++;
      else skipped++;
    }

    console.log(
      `[ProductCreditExpiry] processed=${docs.length} expired=${expired} skipped=${skipped} truncated=${truncated}`
    );
    return { processed: docs.length, expired, skipped, truncated };
  });

async function computeLedgerSumAvailable(
  db: admin.firestore.Firestore,
  customerId: string
): Promise<number> {
  const ledgerSnap = await db.collection("product_credit_ledger").where("customerId", "==", customerId).get();
  let available = 0;
  for (const doc of ledgerSnap.docs) {
    const entry = doc.data();
    const amount = typeof entry.amount === "number" ? entry.amount : 0;
    switch (entry.type) {
      case "CREDIT":
      case "RELEASE":
      case "REVERSAL":
        available += amount;
        break;
      case "REDEMPTION":
      case "EXPIRY":
      case "HOLD":
        available -= amount;
        break;
      case "ADJUSTMENT":
        available += entry.metadata?.direction === "debit" ? -amount : amount;
        break;
    }
  }
  return Math.round(available * 100) / 100;
}

interface ReconcileResult {
  customerId: string;
  projectionAvailable: number;
  ledgerSum: number;
  corrected: boolean;
}

async function reconcileOneCustomer(
  db: admin.firestore.Firestore,
  customerId: string,
  actorUid: string,
  actorEmail: string | null,
  reason: string
): Promise<ReconcileResult | null> {
  // Non-transactional pre-read of the full ledger — the ledger is
  // append-only, so a new entry landing between this read and the
  // transaction below only means this run under-counts a just-arrived
  // entry, which the NEXT reconciliation run picks up. Acceptable for a
  // maintenance/reporting operation, not a security enforcement point.
  const computedAvailable = await computeLedgerSumAvailable(db, customerId);

  const projectionRef = db.collection("product_credit_balances").doc(customerId);
  const auditRef = db.collection("compliance_audit_log").doc();

  return db.runTransaction(async (tx) => {
    const projectionSnap = await tx.get(projectionRef);
    const currentProjection = toProjectionFields(projectionSnap.data());
    const drift = Math.round((currentProjection.available - computedAvailable) * 100) / 100;

    if (Math.abs(drift) < 0.01) {
      return null;
    }

    // Correct via an explicit ADJUSTMENT entry — never by silently
    // overwriting the projection (D4).
    appendLedgerEntry(tx, db, {
      customerId,
      enrollmentId: "",
      type: "ADJUSTMENT",
      amount: Math.abs(drift),
      currentProjection,
      description: `Reconciliation: projection.available (${currentProjection.available}) vs ledger sum (${computedAvailable})`,
      metadata: { direction: drift > 0 ? "debit" : "credit", reconciliation: true },
    });

    tx.set(
      auditRef,
      auditEntry({
        actorUid,
        actorEmail,
        action: "reconcileProductCreditBalances",
        target: customerId,
        previousValue: currentProjection.available,
        newValue: computedAvailable,
        reason,
      })
    );

    return {
      customerId,
      projectionAvailable: currentProjection.available,
      ledgerSum: computedAvailable,
      corrected: true,
    };
  });
}

interface ReconcileProductCreditBalancesData {
  customerId?: string;
  reason?: string;
}

export const reconcileProductCreditBalances = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const email = (request.auth.token.email as string | undefined) || null;
    const isAdminClaim = request.auth.token.admin === true;

    const db = admin.firestore();
    const isAdmin = await resolveIsAdmin(db, uid, isAdminClaim);

    const data = request.data as ReconcileProductCreditBalancesData;
    const reasonInput = String(data?.reason || "").trim();
    const customerIdInput = data?.customerId ? String(data.customerId).trim() : null;

    if (!isAdmin) {
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "reconcileProductCreditBalances.denied",
          target: customerIdInput || "(all)",
          previousValue: null,
          newValue: null,
          reason: reasonInput || null,
        })
      );
      throw new HttpsError("permission-denied", "Admin only");
    }
    if (!reasonInput) {
      throw new HttpsError("invalid-argument", "reason is required");
    }

    let customerIds: string[];
    if (customerIdInput) {
      customerIds = [customerIdInput];
    } else {
      const balancesSnap = await db.collection("product_credit_balances").get();
      customerIds = balancesSnap.docs.map((d) => d.id);
    }

    const drifts: ReconcileResult[] = [];
    for (const cid of customerIds) {
      const result = await reconcileOneCustomer(db, cid, uid, email, reasonInput);
      if (result) drifts.push(result);
    }

    return { success: true, checked: customerIds.length, driftsFound: drifts.length, drifts };
  }
);
