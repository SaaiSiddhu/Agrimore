// Phase DLV-M1 — firestore.rules: the admin client paid-transition on
// rider_payouts is refused while the rider has a payout-detail change pending
// (rider_accounts.bankChangePending), so an older admin client cannot pay a
// stale destination either. markRiderPayoutPaid is the callable path.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLVM1_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp, Timestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const ADMIN_CLAIMS = { ...base, role: "admin", admin: true };
const RIDER_CLAIMS = { ...base, role: "delivery_partner", delivery_partner: true };
const CLEAN = "dlvm1-clean", HELD = "dlvm1-held", CLEARED = "dlvm1-cleared", ADMIN = "dlvm1-admin";

let testEnv;
const results = [];
async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    results.push(true); console.log(`PASSED — ${label}`);
  } catch (e) {
    results.push(false); console.log(`FAILED — ${label} :: expected ${expect} — ${String(e.message || e).slice(0, 160)}`);
  }
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({ projectId: "demo-dlvm1-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.doc(`users/${ADMIN}`).set({ role: "admin" });
    const accounts = { [CLEAN]: {}, [HELD]: { bankChangePending: "req-1" }, [CLEARED]: { bankChangePending: null } };
    for (const [r, extra] of Object.entries(accounts)) {
      await f.doc(`users/${r}`).set({ role: "delivery_partner" });
      await f.doc(`rider_accounts/${r}`).set({ riderId: r, cashHeldPaise: 0, ...extra });
      await f.doc(`rider_payouts/${r}_p`).set({ riderId: r, weekKey: "2026-W39", amount: 100, amountPaise: 10000, status: "pending" });
    }
  });
  const adm = testEnv.authenticatedContext(ADMIN, ADMIN_CLAIMS).firestore();
  const paid = () => ({ status: "paid", paidAt: Timestamp.now(), paymentReference: "UTR123456", paidBy: ADMIN, payoutMethod: "bank", updatedAt: serverTimestamp() });
  await scenario("g01_pays_when_no_change_ever_requested", "allow", () => adm.doc(`rider_payouts/${CLEAN}_p`).update(paid()));
  await scenario("g02_refused_while_a_change_is_pending", "deny", () => adm.doc(`rider_payouts/${HELD}_p`).update(paid()));
  await scenario("g03_pays_after_the_change_was_reviewed", "allow", () => adm.doc(`rider_payouts/${CLEARED}_p`).update(paid()));
  const rider = testEnv.authenticatedContext(HELD, RIDER_CLAIMS).firestore();
  await scenario("g04_rider_cannot_clear_own_pending_flag", "deny", () => rider.doc(`rider_accounts/${HELD}`).update({ bankChangePending: null }));

  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-M1 rules: FAILED"); process.exit(1); }
  console.log("PHASE DLV-M1 rules: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
