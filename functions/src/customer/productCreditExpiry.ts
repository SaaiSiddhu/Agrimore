// ============================================================
//  Product Credit expiry, stale-hold sweep, and reconciliation
//  (Phase B: benefit ledger & accrual engine;
//   Phase C, Workstream 6: releaseExpiredProductCreditHolds)
// ============================================================
//
// expireProductCredits (scheduled) appends an EXPIRY entry for every
// CREDIT entry past its expiresAt that hasn't already been expired.
// releaseExpiredProductCreditHolds (scheduled, Phase C) does the same for
// abandoned checkouts: a HOLD past its TTL (see productCreditHold.ts) is
// auto-released so it doesn't lock a customer's credit forever.
// reconcileProductCreditBalances (admin callable) recomputes each
// projection from the full ledger and reports drift — correcting it, when
// found, via an explicit ADJUSTMENT ledger entry (D4: never silently
// overwrite the projection).
//
// Idempotency choice for credit expiry (Workstream 6 of Phase B asks this
// to be stated explicitly): a QUERY for an existing EXPIRY entry whose
// relatedEntryId points at the original CREDIT entry, read inside the same
// transaction before any write — not a marker field on the original entry,
// and not a separate anchor collection. This keeps the ledger truly
// append-only with zero update() calls ever, even from Cloud Functions,
// and needs no extra schema (mirrors createOrder.ts's own transactional
// query-then-decide pattern for coupon/employee lookups).
//
// Idempotency for the hold sweep (Phase C) is simpler: the hold DOCUMENT
// ITSELF carries its own status ('active'|'released'|'expired'|'settled'),
// so re-checking `status === 'active'` inside the transaction before
// writing is sufficient — no query needed, since (unlike a ledger CREDIT
// entry) a hold is mutable, Cloud-Function-owned state, not an immutable
// ledger fact.

import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { FieldValue, FieldPath, Timestamp } from "firebase-admin/firestore";
import { auditEntry, resolveIsAdmin } from "../admin/complianceGate";
import { appendLedgerEntry, toProjectionFields, LEDGER_ENTRY_TYPES } from "./productCreditLedger";

const MAX_EXPIRY_ENTRIES_PER_RUN = 500;

interface CreditExpiryCursor {
  version: number;
  lastExpiresAt: Timestamp | null;
  lastEntryId: string | null;
}

function parseCreditExpiryCursor(data: FirebaseFirestore.DocumentData | undefined): CreditExpiryCursor | null {
  if (!data) return null;
  const reset = data.lastExpiresAt === null && data.lastEntryId === null;
  if (!Number.isSafeInteger(data.version) || data.version < 1 || data.version >= Number.MAX_SAFE_INTEGER ||
      (!reset && (!(data.lastExpiresAt instanceof Timestamp) ||
        typeof data.lastEntryId !== "string" || !data.lastEntryId || data.lastEntryId.includes("/")))) {
    throw new Error("Invalid Product Credit expiry cursor");
  }
  return data as CreditExpiryCursor;
}

