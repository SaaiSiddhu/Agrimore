// Phase FIX-5 — proves confirmDelivery verifies the code SERVER-side.
//
// N-5 (P1): apps/delivery read deliveryVerificationCode into the delivery
// partner's own client and compared it locally, then wrote
// orderStatus: 'delivered' directly. The party being authenticated was handed
// the answer, and the whole check was skippable.
//
// SCOPE, stated so a green run is not over-read: this suite proves the CALLABLE
// is a real control. It does NOT prove N-5 is closed — the direct status write
// is still permitted by firestore.rules until phase FIX-5B tightens them, and
// that tightening must wait for a released apps/delivery build that uses this
// path. A test here cannot demonstrate the absence of a client that bypasses it.
//
// confirmDelivery is a v2 onCall — wrapped and invoked as wrapped({data, auth}).
//
// Run with:
//   firebase emulators:exec --only firestore,functions \
//     "node scripts/phase29_delivery_confirmation_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { confirmDelivery } = require("../lib/customer/confirmDelivery");
const wrapped = test.wrap(confirmDelivery);

const PARTNER = "phase29-partner";
const OTHER_PARTNER = "phase29-other-partner";
const REAL_CODE = "482913";
const WRONG_CODE = "000000";

async function call(orderId, code, uid) {
  try {
    return { ok: true, result: await wrapped({ data: { orderId, code }, auth: { uid, token: {} } }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedOrder(orderId, opts = {}) {
  const doc = {
    userId: "phase29-customer",
    orderNumber: `ORD-${orderId}`,
    sellerId: "phase29-seller",
    deliveryPartnerId: opts.partnerId === undefined ? PARTNER : opts.partnerId,
    orderStatus: opts.status || "out_for_delivery",
    status: opts.status || "out_for_delivery",
    total: 500,
    items: [],
  };
  if (opts.code !== null) doc.deliveryVerificationCode = opts.code || REAL_CODE;
  await db.collection("orders").doc(orderId).set(doc);
}

const orderDoc = (id) => db.collection("orders").doc(id).get().then((s) => s.data() || {});
const timelineCount = (id) =>
  db.collection("orders").doc(id).collection("timeline").get().then((s) => s.size);

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-5 — server-side delivery confirmation (N-5) ===");

  // 1 — POSITIVE CONTROL. The assigned partner with the right code transitions
  // the order. Without this every refusal below could pass because the callable
  // refuses everything.
  {
    const oid = "phase29-o1";
    await seedOrder(oid);
    const r = await call(oid, REAL_CODE, PARTNER);
    const d = await orderDoc(oid);
    record("scenario1_control_assigned_partner_correct_code_delivers",
      r.ok && d.orderStatus === "delivered" && d.status === "delivered" &&
      d.deliveryConfirmedBy === PARTNER && d.deliveryConfirmedVia === "confirmDelivery" &&
      (await timelineCount(oid)) === 1,
      `ok=${r.ok} status=${d.orderStatus} confirmedBy=${d.deliveryConfirmedBy} timeline=${await timelineCount(oid)}`);
  }

  // 2 — a wrong code is refused and NOTHING moves.
  {
    const oid = "phase29-o2";
    await seedOrder(oid);
    const r = await call(oid, WRONG_CODE, PARTNER);
    const d = await orderDoc(oid);
    record("scenario2_wrong_code_refused_and_status_unchanged",
      !r.ok && r.code === "permission-denied" && d.orderStatus === "out_for_delivery" &&
      (await timelineCount(oid)) === 0,
      `code=${r.code} status=${d.orderStatus} (must stay out_for_delivery) timeline=${await timelineCount(oid)}`);
  }

  // 3 + 4 — THE ORACLE PAIR, the reason the assignment check runs BEFORE the
  // code comparison. A partner this order is NOT assigned to must get the
  // IDENTICAL refusal whether their guess is right or wrong. If the two differed
  // — in code or message — this callable would tell an attacker when they had
  // guessed a code correctly, which is a better oracle than the bug it replaces.
  let unassignedRight, unassignedWrong;
  {
    const oid = "phase29-o3";
    await seedOrder(oid);
    unassignedRight = await call(oid, REAL_CODE, OTHER_PARTNER);
    const d = await orderDoc(oid);
    record("scenario3_unassigned_partner_with_the_CORRECT_code_is_refused",
      !unassignedRight.ok && unassignedRight.code === "permission-denied" && d.orderStatus === "out_for_delivery",
      `code=${unassignedRight.code} status=${d.orderStatus}`);
  }
  {
    const oid = "phase29-o4";
    await seedOrder(oid);
    unassignedWrong = await call(oid, WRONG_CODE, OTHER_PARTNER);
    const same =
      unassignedRight.code === unassignedWrong.code &&
      unassignedRight.message === unassignedWrong.message;
    record("scenario4_no_oracle_right_and_wrong_guesses_are_indistinguishable",
      !unassignedWrong.ok && same,
      `rightGuess=(${unassignedRight.code}: "${unassignedRight.message}") wrongGuess=(${unassignedWrong.code}: "${unassignedWrong.message}") identical=${same}`);
  }

  // 5 — idempotency. A retry after a dropped response reads as success and does
  // not add a second timeline entry. Deliberately retried with the WRONG code,
  // to prove the idempotency check runs before the comparison: a partner
  // retrying need not still have the code to hand.
  {
    const oid = "phase29-o5";
    await seedOrder(oid);
    const first = await call(oid, REAL_CODE, PARTNER);
    const second = await call(oid, WRONG_CODE, PARTNER);
    record("scenario5_retry_is_idempotent_and_does_not_need_the_code_again",
      first.ok && second.ok && second.result?.alreadyDelivered === true &&
      (await timelineCount(oid)) === 1,
      `first.ok=${first.ok} second.alreadyDelivered=${second.result?.alreadyDelivered} timeline=${await timelineCount(oid)} (expect 1)`);
  }

  // 6 — an order with no verification code fails CLOSED. It needs an admin, not
  // a guess.
  {
    const oid = "phase29-o6";
    await seedOrder(oid, { code: null });
    const r = await call(oid, REAL_CODE, PARTNER);
    const d = await orderDoc(oid);
    record("scenario6_missing_code_fails_closed",
      !r.ok && r.code === "failed-precondition" && d.orderStatus === "out_for_delivery",
      `code=${r.code} status=${d.orderStatus}`);
  }

  // 7 — a non-existent order.
  {
    const r = await call("phase29-does-not-exist", REAL_CODE, PARTNER);
    record("scenario7_unknown_order_is_not_found", !r.ok && r.code === "not-found", `code=${r.code}`);
  }

  // 8 — an order with no assigned partner at all cannot be confirmed by anyone.
  {
    const oid = "phase29-o8";
    await seedOrder(oid, { partnerId: null });
    const r = await call(oid, REAL_CODE, PARTNER);
    const d = await orderDoc(oid);
    record("scenario8_unassigned_order_cannot_be_confirmed",
      !r.ok && r.code === "permission-denied" && d.orderStatus === "out_for_delivery",
      `code=${r.code} status=${d.orderStatus}`);
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 29: FAILED"); process.exit(1); }
  console.log("PHASE 29: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 29: harness error", e); process.exit(1); });
