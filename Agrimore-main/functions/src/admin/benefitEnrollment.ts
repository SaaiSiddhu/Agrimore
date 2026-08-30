// ============================================================
//  Benefit enrollment — admin-only participation RECORDS
//  (Phase B: benefit ledger & accrual engine)
// ============================================================
//
// createBenefitEnrollment records that a customer has agreed to
// participate in a Customer Product Benefit Program — it is a RECORD, not
// a purchase flow. `programAmount` is a recorded number describing an
// arrangement agreed elsewhere; this callable does not accept, hold, or
// move any money, exactly like createSellerByAdmin.ts/
// createEmployeeByAdmin.ts create a record of a role grant without moving
// money either. Placed in admin/ (not customer/) for the same reason those
// two files are: only an admin can call it, even though the record it
// creates is about a customer.
//
// /benefit_enrollments/{enrollmentId} is Cloud-Function write-only,
// readable by its own customer or an admin (see firestore.rules).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertProgramLaunchable, auditEntry, resolveIsAdmin } from "./complianceGate";

const ENROLLMENT_STATUSES = [
  "pendingEnrollment",
  "active",
  "benefitEligible",
  "benefitPending",
  "suspended",
  "completed",
  "closed",
] as const;
type EnrollmentStatus = (typeof ENROLLMENT_STATUSES)[number];

const ACTIVE_LIKE_STATUSES: readonly EnrollmentStatus[] = [
  "pendingEnrollment",
  "active",
  "benefitEligible",
  "benefitPending",
];

function addMonthsUTC(date: Date, months: number): Date {
  const d = new Date(date.getTime());
  d.setUTCMonth(d.getUTCMonth() + months);
  return d;
}

interface CreateBenefitEnrollmentData {
  customerId?: string;
  programId?: string;
  programAmount?: number;
  startDate?: string | number;
  consentTermsVersion?: string;
  consentMetadata?: Record<string, unknown>;
  /** Optional (Phase C, Workstream 2) — required when the program's
   *  benefitRuleType is "tier"/"category" for this enrollment to ever
   *  accrue anything nonzero; validated against the program's own
   *  tierRates/categoryRates keys, never accepted blind. */
  benefitTierId?: string;
  benefitCategoryId?: string;
  reason?: string;
}

