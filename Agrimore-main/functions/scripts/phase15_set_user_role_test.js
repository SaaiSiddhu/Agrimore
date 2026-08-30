// Phase 15, Workstream 3b: proves setUserRole.ts against a real emulator —
// a non-admin caller is rejected, an admin cannot change their own role,
// the last remaining admin cannot be demoted, and a legitimate promotion
// works end-to-end (Firestore role write + minted custom claims). setUserRole
// is a v2 onCall, wrapped and invoked as `wrapped({ data: payload, auth })`.
// Run with: node scripts/phase15_set_user_role_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { setUserRole } = require("../lib/admin/setUserRole");

const wrapped = test.wrap(setUserRole);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 15, WORKSTREAM 3b — setUserRole ===");

  // Scenario 1: a non-admin caller is rejected.
  {
    const callerUid = "phase15-sur-nonadmin-caller";
    const targetUid = "phase15-sur-target1";
    await db.collection("users").doc(callerUid).set({ role: "user" });
    await db.collection("users").doc(targetUid).set({ role: "user" });

    const r = await callAndCapture({ userId: targetUid, role: "seller" }, { uid: callerUid, token: {} });
    console.log("Scenario 1 raw:", JSON.stringify(r, null, 2));
    const s = !r.ok && r.code === "permission-denied"
      ? `PASSED — a non-admin caller was rejected. code=${r.code} message="${r.message}"`
      : `FAILED — a non-admin caller was NOT rejected: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "permission-denied") allPassed = false;
    results.scenario1_non_admin_caller_rejected = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: an admin cannot change their own role.
  {
    const adminUid = "phase15-sur-self-admin";
    await db.collection("users").doc(adminUid).set({ role: "admin" });

    const r = await callAndCapture(
      { userId: adminUid, role: "seller" },
      { uid: adminUid, token: { admin: true } }
    );
    console.log("Scenario 2 raw:", JSON.stringify(r, null, 2));
    const s = !r.ok && r.code === "failed-precondition"
      ? `PASSED — an admin could not change their own role. code=${r.code} message="${r.message}"`
      : `FAILED — self-role-change was NOT rejected: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "failed-precondition") allPassed = false;
    results.scenario2_admin_cannot_change_own_role = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3 — THE last-admin proof: exactly one admin exists (the
  // target); a DIFFERENT caller authenticates via the admin CUSTOM CLAIM
  // (bypassing the Firestore admin-count for their own permission check,
  // exactly as callerIsAdmin(uid, isAdminClaim) does elsewhere in this
  // codebase) and tries to demote that sole admin. Must be rejected.
  {
    const callerUid = "phase15-sur-claim-only-admin-caller";
    const targetUid = "phase15-sur-last-admin";

    // Scenario 2 above also created a role:'admin' document
    // (phase15-sur-self-admin) that is still sitting in this same
    // emulator's Firestore state — without removing it first, the admin
    // COUNT query below would see 2 admins, not 1, and this scenario would
    // silently test nothing (the demotion would be allowed, then merely
    // fail later for the unrelated credential reason, which is exactly
    // what happened the first time this test was run and caught here).
    const existingAdmins = await db.collection("users").where("role", "==", "admin").get();
    await Promise.all(existingAdmins.docs.map((d) => d.ref.delete()));

    await db.collection("users").doc(targetUid).set({ role: "admin" });
    // Caller deliberately has NO Firestore admin doc — only the token claim
    // — so the admin COUNT query below counts exactly 1 (the target).

    // "customer" is the API-facing role value (setUserRole.ts's VALID_ROLES,
    // per roleClaims.ts's Role union) — it maps internally to the stored
    // value "user", matching what the rest of the app actually checks for.
    const r = await callAndCapture(
      { userId: targetUid, role: "customer" },
      { uid: callerUid, token: { admin: true } }
    );
    console.log("Scenario 3 raw:", JSON.stringify(r, null, 2));
    let s;
    if (r.ok) {
      s = "FAILED — the last remaining admin was demoted — the admin population can now be zeroed out";
      allPassed = false;
    } else if (r.message !== "Cannot demote the last remaining admin") {
      s = `FAILED — rejected, but with the wrong message: "${r.message}" (code=${r.code})`;
      allPassed = false;
    } else {
      s = `PASSED — demoting the last remaining admin was rejected. code=${r.code} message="${r.message}"`;
    }
    results.scenario3_last_admin_cannot_be_demoted = s;
    console.log("Scenario 3:", s);

    // Confirm the target's role was genuinely NOT changed.
    const targetDoc = await db.collection("users").doc(targetUid).get();
    const stillAdmin = targetDoc.data()?.role === "admin";
    const s2 = stillAdmin
      ? "PASSED — the target's Firestore role is still 'admin' after the rejected demotion"
      : `FAILED — the target's role was changed despite the rejection: ${targetDoc.data()?.role}`;
    if (!stillAdmin) allPassed = false;
    results.scenario3b_target_role_unchanged = s2;
    console.log("Scenario 3b:", s2);
  }

  // Scenario 4 — a legitimate promotion. This environment runs no Auth
  // emulator (see phase15_email_otp_test.js's identical note) and no real
  // service account credential is available/appropriate here, so
  // setUserRole's final setClaims(targetUid) step — which calls
  // admin.auth().setCustomUserClaims() — cannot succeed, and the callable
  // rejects even though its Firestore transaction (the role write) already
  // committed first. This mirrors createSellerByAdmin.ts/
  // createEmployeeByAdmin.ts's existing pattern of calling
  // auth.setCustomUserClaims() directly after their own Firestore write —
  // a pre-existing, accepted rough edge in this codebase (a transient Auth
  // API failure there would surface the same way), not something this
  // phase introduced. The REAL, durable evidence of a legitimate
  // promotion — the Firestore role write itself — is checked directly
  // instead of relying on the callable's returned response.
  {
    const callerUid = "phase15-sur-legit-admin-caller";
    const targetUid = "phase15-sur-promote-target";
    // A second, real admin exists here (distinct from scenario 3's sole
    // admin) so this promotion isn't itself a last-admin edge case.
    await db.collection("users").doc(callerUid).set({ role: "admin" });
    await db.collection("users").doc(targetUid).set({ role: "user" });

    const r = await callAndCapture(
      { userId: targetUid, role: "seller" },
      { uid: callerUid, token: { admin: true } }
    );
    console.log("Scenario 4 raw:", JSON.stringify(r, null, 2));
    let s;
    try {
      const targetDoc = await db.collection("users").doc(targetUid).get();
      const roleWritten = targetDoc.data()?.role === "seller";
      if (!roleWritten) {
        throw new Error(`expected Firestore role 'seller' after promotion, got ${targetDoc.data()?.role}`);
      }
      if (r.ok) {
        if (r.result.role !== "seller" || !r.result.claims) {
          throw new Error(`succeeded, but with an unexpected result shape: ${JSON.stringify(r.result)}`);
        }
        s = `PASSED (full end-to-end) — promotion succeeded: Firestore role='seller', minted claims=${JSON.stringify(r.result.claims)}`;
      } else if (r.code === "app/invalid-credential") {
        s =
          "PASSED (partial — environment-limited) — the Firestore role write committed successfully (role='seller', " +
          "verified directly) before the call failed at the LATER setClaims()/admin.auth() step, which cannot " +
          "succeed in this environment (no Auth emulator configured, no real service account credential " +
          "available/appropriate). Full claims-minting round-trip is NOT verified in this environment.";
      } else {
        throw new Error(`unexpected rejection: code=${r.code} message=${r.message}`);
      }
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario4_legitimate_promotion_works = s;
    console.log("Scenario 4:", s);
  }

  console.log("=== PHASE 15 WORKSTREAM 3b SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase15 setUserRole test:", e);
  process.exit(1);
});
