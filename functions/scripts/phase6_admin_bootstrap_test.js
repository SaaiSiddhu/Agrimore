// Phase 6, Workstream 1, Step 4: proves the admin-bootstrap-email removal
// against the real (emulated) rules engine — not just by reading the diff.
// Mirrors functions/scripts/phase5b_rules_test.js's pattern exactly.
// Run with: node scripts/phase6_admin_bootstrap_test.js
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

// Real production tokens always have this full claim set (roleClaims.ts's
// buildClaims() always returns role/admin/seller/sellerApproved/
// delivery_partner/deliveryApproved/employee/employeeApproved) — a fake
// token missing any of these makes the rules emulator's CEL evaluator throw
// on undefined property access rather than treating it as falsy. Lesson
// carried over from phase5b_rules_test.js.
function unprivilegedClaims(email) {
  return {
    email,
    role: "user",
    admin: false,
    seller: false,
    sellerApproved: false,
    delivery_partner: false,
    deliveryApproved: false,
    employee: false,
    employeeApproved: false,
  };
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");

  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });

  let scenario1 = "NOT RUN";
  let scenario2 = "NOT RUN";

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      // Target doc: reading someone ELSE's users/{uid} doc requires
      // isAdmin() specifically (isOwner() is trivially false for a
      // different uid) — a clean, minimal isAdmin()-gated path to exercise.
      await db.collection("users").doc("phase6-target-user").set({
        role: "user",
        email: "target@phase6-test.example",
      });

      // Caller 1: a real Firebase Auth user whose email happens to be one of
      // the 3 former bootstrap addresses, but with no admin custom claim and
      // no role:'admin' in their own Firestore doc — i.e. someone who just
      // self-registered with that email and nothing else.
      await db.collection("users").doc("phase6-bootstrap-caller").set({
        role: "user",
        email: "admin@agrimore.com",
      });

      // Caller 2: the legitimate bootstrap path (console-edit style) —
      // role: 'admin' written directly to Firestore, no special email, and
      // (realistically) before syncUserRoleClaims has refreshed their custom
      // claims — this is exactly the window the Firestore-doc fallback in
      // isAdmin() exists to cover.
      await db.collection("users").doc("phase6-legit-admin").set({
        role: "admin",
        email: "legit-admin@phase6-test.example",
      });
    });

    // Scenario 1: bootstrap email, no real admin role anywhere — must be REJECTED.
    const bootstrapEmailDb = testEnv
      .authenticatedContext("phase6-bootstrap-caller", unprivilegedClaims("admin@agrimore.com"))
      .firestore();
    try {
      await bootstrapEmailDb.collection("users").doc("phase6-target-user").get();
      scenario1 =
        "FAILED — a caller whose email is admin@agrimore.com, but who has no real admin role/claim, was able to read another user's document!";
    } catch (e) {
      scenario1 = `PASSED — rejected as expected. code=${e.code} message=${e.message}`;
    }

    // Scenario 2: legitimate role:'admin' in Firestore, ordinary email — must SUCCEED.
    const legitAdminDb = testEnv
      .authenticatedContext("phase6-legit-admin", unprivilegedClaims("legit-admin@phase6-test.example"))
      .firestore();
    try {
      const snap = await legitAdminDb.collection("users").doc("phase6-target-user").get();
      if (!snap.exists) throw new Error("read succeeded but returned doc unexpectedly did not exist");
      scenario2 =
        "PASSED — a caller with Firestore role:'admin' (the legitimate console-edit bootstrap path) could still read another user's document";
    } catch (e) {
      scenario2 = `FAILED — the legitimate admin (Firestore role:'admin', no special email) was rejected: ${e.message}`;
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE 6 — ADMIN BOOTSTRAP-EMAIL REMOVAL TEST ===");
  console.log("Scenario 1 (former bootstrap email, no real admin role, must be REJECTED):", scenario1);
  console.log("Scenario 2 (legitimate Firestore role:'admin', must SUCCEED):", scenario2);

  const allPassed = scenario1.startsWith("PASSED") && scenario2.startsWith("PASSED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running admin bootstrap test:", e);
  process.exit(1);
});
