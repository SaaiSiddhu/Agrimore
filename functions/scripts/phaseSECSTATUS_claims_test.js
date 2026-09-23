// ============================================================
//  Phase SEC-STATUSCASE — a case variant of "approved" never grants a role claim
// ============================================================
//
// firestore.rules stop an owner writing the exact string 'approved' into
// users.sellerStatus / deliveryStatus / employeeStatus and sellers|
// delivery_partners|employees/{uid}.status — but roleClaims.ts compared
// case-insensitively after trimming, so "Approved" or " approved " (which the
// rules allow) re-granted the claim. A suspended seller keeps role 'seller',
// so they could un-suspend themselves. This suite proves both halves:
// the rules accept the variant write (so the server must not trust it) and
// buildClaims() grants nothing for it.
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSECSTATUS_claims_test.js"
// buildClaims() only READS Firestore; nothing here calls Auth.

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { buildClaims } = require("../lib/admin/roleClaims");

async function main() {
  const db = admin.firestore();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };

  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({ projectId: "agrimore-66a4e", firestore: { rules, host: "127.0.0.1", port: 8080 } });

  try {
    // A suspended seller: role stays 'seller', status is 'suspended'.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await d.doc("users/sus1").set({ role: "seller", sellerStatus: "suspended" });
      await d.doc("sellers/sus1").set({ status: "suspended", shopName: "S" });
      await d.doc("users/sus2").set({ role: "seller", sellerStatus: "suspended" });
      await d.doc("sellers/sus2").set({ status: "suspended" });
      await d.doc("users/rider1").set({ role: "delivery_partner", deliveryStatus: "suspended" });
      await d.doc("users/emp1").set({ role: "employee", employeeStatus: "suspended" });
      await d.doc("users/ok1").set({ role: "seller", sellerStatus: "approved" });
    });
    const as = (uid) => testEnv.authenticatedContext(uid).firestore();

    await check("c1_rules_let_an_owner_write_a_case_variant_on_users", async () => {
      // Documents why the server must be exact: these users/* writes are allowed.
      await assertSucceeds(as("sus1").doc("users/sus1").update({ sellerStatus: "Approved" }));
      await assertSucceeds(as("rider1").doc("users/rider1").update({ deliveryStatus: "Approved" }));
      await assertSucceeds(as("emp1").doc("users/emp1").update({ employeeStatus: "approved " }));
    });

    await check("c1b_sellers_status_is_no_longer_owner_writable", async () => {
      // SELLER-STOREFRONT-EDIT-1's allow-list removed status from the owner's
      // sellers/{uid} keys, so this variant write is now denied outright.
      await assertFails(as("sus2").doc("sellers/sus2").update({ status: " APPROVED " }));
      // Seed the variant directly so c3 still proves the server ignores it.
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().doc("sellers/sus2").update({ status: " APPROVED " });
      });
    });

    await check("c2_user_doc_variant_grants_no_seller_claim", async () => {
      const c = await buildClaims("sus1");
      expect(c && c.seller === false && c.sellerApproved === false, JSON.stringify(c));
    });

    await check("c3_seller_doc_variant_grants_no_seller_claim", async () => {
      const c = await buildClaims("sus2");
      expect(c && c.seller === false, JSON.stringify(c));
    });

    await check("c4_delivery_variant_grants_no_claim", async () => {
      const c = await buildClaims("rider1");
      expect(c && c.delivery_partner === false, JSON.stringify(c));
    });

    await check("c5_employee_variant_grants_no_claim", async () => {
      const c = await buildClaims("emp1");
      expect(c && c.employee === false, JSON.stringify(c));
    });

    await check("c6_exact_approved_still_grants", async () => {
      const c = await buildClaims("ok1");
      expect(c && c.seller === true, JSON.stringify(c));
    });
  } finally {
    await testEnv.cleanup();
  }

  console.log("\n=== PHASE SEC-STATUSCASE SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SEC-STATUSCASE: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SEC-STATUSCASE: ALL PASSED");
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
