// ============================================================
//  Phase SELLER-HOME-1b — users/{uid}/notifications: owner reads, marks read, deletes; never creates
// ============================================================

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );
  const entry = { title: "New order received", body: "Order 1", type: "seller_new_order", unread: true, data: { actionUrl: "order/1" } };
  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const id of ["n1", "n2", "n3", "n4", "n5"]) await db.doc(`users/u1/notifications/${id}`).set(entry);
    });
    const u1 = testEnv.authenticatedContext("u1").firestore();
    const u2 = testEnv.authenticatedContext("u2").firestore();
    const adminDb = testEnv.authenticatedContext("admin1", { role: "admin", admin: true }).firestore();
    const n = (db, id) => db.doc(`users/u1/notifications/${id}`);

    await record("r1_positive_owner_reads", assertSucceeds(n(u1, "n1").get()));
    await record("r2_negative_other_user_cannot_read", assertFails(n(u2, "n1").get()));
    await record("r3_positive_owner_marks_read_unread_flag", assertSucceeds(n(u1, "n1").update({ unread: false })));
    await record("r4_positive_owner_marks_read_employee_convention", assertSucceeds(n(u1, "n2").update({ read: true, readAt: new Date() })));
    await record("r5_negative_owner_cannot_rewrite_content", assertFails(n(u1, "n3").update({ title: "You won ₹10,000", unread: false })));
    await record("r6_negative_owner_cannot_retarget_link", assertFails(n(u1, "n3").update({ data: { actionUrl: "https://evil" } })));
    await record("r7_negative_owner_cannot_create", assertFails(n(u1, "forged").set(entry)));
    await record("r8_negative_other_user_cannot_create", assertFails(n(u2, "forged2").set(entry)));
    await record("r9_positive_owner_deletes", assertSucceeds(n(u1, "n4").delete()));
    await record("r10_negative_other_user_cannot_mark_read", assertFails(n(u2, "n5").update({ unread: false })));
    await record("r11_positive_admin_creates", assertSucceeds(n(adminDb, "adminmsg").set(entry)));

    console.log("\n=== PHASE SELLER-HOME-1b (inbox rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SELLER-HOME-1b (inbox rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SELLER-HOME-1b (inbox rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
