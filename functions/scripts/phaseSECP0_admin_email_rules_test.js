// ============================================================
//  Phase SEC-P0 — isAdmin() email allowlist must require a VERIFIED email
// ============================================================
//
// Commit 9e77189 (2026-09-22) added an email allowlist to isAdmin() that
// trusted request.auth.token.email with no email_verified check. Email/
// password sign-up is enabled on this project, so anyone could register an
// allow-listed address they do not own (one not yet registered in Auth) and
// receive full admin over Firestore.
//
// This suite proves:
//   - the exploit (allow-listed email, email_verified == false) is DENIED
//   - positive controls: the same email VERIFIED, and a real admin claim,
//     are ALLOWED — so the fix does not lock out legitimate admins
//   - a non-listed verified email is DENIED
//   - auth_test_mode/* and auth_test_mode_log/* are unreachable by every
//     client, admin included (Console / Admin SDK only)
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSECP0_admin_email_rules_test.js"

const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

const LISTED_EMAIL = "admin@agrimore.in"; // one of the four addresses in isAdmin()

function claims(email, emailVerified, extra = {}) {
  return {
    email,
    email_verified: emailVerified,
    role: "user",
    admin: false,
    ...extra,
  };
}

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

  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("logs").doc("secp0-log").set({ message: "admin-only" });
      await db.collection("auth_test_mode").doc("config").set({ enabled: false });
      await db.collection("auth_test_mode_log").doc("l1").set({ phone: "+91•••" });
      // The attacker's own users doc: role 'user', so the users/{uid}.role
      // fallback inside isAdmin() cannot be what grants access.
      await db.collection("users").doc("secp0-attacker").set({ role: "user" });
      await db.collection("users").doc("secp0-verified").set({ role: "user" });
      await db.collection("users").doc("secp0-claim-admin").set({ role: "user" });
      await db.collection("users").doc("secp0-other").set({ role: "user" });
    });

    const attacker = testEnv.authenticatedContext("secp0-attacker", claims(LISTED_EMAIL, false)).firestore();
    const verified = testEnv.authenticatedContext("secp0-verified", claims(LISTED_EMAIL, true)).firestore();
    const claimAdmin = testEnv
      .authenticatedContext("secp0-claim-admin", claims("someone@example.com", true, { admin: true, role: "admin" }))
      .firestore();
    const other = testEnv.authenticatedContext("secp0-other", claims("random@example.com", true)).firestore();
    const unverifiedUpper = testEnv
      .authenticatedContext("secp0-attacker", claims(LISTED_EMAIL.toUpperCase(), false))
      .firestore();

    // --- the exploit ---
    await record("s1_negative_unverified_listed_email_cannot_read_admin_only",
      assertFails(attacker.collection("logs").doc("secp0-log").get()));
    await record("s1b_negative_unverified_listed_email_uppercase_cannot_read_admin_only",
      assertFails(unverifiedUpper.collection("logs").doc("secp0-log").get()));
    await record("s1c_negative_unverified_listed_email_cannot_write_settings",
      assertFails(attacker.collection("settings").doc("secp0").set({ x: 1 })));

    // --- positive controls: legitimate admins keep access ---
    await record("s2_positive_verified_listed_email_reads_admin_only",
      assertSucceeds(verified.collection("logs").doc("secp0-log").get()));
    await record("s3_positive_admin_claim_reads_admin_only",
      assertSucceeds(claimAdmin.collection("logs").doc("secp0-log").get()));

    // --- a verified but non-listed email is not admin ---
    await record("s4_negative_verified_unlisted_email_cannot_read_admin_only",
      assertFails(other.collection("logs").doc("secp0-log").get()));

    // --- test-mode config and log: no client, not even an admin ---
    await record("s5_negative_admin_cannot_read_test_mode_config",
      assertFails(claimAdmin.collection("auth_test_mode").doc("config").get()));
    await record("s5b_negative_admin_cannot_write_test_mode_config",
      assertFails(claimAdmin.collection("auth_test_mode").doc("config").set({ enabled: true })));
    await record("s5c_negative_user_cannot_read_test_mode_config",
      assertFails(other.collection("auth_test_mode").doc("config").get()));
    await record("s6_negative_admin_cannot_read_test_mode_log",
      assertFails(claimAdmin.collection("auth_test_mode_log").doc("l1").get()));
    await record("s6b_negative_user_cannot_create_test_mode_log",
      assertFails(other.collection("auth_test_mode_log").doc("l2").set({ phone: "x" })));

    console.log("\n=== PHASE SEC-P0 (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    if (passed !== total) { console.error("PHASE SEC-P0 (rules): FAILED"); process.exitCode = 1; }
    else console.log("PHASE SEC-P0 (rules): ALL PASSED");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error("PHASE SEC-P0 (rules): harness error", e);
  process.exit(1);
});
