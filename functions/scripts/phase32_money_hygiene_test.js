// Phase FIX-9 — payment/money hygiene: proves all 8 workstreams against the
// real compiled functions on a Firestore emulator, plus source guards for
// the claims an emulator cannot exercise (a live Razorpay network call, or
// a statistical proof of CSPRNG-vs-Math.random).
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase32_money_hygiene_test.js"
//           (Firestore emulator only — every function under test is
//           required in-process and invoked directly via firebase-
//           functions-test's wrap(), mirroring phase16/22/27/28's
//           established pattern. Deliberately NOT --only firestore,functions:
//           that starts a real functions emulator that watches Firestore and
//           fires every OTHER trigger too (onOrderCreatedNotifications,
//           syncUserRoleClaims, ...) as a side effect of this suite's own
//           writes — unrelated noise this suite doesn't need and, in this
//           environment, an unrelated pre-existing crash in
//           orderNotifications.ts's admin.firestore.FieldValue access under
//           that specific emulator path.)
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
// Never real credentials — mirrors phase25_payment_single_consumption_test.js's
// identical setup for the identical reason: getRazorpayCredentials() reads
// these directly from process.env, and test.wrap()'s direct in-process
// invocation bypasses whatever secret-injection the real Cloud Functions
// runtime (or functions/.secret.local under a real functions emulator)
// would otherwise provide.
process.env.RAZORPAY_KEY_ID = "rzp_test_phase32_fake_key";
process.env.RAZORPAY_KEY_SECRET = "phase32_fake_secret_never_a_real_key";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { verifyWalletTopup } = require("../lib/customer/wallet");
const { verifyRazorpayPayment } = require("../lib/customer/payment");
const { createOrder } = require("../lib/customer/createOrder");
const { setLowStockThreshold } = require("../lib/customer/inventory");

const wrappedWalletVerify = test.wrap(verifyWalletTopup);
const wrappedPaymentVerify = test.wrap(verifyRazorpayPayment);
const wrappedCreateOrder = test.wrap(createOrder);
const wrappedSetThreshold = test.wrap(setLowStockThreshold);

