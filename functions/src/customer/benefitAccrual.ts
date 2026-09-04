// ============================================================
//  Monthly benefit accrual engine
//  (Phase B: benefit ledger & accrual engine)
// ============================================================
//
// Calculates each eligible enrollment's benefit for the current period and
// credits it as Product Credit via appendLedgerEntry — the ONLY writer of
// product_credit_ledger/product_credit_balances (see productCreditLedger.ts).
//
// Idempotency: /benefit_accruals/{enrollmentId}_{period} is the anchor,
// exactly wallet.ts's verifyWalletTopup's wallet_topups/{paymentId} shape —
// its existence (checked inside the SAME transaction that would credit the
// ledger) is what makes running the same period twice a no-op rather than
// a double-credit.
//
// A daily tick (not a monthly cron) deliberately mirrors
// common/scheduled.ts's existing pattern — a monthly schedule that
// misfires once is missed for a whole month; a daily tick that finds the
// period's anchor already written just no-ops every day after the first
// successful run.
//
// Gate discipline (Q5): every run calls assertProgramLaunchable(db) FIRST
// and no-ops if it returns false — the whole point of Phase A's gate is
// that nothing downstream can ignore it.

import * as functions from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertProgramLaunchable, auditEntry, resolveIsAdmin } from "../admin/complianceGate";
import { appendLedgerEntry, toProjectionFields } from "./productCreditLedger";
import { calculateBenefitForPeriod } from "./benefitCalculation";

// Bounds the work per run — see the file-level note on why a daily tick
// makes a bounded, "pick up the rest next run" design safe rather than a
// silent truncation: nothing is ever skipped permanently, just deferred.
const MAX_ENROLLMENTS_PER_RUN = 500;

const ACCRUAL_ELIGIBLE_STATUSES = new Set(["active", "benefitEligible"]);

