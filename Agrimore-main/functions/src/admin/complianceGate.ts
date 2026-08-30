// ============================================================
//  AgriMore Customer Product Benefit Program — compliance gate
//  (Phase A: compliance & feature-flag control plane)
// ============================================================
//
// The Product Benefit Program (customer pays a program amount, receives
// monthly Product Credit, and has principal returned at maturity) is in
// substance a deposit under India's Banning of Unregulated Deposit Schemes
// Act, 2019. Written legal/compliance clearance is required before any
// principal intake or principal return is ever exposed to a real customer.
//
// This file is the enforcement mechanism, not a decoration: firestore.rules
// makes `feature_flags/benefit_program` and `compliance_config/{programId}`
// write:false for every client (including an authenticated admin client),
// so these two callables — running with the Admin SDK, which bypasses
// firestore.rules entirely — are the ONLY way either document can change.
// Every mutation, successful or denied, is recorded in the
// Cloud-Function-write-only `compliance_audit_log` collection in the same
// transaction as the change, so the change is tamper-evident.
//
// No enrollment, ledger, accrual, or redemption logic exists anywhere in
// this codebase yet (that is Phase B/C, gated on this file). The four
// flags that would guard that not-yet-written logic
// (COMPOUNDING_ENABLED, CASH_REDEMPTION_ENABLED, PRINCIPAL_INTAKE_ENABLED,
// PRINCIPAL_RETURN_ENABLED) are hard-blocked from ever being set to `true`
// here, regardless of approval state — setting a flag true for logic that
// doesn't exist yet would just be a landmine for whoever writes Phase B.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// ------------------------------------------------------------
// Feature flags — feature_flags/benefit_program
// ------------------------------------------------------------

const FLAG_DOC_PATH = { collection: "feature_flags", doc: "benefit_program" } as const;

const FEATURE_FLAG_KEYS = [
  "BENEFIT_PROGRAM_ENABLED",
  "NEW_ENROLLMENT_ENABLED",
  "MONTHLY_CREDIT_ENABLED",
  "PERCENTAGE_BENEFIT_ENABLED",
  "BENEFIT_EXAMPLES_ENABLED",
  "PRODUCT_CREDIT_REDEMPTION_ENABLED",
  "BENEFIT_ACCUMULATION_ENABLED",
  "COMPOUNDING_ENABLED",
  "CASH_REDEMPTION_ENABLED",
  "PRINCIPAL_INTAKE_ENABLED",
  "PRINCIPAL_RETURN_ENABLED",
] as const;
type FeatureFlagKey = (typeof FEATURE_FLAG_KEYS)[number];

// These four guard logic (compounding, cash redemption, principal intake,
// principal return) that does not exist in this codebase yet, and/or is
// legally blocked pending the BUDS Act review. Setting any of them to
// `false` is always permitted (that's the safe direction); setting any of
// them to `true` is refused unconditionally, even with full approval.
const HARD_BLOCKED_TRUE_FLAGS: readonly FeatureFlagKey[] = [
  "COMPOUNDING_ENABLED",
  "CASH_REDEMPTION_ENABLED",
  "PRINCIPAL_INTAKE_ENABLED",
  "PRINCIPAL_RETURN_ENABLED",
];

// These two are the actual customer-facing "the program is live" switches.
// They may only be set to `true` once both approvals below are APPROVED.
const APPROVAL_GATED_TRUE_FLAGS: readonly FeatureFlagKey[] = [
  "BENEFIT_PROGRAM_ENABLED",
  "NEW_ENROLLMENT_ENABLED",
];

function defaultFlags(): Record<FeatureFlagKey, boolean> {
  const flags = {} as Record<FeatureFlagKey, boolean>;
  for (const key of FEATURE_FLAG_KEYS) flags[key] = false;
  return flags;
}

// Mirrors BenefitFeatureFlagsModel.fromMap's fail-closed logic
// (packages/agrimore_core/lib/models/benefit_feature_flags_model.dart):
// only a literal boolean `true` on a known key counts; everything else —
// missing key, missing document, non-boolean value — is `false`.
function sanitizeFlags(raw: FirebaseFirestore.DocumentData | undefined): Partial<Record<FeatureFlagKey, boolean>> {
  const out: Partial<Record<FeatureFlagKey, boolean>> = {};
  if (!raw) return out;
  for (const key of FEATURE_FLAG_KEYS) {
    if (typeof raw[key] === "boolean") out[key] = raw[key];
  }
  return out;
}

// ------------------------------------------------------------
// Compliance config — compliance_config/{programId}
// ------------------------------------------------------------

const PROGRAM_ID = "benefit_program";

