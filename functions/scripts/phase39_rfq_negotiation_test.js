// Phase RFQ-1: proves createRfq/submitRfqOffer/respondToRfqOffer against a
// real emulator — the full negotiation state machine (create -> counter ->
// counter -> accept/reject), role derivation from stored identity (never
// client-asserted), turn-taking enforcement, and input bounds.
// Run with: node scripts/phase39_rfq_negotiation_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { createRfq, submitRfqOffer, respondToRfqOffer } = require("../lib/customer/rfq");

const wrappedCreate = test.wrap(createRfq);
const wrappedOffer = test.wrap(submitRfqOffer);
const wrappedRespond = test.wrap(respondToRfqOffer);

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedProduct(db, productId, sellerId, { b2bEnabled = true } = {}) {
  await db.collection("products").doc(productId).set({
    name: `Test Product ${productId}`,
    sellerId,
    isB2BEnabled: b2bEnabled,
    b2bPrice: 100,
    b2bMoq: 10,
  });
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE RFQ-1 — createRfq / submitRfqOffer / respondToRfqOffer ===");

  const BUYER = "phase39-buyer";
  const SELLER = "phase39-seller";
  const STRANGER = "phase39-stranger";

  // Scenario 1: unauthenticated createRfq is rejected.
  {
    const r = await callAndCapture(wrappedCreate, { productId: "x", quantity: 10 }, undefined);
    const s = !r.ok && r.code === "unauthenticated" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario1_unauthenticated = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: non-B2B product is rejected.
  {
    await seedProduct(db, "phase39-product-nonb2b", SELLER, { b2bEnabled: false });
    const r = await callAndCapture(
      wrappedCreate,
      { productId: "phase39-product-nonb2b", quantity: 10 },
      { uid: BUYER, token: {} }
    );
    const s =
      !r.ok && r.code === "failed-precondition" && /not enabled for B2B/.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario2_non_b2b_product = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: requesting a quote on your own product is rejected.
  const PRODUCT = "phase39-product-1";
  {
    await seedProduct(db, PRODUCT, SELLER);
    const r = await callAndCapture(
      wrappedCreate,
      { productId: PRODUCT, quantity: 50, proposedPrice: 90 },
      { uid: SELLER, token: {} }
    );
    const s =
      !r.ok && r.code === "invalid-argument" && /own product/.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario3_self_rfq_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: successful creation with a proposed price.
  let rfqId;
  {
    const r = await callAndCapture(
      wrappedCreate,
      { productId: PRODUCT, quantity: 50, proposedPrice: 90, notes: "Need it by Friday" },
      { uid: BUYER, token: {} }
    );
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got ${JSON.stringify(r)}`);
      rfqId = r.result.rfqId;
      const snap = await db.collection("rfqs").doc(rfqId).get();
      const rfq = snap.data();
      if (rfq.status !== "pending") throw new Error(`expected status pending, got ${rfq.status}`);
      if (rfq.awaitingResponseFrom !== "seller") throw new Error(`expected awaiting seller, got ${rfq.awaitingResponseFrom}`);
      if (rfq.buyerId !== BUYER || rfq.sellerId !== SELLER) throw new Error("buyer/seller mismatch");
      if (!rfq.lastOffer || rfq.lastOffer.price !== 90 || rfq.lastOffer.quantity !== 50) {
        throw new Error(`unexpected lastOffer: ${JSON.stringify(rfq.lastOffer)}`);
      }
      if (rfq.history.length !== 1 || rfq.history[0].action !== "create") {
        throw new Error(`unexpected history: ${JSON.stringify(rfq.history)}`);
      }
      s = `PASSED — rfqId=${rfqId}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario4_create_success = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 4:", s);
  }

  // Scenario 5: buyer cannot submit an offer out of turn (seller is awaited).
  {
    const r = await callAndCapture(wrappedOffer, { rfqId, price: 85, quantity: 50 }, { uid: BUYER, token: {} });
    const s =
      !r.ok && r.code === "failed-precondition" && /Waiting for the other party/.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario5_out_of_turn_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 5:", s);
  }

  // Scenario 6: a stranger (not buyer or seller) cannot act on the RFQ.
  {
    const r = await callAndCapture(wrappedOffer, { rfqId, price: 85, quantity: 50 }, { uid: STRANGER, token: {} });
    const s = !r.ok && r.code === "permission-denied" ? "PASSED" : `FAILED — ${JSON.stringify(r)}`;
    results.scenario6_stranger_denied = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 6:", s);
  }

  // Scenario 7: the seller (correct turn) counters — negotiation continues.
  {
    const r = await callAndCapture(
      wrappedOffer,
      { rfqId, price: 95, quantity: 50, notes: "Best I can do" },
      { uid: SELLER, token: {} }
    );
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got ${JSON.stringify(r)}`);
      const snap = await db.collection("rfqs").doc(rfqId).get();
      const rfq = snap.data();
      if (rfq.status !== "negotiating") throw new Error(`expected negotiating, got ${rfq.status}`);
      if (rfq.awaitingResponseFrom !== "buyer") throw new Error(`expected awaiting buyer, got ${rfq.awaitingResponseFrom}`);
      if (rfq.lastOffer.price !== 95 || rfq.lastOffer.by !== "seller") throw new Error(`unexpected lastOffer: ${JSON.stringify(rfq.lastOffer)}`);
      if (rfq.history.length !== 2) throw new Error(`expected 2 history entries, got ${rfq.history.length}`);
      s = "PASSED — countered to 95, awaiting buyer";
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario7_seller_counters = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 7:", s);
  }

  // Scenario 8: buyer accepts the seller's counter — locks final terms.
  {
    const r = await callAndCapture(wrappedRespond, { rfqId, action: "accept" }, { uid: BUYER, token: {} });
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got ${JSON.stringify(r)}`);
      const snap = await db.collection("rfqs").doc(rfqId).get();
      const rfq = snap.data();
      if (rfq.status !== "accepted") throw new Error(`expected accepted, got ${rfq.status}`);
      if (rfq.finalPrice !== 95 || rfq.finalQuantity !== 50) throw new Error(`unexpected final terms: ${rfq.finalPrice}/${rfq.finalQuantity}`);
      if (rfq.awaitingResponseFrom !== null) throw new Error("expected awaitingResponseFrom to be cleared");
      if (rfq.history.length !== 3 || rfq.history[2].action !== "accept") throw new Error(`unexpected history: ${JSON.stringify(rfq.history)}`);
      s = `PASSED — locked at price=${rfq.finalPrice} quantity=${rfq.finalQuantity}`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario8_buyer_accepts = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 8:", s);
  }

  // Scenario 9: no further action is possible on an accepted RFQ.
  {
    const r = await callAndCapture(wrappedOffer, { rfqId, price: 100, quantity: 50 }, { uid: SELLER, token: {} });
    const s =
      !r.ok && r.code === "failed-precondition" && /no longer open/.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario9_closed_rfq_immutable = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 9:", s);
  }

  // Scenario 10: a fresh RFQ with no proposed price cannot be accepted
  // before any real offer exists.
  {
    const productNoPrice = "phase39-product-2";
    await seedProduct(db, productNoPrice, SELLER);
    const created = await callAndCapture(
      wrappedCreate,
      { productId: productNoPrice, quantity: 20 },
      { uid: BUYER, token: {} }
    );
    const rfqId2 = created.result.rfqId;
    const r = await callAndCapture(wrappedRespond, { rfqId: rfqId2, action: "accept" }, { uid: SELLER, token: {} });
    const s =
      !r.ok && r.code === "failed-precondition" && /no offer to accept/i.test(r.message)
        ? "PASSED"
        : `FAILED — ${JSON.stringify(r)}`;
    results.scenario10_accept_with_no_offer_rejected = s;
    if (s !== "PASSED") allPassed = false;
    console.log("Scenario 10:", s);
  }

  // Scenario 11: reject path works even with no offer on the table (a
  // straight "no thanks" needs no prior counter-offer).
  {
    const productReject = "phase39-product-3";
    await seedProduct(db, productReject, SELLER);
    const created = await callAndCapture(
      wrappedCreate,
      { productId: productReject, quantity: 5 },
      { uid: BUYER, token: {} }
    );
    const rfqId3 = created.result.rfqId;
    const r = await callAndCapture(wrappedRespond, { rfqId: rfqId3, action: "reject" }, { uid: SELLER, token: {} });
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got ${JSON.stringify(r)}`);
      const snap = await db.collection("rfqs").doc(rfqId3).get();
      if (snap.data().status !== "rejected") throw new Error(`expected rejected, got ${snap.data().status}`);
      s = "PASSED — rejected with no prior offer";
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario11_reject_without_offer = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 11:", s);
  }

  // Scenario 12: input bounds — negative price, non-integer quantity,
  // oversized notes are all rejected.
  {
    const badPrice = await callAndCapture(wrappedCreate, { productId: PRODUCT, quantity: 10, proposedPrice: -5 }, { uid: BUYER, token: {} });
    const badQty = await callAndCapture(wrappedCreate, { productId: PRODUCT, quantity: 1.5 }, { uid: BUYER, token: {} });
    const badNotes = await callAndCapture(
      wrappedCreate,
      { productId: PRODUCT, quantity: 10, notes: "x".repeat(600) },
      { uid: BUYER, token: {} }
    );
    let s;
    if (badPrice.ok || badPrice.code !== "invalid-argument") s = `FAILED — negative price accepted: ${JSON.stringify(badPrice)}`;
    else if (badQty.ok || badQty.code !== "invalid-argument") s = `FAILED — fractional quantity accepted: ${JSON.stringify(badQty)}`;
    else if (badNotes.ok || badNotes.code !== "invalid-argument") s = `FAILED — oversized notes accepted: ${JSON.stringify(badNotes)}`;
    else s = "PASSED — all three malformed inputs rejected";
    results.scenario12_input_bounds = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 12:", s);
  }

  console.log("=== PHASE RFQ-1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase39 RFQ negotiation test:", e);
  process.exit(1);
});
