// Phase AI-1: proves the ai_connections / ai_connection_status rules against
// the real rules engine. ai_connections must be closed to EVERY client,
// including the document's own owner and admin — the encrypted key material
// has no legitimate client-side reader at all. ai_connection_status is the
// separate, client-readable-by-owner projection with no key material.
// Mirrors phase9_wallet_rules_test.js's @firebase/rules-unit-testing pattern.
// Run with: node scripts/phase37b_ai_wallet_rules_test.js
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
  return { ...unprivilegedClaims(email), admin: true };
}

const FAKE_CONNECTION_DOC = {
  uid: "phase37b-owner",
  provider: "gemini",
  encryptedKey: "ZmFrZS1jaXBoZXJ0ZXh0",
  iv: "ZmFrZS1pdg==",
  authTag: "ZmFrZS1hdXRodGFn",
  algorithm: "aes-256-gcm",
};

const FAKE_STATUS_DOC = {
  provider: "gemini",
  connected: true,
};

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};

  try {
    // Seed both documents as the Admin SDK would (bypassing rules), so the
    // read/write scenarios below test against real, existing documents.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("ai_connections").doc("phase37b-owner").set(FAKE_CONNECTION_DOC);
      await db.collection("ai_connection_status").doc("phase37b-owner").set(FAKE_STATUS_DOC);
    });

    // Scenario 1: the owner cannot read their own ai_connections doc — the
    // encrypted key has no legitimate client reader, not even its owner.
    {
      const db = testEnv
        .authenticatedContext("phase37b-owner", unprivilegedClaims("owner@phase37b-test.example"))
        .firestore();
      try {
        await assertFails(db.collection("ai_connections").doc("phase37b-owner").get());
        results.scenario1_owner_cannot_read_connection = "PASSED — owner read of their own ai_connections doc was denied as expected";
      } catch (e) {
        results.scenario1_owner_cannot_read_connection = `FAILED — ${e.message}`;
      }
    }

    // Scenario 2: the owner cannot write their own ai_connections doc.
    {
      const db = testEnv
        .authenticatedContext("phase37b-owner", unprivilegedClaims("owner@phase37b-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("ai_connections").doc("phase37b-owner").set({ ...FAKE_CONNECTION_DOC, provider: "chatgpt" })
        );
        results.scenario2_owner_cannot_write_connection = "PASSED — owner write to their own ai_connections doc was denied as expected";
      } catch (e) {
        results.scenario2_owner_cannot_write_connection = `FAILED — ${e.message}`;
      }
    }

    // Scenario 3: admin ALSO cannot read ai_connections — fully closed, no
    // admin carve-out, unlike wallets/wallet_transactions.
    {
      const db = testEnv
        .authenticatedContext("phase37b-admin", adminClaims("admin@phase37b-test.example"))
        .firestore();
      try {
        await assertFails(db.collection("ai_connections").doc("phase37b-owner").get());
        results.scenario3_admin_cannot_read_connection = "PASSED — admin read of ai_connections was denied as expected (no admin carve-out)";
      } catch (e) {
        results.scenario3_admin_cannot_read_connection = `FAILED — ${e.message}`;
      }
    }

    // Scenario 4 (positive control): the owner CAN read their own
    // ai_connection_status doc — this is the doc the Settings -> AI
    // Integration screen (AI-3) is meant to read.
    {
      const db = testEnv
        .authenticatedContext("phase37b-owner", unprivilegedClaims("owner@phase37b-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("ai_connection_status").doc("phase37b-owner").get());
        results.scenario4_owner_can_read_own_status = "PASSED — owner read of their own ai_connection_status doc succeeded as expected";
      } catch (e) {
        results.scenario4_owner_can_read_own_status = `FAILED — ${e.message}`;
      }
    }

    // Scenario 5: a DIFFERENT authenticated user cannot read someone else's
    // ai_connection_status doc.
    {
      const db = testEnv
        .authenticatedContext("phase37b-other-user", unprivilegedClaims("other@phase37b-test.example"))
        .firestore();
      try {
        await assertFails(db.collection("ai_connection_status").doc("phase37b-owner").get());
        results.scenario5_other_user_cannot_read_status = "PASSED — a different user's read of someone else's status was denied as expected";
      } catch (e) {
        results.scenario5_other_user_cannot_read_status = `FAILED — ${e.message}`;
      }
    }

    // Scenario 6 (positive control): admin CAN read any ai_connection_status
    // doc (matches the wallets/wallet_transactions admin-audit precedent).
    {
      const db = testEnv
        .authenticatedContext("phase37b-admin", adminClaims("admin@phase37b-test.example"))
        .firestore();
      try {
        await assertSucceeds(db.collection("ai_connection_status").doc("phase37b-owner").get());
        results.scenario6_admin_can_read_any_status = "PASSED — admin read of any ai_connection_status doc succeeded as expected";
      } catch (e) {
        results.scenario6_admin_can_read_any_status = `FAILED — ${e.message}`;
      }
    }

    // Scenario 7: the owner cannot write ai_connection_status themselves
    // (e.g. self-granting connected:true without ever paying) — Cloud
    // Functions only, same as ai_connections.
    {
      const db = testEnv
        .authenticatedContext("phase37b-owner", unprivilegedClaims("owner@phase37b-test.example"))
        .firestore();
      try {
        await assertFails(
          db.collection("ai_connection_status").doc("phase37b-owner").set({ provider: "gemini", connected: true })
        );
        results.scenario7_owner_cannot_write_status = "PASSED — owner write to ai_connection_status was denied as expected";
      } catch (e) {
        results.scenario7_owner_cannot_write_status = `FAILED — ${e.message}`;
      }
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("=== PHASE AI-1B (RULES) SUMMARY ===");
  let allPassed = true;
  for (const [k, v] of Object.entries(results)) {
    console.log(`${k}:`, v);
    if (!v.startsWith("PASSED")) allPassed = false;
  }
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase37b AI wallet rules test:", e);
  process.exit(1);
});