export const createBenefitEnrollment = onCall(
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

    const data = request.data as CreateBenefitEnrollmentData;
    const customerId = String(data?.customerId || "").trim();
    const programId = String(data?.programId || "").trim();
    const reasonInput = String(data?.reason || "").trim();

    if (!isAdmin) {
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "createBenefitEnrollment.denied",
          target: `${customerId || "(unknown)"}/${programId || "(unknown)"}`,
          previousValue: null,
          newValue: { customerId, programId, programAmount: data?.programAmount ?? null },
          reason: reasonInput || null,
        })
      );
      throw new HttpsError("permission-denied", "Admin only");
    }

    if (!customerId) throw new HttpsError("invalid-argument", "customerId is required");
    if (!programId) throw new HttpsError("invalid-argument", "programId is required");
    if (!reasonInput) throw new HttpsError("invalid-argument", "reason is required");

    const programAmount = Number(data?.programAmount);
    if (!Number.isFinite(programAmount) || programAmount <= 0) {
      throw new HttpsError("invalid-argument", "programAmount must be a positive number");
    }

    const consentTermsVersion = String(data?.consentTermsVersion || "").trim();
    if (!consentTermsVersion) {
      throw new HttpsError("invalid-argument", "consentTermsVersion is required");
    }

    const startDateRaw = data?.startDate;
    const startDate = startDateRaw !== undefined ? new Date(startDateRaw) : new Date();
    if (Number.isNaN(startDate.getTime())) {
      throw new HttpsError("invalid-argument", "startDate must be a valid date");
    }
    // Edge case explicitly allowed: startDate in the past (back-dating a
    // real agreement) — audit-logged like every other field here, not
    // specially flagged, since the audit entry already records it.

    // §4's line: the compliance gate must be launchable AND new enrollment
    // must be explicitly enabled — checked before the transaction, mirrors
    // setBenefitProgramConfig's activation check.
    const launch = await assertProgramLaunchable(db);
    if (!launch.launchable) {
      throw new HttpsError(
        "failed-precondition",
        `Cannot create enrollment: program is not launchable (${launch.reasons.join("; ")})`
      );
    }

    const programRef = db.collection("benefit_programs").doc(programId);
    const flagRef = db.collection("feature_flags").doc("benefit_program");
    const customerRef = db.collection("users").doc(customerId);
    const enrollmentRef = db.collection("benefit_enrollments").doc();
    const auditRef = db.collection("compliance_audit_log").doc();
    const existingEnrollmentQuery = db
      .collection("benefit_enrollments")
      .where("customerId", "==", customerId)
      .where("programId", "==", programId)
      .where("status", "in", ACTIVE_LIKE_STATUSES as string[]);

    const result = await db.runTransaction(async (tx) => {
      // All reads before all writes.
      const [programSnap, flagSnap, customerSnap, existingSnap] = await Promise.all([
        tx.get(programRef),
        tx.get(flagRef),
        tx.get(customerRef),
        tx.get(existingEnrollmentQuery),
      ]);

      if (flagSnap.data()?.NEW_ENROLLMENT_ENABLED !== true) {
        throw new HttpsError("failed-precondition", "NEW_ENROLLMENT_ENABLED is not enabled");
      }
      if (!programSnap.exists || programSnap.data()?.status !== "active") {
        throw new HttpsError("failed-precondition", "Program is not active");
      }
      if (!customerSnap.exists) {
        throw new HttpsError("not-found", "Customer not found");
      }
      if (!existingSnap.empty) {
        throw new HttpsError(
          "failed-precondition",
          "This customer already has an active enrollment in this program"
        );
      }

      const program = programSnap.data()!;
      const minAmount = typeof program.minProgramAmount === "number" ? program.minProgramAmount : 0;
      const maxAmount = typeof program.maxProgramAmount === "number" ? program.maxProgramAmount : 0;
      if (programAmount < minAmount || (maxAmount > 0 && programAmount > maxAmount)) {
        throw new HttpsError(
          "invalid-argument",
          `programAmount must be between ${minAmount} and ${maxAmount || "unbounded"}`
        );
      }

      const durationMonths = typeof program.durationMonths === "number" ? program.durationMonths : 0;
      if (durationMonths <= 0) {
        throw new HttpsError("failed-precondition", "Program has no valid durationMonths configured");
      }
      const maturityDate = addMonthsUTC(startDate, durationMonths);
      const rulesVersionAtEnrollment = typeof program.rulesVersion === "number" ? program.rulesVersion : 1;

      // Reject an unknown tier/category id rather than silently accepting
      // it — an enrollment pointing at a key that doesn't exist in the
      // program's tierRates/categoryRates would accrue 0 forever with no
      // indication why, which is worse than failing loudly at enrollment
      // time.
      const benefitTierId = data?.benefitTierId ? String(data.benefitTierId).trim() : null;
      if (benefitTierId) {
        const tierRates = (program.tierRates as Record<string, unknown> | undefined) ?? {};
        if (!(benefitTierId in tierRates)) {
          throw new HttpsError(
            "invalid-argument",
            `benefitTierId "${benefitTierId}" is not a configured tier on this program`
          );
        }
      }
      const benefitCategoryId = data?.benefitCategoryId ? String(data.benefitCategoryId).trim() : null;
      if (benefitCategoryId) {
        const categoryRates = (program.categoryRates as Record<string, unknown> | undefined) ?? {};
        if (!(benefitCategoryId in categoryRates)) {
          throw new HttpsError(
            "invalid-argument",
            `benefitCategoryId "${benefitCategoryId}" is not a configured category on this program`
          );
        }
      }

      tx.set(enrollmentRef, {
        id: enrollmentRef.id,
        customerId,
        programId,
        status: "active" as EnrollmentStatus,
        programAmount,
        rulesVersionAtEnrollment,
        enrollmentDate: admin.firestore.FieldValue.serverTimestamp(),
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        maturityDate: admin.firestore.Timestamp.fromDate(maturityDate),
        completionDate: null,
        consentTermsVersion,
        consentAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        consentMetadata: data?.consentMetadata ?? null,
        lastAccrualPeriod: null,
        benefitTierId,
        benefitCategoryId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        auditRef,
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "createBenefitEnrollment",
          target: enrollmentRef.id,
          previousValue: null,
          newValue: {
            customerId,
            programId,
            programAmount,
            startDate: startDate.toISOString(),
            maturityDate: maturityDate.toISOString(),
          },
          reason: reasonInput,
        })
      );

      return { enrollmentId: enrollmentRef.id, maturityDate: maturityDate.toISOString(), rulesVersionAtEnrollment };
    });

    return { success: true, ...result };
  }
);

interface SetEnrollmentStatusData {
  enrollmentId?: string;
  status?: string;
  reason?: string;
}

export const setEnrollmentStatus = onCall(
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

    const data = request.data as SetEnrollmentStatusData;
    const enrollmentId = String(data?.enrollmentId || "").trim();
    const statusInput = String(data?.status || "").trim();
    const reasonInput = String(data?.reason || "").trim();

    if (!isAdmin) {
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setEnrollmentStatus.denied",
          target: enrollmentId || "(unknown)",
          previousValue: null,
          newValue: statusInput || null,
          reason: reasonInput || null,
        })
      );
      throw new HttpsError("permission-denied", "Admin only");
    }

    if (!enrollmentId) throw new HttpsError("invalid-argument", "enrollmentId is required");
    if (!(ENROLLMENT_STATUSES as readonly string[]).includes(statusInput)) {
      throw new HttpsError("invalid-argument", `status must be one of: ${ENROLLMENT_STATUSES.join(", ")}`);
    }
    if (!reasonInput) throw new HttpsError("invalid-argument", "reason is required");

    const status = statusInput as EnrollmentStatus;
    const enrollmentRef = db.collection("benefit_enrollments").doc(enrollmentId);
    const auditRef = db.collection("compliance_audit_log").doc();

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(enrollmentRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Enrollment not found");
      }
      const previousStatus = snap.data()?.status ?? null;

      const update: Record<string, unknown> = {
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (status === "completed" || status === "closed") {
        update.completionDate = admin.firestore.FieldValue.serverTimestamp();
      }
      tx.update(enrollmentRef, update);

      tx.set(
        auditRef,
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setEnrollmentStatus",
          target: enrollmentId,
          previousValue: previousStatus,
          newValue: status,
          reason: reasonInput,
        })
      );

      return { previousStatus, newStatus: status };
    });

    return { success: true, enrollmentId, ...result };
  }
);
