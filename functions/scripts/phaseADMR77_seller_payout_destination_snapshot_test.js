// PHASE ADMR-77 — seller withdrawal destination must use its own request-time
// snapshot, never a live re-read of seller_payout_details
// (functions/src/seller/sellerWallet.ts). Complements
// phaseSWALLET1_wallet_test.js's own w4 block (which covers the
// change-mid-flight sequence for bank -> UPI); this file adds the scenarios
// that block does not: a vanilla no-change payment, a bare method mismatch
// with no underlying change at all, the opposite UPI -> bank direction (full
// symmetry), and payoutDestinationFull's own completeness parity with the
// existing masked payoutDestination.
//  f01 no bank/UPi change at all: pays to exactly the requested destination,
//      destinationFull carries the real account number, masked paidTo does not
//  f02 a bare method mismatch (no underlying change) is refused and mutates
//      nothing -- the withdrawal and its payouts stay exactly as they were
//  f03 UPI -> bank mid-flight (opposite direction from SWALLET1's w4c): the
//      already-open withdrawal still pays to the ORIGINAL upi id, never the
//      newly-approved bank account; a NEW withdrawal requested after the
//      change correctly picks up the new (now-current) bank details
//  f04 payoutDestinationFull agrees with payoutDestination on when a
//      destination exists at all, for both complete and incomplete inputs
// Run with: firebase emulators:exec --only firestore "node scripts/phaseADMR77_seller_payout_destination_snapshot_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-admr77-destination-snapshot";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const W = require("../lib/seller/sellerWallet");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const get = async (p) => (await db.doc(p).get()).data();
const NOW = Date.UTC(2026, 8, 28, 6, 0, 0);

async function seller(id, details) {
  await db.doc(`sellers/${id}`).set({ shopName: id });
  if (details) await db.doc(`seller_payout_details/${id}`).set({ sellerId: id, ...details });
}
async function payout(id, sellerId, net) {
  await db.doc(`seller_payouts/${id}`).set({ sellerId, orderId: id, orderNumber: id.toUpperCase(), netAmount: net, status: "pending",
    createdAt: Timestamp.fromMillis(NOW - 86400000) });
}
const BANK = { payoutMethod: "bank", accountHolder: "Ravi", bankName: "First Bank", accountNumber: "555000111222", ifsc: "FRST0009988" };
const UPI = { payoutMethod: "upi", upiId: "Ravi@examplebank", accountHolder: "Ravi" };
const BANK2 = { payoutMethod: "bank", accountHolder: "Ravi", bankName: "Second Bank", accountNumber: "999888777666", ifsc: "SCND0001122" };

async function main() {
  console.log("=== PHASE ADMR-77 — seller payout destination snapshot ===");

  // f01
  await seller("f1", BANK);
  await payout("f1a", "f1", 300);
  await payout("f1b", "f1", 250);
  const v1 = await W.requestWithdrawalCore(db, "f1", "req-f001-0001", NOW);
  const paid1 = await W.markWithdrawalPaidCore(db, "adm", v1.id, "UTRF00100", "bank", NOW + 1000);
  const w1 = await get(`seller_withdrawals/${v1.id}`);
  record("f01_no_change_pays_to_requested_destination",
    paid1.kind === "paid" &&
    JSON.stringify(paid1.paidTo) === JSON.stringify(w1.destination) &&
    w1.paidTo.accountLast4 === "1222" && !("accountNumber" in w1.paidTo) &&
    w1.destinationFull.accountNumber === "555000111222" && w1.destinationFull.ifsc === "FRST0009988",
    JSON.stringify({ paid1, w1 }));

  // f02
  await seller("f2", BANK);
  await payout("f2a", "f2", 400);
  const v2 = await W.requestWithdrawalCore(db, "f2", "req-f002-0001", NOW);
  const mismatch = await W.markWithdrawalPaidCore(db, "adm", v2.id, "UTRF00200", "upi", NOW + 1000);
  const w2 = await get(`seller_withdrawals/${v2.id}`);
  const p2 = await get("seller_payouts/f2a");
  record("f02_bare_method_mismatch_refused_and_untouched",
    mismatch.reason === "method_mismatch" && w2.status === "requested" && !("paidTo" in w2) &&
    p2.status === "requested" && !("paidAt" in p2),
    JSON.stringify({ mismatch, w2, p2 }));

  // f03
  await seller("f3", UPI);
  await payout("f3a", "f3", 600);
  const v3 = await W.requestWithdrawalCore(db, "f3", "req-f003-0001", NOW);
  const ch3 = await W.requestPayoutChangeCore(db, "f3", BANK2, NOW + 500);
  const app3 = await W.reviewPayoutChangeCore(db, { adminUid: "adm" }, ch3.id, true, null, NOW + 600);
  const wrongMethod3 = await W.markWithdrawalPaidCore(db, "adm", v3.id, "UTRF00300", "bank", NOW + 1000);
  const paid3 = await W.markWithdrawalPaidCore(db, "adm", v3.id, "UTRF00300", "upi", NOW + 1100);
  const w3 = await get(`seller_withdrawals/${v3.id}`);
  // A fresh withdrawal requested AFTER the approved change should reflect the
  // NEW, now-current bank details -- the freeze applies only to a withdrawal
  // already open when the change happened, never to a future one.
  await payout("f3b", "f3", 700);
  const v3b = await W.requestWithdrawalCore(db, "f3", "req-f003-0002", NOW + 1200);
  const w3b = await get(`seller_withdrawals/${v3b.id}`);
  record("f03_upi_to_bank_mid_flight_still_pays_original_upi",
    app3.kind === "approved" && wrongMethod3.reason === "method_mismatch" && paid3.kind === "paid" &&
    w3.paidTo.upiId === "Ravi@examplebank" && !("accountLast4" in w3.paidTo) &&
    w3b.destination.method === "bank" && w3b.destination.accountLast4 === "7666" &&
    w3b.destinationFull.accountNumber === "999888777666",
    JSON.stringify({ app3, wrongMethod3, paid3, w3, w3b }));

  // f04
  const completeBank = W.payoutDestination(BANK) !== null && W.payoutDestinationFull(BANK) !== null;
  const completeUpi = W.payoutDestination(UPI) !== null && W.payoutDestinationFull(UPI) !== null;
  const missingIfsc = W.payoutDestination({ ...BANK, ifsc: "" }) === null && W.payoutDestinationFull({ ...BANK, ifsc: "" }) === null;
  const missingUpiId = W.payoutDestination({ payoutMethod: "upi" }) === null && W.payoutDestinationFull({ payoutMethod: "upi" }) === null;
  const undef = W.payoutDestination(undefined) === null && W.payoutDestinationFull(undefined) === null;
  const fullShape = W.payoutDestinationFull(BANK);
  record("f04_destinationFull_agrees_with_masked_completeness",
    completeBank && completeUpi && missingIfsc && missingUpiId && undef &&
    fullShape.payoutMethod === "bank" && fullShape.accountNumber === "555000111222" && fullShape.upiId === null,
    JSON.stringify({ completeBank, completeUpi, missingIfsc, missingUpiId, undef, fullShape }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR-77 destination snapshot: FAILED"); process.exit(1); }
  console.log("PHASE ADMR-77 destination snapshot: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