async function advanceCreditExpiryCursor(
  db: FirebaseFirestore.Firestore, ref: FirebaseFirestore.DocumentReference,
  expectedVersion: number, last: FirebaseFirestore.QueryDocumentSnapshot | null
): Promise<boolean> {
  const expiresAt = last ? last.get("expiresAt") : null;
  if (last && !(expiresAt instanceof Timestamp)) throw new Error("Invalid Product Credit expiry timestamp");
  return db.runTransaction(async tx => {
    const current = parseCreditExpiryCursor((await tx.get(ref)).data());
    if ((current?.version ?? 0) !== expectedVersion) return false;
    tx.set(ref, {
      version: expectedVersion + 1, lastExpiresAt: expiresAt,
      lastEntryId: last?.id ?? null, updatedAt: Timestamp.now(),
    });
    return true;
  });
}

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
    const now = Timestamp.now();
    const cursorRef = db.collection("product_credit_expiry_cursors").doc("credits");
    const cursor = parseCreditExpiryCursor((await cursorRef.get()).data());

    const baseQuery = db
      .collection("product_credit_ledger")
      .where("type", "==", "CREDIT")
      .where("expiresAt", "<=", now)
      .orderBy("expiresAt", "asc").orderBy(FieldPath.documentId(), "asc")
      .limit(MAX_EXPIRY_ENTRIES_PER_RUN + 1);
    const dueSnap = await (cursor?.lastExpiresAt
      ? baseQuery.startAfter(cursor.lastExpiresAt, cursor.lastEntryId)
      : baseQuery).get();

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

    // Advance only after the complete page succeeds. A failure replays safely
    // through immutable expiry idempotency. Reset at cycle end so entries added
    // behind the cursor or previously unavailable credits are revisited.
    await advanceCreditExpiryCursor(db, cursorRef, cursor?.version ?? 0,
      truncated ? docs[docs.length - 1] : null);

    console.log(
      `[ProductCreditExpiry] processed=${docs.length} expired=${expired} skipped=${skipped} truncated=${truncated}`
    );
    return { processed: docs.length, expired, skipped, truncated };
  });

// ------------------------------------------------------------
// Stale hold sweep (Phase C, Workstream 6)
// ------------------------------------------------------------

const MAX_HOLD_RELEASES_PER_RUN = 500;

async function releaseOneExpiredHold(
  db: admin.firestore.Firestore,
  holdRef: FirebaseFirestore.DocumentReference
): Promise<"released" | "skipped"> {
  return db.runTransaction(async (tx) => {
    // All reads before all writes.
    const holdSnap = await tx.get(holdRef);
    if (!holdSnap.exists) return "skipped";
    const hold = holdSnap.data()!;

    // Idempotency: only ever act on a hold still 'active' whose expiresAt
    // is in the past. A hold already released/expired/settled by a
    // concurrent path (e.g. the customer released it themselves moments
    // before this run) is left untouched.
    if (hold.status !== "active") return "skipped";
    const expiresAt = (hold.expiresAt as admin.firestore.Timestamp | undefined)?.toDate();
    if (!expiresAt || expiresAt > new Date()) return "skipped";

    const holdAmount = typeof hold.amount === "number" ? hold.amount : 0;
    if (holdAmount > 0) {
      const projectionRef = db.collection("product_credit_balances").doc(hold.customerId);
      const projectionSnap = await tx.get(projectionRef);
      const currentProjection = toProjectionFields(projectionSnap.data());

      appendLedgerEntry(tx, db, {
        customerId: hold.customerId,
        enrollmentId: hold.enrollmentId ?? "",
        type: "RELEASE",
        amount: holdAmount,
        currentProjection,
        relatedEntryId: hold.ledgerEntryId ?? null,
        description: `Hold ${holdRef.id} auto-released: TTL exceeded (abandoned checkout)`,
      });
    }

    // `releasedAt` doubles as "when this hold left the active state" for
    // both a manual release (productCreditHold.ts) and this sweep — the
    // schema has no separate expiredAt field, and `status` already
    // distinguishes the two cases.
    tx.update(holdRef, {
      status: "expired",
      releasedAt: FieldValue.serverTimestamp(),
    });

    return "released";
  });
}

export const releaseExpiredProductCreditHolds = functions.pubsub
  .schedule("every 15 minutes")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const db = admin.firestore();
    const now = Timestamp.now();

    const dueSnap = await db
      .collection("product_credit_holds")
      .where("status", "==", "active")
      .where("expiresAt", "<=", now)
      .limit(MAX_HOLD_RELEASES_PER_RUN + 1)
      .get();

    const truncated = dueSnap.size > MAX_HOLD_RELEASES_PER_RUN;
    const docs = truncated ? dueSnap.docs.slice(0, MAX_HOLD_RELEASES_PER_RUN) : dueSnap.docs;
    if (truncated) {
      console.warn(
        `[ProductCreditHoldSweep] Hit the ${MAX_HOLD_RELEASES_PER_RUN}-hold cap — ` +
          `${dueSnap.size - MAX_HOLD_RELEASES_PER_RUN} hold(s) NOT processed this run; ` +
          "each remains due and will be picked up on a later run."
      );
    }

    let released = 0;
    let skipped = 0;
    for (const doc of docs) {
      const outcome = await releaseOneExpiredHold(db, doc.ref);
      if (outcome === "released") released++;
      else skipped++;
    }

    console.log(
      `[ProductCreditHoldSweep] processed=${docs.length} released=${released} skipped=${skipped} truncated=${truncated}`
    );
    return { processed: docs.length, released, skipped, truncated };
  });

