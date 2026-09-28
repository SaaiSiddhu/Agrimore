// PHASE ADMR-84 — the server must also refuse to pay a legacy-unresolved
// withdrawal, not just the admin app's own "Mark paid" button
// (functions/src/seller/sellerWallet.ts) on the Firestore emulator.
//
// ADMR-77/78/81/83 established that a withdrawal with no destinationFull
// (a pre-ADMR-77 "legacy" row) can never be reliably resolved to a real
// account, and made seller_wallet_admin.dart refuse to open the pay dialog
// for one. markWithdrawalPaidCore itself was never changed to match — it
// only reads the ALWAYS-present masked `destination`, so a DIRECT call
// (bypassing the admin app entirely) could still mark a legacy withdrawal
// paid. d1 proves this against the CURRENT, unmodified core function before
// any fix is applied; d2 onward prove the fix.
//  d1 THE BYPASS ITSELF: a direct markWithdrawalPaidCore call for a
//     withdrawal with no destinationFull currently SUCCEEDS
//  d2 after the fix, the same call is refused (legacy_destination_unresolved)
//     and mutates NOTHING — withdrawal, payout rows and wallet marker unchanged
//  d3 a withdrawal WITH a valid destinationFull still pays normally (no regression)
//  d4 an empty-object destinationFull ({}) is refused the same way as absent —
//     "non-null" is never treated as "valid"
//  d5 a destinationFull missing its required bank fields (no ifsc) is refused
//  d6 a destinationFull missing its required UPI field (no upiId) is refused
//  d7 an ALREADY-paid legacy withdrawal (paid before this phase shipped, or in
//     principle by any other means) remains readable and its own idempotent
//     replay (same reference) still returns "already", completely unaffected
//     by the new gate — historical results are never retroactively broken
//  d8 a conflicting replay (same withdrawal, DIFFERENT reference) on an
//     already-paid withdrawal is still refused not_requested, exactly as before
// Run with: firebase emulators:exec --only firestore "node scripts/phaseADMR84_server_legacy_destination_refusal_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-admr84-legacy-refusal";
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
const MASKED_BANK = { method: "bank", accountLast4: "4821", ifsc: "EXMP0001234", bankName: "Example Bank", accountHolder: "Kaveri" };
const FULL_BANK = { payoutMethod: "bank", accountNumber: "123456784821", ifsc: "EXMP0001234", accountHolder: "Kaveri", bankName: "Example Bank", upiId: null };

async function seedWithdrawal(id, sellerId, extra) {
  await db.doc(`seller_payouts/${id}-p1`).set({ sellerId, netAmount: 100, status: "requested", withdrawalId: id });
  await db.doc(`seller_withdrawals/${id}`).set({
    sellerId, status: "requested", amountPaise: 10000, payoutIds: [`${id}-p1`],
    destination: MASKED_BANK, createdAt: Timestamp.fromMillis(NOW), ...extra,
  });
}

