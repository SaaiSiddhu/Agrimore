// ============================================================
//  Benefit program configuration
//  (Phase B: benefit ledger & accrual engine)
// ============================================================
//
// /benefit_programs/{programId} holds the rates/duration/limits that
// determine how much Product Credit a customer earns — it is
// Cloud-Function write-only and admin-read-only (see firestore.rules),
// for the same additive-rules reason as Phase A's feature_flags/
// compliance_config (D5 here == D2 there): `match /settings/{docId}`
// already grants `allow write: if isAdmin()`, so anything placed under
// settings/ would stay directly admin-client-writable regardless of any
// extra rule written on top.
//
// setBenefitProgramConfig is the ONLY writer. It reuses complianceGate.ts's
// admin check and audit-entry shape exactly (resolveIsAdmin/auditEntry),
// so every change here lands in the same compliance_audit_log trail as
// Phase A's flag/compliance changes.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertProgramLaunchable, auditEntry, resolveIsAdmin } from "./complianceGate";

const PROGRAM_STATUSES = [
  "draft",
  "pendingApproval",
  "active",
  "suspended",
  "completed",
  "cancelled",
  "expired",
  "complianceHold",
] as const;

const BENEFIT_RULE_TYPES = ["none", "flatRupee", "percentage", "promotional", "tier", "category"] as const;
const CREDIT_FREQUENCIES = ["monthly", "quarterly", "annual"] as const;

const PATCHABLE_FIELDS = [
  "name",
  "description",
  "status",
  "durationMonths",
  "enrollmentOpensAt",
  "enrollmentClosesAt",
  "minProgramAmount",
  "maxProgramAmount",
  "benefitRuleType",
  "benefitRateValue",
  "creditFrequency",
  "creditExpiryDays",
  "eligibleCategoryIds",
  "tierRates",
  "categoryRates",
  "promotionalFrom",
  "promotionalTo",
  "minOrderValueForRedemption",
  "maxCreditPerOrder",
  "maxCreditPercentOfOrder",
  "redeemableCategoryIds",
  "redemptionEnabled",
] as const;
type PatchableField = (typeof PATCHABLE_FIELDS)[number];

// D6: "never hardcode 12%, or any rate" — these are the fields that decide
// HOW MUCH benefit a customer EARNS. Changing any of them bumps
// rulesVersion so an already-accrued benefit remains explainable under the
// rules version in force when it accrued (see benefitCalculation.ts).
// Redemption-restriction fields (minOrderValueForRedemption,
// maxCreditPerOrder, maxCreditPercentOfOrder, redeemableCategoryIds,
// redemptionEnabled) are deliberately NOT here — they govern how much
// ALREADY-EARNED credit may be SPENT, evaluated fresh against the current
// config every time (redemptionRules.ts), not something a past accrual
// needs to stay explainable under.
const VERSION_BUMPING_FIELDS: readonly PatchableField[] = [
  "durationMonths",
  "minProgramAmount",
  "maxProgramAmount",
  "benefitRuleType",
  "benefitRateValue",
  "creditFrequency",
  "creditExpiryDays",
  "eligibleCategoryIds",
  "tierRates",
  "categoryRates",
  "promotionalFrom",
  "promotionalTo",
];

function sanitizePatchValue(field: PatchableField, value: unknown): unknown {
  switch (field) {
    case "status":
      if (!(PROGRAM_STATUSES as readonly string[]).includes(String(value))) {
        throw new HttpsError("invalid-argument", `status must be one of: ${PROGRAM_STATUSES.join(", ")}`);
      }
      return value;
    case "benefitRuleType":
      if (!(BENEFIT_RULE_TYPES as readonly string[]).includes(String(value))) {
        throw new HttpsError(
          "invalid-argument",
          `benefitRuleType must be one of: ${BENEFIT_RULE_TYPES.join(", ")}`
        );
      }
      return value;
    case "creditFrequency":
      if (!(CREDIT_FREQUENCIES as readonly string[]).includes(String(value))) {
        throw new HttpsError(
          "invalid-argument",
          `creditFrequency must be one of: ${CREDIT_FREQUENCIES.join(", ")}`
        );
      }
      return value;
    case "durationMonths":
      if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
        throw new HttpsError("invalid-argument", "durationMonths must be a positive integer");
      }
      return value;
    case "creditExpiryDays":
      if (value !== null && (typeof value !== "number" || !Number.isInteger(value) || value < 0)) {
        throw new HttpsError("invalid-argument", "creditExpiryDays must be a non-negative integer or null");
      }
      return value;
    case "minProgramAmount":
    case "maxProgramAmount":
    case "benefitRateValue":
      if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
        throw new HttpsError("invalid-argument", `${field} must be a non-negative number`);
      }
      return value;
    case "name":
    case "description":
      if (typeof value !== "string") {
        throw new HttpsError("invalid-argument", `${field} must be a string`);
      }
      return value;
    case "enrollmentOpensAt":
    case "enrollmentClosesAt":
    case "promotionalFrom":
    case "promotionalTo": {
      if (value === null) return null;
      const date = new Date(value as string | number);
      if (Number.isNaN(date.getTime())) {
        throw new HttpsError("invalid-argument", `${field} must be a valid date or null`);
      }
      return admin.firestore.Timestamp.fromDate(date);
    }
    case "eligibleCategoryIds":
    case "redeemableCategoryIds":
      if (value !== null && !(Array.isArray(value) && value.every((v) => typeof v === "string"))) {
        throw new HttpsError("invalid-argument", `${field} must be an array of strings or null`);
      }
      return value;
    case "tierRates":
    case "categoryRates":
      if (value !== null && (typeof value !== "object" || Array.isArray(value))) {
        throw new HttpsError("invalid-argument", `${field} must be an object map or null`);
      }
      return value;
    case "minOrderValueForRedemption":
      if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
        throw new HttpsError("invalid-argument", "minOrderValueForRedemption must be a non-negative number");
      }
      return value;
    case "maxCreditPerOrder":
      if (value !== null && (typeof value !== "number" || !Number.isFinite(value) || value < 0)) {
        throw new HttpsError("invalid-argument", "maxCreditPerOrder must be a non-negative number or null");
      }
      return value;
    case "maxCreditPercentOfOrder":
      if (value !== null && (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 100)) {
        throw new HttpsError("invalid-argument", "maxCreditPercentOfOrder must be between 0 and 100, or null");
      }
      return value;
    case "redemptionEnabled":
      if (typeof value !== "boolean") {
        throw new HttpsError("invalid-argument", "redemptionEnabled must be a boolean");
      }
      return value;
  }
}