async function callV2(wrapped, payload, auth) {
  try {
    return { ok: true, result: await wrapped({ data: payload, auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

// v1 onCall — firebase-functions-test's documented convention is
// wrapped(data, { auth: { uid, token } }), a separate second argument, not
// v2's single merged object.
async function callV1(wrapped, payload, auth) {
  try {
    return { ok: true, result: await wrapped(payload, { auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedUser(uid, extra = {}) {
  await db.collection("users").doc(uid).set({ uid, profileCompleted: true, ...extra });
}

async function seedProduct(id, salePrice, sellerId, stock) {
  await db.collection("products").doc(id).set({
    name: `P ${id}`, salePrice, sellerId, images: [], isB2BEnabled: false, stock,
  });
}

function orderPayload(items, extra = {}) {
  return {
    items,
    orderMode: "B2C",
    deliveryAddress: { name: "T", phone: "9999999999", addressLine1: "1 St", city: "Chennai", state: "TN", zipcode: "600001", country: "India" },
    paymentMethod: "cod",
    deliveryCharge: 0,
    tax: 0,
    ...extra,
  };
}

const src = (rel) => fs.readFileSync(path.join(__dirname, "..", "src", rel), "utf8");

async function latestSecurityLog(paymentId) {
  const snap = await db.collection("payment_security_logs").where("paymentId", "==", paymentId).get();
  return snap.empty ? null : snap.docs[snap.docs.length - 1].data();
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-9 — payment/money hygiene ===");

  // ---------------- PART A: emulator-backed behavioral scenarios ----------------

  // WS1a — wallet.ts: a signature mismatch must be rejected AND the logged
  // document must never carry the correct signature.
  {
    const uid = "phase32-wallet-user";
    const paymentId = "phase32-wallet-pay-1";
    await seedUser(uid);
    const r = await callV2(wrappedWalletVerify, { amount: 100, paymentId, orderId: "phase32-wallet-order-1", signature: "deliberately-wrong" }, { uid, token: {} });
    const log = await latestSecurityLog(paymentId);
    record("ws1a_wallet_signature_mismatch_rejected_and_not_logged_reversibly",
      !r.ok && log && log.signatureMatched === false && !Object.prototype.hasOwnProperty.call(log, "expectedSignature"),
      `ok=${r.ok} code=${r.code} log=${JSON.stringify(log)}`);
  }

  // WS1b — payment.ts: same proof, the sibling file.
  {
    const paymentId = "phase32-payment-pay-1";
    const r = await callV2(wrappedPaymentVerify, { paymentId, orderId: "phase32-payment-order-1", signature: "deliberately-wrong" }, { uid: "phase32-payment-user", token: {} });
    const log = await latestSecurityLog(paymentId);
    record("ws1b_payment_signature_mismatch_rejected_and_not_logged_reversibly",
      r.ok && r.result?.verified === false && log && log.signatureMatched === false && !Object.prototype.hasOwnProperty.call(log, "expectedSignature"),
      `ok=${r.ok} verified=${r.result?.verified} log=${JSON.stringify(log)}`);
  }

  // WS3a — the tightened tolerance: a payment ₹0.50 short of the order total
  // (inside the OLD ₹1 tolerance, outside the NEW 0.02) must now be REFUSED.
  {
    const uid = "phase32-ws3a-user"; const p = "phase32-ws3a-product";
    await seedUser(uid); await seedProduct(p, 100, "phase32-seller", 10);
    const paymentId = "phase32-ws3a-payment";
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: "phase32-ws3a-razorpay-order", paymentId, userId: uid, status: "captured", amount: 99.5,
    });
    const r = await callV2(wrappedCreateOrder, orderPayload([{ productId: p, quantity: 1 }], {
      paymentMethod: "razorpay", razorpayPaymentId: paymentId, razorpayOrderId: "phase32-ws3a-razorpay-order",
    }), { uid, token: {} });
    record("ws3a_half_rupee_short_payment_now_refused",
      !r.ok && r.code === "failed-precondition",
      `ok=${r.ok} code=${r.code} message="${r.message}"`);
  }

  // WS3b — regression control: a payment within the NEW epsilon (1 paisa
  // short) must still be accepted — the tightened tolerance must not be so
  // tight it rejects legitimate rounding.
  {
    const uid = "phase32-ws3b-user"; const p = "phase32-ws3b-product";
    await seedUser(uid); await seedProduct(p, 100, "phase32-seller", 10);
    const paymentId = "phase32-ws3b-payment";
    await db.collection("verified_payments").doc(paymentId).set({
      orderId: "phase32-ws3b-razorpay-order", paymentId, userId: uid, status: "captured", amount: 99.99,
    });
    const r = await callV2(wrappedCreateOrder, orderPayload([{ productId: p, quantity: 1 }], {
      paymentMethod: "razorpay", razorpayPaymentId: paymentId, razorpayOrderId: "phase32-ws3b-razorpay-order",
    }), { uid, token: {} });
    record("ws3b_one_paisa_short_payment_still_accepted",
      r.ok,
      `ok=${r.ok} code=${r.code} message="${r.message}"`);
  }

  // WS3c — the payable-requires-payment branch (`payable > MONEY_EPSILON`,
  // was `payable > 1`) only runs when a product-credit hold was supplied —
  // an EARLIER, separate upfront guard (createOrder.ts:176) already requires
  // Razorpay details whenever no hold exists, so a no-hold order can never
  // reach this branch at all (confirmed: a first pass at this scenario with
  // no hold "passed" identically on the pre-fix code too — vacuous, not
  // evidence). Reaching it behaviorally needs a genuinely valid
  // product-credit hold (compliance_config, feature_flags, a matching cart
  // fingerprint, hold status) — disproportionate test infrastructure for one
  // narrow branch that shares its comparison operator and constant with
  // WS3a/b, already proven behaviorally above. Proven at the source level
  // instead, the same idiom phase19/23 use for a claim an emulator cannot
  // reach without that infrastructure.
  {
    const createOrderSrc = src("customer/createOrder.ts");
    const branchMatch = createOrderSrc.match(/\} else if \(paymentMethod !== "cod" && payable > [^)]+\) \{/);
    record("ws3c_source_payable_requires_payment_branch_uses_the_tightened_epsilon",
      !!branchMatch && /MONEY_EPSILON/.test(branchMatch[0]) && !/payable > 1/.test(branchMatch[0]),
      `branch condition: ${branchMatch && branchMatch[0]}`);
  }

  // WS4a/b — threshold validation.
  {
    const uid = "phase32-ws4-seller"; const p = "phase32-ws4-product";
    await seedProduct(p, 100, uid, 10);
    const rNeg = await callV1(wrappedSetThreshold, { productId: p, threshold: -5 }, { uid, token: {} });
    record("ws4a_negative_threshold_rejected", !rNeg.ok && rNeg.code === "invalid-argument", `code=${rNeg.code}`);
    const rNaN = await callV1(wrappedSetThreshold, { productId: p, threshold: "abc" }, { uid, token: {} });
    record("ws4b_non_numeric_threshold_rejected", !rNaN.ok && rNaN.code === "invalid-argument", `code=${rNaN.code}`);
  }

  // WS4c — positive control: the product's own seller can still set a valid
  // threshold (regression control — validation must not be over-tight).
  {
    const uid = "phase32-ws4c-seller"; const p = "phase32-ws4c-product";
    await seedProduct(p, 100, uid, 10);
    const r = await callV1(wrappedSetThreshold, { productId: p, threshold: 3 }, { uid, token: {} });
    const after = await db.collection("products").doc(p).get();
    record("ws4c_owner_seller_can_still_set_a_valid_threshold",
      r.ok && after.data()?.lowStockThreshold === 3,
      `ok=${r.ok} lowStockThreshold=${after.data()?.lowStockThreshold}`);
  }

  // WS4d — claim-first: an admin-CLAIMED caller (not the product's seller,
  // and no users/{uid} document at all) can still set a threshold, proving
  // the claim-first fallback path works without needing a Firestore role
  // read to succeed.
  {
    const p = "phase32-ws4d-product";
    await seedProduct(p, 100, "phase32-ws4d-someone-else", 10);
    const r = await callV1(wrappedSetThreshold, { productId: p, threshold: 7 }, { uid: "phase32-ws4d-admin-no-userdoc", token: { admin: true } });
    const after = await db.collection("products").doc(p).get();
    record("ws4d_admin_by_claim_succeeds_without_a_users_document",
      r.ok && after.data()?.lowStockThreshold === 7,
      `ok=${r.ok} lowStockThreshold=${after.data()?.lowStockThreshold}`);
  }

  // WS7 — the rounding residual: 3 equal-subtotal sellers plus a delivery
  // charge that does not divide evenly by 3 must still sum EXACTLY to
  // grandTotal across the created per-seller order documents.
  {
    const uid = "phase32-ws7-user";
    const sellers = ["phase32-ws7-seller-a", "phase32-ws7-seller-b", "phase32-ws7-seller-c"];
    const products = ["phase32-ws7-p-a", "phase32-ws7-p-b", "phase32-ws7-p-c"];
    await seedUser(uid);
    for (let i = 0; i < 3; i++) await seedProduct(products[i], 10, sellers[i], 10);
    const items = products.map((id) => ({ productId: id, quantity: 1 }));
    const r = await callV2(wrappedCreateOrder, orderPayload(items, { deliveryCharge: 1, tax: 0 }), { uid, token: {} });
    const sumOfTotals = r.ok ? r.result.orders.reduce((acc, o) => acc + o.total, 0) : null;
    const grandTotal = 31; // 3 x 10 subtotal + 1 delivery charge, no discount/tax
    record("ws7_per_seller_totals_sum_exactly_to_grand_total",
      r.ok && Math.round(sumOfTotals * 100) === Math.round(grandTotal * 100),
      `ok=${r.ok} createdOrders=${JSON.stringify(r.result?.orders)} sum=${sumOfTotals} (expect ${grandTotal})`);
  }

  // ---------------- PART B: source guards (claims an emulator cannot exercise) ----------------

  {
    const walletSrc = src("customer/wallet.ts");
    const paymentSrc = src("customer/payment.ts");
    record("ws1c_source_neither_file_persists_a_field_named_expectedSignature",
      !/expectedSignature\s*:/.test(walletSrc) && !/expectedSignature\s*:/.test(paymentSrc),
      "grepped both files for the literal field name");
  }

  {
    const paymentSrc = src("customer/payment.ts");
    const noteBlockMatch = paymentSrc.match(/notes:\s*\{([^}]*)\}/);
    const orderInSpreadFirst = !!noteBlockMatch && /\.\.\.notes/.test(noteBlockMatch[1]) &&
      noteBlockMatch[1].indexOf("...notes") < noteBlockMatch[1].indexOf("userId:");
    record("ws2_source_notes_spread_comes_before_serverset_userId",
      orderInSpreadFirst,
      `notes block: ${JSON.stringify(noteBlockMatch && noteBlockMatch[1])}`);
  }

  {
    const createOrderSrc = src("customer/createOrder.ts");
    const genFnMatch = createOrderSrc.match(/function generateOrderNumber\(\)[^}]*\}/);
    const usesCsprng = !!genFnMatch && /crypto\.randomInt/.test(genFnMatch[0]) && !/Math\.random/.test(genFnMatch[0]);
    record("ws5_source_order_number_uses_csprng_not_math_random",
      usesCsprng,
      `generateOrderNumber: ${genFnMatch && genFnMatch[0]}`);
  }

  {
    const verifyPhoneOtpSrc = src("common/verifyPhoneOTP.ts");
    record("ws6_source_otp_hash_comparison_is_constant_time",
      /timingSafeEqual/.test(verifyPhoneOtpSrc) && !/otpData\.otpHash\s*!==\s*hashOtp/.test(verifyPhoneOtpSrc),
      "grepped for timingSafeEqual and the removed plain !== comparison");
  }

  {
    const paymentSrc = src("customer/payment.ts");
    record("ws8a_source_internal_runbook_command_no_longer_client_facing",
      !/functions:config:set/.test(paymentSrc),
      "grepped for the removed runbook command string");
    // The narrowed shape must appear in BOTH return statements (verified
    // true and verified false), and no PII field of the raw Razorpay
    // payment object may be referenced AFTER the verified_payments write
    // block (where email/bank/contact are legitimately read for that
    // internal audit record, never for the client-facing response).
    const narrowedShapeCount = (paymentSrc.match(/payment: \{ id: payment\.id, status: payment\.status, method: payment\.method \}/g) || []).length;
    const afterWriteBlock = paymentSrc.split("currency: payment.currency,")[1] || "";
    const noPiiInReturns = !/payment\.email|payment\.bank|payment\.contact/.test(afterWriteBlock);
    record("ws8b_source_returned_payment_object_excludes_pii_fields",
      narrowedShapeCount === 2 && noPiiInReturns,
      `narrowedShapeCount=${narrowedShapeCount} (expect 2) noPiiInReturns=${noPiiInReturns}`);
    record("ws8c_source_dead_transfers_field_removed",
      !/transfers\?:/.test(paymentSrc) && !/,\s*transfers\s*\}\s*=\s*data/.test(paymentSrc),
      "grepped for the removed transfers field in the interface and destructure");
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 32: FAILED"); process.exit(1); }
  console.log("PHASE 32: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 32: harness error", e); process.exit(1); });
