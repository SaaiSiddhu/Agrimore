// Phase DLVH9 — real-emulator proof for the orders(deliveryPartnerId, orderNumber)
// composite index DLVH7 added to firestore.indexes.json, and for the security
// rule that actually protects it. Never previously run against a live Firestore:
// DLVH7's own claim reasoned about Firestore's documented indexing rules but
// never executed the query for real. This closes that gap.
//
// IMPORTANT scope, not to be overstated: this proves the QUERY is correct and
// that firestore.rules already scopes it to the requesting rider. It does NOT
// prove the production composite index is deployed — the emulator is known to
// be lenient about missing composite indexes in ways production is not. That
// is a separate fact (see firestore:indexes deploy status, checked read-only,
// never run by this session).
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLVH9_search_index_test.js"
// Honours FIRESTORE_EMULATOR_HOST (set by emulators:exec), falling back to 127.0.0.1:8080.
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const CLAIMS = {
  delivery: { ...base, role: "delivery_partner", delivery_partner: true },
};
const R1 = "dlvh9-r1", R2 = "dlvh9-r2";

let testEnv;
const results = [];
async function scenario(label, fn) {
  try {
    await fn();
    results.push({ label, pass: true });
    console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push({ label, pass: false });
    console.log(`FAILED — ${label} :: ${String(e.message || e).slice(0, 200)}`);
  }
}
const db = (uid) => testEnv.authenticatedContext(uid, CLAIMS.delivery).firestore();

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "demo-dlvh9-search",
    firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) },
  });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    for (const r of [R1, R2]) {
      await f.doc(`users/${r}`).set({ role: "delivery_partner" });
      await f.doc(`delivery_partners/${r}`).set({ status: "approved" });
    }
    // Two orders for R1 (distinct orderNumbers), one for R2 -- the exact
    // shape firestoreOrderBySearchId queries: deliveryPartnerId + orderNumber.
    await f.doc("orders/o-r1-a").set({ userId: "cust-1", deliveryPartnerId: R1, orderNumber: "AGM-100", orderStatus: "delivered", total: 100 });
    await f.doc("orders/o-r1-b").set({ userId: "cust-1", deliveryPartnerId: R1, orderNumber: "AGM-101", orderStatus: "cancelled", total: 50 });
    await f.doc("orders/o-r2-a").set({ userId: "cust-2", deliveryPartnerId: R2, orderNumber: "AGM-200", orderStatus: "delivered", total: 75 });
  });

  const r1 = db(R1);

  console.log("=== PHASE DLVH9 — orders(deliveryPartnerId, orderNumber) search, real emulator ===");

  await scenario("R1 finds their own order by its exact orderNumber", async () => {
    const snap = await assertSucceeds(
      r1.collection("orders").where("deliveryPartnerId", "==", R1).where("orderNumber", "==", "AGM-100").limit(1).get()
    );
    if (snap.docs.length !== 1 || snap.docs[0].id !== "o-r1-a") {
      throw new Error(`expected exactly o-r1-a, got ${snap.docs.map((d) => d.id).join(",")}`);
    }
  });

  await scenario("R1 searching for R2's own orderNumber (scoped by their own deliveryPartnerId) returns nothing, not an error, not R2's data", async () => {
    const snap = await assertSucceeds(
      r1.collection("orders").where("deliveryPartnerId", "==", R1).where("orderNumber", "==", "AGM-200").limit(1).get()
    );
    if (snap.docs.length !== 0) throw new Error(`expected 0 docs, got ${snap.docs.length}`);
  });

  await scenario("R1 cannot read R2's order directly, even knowing its exact document id (the rule protects it, not just the query shape)", async () => {
    await assertFails(r1.collection("orders").doc("o-r2-a").get());
  });

  await scenario("a non-existent orderNumber for R1's own account returns an empty page (not found), not an error", async () => {
    const snap = await assertSucceeds(
      r1.collection("orders").where("deliveryPartnerId", "==", R1).where("orderNumber", "==", "DOES-NOT-EXIST").limit(1).get()
    );
    if (snap.docs.length !== 0) throw new Error(`expected 0 docs, got ${snap.docs.length}`);
  });

  const passed = results.filter((r) => r.pass).length;
  console.log(`\n${passed}/${results.length} passed`);
  if (passed !== results.length) process.exit(1);
}

main().then(() => testEnv.cleanup()).catch((e) => {
  console.error(e);
  process.exit(1);
});
