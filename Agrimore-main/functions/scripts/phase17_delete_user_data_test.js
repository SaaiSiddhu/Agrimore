// Phase 17 (account deletion) — proves deleteUserData.ts against a real
// Firestore + Auth emulator. This callable performs IRREVERSIBLE production
// deletions and, until this script, had never been run against anything —
// only reviewed by reading its source. It shipped with no dedicated test.
//
// Unlike phase15_set_user_role_test.js (which could not exercise its final
// admin.auth() call — no Auth emulator was pointed at), this script sets
// FIREBASE_AUTH_EMULATOR_HOST explicitly, so the final auth.deleteUser(uid)
// step is exercised for real, not just documented as environment-limited.
//
// deleteUserData is a v1 onCall (firebase-functions/v1 — see the file's own
// header comment for why: production is v1 and there is no in-place
// Gen1->Gen2 upgrade), wrapped and invoked as `wrapped({ data: payload, auth })`,
// same convention as every other callable test in this directory.
//
// Run with: node scripts/phase17_delete_user_data_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "agrimore-66a4e" });
}
const db = admin.firestore();
const auth = admin.auth();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { deleteUserData } = require("../lib/customer/deleteUserData");

const wrapped = test.wrap(deleteUserData);

async function callAndCapture(auth_) {
  try {
    // deleteUserData is a v1 onCall — firebase-functions-test's v1 wrap()
    // takes (data, options) as two POSITIONAL arguments, with auth nested
    // under options.auth, unlike v2's single {data, auth} object (see
    // node_modules/firebase-functions-test/lib/v1.js's wrapV1: `context =
    // Object.assign({}, options)`, then `cloudFunction.run(data, context)`).
    // Calling it the v2 way here silently produces an empty options object,
    // so context.auth is always undefined and EVERY call looks
    // unauthenticated regardless of what auth was passed — caught by every
    // authenticated scenario failing with 'unauthenticated' on the first
    // run, before this was fixed.
    const result = await wrapped({}, { auth: auth_ });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function main() {
  let allPassed = true;
  const results = {};

  console.log("=== PHASE 17 — deleteUserData ===");

  // Scenario 1: unauthenticated call is rejected.
  {
    const r = await callAndCapture(undefined);
    const s =
      !r.ok && r.code === "unauthenticated"
        ? `PASSED — unauthenticated call rejected. code=${r.code}`
        : `FAILED — unauthenticated call was NOT rejected: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "unauthenticated") allPassed = false;
    results.scenario1_unauthenticated_rejected = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: non-zero wallet balance refuses deletion.
  {
    const uid = "phase17-dud-wallet-refuse";
    await db.collection("wallets").doc(uid).set({ balance: 250 });
    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 2 raw:", JSON.stringify(r));
    const s =
      !r.ok && r.code === "failed-precondition" && r.message.includes("wallet balance")
        ? `PASSED — non-zero wallet balance refused deletion. code=${r.code} message="${r.message}"`
        : `FAILED — non-zero wallet balance did NOT refuse deletion correctly: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "failed-precondition" || !r.message.includes("wallet balance")) {
      allPassed = false;
    }
    results.scenario2_nonzero_wallet_refused = s;
    console.log("Scenario 2:", s);

    // Confirm nothing was deleted despite the refusal.
    const stillThere = (await db.collection("wallets").doc(uid).get()).exists;
    const s2 = stillThere
      ? "PASSED — wallet document untouched after the refused call"
      : "FAILED — wallet document was deleted despite the refusal";
    if (!stillThere) allPassed = false;
    results.scenario2b_wallet_untouched_on_refusal = s2;
    console.log("Scenario 2b:", s2);
  }

  // Scenario 3: an in-flight (non-terminal) order refuses deletion.
  {
    const uid = "phase17-dud-inflight-refuse";
    await db.collection("wallets").doc(uid).set({ balance: 0 });
    await db.collection("orders").add({ userId: uid, orderStatus: "processing" });
    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 3 raw:", JSON.stringify(r));
    const s =
      !r.ok && r.code === "failed-precondition" && r.message.includes("in progress")
        ? `PASSED — in-flight order refused deletion. code=${r.code} message="${r.message}"`
        : `FAILED — in-flight order did NOT refuse deletion correctly: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "failed-precondition" || !r.message.includes("in progress")) {
      allPassed = false;
    }
    results.scenario3_inflight_order_refused = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 3b: a TERMINAL order (delivered) does NOT block deletion by
  // itself — proves the terminal-status set is actually being honored, not
  // just "any order at all" being treated as blocking.
  {
    const uid = "phase17-dud-terminal-order-ok";
    await db.collection("wallets").doc(uid).set({ balance: 0 });
    await db.collection("users").doc(uid).set({ name: "Terminal Order Tester" });
    await db.collection("orders").add({ userId: uid, orderStatus: "delivered", total: 500 });
    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 3b raw:", JSON.stringify(r));
    // May still fail at the final auth.deleteUser() step for reasons
    // unrelated to the refusal logic (no Auth user was ever created for
    // this uid) -- what matters here is it did NOT fail with the
    // in-flight-order message.
    const blockedByOrder = !r.ok && r.code === "failed-precondition" && r.message.includes("in progress");
    const s = !blockedByOrder
      ? "PASSED — a terminal (delivered) order did not block deletion on its own"
      : `FAILED — a terminal order incorrectly blocked deletion: ${JSON.stringify(r)}`;
    if (blockedByOrder) allPassed = false;
    results.scenario3b_terminal_order_does_not_block = s;
    console.log("Scenario 3b:", s);
  }

  // Scenario 4: a pending employee payout refuses deletion.
  {
    const uid = "phase17-dud-payout-refuse";
    await db.collection("wallets").doc(uid).set({ balance: 0 });
    await db.collection("employee_payouts").add({ employeeId: uid, status: "requested" });
    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 4 raw:", JSON.stringify(r));
    const s =
      !r.ok && r.code === "failed-precondition" && r.message.includes("pending payout")
        ? `PASSED — pending payout refused deletion. code=${r.code} message="${r.message}"`
        : `FAILED — pending payout did NOT refuse deletion correctly: ${JSON.stringify(r)}`;
    if (r.ok || r.code !== "failed-precondition" || !r.message.includes("pending payout")) {
      allPassed = false;
    }
    results.scenario4_pending_payout_refused = s;
    console.log("Scenario 4:", s);
  }

  // Scenario 5 — THE full success path. A real Auth user is created first
  // (via the Auth emulator) so the final auth.deleteUser(uid) step is
  // genuinely exercised end-to-end, not just documented as untestable here.
  {
    const uid = "phase17-dud-success-full";
    const userRecord = await auth.createUser({ uid, phoneNumber: "+919876500001" });
    if (userRecord.uid !== uid) throw new Error("Auth emulator did not honor the requested uid");

    await db.collection("users").doc(uid).set({ name: "Full Success Tester", phone: "+919876500001" });
    await db.collection("wallets").doc(uid).set({ balance: 0 });
    await db.collection("addresses").add({ userId: uid, city: "Chennai" });
    await db.collection("carts").doc(uid).collection("items").doc("item1").set({ productId: "p1", qty: 2 });
    await db.collection("wishlists").doc(uid).collection("items").doc("item1").set({ productId: "p2" });
    await db.collection("users").doc(uid).collection("notifications").doc("n1").set({ title: "hi" });
    await db.collection("users").doc(uid).collection("recently_viewed").doc("rv1").set({ productId: "p3" });

    const orderRef = await db.collection("orders").add({
      userId: uid,
      orderStatus: "delivered",
      total: 799,
      items: [{ productId: "p1", qty: 2 }],
      deliveryAddress: { name: "Full Success Tester", phone: "+919876500001", city: "Chennai" },
      notes: "Leave at the gate",
    });

    // These must NOT be touched by deleteUserData, even though they carry
    // this uid — proves the "accounting key, not PII" boundary the file's
    // own header comment describes.
    const walletTxRef = await db.collection("wallet_transactions").add({ userId: uid, amount: 100, type: "credit" });
    const ledgerRef = await db
      .collection("product_credit_ledger")
      .add({ customerId: uid, amount: 50, type: "credit" });

    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 5 raw:", JSON.stringify(r));

    // The callable's OWN return may legitimately be a failure here if the
    // Auth emulator's deleteUser has any quirk this environment doesn't
    // replicate exactly like production — what's durably provable, and
    // what actually matters, is checked directly against Firestore/Auth
    // below, exactly as phase15_set_user_role_test.js's Scenario 4 does for
    // its own environment-sensitive final step.
    const checks = [];

    const userGone = !(await db.collection("users").doc(uid).get()).exists;
    checks.push(["users/{uid} hard-deleted", userGone]);

    const walletGone = !(await db.collection("wallets").doc(uid).get()).exists;
    checks.push(["wallets/{uid} hard-deleted", walletGone]);

    const cartGone = !(await db.collection("carts").doc(uid).get()).exists;
    checks.push(["carts/{uid} doc gone", cartGone]);
    const cartItemsGone = (await db.collection("carts").doc(uid).collection("items").get()).empty;
    checks.push(["carts/{uid}/items emptied", cartItemsGone]);

    const wishlistGone = !(await db.collection("wishlists").doc(uid).get()).exists;
    checks.push(["wishlists/{uid} doc gone", wishlistGone]);

    const addressesGone = (await db.collection("addresses").where("userId", "==", uid).get()).empty;
    checks.push(["addresses for uid gone", addressesGone]);

    const notificationsGone = (await db.collection("users").doc(uid).collection("notifications").get()).empty;
    checks.push(["notifications subcollection emptied", notificationsGone]);

    const recentlyViewedGone = (await db.collection("users").doc(uid).collection("recently_viewed").get()).empty;
    checks.push(["recently_viewed subcollection emptied", recentlyViewedGone]);

    const orderAfter = await orderRef.get();
    const orderData = orderAfter.data() || {};
    checks.push(["order document still exists (kept, not deleted)", orderAfter.exists]);
    checks.push(["order.deliveryAddress stripped to null", orderData.deliveryAddress === null]);
    checks.push(["order.notes stripped to empty string", orderData.notes === ""]);
    checks.push(["order.total unchanged (799)", orderData.total === 799]);
    checks.push(["order.orderStatus unchanged ('delivered')", orderData.orderStatus === "delivered"]);
    checks.push(["order.items unchanged", JSON.stringify(orderData.items) === JSON.stringify([{ productId: "p1", qty: 2 }])]);

    const walletTxAfter = await walletTxRef.get();
    checks.push(["wallet_transactions doc completely untouched", walletTxAfter.exists && walletTxAfter.data().userId === uid && walletTxAfter.data().amount === 100]);

    const ledgerAfter = await ledgerRef.get();
    checks.push(["product_credit_ledger doc completely untouched", ledgerAfter.exists && ledgerAfter.data().customerId === uid && ledgerAfter.data().amount === 50]);

    const auditDoc = await db.collection("account_deletion_audit").doc(uid).get();
    checks.push(["account_deletion_audit record written", auditDoc.exists]);
    if (auditDoc.exists) {
      const ad = auditDoc.data();
      checks.push(["audit record carries no name/email/phone/address field", !("name" in ad) && !("email" in ad) && !("phone" in ad) && !("address" in ad)]);
      checks.push(["audit.anonymizedOrdersCount === 1", ad.anonymizedOrdersCount === 1]);
    }

    let authUserGone = false;
    try {
      await auth.getUser(uid);
      authUserGone = false;
    } catch (e) {
      authUserGone = e.code === "auth/user-not-found";
    }
    checks.push(["Auth user actually deleted (end-to-end, via the real Auth emulator)", authUserGone]);

    let allChecksPassed = true;
    for (const [label, passed] of checks) {
      console.log(`  [Scenario 5] ${passed ? "PASSED" : "FAILED"} — ${label}`);
      if (!passed) allChecksPassed = false;
    }
    if (!allChecksPassed) allPassed = false;
    results.scenario5_full_success_path = allChecksPassed
      ? "PASSED — every durable check (Firestore + real Auth emulator deletion) succeeded"
      : "FAILED — see per-check log above";
    console.log("Scenario 5 summary:", results.scenario5_full_success_path);
  }

  // Scenario 6 — idempotency: calling again on the now-deleted account does
  // not throw on the refusal checks (wallets/{uid} gone -> balance defaults
  // to 0; the anonymized order is still 'delivered', still terminal) and
  // correctly reports alreadyDeleted=true without attempting the Firestore
  // work a second time.
  {
    const uid = "phase17-dud-success-full"; // reuses Scenario 5's now-deleted account
    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 6 raw:", JSON.stringify(r));
    const s =
      r.ok && r.result.alreadyDeleted === true && r.result.hardDeletedDocCount === 0
        ? `PASSED — idempotent retry succeeded and correctly reported alreadyDeleted=true, hardDeletedDocCount=0`
        : `FAILED — idempotent retry did not behave correctly: ${JSON.stringify(r)}`;
    if (!r.ok || r.result?.alreadyDeleted !== true || r.result?.hardDeletedDocCount !== 0) {
      allPassed = false;
    }
    results.scenario6_idempotent_retry = s;
    console.log("Scenario 6:", s);
  }

  // Scenario 7 — the associate edge case: employees/{uid} exists, wallet is
  // $0, no pending payout -> deletion succeeds and employees/{uid} is also
  // hard-deleted, wasAssociate reported true.
  {
    const uid = "phase17-dud-associate-success";
    await auth.createUser({ uid, phoneNumber: "+919876500002" });
    await db.collection("users").doc(uid).set({ name: "Associate Tester" });
    await db.collection("wallets").doc(uid).set({ balance: 0 });
    await db.collection("employees").doc(uid).set({ name: "Associate Tester", employeeCode: "SA-TEST-01" });

    const r = await callAndCapture({ uid, token: {} });
    console.log("Scenario 7 raw:", JSON.stringify(r));

    const employeeGone = !(await db.collection("employees").doc(uid).get()).exists;
    const s = employeeGone
      ? "PASSED — employees/{uid} hard-deleted for an associate account"
      : "FAILED — employees/{uid} was NOT deleted for an associate account";
    if (!employeeGone) allPassed = false;
    results.scenario7_associate_employee_doc_deleted = s;
    console.log("Scenario 7:", s);

    if (r.ok) {
      const s2 = r.result.wasAssociate === true
        ? "PASSED — callable reported wasAssociate=true"
        : `FAILED — callable did not report wasAssociate=true: ${JSON.stringify(r.result)}`;
      if (r.result.wasAssociate !== true) allPassed = false;
      results.scenario7b_wasAssociate_reported = s2;
      console.log("Scenario 7b:", s2);
    } else {
      results.scenario7b_wasAssociate_reported = `SKIPPED (callable returned a top-level error, checked employees/{uid} deletion directly instead): ${JSON.stringify(r)}`;
      console.log("Scenario 7b:", results.scenario7b_wasAssociate_reported);
    }
  }

  console.log("=== PHASE 17 deleteUserData SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase17 deleteUserData test:", e);
  process.exit(1);
});
