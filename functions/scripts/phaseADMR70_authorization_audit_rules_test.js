// ADMR-70 — authorization audit, rules layer.
//
// phaseADMR61_support_cases_rules_test.js's own r02 already proves a
// case's own primaryActor cannot read the case about them (CUSTOMER is
// both the non-admin AND the seeded case's own primaryActor in that
// scenario) -- not repeated here. What's genuinely new, since ADMR-65/67
// added linkedRecords AFTER that test was written: does being a LINKED
// record's own actor (not primaryActor) grant any access either? Being
// referenced anywhere in a case's own linkedRecords array must never be
// an access grant.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseADMR70_authorization_audit_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false };
const ADMIN_CLAIMS = { ...base, role: "admin", admin: true };
const ADMIN = "aa-admin", CUSTOMER = "aa-customer", LINKED_SELLER = "aa-linked-seller";

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
  testEnv = await initializeTestEnvironment({
    projectId: "demo-admr70-rules",
    firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) },
  });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.doc(`users/${ADMIN}`).set({ role: "admin" });
    await f.doc(`users/${CUSTOMER}`).set({ role: "user" });
    await f.doc(`sellers/${LINKED_SELLER}`).set({ shopName: "Shop" });
    await f.doc("support_cases/case-linked").set({
      caseId: "case-linked",
      title: "t",
      category: "delivery_issue",
      primaryActor: { type: "customer", id: CUSTOMER },
      // The seller is referenced ONLY via linkedRecords, never as
      // primaryActor -- the exact scenario r02 (ADMR-61) never covered.
      linkedRecords: [{ type: "seller", id: LINKED_SELLER }],
      status: "open",
      version: 1,
    });
  });
  const adm = testEnv.authenticatedContext(ADMIN, ADMIN_CLAIMS).firestore();
  const linkedSeller = testEnv.authenticatedContext(LINKED_SELLER, base).firestore();

  await scenario("aa01_admin_still_reads_the_linked_case", "allow", () =>
    adm.doc("support_cases/case-linked").get());
  await scenario(
    "aa02_being_referenced_only_via_linkedRecords_grants_no_read_access_at_all",
    "deny",
    () => linkedSeller.doc("support_cases/case-linked").get()
  );
  await scenario(
    "aa03_a_linked_actor_cannot_write_to_the_case_either",
    "deny",
    () => linkedSeller.doc("support_cases/case-linked").update({ status: "resolved" })
  );

  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR70 rules: FAILED"); process.exit(1); }
  console.log("PHASE ADMR70 rules: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
