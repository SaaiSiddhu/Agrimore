// ADMR-61 — firestore.rules for the new unified support case collections
// (support_cases / support_case_notes / support_case_events): admin-only
// read, no client writes at all (every mutation goes through the
// callables in functions/src/admin/supportCases.ts, Admin SDK, bypasses
// rules) -- matching every other admin-mutated collection in this file.
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseADMR61_support_cases_rules_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");

const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":");
const base = { admin: false, seller: false, delivery_partner: false, employee: false };
const ADMIN_CLAIMS = { ...base, role: "admin", admin: true };
const ADMIN = "sc-admin", CUSTOMER = "sc-customer";

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
  testEnv = await initializeTestEnvironment({ projectId: "demo-admr61-rules", firestore: { rules, host: EMU_HOST, port: Number(EMU_PORT) } });
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await f.doc(`users/${ADMIN}`).set({ role: "admin" });
    await f.doc(`users/${CUSTOMER}`).set({ role: "user" });
    await f.doc("support_cases/case-1").set({
      caseId: "case-1", title: "t", category: "delivery_issue",
      primaryActor: { type: "customer", id: CUSTOMER }, status: "open", version: 1,
    });
    await f.doc("support_case_notes/note-1").set({ noteId: "note-1", caseId: "case-1", authorUid: ADMIN, text: "n" });
    await f.doc("support_case_events/event-1").set({ caseId: "case-1", type: "created", actorUid: ADMIN });
  });
  const adm = testEnv.authenticatedContext(ADMIN, ADMIN_CLAIMS).firestore();
  const cust = testEnv.authenticatedContext(CUSTOMER, base).firestore();
  const anon = testEnv.unauthenticatedContext().firestore();

  await scenario("r01_admin_reads_case", "allow", () => adm.doc("support_cases/case-1").get());
  await scenario("r02_non_admin_cannot_read_case", "deny", () => cust.doc("support_cases/case-1").get());
  await scenario("r03_unauthenticated_cannot_read_case", "deny", () => anon.doc("support_cases/case-1").get());
  await scenario("r04_admin_cannot_write_case_directly", "deny", () => adm.doc("support_cases/case-1").update({ status: "resolved" }));
  await scenario("r05_non_admin_cannot_create_case", "deny", () => cust.doc("support_cases/case-2").set({ caseId: "case-2", status: "open" }));

  await scenario("r06_admin_reads_note", "allow", () => adm.doc("support_case_notes/note-1").get());
  await scenario("r07_non_admin_cannot_read_note", "deny", () => cust.doc("support_case_notes/note-1").get());
  await scenario("r08_admin_cannot_write_note_directly", "deny", () => adm.doc("support_case_notes/note-1").update({ text: "edited" }));
  await scenario("r09_non_admin_cannot_create_note", "deny", () => cust.doc("support_case_notes/note-2").set({ caseId: "case-1", text: "forged" }));

  await scenario("r10_admin_reads_event", "allow", () => adm.doc("support_case_events/event-1").get());
  await scenario("r11_non_admin_cannot_read_event", "deny", () => cust.doc("support_case_events/event-1").get());
  await scenario("r12_admin_cannot_write_event_directly", "deny", () => adm.doc("support_case_events/event-1").update({ type: "forged" }));
  await scenario("r13_non_admin_cannot_forge_event",
    "deny", () => cust.doc("support_case_events/event-2").set({ caseId: "case-1", type: "resolved", actorUid: CUSTOMER, at: serverTimestamp() }));

  await testEnv.cleanup();
  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR61 rules: FAILED"); process.exit(1); }
  console.log("PHASE ADMR61 rules: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