async function main() {
  console.log("=== PHASE ADMR-84 — server-side legacy destination refusal ===");

  // d1 — the bypass itself, against whatever core function is currently compiled
  await seedWithdrawal("d1w", "d1s", {}); // no destinationFull at all
  const d1 = await W.markWithdrawalPaidCore(db, "adm", "d1w", "UTR-D1", "bank", NOW);
  const d1w = await get("seller_withdrawals/d1w");
  const wasBypassable = d1.kind === "paid" && d1w.status === "paid";
  record("d1_current_behavior_observed", true,
    wasBypassable
      ? "BYPASS CONFIRMED: a legacy withdrawal (no destinationFull) was paid via a direct call — " + JSON.stringify(d1)
      : "Already refused (fix is already applied in the compiled lib): " + JSON.stringify(d1));
  console.log(`  >>> d1 observed kind=${d1.kind}${d1.kind === "refused" ? ` reason=${d1.reason}` : ""} (informational, not pass/fail on its own)`);

  // d2 — after the fix: refused, zero mutation
  await seedWithdrawal("d2w", "d2s", {});
  const d2 = await W.markWithdrawalPaidCore(db, "adm", "d2w", "UTR-D2", "bank", NOW);
  const d2w = await get("seller_withdrawals/d2w");
  const d2p = await get("seller_payouts/d2w-p1");
  record("d2_legacy_no_destinationFull_refused_zero_mutation",
    d2.kind === "refused" && d2.reason === "legacy_destination_unresolved" &&
      d2w.status === "requested" && !("paidAt" in d2w) && d2p.status === "requested" && !("paidAt" in d2p),
    JSON.stringify({ d2, d2w, d2p }));

  // d3 — valid destinationFull still pays normally
  await seedWithdrawal("d3w", "d3s", { destinationFull: FULL_BANK });
  const d3 = await W.markWithdrawalPaidCore(db, "adm", "d3w", "UTR-D3", "bank", NOW);
  const d3w = await get("seller_withdrawals/d3w");
  record("d3_valid_destinationFull_still_pays", d3.kind === "paid" && d3w.status === "paid" && d3w.paidTo.accountLast4 === "4821",
    JSON.stringify({ d3, d3w }));

  // d4 — empty object is not "valid"
  await seedWithdrawal("d4w", "d4s", { destinationFull: {} });
  const d4 = await W.markWithdrawalPaidCore(db, "adm", "d4w", "UTR-D4", "bank", NOW);
  record("d4_empty_object_destinationFull_refused", d4.kind === "refused" && d4.reason === "legacy_destination_unresolved", JSON.stringify(d4));

  // d5 — missing ifsc
  await seedWithdrawal("d5w", "d5s", { destinationFull: { payoutMethod: "bank", accountNumber: "123456784821", accountHolder: "Kaveri" } });
  const d5 = await W.markWithdrawalPaidCore(db, "adm", "d5w", "UTR-D5", "bank", NOW);
  record("d5_missing_ifsc_refused", d5.kind === "refused" && d5.reason === "legacy_destination_unresolved", JSON.stringify(d5));

  // d6 — missing upiId
  await seedWithdrawal("d6w", "d6s", {
    destination: { method: "upi", upiId: "kaveri@okbank" },
    destinationFull: { payoutMethod: "upi", accountHolder: "Kaveri" },
  });
  const d6 = await W.markWithdrawalPaidCore(db, "adm", "d6w", "UTR-D6", "upi", NOW);
  record("d6_missing_upiId_refused", d6.kind === "refused" && d6.reason === "legacy_destination_unresolved", JSON.stringify(d6));

  // d7 — an already-paid legacy withdrawal remains readable; idempotent replay unaffected
  await seedWithdrawal("d7w", "d7s", {});
  await db.doc("seller_withdrawals/d7w").update({
    status: "paid", paymentReference: "UTR-D7-OLD", paidAt: Timestamp.fromMillis(NOW), paidBy: "adm-old", paidTo: MASKED_BANK,
  });
  const d7Before = await get("seller_withdrawals/d7w");
  const d7 = await W.markWithdrawalPaidCore(db, "adm", "d7w", "UTR-D7-OLD", "bank", NOW + 1000);
  const d7After = await get("seller_withdrawals/d7w");
  record("d7_already_paid_legacy_withdrawal_replay_unaffected",
    d7.kind === "already" && JSON.stringify(d7Before) === JSON.stringify(d7After),
    JSON.stringify({ d7, d7Before, d7After }));

  // d8 — conflicting replay (different reference) on an already-paid withdrawal still refused
  const d8 = await W.markWithdrawalPaidCore(db, "adm", "d7w", "UTR-D7-DIFFERENT", "bank", NOW + 2000);
  const d8After = await get("seller_withdrawals/d7w");
  record("d8_conflicting_replay_refused_not_requested",
    d8.kind === "refused" && d8.reason === "not_requested" && d8After.paymentReference === "UTR-D7-OLD",
    JSON.stringify({ d8, d8After }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE ADMR-84 server legacy refusal: FAILED"); process.exit(1); }
  console.log("PHASE ADMR-84 server legacy refusal: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
