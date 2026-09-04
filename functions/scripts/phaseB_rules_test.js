// Phase B — Customer Product Benefit Program ledger & accrual engine.
// Proves the five new firestore.rules blocks (benefit_programs,
// benefit_enrollments, benefit_accruals, product_credit_ledger,
// product_credit_balances) against the real rules engine. Mirrors
// phaseA_rules_test.js's @firebase/rules-unit-testing pattern exactly.
// Run with: node scripts/phaseB_rules_test.js
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

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

function adminClaims(email) {
  return { ...unprivilegedClaims(email), role: "admin", admin: true };
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};
  const owner = "phaseB-rules-owner";
  const nonOwner = "phaseB-rules-nonowner";
  const admin = "phaseB-rules-admin";

  try {
    // Seed one document in each of the five collections, owned by `owner`.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("benefit_programs").doc("prog1").set({ name: "Test Program", status: "active" });
      await db.collection("benefit_enrollments").doc("enroll1").set({ customerId: owner, programId: "prog1", status: "active" });
      await db.collection("benefit_accruals").doc("enroll1_2026-08").set({ customerId: owner, enrollmentId: "enroll1", period: "2026-08" });
      await db.collection("product_credit_ledger").doc("entry1").set({ customerId: owner, enrollmentId: "enroll1", type: "CREDIT", amount: 100 });
      await db.collection("product_credit_balances").doc(owner).set({ available: 100 });
    });

    const nonOwnerDb = testEnv.authenticatedContext(nonOwner, unprivilegedClaims("nonowner@phaseB-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext(admin, adminClaims("admin@phaseB-test.example")).firestore();
    const ownerDb = testEnv.authenticatedContext(owner, unprivilegedClaims("owner@phaseB-test.example")).firestore();

    // ============================================
    // 1-5 — a non-owner authenticated client cannot read
    // ============================================
    const readTargets = [
      ["benefit_programs", "prog1", "r1"],
      ["benefit_enrollments", "enroll1", "r2"],
      ["benefit_accruals", "enroll1_2026-08", "r3"],
      ["product_credit_ledger", "entry1", "r4"],
      ["product_credit_balances", owner, "r5"],
    ];
    for (const [collection, docId, key] of readTargets) {
      try {
        await assertFails(nonOwnerDb.collection(collection).doc(docId).get());
        results[`${key}_nonowner_cannot_read_${collection}`] =
          `PASSED — a non-owner authenticated client cannot read ${collection}`;
      } catch (e) {
        results[`${key}_nonowner_cannot_read_${collection}`] = `FAILED — non-owner read succeeded: ${e.message}`;
      }
    }

    // ============================================
    // 6-10 — an ADMIN client cannot write directly
    // ============================================
    const writeTargets = [
      ["benefit_programs", "prog1", { name: "Hijacked" }, "w1"],
      ["benefit_enrollments", "enroll1", { status: "completed" }, "w2"],
      ["benefit_accruals", "enroll1_2026-08", { calculatedAmount: 999999 }, "w3"],
      ["product_credit_ledger", "entry1", { amount: 999999 }, "w4"],
      ["product_credit_balances", owner, { available: 999999 }, "w5"],
    ];
    for (const [collection, docId, patch, key] of writeTargets) {
      try {
        await assertFails(adminDb.collection(collection).doc(docId).set(patch, { merge: true }));
        results[`${key}_admin_cannot_write_${collection}`] =
          `PASSED — an admin client cannot write ${collection} directly`;
      } catch (e) {
        results[`${key}_admin_cannot_write_${collection}`] = `FAILED — direct admin write succeeded: ${e.message}`;
      }
    }

    // ============================================
    // 11 — an owner CAN read their own ledger entry / balance / enrollment
    // ============================================
    try {
      await assertSucceeds(ownerDb.collection("product_credit_ledger").doc("entry1").get());
      await assertSucceeds(ownerDb.collection("product_credit_balances").doc(owner).get());
      await assertSucceeds(ownerDb.collection("benefit_enrollments").doc("enroll1").get());
      results.r11_owner_can_read_own_records = "PASSED — the owner can read their own ledger entry, balance, and enrollment";
    } catch (e) {
      results.r11_owner_can_read_own_records = `FAILED — owner read was rejected: ${e.message}`;
    }

    // ============================================
    // 12 — nobody can update or delete a ledger entry (append-only proof)
    // ============================================
    try {
      await assertFails(adminDb.collection("product_credit_ledger").doc("entry1").update({ amount: 1 }));
      results.r12a_admin_cannot_update_ledger_entry = "PASSED — an admin cannot update an existing ledger entry";
    } catch (e) {
      results.r12a_admin_cannot_update_ledger_entry = `FAILED — an admin updated a ledger entry: ${e.message}`;
    }
    try {
      await assertFails(adminDb.collection("product_credit_ledger").doc("entry1").delete());
      results.r12b_admin_cannot_delete_ledger_entry = "PASSED — an admin cannot delete an existing ledger entry";
    } catch (e) {
      results.r12b_admin_cannot_delete_ledger_entry = `FAILED — an admin deleted a ledger entry: ${e.message}`;
    }
    try {
      await assertFails(ownerDb.collection("product_credit_ledger").doc("entry1").update({ amount: 1 }));
      results.r12c_owner_cannot_update_own_ledger_entry = "PASSED — the owner cannot update their own ledger entry";
    } catch (e) {
      results.r12c_owner_cannot_update_own_ledger_entry = `FAILED — the owner updated their own ledger entry: ${e.message}`;
    }
    try {
      await assertFails(ownerDb.collection("product_credit_ledger").doc("entry1").delete());
      results.r12d_owner_cannot_delete_own_ledger_entry = "PASSED — the owner cannot delete their own ledger entry";
    } catch (e) {
      results.r12d_owner_cannot_delete_own_ledger_entry = `FAILED — the owner deleted their own ledger entry: ${e.message}`;
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE B — LEDGER/ACCRUAL RULES TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);

  const allPassed = Object.values(results).every((v) => v.startsWith("PASSED"));
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseB rules test:", e);
  process.exit(1);
});
