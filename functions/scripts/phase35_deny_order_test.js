// Phase FIX-13 — proves a delivery partner's order rejection actually
// persists (finding N-24): deliveryPartnerCanDenyUnassignedOrder() lets an
// approved partner append ONLY their own uid to deliveryRejectedBy on a
// still-unassigned order, and nothing else.
//
// Mirrors phase5b_rules_test.js's/phase24's @firebase/rules-unit-testing
// pattern.
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase35_deny_order_test.js"
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

function baseClaims() {
  return { admin: false, seller: false, delivery_partner: false, employee: false };
}
const CLAIMS = {
  user: { ...baseClaims(), role: "user" },
  delivery: { ...baseClaims(), role: "delivery_partner", delivery_partner: true },
};

let testEnv;
const results = [];
function record(label, pass, detail) {
  results.push({ label, pass, detail });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}

async function scenario(label, expect, fn) {
  try {
    await (expect === "allow" ? assertSucceeds(fn()) : assertFails(fn()));
    record(label, true, "");
  } catch (e) {
    record(label, false, `expected ${expect} — ${String(e.message || e).slice(0, 200)}`);
  }
}

function ctx(kind, uid) {
  return testEnv.authenticatedContext(uid, CLAIMS[kind]).firestore();
}

async function seedOrder(id, extra = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("orders").doc(id).set({
      userId: "phase35-customer",
      sellerId: "phase35-seller",
      orderStatus: "ready_for_pickup",
      status: "ready_for_pickup",
      total: 500,
      ...extra,
    });
  });
}

async function readOrder(id) {
  let data;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await context.firestore().collection("orders").doc(id).get();
    data = snap.data();
  });
  return data;
}

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  console.log("=== PHASE FIX-13 — deny order actually persists (N-24) ===");

  const P1 = "phase35-partner-1";
  const P2 = "phase35-partner-2";

  // 1 — THE FIX: an approved partner can append their own uid to
  // deliveryRejectedBy on an unassigned order.
  {
    const oid = "phase35-o1";
    await seedOrder(oid);
    await scenario("s1_partner_can_deny_an_unassigned_order", "allow", () =>
      ctx("delivery", P1).collection("orders").doc(oid).set(
        { deliveryRejectedBy: [P1], updatedAt: new Date() },
        { merge: true }
      )
    );
    const after = await readOrder(oid);
    record("s1b_the_write_actually_persisted", Array.isArray(after.deliveryRejectedBy) && after.deliveryRejectedBy.includes(P1),
      `deliveryRejectedBy=${JSON.stringify(after.deliveryRejectedBy)}`);
  }

  // 2 — a repeat deny by the SAME partner (already present) is a no-op,
  // not a forced duplicate — must still succeed.
  {
    const oid = "phase35-o2";
    await seedOrder(oid, { deliveryRejectedBy: [P1] });
    await scenario("s2_repeat_deny_by_the_same_partner_still_succeeds", "allow", () =>
      ctx("delivery", P1).collection("orders").doc(oid).set(
        { deliveryRejectedBy: [P1], updatedAt: new Date() },
        { merge: true }
      )
    );
  }

  // 3 — a partner CANNOT union ANOTHER partner's uid into the array.
  {
    const oid = "phase35-o3";
    await seedOrder(oid);
    await scenario("s3_partner_cannot_union_someone_elses_uid", "deny", () =>
      ctx("delivery", P1).collection("orders").doc(oid).set(
        { deliveryRejectedBy: [P2], updatedAt: new Date() },
        { merge: true }
      )
    );
  }

  // 4 — a partner cannot touch any OTHER field while denying.
  {
    const oid = "phase35-o4";
    await seedOrder(oid);
    await scenario("s4_partner_cannot_touch_another_field_while_denying", "deny", () =>
      ctx("delivery", P1).collection("orders").doc(oid).set(
        { deliveryRejectedBy: [P1], updatedAt: new Date(), orderStatus: "delivered" },
        { merge: true }
      )
    );
  }

  // 5 — a partner cannot deny an ALREADY-ASSIGNED order this way (that is
  // the assigned partner's own fulfilment branch's job, not this one's).
  {
    const oid = "phase35-o5";
    await seedOrder(oid, { deliveryPartnerId: P2 });
    await scenario("s5_cannot_deny_an_already_assigned_order_via_this_branch", "deny", () =>
      ctx("delivery", P1).collection("orders").doc(oid).set(
        { deliveryRejectedBy: [P1], updatedAt: new Date() },
        { merge: true }
      )
    );
  }

  // 6 — a plain (non-delivery-partner) user cannot deny at all.
  {
    const oid = "phase35-o6";
    await seedOrder(oid);
    await scenario("s6_plain_user_cannot_deny", "deny", () =>
      ctx("user", "phase35-random-user").collection("orders").doc(oid).set(
        { deliveryRejectedBy: ["phase35-random-user"], updatedAt: new Date() },
        { merge: true }
      )
    );
  }

  await testEnv.cleanup();

  console.log("\n=== SUMMARY ===");
  const passed = results.filter((r) => r.pass).length;
  console.log(`${passed}/${results.length} scenarios passed`);
  if (passed !== results.length) { console.error("PHASE 35: FAILED"); process.exit(1); }
  console.log("PHASE 35: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 35: harness error", e); process.exit(1); });