function computeLedgerSumAvailable(
  ledgerSnap: FirebaseFirestore.QuerySnapshot
): number {
  let available = 0;
  for (const doc of ledgerSnap.docs) {
    const entry = doc.data();
    if (!LEDGER_ENTRY_TYPES.includes(entry.type) || typeof entry.amount !== "number" ||
        !Number.isFinite(entry.amount) || entry.amount < 0 ||
        (entry.type === "ADJUSTMENT" && !["credit", "debit"].includes(entry.metadata?.direction)) ||
        (entry.type === "REDEMPTION" && entry.relatedEntryId != null && typeof entry.relatedEntryId !== "string")) {
      throw new HttpsError("failed-precondition", "Product Credit ledger needs review before reconciliation.");
    }
    const amount = entry.amount;
    switch (entry.type) {
      case "CREDIT":
      case "RELEASE":
      case "REVERSAL":
        available += amount;
        break;
      case "REDEMPTION":
        // A related HOLD already reduced available. Match the canonical
        // appendLedgerEntry arithmetic; only a direct spend reduces it here.
        if (!entry.relatedEntryId) available -= amount;
        break;
      case "EXPIRY":
      case "HOLD":
        available -= amount;
        break;
      case "ADJUSTMENT":
        available += entry.metadata?.direction === "debit" ? -amount : amount;
        break;
    }
  }
  const paise = Math.round(available * 100);
  if (!Number.isSafeInteger(paise) || paise < 0) {
    throw new HttpsError("failed-precondition", "Product Credit ledger needs review before reconciliation.");
  }
  return paise / 100;
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
  const ledgerQuery = db.collection("product_credit_ledger").where("customerId", "==", customerId);
  const projectionRef = db.collection("product_credit_balances").doc(customerId);
  const auditRef = db.collection("compliance_audit_log").doc();

  return db.runTransaction(async (tx) => {
    // Ledger and projection must share this transaction's snapshot. A stale
    // pre-read can offset a legitimate interleaved credit/hold with an adjustment.
    const [ledgerSnap, projectionSnap] = await Promise.all([
      tx.get(ledgerQuery), tx.get(projectionRef),
    ]);
    const computedAvailable = computeLedgerSumAvailable(ledgerSnap);
    const currentProjection = toProjectionFields(projectionSnap.data());
    if (!Number.isFinite(currentProjection.available) || currentProjection.available < 0 ||
        !Number.isSafeInteger(Math.round(currentProjection.available * 100))) {
      throw new HttpsError("failed-precondition", "Product Credit balance needs review before reconciliation.");
    }
    const drift = Math.round((currentProjection.available - computedAvailable) * 100) / 100;

    if (Math.abs(drift) < 0.01) {
      return null;
    }

    // Repair the cache, not the customer's economic ledger. A nonzero
    // adjustment would move ledger truth too and cause drift on the next run.
    // Preserve D4's explicit immutable adjustment/audit with zero monetary effect.
    appendLedgerEntry(tx, db, {
      customerId,
      enrollmentId: "",
      type: "ADJUSTMENT",
      amount: 0,
      currentProjection: { ...currentProjection, available: computedAvailable },
      description: `Reconciliation: projection.available (${currentProjection.available}) vs ledger sum (${computedAvailable})`,
      metadata: {
        direction: drift > 0 ? "debit" : "credit", reconciliation: true,
        projectionRepair: true, previousProjectionAvailable: currentProjection.available,
        ledgerAvailable: computedAvailable, drift,
      },
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