interface SetBenefitProgramConfigData {
  programId?: string;
  patch?: Record<string, unknown>;
  reason?: string;
}

export const setBenefitProgramConfig = onCall(
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

    const data = request.data as SetBenefitProgramConfigData;
    const programId = String(data?.programId || "").trim();
    const reasonInput = String(data?.reason || "").trim();
    const patch = data?.patch && typeof data.patch === "object" && !Array.isArray(data.patch) ? data.patch : {};

    if (!isAdmin) {
      await db.collection("compliance_audit_log").add(
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setBenefitProgramConfig.denied",
          target: programId || "(unknown)",
          previousValue: null,
          newValue: patch,
          reason: reasonInput || null,
        })
      );
      throw new HttpsError("permission-denied", "Admin only");
    }

    if (!programId) {
      throw new HttpsError("invalid-argument", "programId is required");
    }
    if (!reasonInput) {
      throw new HttpsError("invalid-argument", "reason is required");
    }

    const patchKeys = Object.keys(patch) as PatchableField[];
    if (patchKeys.length === 0) {
      throw new HttpsError("invalid-argument", "patch must contain at least one field");
    }
    for (const key of patchKeys) {
      if (!(PATCHABLE_FIELDS as readonly string[]).includes(key)) {
        throw new HttpsError("invalid-argument", `Unknown or non-patchable field: ${key}`);
      }
    }

    const sanitized: Record<string, unknown> = {};
    for (const key of patchKeys) {
      sanitized[key] = sanitizePatchValue(key, patch[key]);
    }

    // status -> active requires the compliance gate to be launchable.
    // Checked outside the transaction (assertProgramLaunchable does its
    // own independent, non-transactional reads) — a small TOCTOU window
    // is an acceptable, non-exploitable risk for an admin-only action, not
    // a security bypass.
    if (sanitized.status === "active") {
      const launch = await assertProgramLaunchable(db);
      if (!launch.launchable) {
        throw new HttpsError(
          "failed-precondition",
          `Cannot activate program: ${launch.reasons.join("; ")}`
        );
      }
    }

    const programRef = db.collection("benefit_programs").doc(programId);
    const auditRef = db.collection("compliance_audit_log").doc();

    const result = await db.runTransaction(async (tx) => {
      // All reads before all writes.
      const programSnap = await tx.get(programRef);
      const previousData = programSnap.exists ? (programSnap.data() as Record<string, unknown>) : {};

      const mergedMin =
        typeof sanitized.minProgramAmount === "number"
          ? sanitized.minProgramAmount
          : (previousData.minProgramAmount as number | undefined) ?? 0;
      const mergedMax =
        typeof sanitized.maxProgramAmount === "number"
          ? sanitized.maxProgramAmount
          : (previousData.maxProgramAmount as number | undefined) ?? 0;
      if (mergedMax > 0 && mergedMax < mergedMin) {
        throw new HttpsError("invalid-argument", "maxProgramAmount must be >= minProgramAmount");
      }

      const mergedDuration =
        typeof sanitized.durationMonths === "number"
          ? sanitized.durationMonths
          : (previousData.durationMonths as number | undefined) ?? 0;
      if (mergedDuration <= 0) {
        throw new HttpsError("invalid-argument", "durationMonths must be greater than 0");
      }

      let newRulesVersion: number;
      let rulesVersionBumped = false;
      if (!programSnap.exists) {
        newRulesVersion = 1;
      } else {
        const previousRulesVersion =
          typeof previousData.rulesVersion === "number" ? previousData.rulesVersion : 1;
        rulesVersionBumped = patchKeys.some((k) => VERSION_BUMPING_FIELDS.includes(k));
        newRulesVersion = rulesVersionBumped ? previousRulesVersion + 1 : previousRulesVersion;
      }

      const writeData: Record<string, unknown> = {
        ...sanitized,
        rulesVersion: newRulesVersion,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: uid,
      };
      if (!programSnap.exists) {
        writeData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      tx.set(programRef, writeData, { merge: true });

      tx.set(
        auditRef,
        auditEntry({
          actorUid: uid,
          actorEmail: email,
          action: "setBenefitProgramConfig",
          target: programId,
          previousValue: previousData,
          newValue: sanitized,
          reason: reasonInput,
        })
      );

      return { rulesVersion: newRulesVersion, rulesVersionBumped, created: !programSnap.exists };
    });

    return { success: true, programId, ...result };
  }
);