const REVIEW_STATUSES = ["NOT_STARTED", "IN_REVIEW", "APPROVED", "REJECTED"] as const;
type ReviewStatus = (typeof REVIEW_STATUSES)[number];

const COMPLIANCE_FIELDS = [
  "legalReviewStatus",
  "complianceApprovalStatus",
  "approvedMarketingCopyVersion",
  "approvedBenefitStructure",
  "approvedProductTerms",
  "approvalDate",
  "reviewer",
  "jurisdiction",
  "internalNotes",
  "budsActReviewStatus",
  "rbiReviewStatus",
  "legalOpinionDocumentRef",
] as const;
type ComplianceField = (typeof COMPLIANCE_FIELDS)[number];

const STATUS_FIELDS: readonly ComplianceField[] = [
  "legalReviewStatus",
  "complianceApprovalStatus",
  "budsActReviewStatus",
  "rbiReviewStatus",
];

// ------------------------------------------------------------
// Shared helpers
// ------------------------------------------------------------

interface AuditEntryInput {
  actorUid: string;
  actorEmail: string | null;
  action: string;
  target: string;
  previousValue: unknown;
  newValue: unknown;
  reason: string | null;
}

function auditEntry(input: AuditEntryInput) {
  return {
    ...input,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// Claim-first, mirroring setUserRole.ts's callerIsAdmin(uid, isAdminClaim)
// shape exactly, rather than inventing a new admin check.
async function resolveIsAdmin(
  db: admin.firestore.Firestore,
  uid: string,
  isAdminClaim: boolean
): Promise<boolean> {
  if (isAdminClaim) return true;
  const callerSnap = await db.collection("users").doc(uid).get();
  return callerSnap.data()?.role === "admin";
}

/// Returns `{ launchable, reasons }` — launchable ONLY if legal review AND
/// compliance approval are both APPROVED AND BENEFIT_PROGRAM_ENABLED is
/// true. Exported for Phase B to consume; deliberately has no callers in
/// this phase (Phase A adds the gate only, not the thing being gated).
export async function assertProgramLaunchable(
  db: admin.firestore.Firestore
): Promise<{ launchable: boolean; reasons: string[] }> {
  const [complianceSnap, flagSnap] = await Promise.all([
    db.collection("compliance_config").doc(PROGRAM_ID).get(),
    db.collection(FLAG_DOC_PATH.collection).doc(FLAG_DOC_PATH.doc).get(),
  ]);

  const compliance = complianceSnap.data() || {};
  const flags = { ...defaultFlags(), ...sanitizeFlags(flagSnap.data()) };

  const reasons: string[] = [];
  if (compliance.legalReviewStatus !== "APPROVED") {
    reasons.push("legalReviewStatus is not APPROVED");
  }
  if (compliance.complianceApprovalStatus !== "APPROVED") {
    reasons.push("complianceApprovalStatus is not APPROVED");
  }
  if (flags.BENEFIT_PROGRAM_ENABLED !== true) {
    reasons.push("BENEFIT_PROGRAM_ENABLED is not enabled");
  }

  return { launchable: reasons.length === 0, reasons };
}

// ------------------------------------------------------------
// Callable: setBenefitFeatureFlag
// ------------------------------------------------------------

interface SetBenefitFeatureFlagData {
  flag?: string;
  value?: boolean;
  reason?: string;
}

export const setBenefitFeatureFlag = onCall(
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

    const data = request.data as SetBenefitFeatureFlagData;
    const flagInput = String(data?.flag || "").trim();
    const valueInput = data?.value;
    const reasonInput = String(data?.reason || "").trim();

    if (!isAdmin) {
      // Denied attempts are a governance signal too — recorded even though
      // the request itself may also be malformed.
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setBenefitFeatureFlag.denied",
          target: flagInput || "(unknown)",
          previousValue: null,
          newValue: valueInput ?? null,
          reason: reasonInput || null,
        })
      );
      throw new HttpsError("permission-denied", "Admin only");
    }

    if (!(FEATURE_FLAG_KEYS as readonly string[]).includes(flagInput)) {
      throw new HttpsError(
        "invalid-argument",
        `flag must be one of: ${FEATURE_FLAG_KEYS.join(", ")}`
      );
    }
    if (typeof valueInput !== "boolean") {
      throw new HttpsError("invalid-argument", "value must be a boolean");
    }
    if (!reasonInput) {
      throw new HttpsError("invalid-argument", "reason is required");
    }

    const flag = flagInput as FeatureFlagKey;
    const value = valueInput;

    if (value === true && HARD_BLOCKED_TRUE_FLAGS.includes(flag)) {
      throw new HttpsError(
        "failed-precondition",
        `${flag} guards logic that does not exist yet in this codebase and is legally blocked. ` +
          "It cannot be set to true. Setting it to false is always permitted."
      );
    }

    const flagRef = db.collection(FLAG_DOC_PATH.collection).doc(FLAG_DOC_PATH.doc);
    const complianceRef = db.collection("compliance_config").doc(PROGRAM_ID);
    const auditRef = db.collection("compliance_audit_log").doc();

    const result = await db.runTransaction(async (tx) => {
      // All reads before all writes.
      const [flagSnap, complianceSnap] = await Promise.all([
        tx.get(flagRef),
        tx.get(complianceRef),
      ]);

      const currentFlags = { ...defaultFlags(), ...sanitizeFlags(flagSnap.data()) };
      const previousValue = currentFlags[flag];

      if (value === true && APPROVAL_GATED_TRUE_FLAGS.includes(flag)) {
        const compliance = complianceSnap.data() || {};
        const legalApproved = compliance.legalReviewStatus === "APPROVED";
        const complianceApproved = compliance.complianceApprovalStatus === "APPROVED";
        if (!legalApproved || !complianceApproved) {
          throw new HttpsError(
            "failed-precondition",
            `${flag} cannot be enabled until legalReviewStatus and complianceApprovalStatus ` +
              "are both APPROVED in compliance_config/" + PROGRAM_ID
          );
        }
      }

      const updatedFlags = { ...currentFlags, [flag]: value };
      tx.set(flagRef, updatedFlags, { merge: true });
      tx.set(
        auditRef,
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setBenefitFeatureFlag",
          target: flag,
          previousValue,
          newValue: value,
          reason: reasonInput,
        })
      );

      return { previousValue, newValue: value };
    });

    return { success: true, flag, ...result };
  }
);

