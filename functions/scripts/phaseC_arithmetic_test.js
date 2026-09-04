// Phase C, Workstream 1 — corrected REDEMPTION arithmetic.
// Proves functions/src/customer/productCreditLedger.ts's
// applyEntryToProjection fix against a real emulator: HOLD-then-REDEMPTION
// (settling the hold) nets exactly the amount once, a REDEMPTION with no
// relatedEntryId still decrements available directly, HOLD-then-RELEASE
// fully restores the balance, a negative-balance-producing operation
// throws and writes nothing, and an ADJUSTMENT without metadata.direction
// still throws. Calls appendLedgerEntry directly (it is not a callable) —
// same style as phaseB_accrual_test.js's scenario 9.
// Run with: node scripts/phaseC_arithmetic_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const { appendLedgerEntry, toProjectionFields } = require("../lib/customer/productCreditLedger");

const db = admin.firestore();

function zeroBalanceDoc(available) {
  return { available, pending: 0, onHold: 0, lifetimeEarned: available, lifetimeUsed: 0, lifetimeExpired: 0 };
}

async function seedBalance(customerId, available) {
  await db.collection("product_credit_balances").doc(customerId).set(zeroBalanceDoc(available));
}

async function getBalance(customerId) {
  const snap = await db.collection("product_credit_balances").doc(customerId).get();
  return snap.data() || {};
}

async function appendInTx(customerId, params) {
  return db.runTransaction(async (tx) => {
    const projectionSnap = await tx.get(db.collection("product_credit_balances").doc(customerId));
    const currentProjection = toProjectionFields(projectionSnap.data());
    return appendLedgerEntry(tx, db, { customerId, currentProjection, ...params });
  });
}

async function main() {
  let allPassed = true;
  const results = {};

  // Scenario 1: HOLD 1000 then REDEMPTION 1000 WITH relatedEntryId ->
  // available nets exactly -1000, onHold ends at 0.
  {
    const customerId = "phaseC-arith-cust1";
    await seedBalance(customerId, 2000);
    const holdResult = await appendInTx(customerId, {
      enrollmentId: "enroll1",
      type: "HOLD",
      amount: 1000,
      description: "test hold",
    });
    await appendInTx(customerId, {
      enrollmentId: "enroll1",
      type: "REDEMPTION",
      amount: 1000,
      relatedEntryId: holdResult.entryRef.id,
      description: "test redemption settling the hold",
    });
    const bal = await getBalance(customerId);
    const pass = bal.available === 1000 && bal.onHold === 0;
    results.scenario1_hold_then_redemption_settles_correctly = pass
      ? `PASSED — HOLD 1000 then REDEMPTION 1000 (relatedEntryId) nets available 2000->1000 (-1000), onHold=0`
      : `FAILED — final balance: ${JSON.stringify(bal)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 2: REDEMPTION 1000 with NO relatedEntryId (direct spend) ->
  // available -1000 directly.
  {
    const customerId = "phaseC-arith-cust2";
    await seedBalance(customerId, 2000);
    await appendInTx(customerId, {
      enrollmentId: "enroll1",
      type: "REDEMPTION",
      amount: 1000,
      description: "direct redemption, no prior hold",
    });
    const bal = await getBalance(customerId);
    const pass = bal.available === 1000 && bal.onHold === 0;
    results.scenario2_redemption_without_related_entry_decrements_directly = pass
      ? `PASSED — REDEMPTION 1000 with no relatedEntryId decremented available directly (2000->1000)`
      : `FAILED — final balance: ${JSON.stringify(bal)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 3: HOLD 1000 then RELEASE 1000 -> balance fully restored.
  {
    const customerId = "phaseC-arith-cust3";
    await seedBalance(customerId, 2000);
    const holdResult = await appendInTx(customerId, {
      enrollmentId: "enroll1",
      type: "HOLD",
      amount: 1000,
      description: "hold",
    });
    await appendInTx(customerId, {
      enrollmentId: "enroll1",
      type: "RELEASE",
      amount: 1000,
      relatedEntryId: holdResult.entryRef.id,
      description: "release",
    });
    const bal = await getBalance(customerId);
    const pass = bal.available === 2000 && bal.onHold === 0;
    results.scenario3_hold_then_release_fully_restores_balance = pass
      ? "PASSED — HOLD 1000 then RELEASE 1000 restored available to 2000, onHold=0"
      : `FAILED — final balance: ${JSON.stringify(bal)}`;
    if (!pass) allPassed = false;
  }

  // Scenario 4: a REDEMPTION that would drive available negative throws
  // and writes nothing.
  {
    const customerId = "phaseC-arith-cust4";
    await seedBalance(customerId, 50);
    let threw = false;
    let errorMessage = "";
    try {
      await appendInTx(customerId, {
        enrollmentId: "enroll1",
        type: "REDEMPTION",
        amount: 100,
        description: "over-redeem, no prior hold",
      });
    } catch (e) {
      threw = true;
      errorMessage = e.message;
    }
    const bal = await getBalance(customerId);
    const ledgerSnap = await db
      .collection("product_credit_ledger")
      .where("customerId", "==", customerId)
      .where("type", "==", "REDEMPTION")
      .get();
    const pass = threw && bal.available === 50 && ledgerSnap.empty;
    results.scenario4_negative_balance_redemption_throws_writes_nothing = pass
      ? `PASSED — the operation threw ("${errorMessage}") and nothing was written`
      : `FAILED — threw=${threw}, available=${bal.available}, ledgerCount=${ledgerSnap.size}`;
    if (!pass) allPassed = false;
  }

  // Scenario 5: ADJUSTMENT without metadata.direction still throws.
  {
    const customerId = "phaseC-arith-cust5";
    await seedBalance(customerId, 100);
    let threw = false;
    try {
      await appendInTx(customerId, {
        enrollmentId: "",
        type: "ADJUSTMENT",
        amount: 10,
        description: "bad adjustment, no direction",
        metadata: {},
      });
    } catch (e) {
      threw = true;
    }
    const bal = await getBalance(customerId);
    const pass = threw && bal.available === 100;
    results.scenario5_adjustment_without_direction_throws = pass
      ? "PASSED — an ADJUSTMENT with no metadata.direction was rejected, balance unchanged"
      : `FAILED — threw=${threw}, available=${bal.available}`;
    if (!pass) allPassed = false;
  }

  console.log("=== PHASE C — LEDGER ARITHMETIC TEST ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  console.log(allPassed ? "\nALL PASSED" : "\nSOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phaseC arithmetic test:", e);
  process.exit(1);
});