function currentPeriod(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

function addMonthsUTC(date: Date, months: number): Date {
  const d = new Date(date.getTime());
  d.setUTCMonth(d.getUTCMonth() + months);
  return d;
}

function periodsPerYearFor(frequency: unknown): number {
  if (frequency === "quarterly") return 4;
  if (frequency === "annual") return 1;
  return 12;
}

interface AccrualRunResult {
  processed: number;
  credited: number;
  skipped: number;
  truncated: boolean;
  notLaunchable?: boolean;
  monthlyCreditDisabled?: boolean;
}

async function accrueOneEnrollment(
  db: admin.firestore.Firestore,
  enrollmentId: string,
  period: string,
  periodDate: Date
): Promise<"credited" | "skipped"> {
  const anchorRef = db.collection("benefit_accruals").doc(`${enrollmentId}_${period}`);
  const enrollmentRef = db.collection("benefit_enrollments").doc(enrollmentId);

  return db.runTransaction(async (tx) => {
    // All reads before all writes.
    const [anchorSnap, enrollmentSnap] = await Promise.all([tx.get(anchorRef), tx.get(enrollmentRef)]);

    // THE critical idempotency check: this period is already done for this
    // enrollment, regardless of outcome (credited or zero) — never
    // recomputed, never re-attempted.
    if (anchorSnap.exists) return "skipped";
    if (!enrollmentSnap.exists) return "skipped";

    const enrollment = enrollmentSnap.data()!;
    if (!ACCRUAL_ELIGIBLE_STATUSES.has(enrollment.status)) return "skipped";

    const startDate = (enrollment.startDate as admin.firestore.Timestamp | undefined)?.toDate();
    const maturityDate = (enrollment.maturityDate as admin.firestore.Timestamp | undefined)?.toDate();
    if (!startDate || startDate > periodDate) return "skipped"; // not started yet
    if (maturityDate && maturityDate < periodDate) return "skipped"; // matured — accrue nothing after maturityDate

    const programRef = db.collection("benefit_programs").doc(enrollment.programId);
    const programSnap = await tx.get(programRef);
    if (!programSnap.exists) return "skipped";
    const program = programSnap.data()!;
    // Suspended / complianceHold / any non-active program status — skip,
    // log, do not accrue.
    if (program.status !== "active") {
      console.log(
        `[BenefitAccrual] Skipping enrollment ${enrollmentId}: program ${enrollment.programId} status is "${program.status}", not "active"`
      );
      return "skipped";
    }

    const projectionRef = db.collection("product_credit_balances").doc(enrollment.customerId);
    const projectionSnap = await tx.get(projectionRef);
    const currentProjection = toProjectionFields(projectionSnap.data());

    const calc = calculateBenefitForPeriod({
      program: {
        benefitRuleType: program.benefitRuleType,
        benefitRateValue: typeof program.benefitRateValue === "number" ? program.benefitRateValue : 0,
        creditFrequency: program.creditFrequency,
        rulesVersion: typeof program.rulesVersion === "number" ? program.rulesVersion : 1,
        tierRates: program.tierRates ?? null,
        categoryRates: program.categoryRates ?? null,
        promotionalFrom: (program.promotionalFrom as admin.firestore.Timestamp | undefined)?.toDate() ?? null,
        promotionalTo: (program.promotionalTo as admin.firestore.Timestamp | undefined)?.toDate() ?? null,
      },
      enrollment: {
        // programAmount 0/missing -> accrue 0, never throw (edge case).
        programAmount: typeof enrollment.programAmount === "number" ? enrollment.programAmount : 0,
        rulesVersionAtEnrollment:
          typeof enrollment.rulesVersionAtEnrollment === "number" ? enrollment.rulesVersionAtEnrollment : 1,
        benefitTierId: (enrollment.benefitTierId as string | undefined) ?? null,
        benefitCategoryId: (enrollment.benefitCategoryId as string | undefined) ?? null,
      },
      period,
      periodDate,
    });

    // The ledger entry ref is generated up front (client-side id
    // generation, no network round trip) so the anchor can embed
    // ledgerEntryId in its single initial write, rather than a separate
    // update() call afterward.
    const entryRef = calc.amount > 0 ? db.collection("product_credit_ledger").doc() : null;

    tx.set(anchorRef, {
      id: anchorRef.id,
      enrollmentId,
      customerId: enrollment.customerId,
      programId: enrollment.programId,
      period,
      calculatedAmount: calc.amount,
      ruleType: calc.ruleType,
      rulesVersion: calc.rulesVersion,
      explanation: calc.explanation,
      status: calc.amount > 0 ? "credited" : "zero",
      ledgerEntryId: entryRef?.id ?? null,
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (calc.amount > 0 && entryRef) {
      const expiresAt =
        typeof program.creditExpiryDays === "number"
          ? admin.firestore.Timestamp.fromMillis(periodDate.getTime() + program.creditExpiryDays * 86400000)
          : null;

      appendLedgerEntry(tx, db, {
        entryRef,
        customerId: enrollment.customerId,
        enrollmentId,
        type: "CREDIT",
        amount: calc.amount,
        currentProjection,
        period,
        description: `Monthly Product Credit for ${period}`,
        metadata: { ruleType: calc.ruleType, rulesVersion: calc.rulesVersion, explanation: calc.explanation },
        expiresAt,
        nextCreditDate: admin.firestore.Timestamp.fromDate(
          addMonthsUTC(periodDate, 12 / periodsPerYearFor(program.creditFrequency))
        ),
      });
    }

    tx.update(enrollmentRef, {
      lastAccrualPeriod: period,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return calc.amount > 0 ? "credited" : "skipped";
  });
}

async function runAccrualForPeriod(
  db: admin.firestore.Firestore,
  period: string,
  periodDate: Date
): Promise<AccrualRunResult> {
  const launch = await assertProgramLaunchable(db);
  if (!launch.launchable) {
    console.log(`[BenefitAccrual] Not launchable for period ${period}: ${launch.reasons.join("; ")}`);
    return { processed: 0, credited: 0, skipped: 0, truncated: false, notLaunchable: true };
  }

  const flagSnap = await db.collection("feature_flags").doc("benefit_program").get();
  if (flagSnap.data()?.MONTHLY_CREDIT_ENABLED !== true) {
    console.log(`[BenefitAccrual] MONTHLY_CREDIT_ENABLED is not true — skipping period ${period}`);
    return { processed: 0, credited: 0, skipped: 0, truncated: false, monthlyCreditDisabled: true };
  }

  const enrollmentsSnap = await db
    .collection("benefit_enrollments")
    .where("status", "in", Array.from(ACCRUAL_ELIGIBLE_STATUSES))
    .limit(MAX_ENROLLMENTS_PER_RUN + 1)
    .get();

  const truncated = enrollmentsSnap.size > MAX_ENROLLMENTS_PER_RUN;
  const docs = truncated ? enrollmentsSnap.docs.slice(0, MAX_ENROLLMENTS_PER_RUN) : enrollmentsSnap.docs;
  if (truncated) {
    console.warn(
      `[BenefitAccrual] Hit the ${MAX_ENROLLMENTS_PER_RUN}-enrollment cap for period ${period} — ` +
        `${enrollmentsSnap.size - MAX_ENROLLMENTS_PER_RUN} enrollment(s) NOT processed this run; ` +
        "they remain eligible and will be picked up on a later run (the anchor is per-enrollment, not global)."
    );
  }

  let credited = 0;
  let skipped = 0;
  for (const doc of docs) {
    const outcome = await accrueOneEnrollment(db, doc.id, period, periodDate);
    if (outcome === "credited") credited++;
    else skipped++;
  }

  return { processed: docs.length, credited, skipped, truncated };
}

export const accrueMonthlyBenefits = functions.pubsub
  .schedule("every day 03:00")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    const period = currentPeriod(now);
    const result = await runAccrualForPeriod(db, period, now);
    console.log(
      `[BenefitAccrual] period=${period} processed=${result.processed} credited=${result.credited} ` +
        `skipped=${result.skipped} truncated=${result.truncated}`
    );
    return result;
  });

interface RunBenefitAccrualNowData {
  period?: string;
  reason?: string;
}

export const runBenefitAccrualNow = onCall(
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

    const data = request.data as RunBenefitAccrualNowData;
    const reasonInput = String(data?.reason || "").trim();
    const period = String(data?.period || currentPeriod(new Date())).trim();

    if (!isAdmin) {
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "runBenefitAccrualNow.denied",
          target: period,
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
    if (!/^\d{4}-\d{2}$/.test(period)) {
      throw new HttpsError("invalid-argument", "period must be in YYYY-MM format");
    }

    const periodDate = new Date(`${period}-01T00:00:00.000Z`);
    const result = await runAccrualForPeriod(db, period, periodDate);

    await db.collection("compliance_audit_log").add(
      auditEntry({
        actorUid: uid,
        actorEmail: email,
        action: "runBenefitAccrualNow",
        target: period,
        previousValue: null,
        newValue: result,
        reason: reasonInput,
      })
    );

    return { success: true, period, ...result };
  }
);