// ------------------------------------------------------------
// Callable: setComplianceStatus
// ------------------------------------------------------------

interface SetComplianceStatusData {
  field?: string;
  value?: unknown;
  reason?: string;
}

export const setComplianceStatus = onCall(
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

    const data = request.data as SetComplianceStatusData;
    const fieldInput = String(data?.field || "").trim();
    const reasonInput = String(data?.reason || "").trim();

    if (!isAdmin) {
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setComplianceStatus.denied",
          target: fieldInput || "(unknown)",
          previousValue: null,
          newValue: data?.value ?? null,
          reason: reasonInput || null,
        })
      );
      throw new HttpsError("permission-denied", "Admin only");
    }

    if (!(COMPLIANCE_FIELDS as readonly string[]).includes(fieldInput)) {
      throw new HttpsError(
        "invalid-argument",
        `field must be one of: ${COMPLIANCE_FIELDS.join(", ")}`
      );
    }
    if (!reasonInput) {
      throw new HttpsError("invalid-argument", "reason is required");
    }

    const field = fieldInput as ComplianceField;
    let value: unknown = data?.value;

    if (STATUS_FIELDS.includes(field)) {
      const normalized = String(value || "").trim().toUpperCase();
      if (!(REVIEW_STATUSES as readonly string[]).includes(normalized)) {
        throw new HttpsError(
          "invalid-argument",
          `${field} must be one of: ${REVIEW_STATUSES.join(", ")}`
        );
      }
      value = normalized as ReviewStatus;
    } else if (field === "approvalDate") {
      if (value === null || value === undefined || value === "") {
        value = null;
      } else {
        const date = new Date(value as string | number);
        if (Number.isNaN(date.getTime())) {
          throw new HttpsError("invalid-argument", "approvalDate must be a valid date");
        }
        value = admin.firestore.Timestamp.fromDate(date);
      }
    } else {
      if (value !== null && value !== undefined && typeof value !== "string") {
        throw new HttpsError("invalid-argument", `${field} must be a string or null`);
      }
      value = value ?? null;
    }

    const complianceRef = db.collection("compliance_config").doc(PROGRAM_ID);
    const auditRef = db.collection("compliance_audit_log").doc();

    const result = await db.runTransaction(async (tx) => {
      // All reads before all writes.
      const complianceSnap = await tx.get(complianceRef);
      const previousValue = complianceSnap.exists
        ? (complianceSnap.data() as Record<string, unknown>)[field] ?? null
        : null;

      tx.set(
        complianceRef,
        {
          [field]: value,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: uid,
        },
        { merge: true }
      );
      tx.set(
        auditRef,
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setComplianceStatus",
          target: field,
          previousValue,
          newValue: value,
          reason: reasonInput,
        })
      );

      return { previousValue, newValue: value };
    });

    return { success: true, field, ...result };
  }
);
