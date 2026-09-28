// SELLER-WALLET-1 — seller wallet + payout-account changes
// (functions/src/seller/sellerWallet.ts) on the Firestore emulator.
//  w1 withdraw gathers every pending payout, exact to the paisa; payouts
//     become `requested`; the wallet records the open withdrawal
//  w2 a retried request id returns the first result; a second withdrawal
//     while one is open is refused; two concurrent taps make one withdrawal
//  w3 refused: below the minimum, nothing to withdraw, no bank/UPI on file
//  w4 paying is refused while a bank/UPI change is pending; approving the
//     change updates seller_payout_details, but the ALREADY-open withdrawal's
//     own destination stays frozen at what it was when requested (ADMR-77) --
//     paying it uses that frozen method/account, not the newly-approved one,
//     and marks every payout paid; a replay is "already"
//  w5 admin reject (reason required) puts the payouts back in the balance
//  w6 the seller can cancel their own open withdrawal, not someone else's
//  w7 settings holdDays keeps recent payouts out of the balance
//  w8 validation: bad IFSC / UPI refused; UPI lower-cased; bank fields dropped
//  w9 summary matches what a withdrawal would take
// Run with: firebase emulators:exec --only firestore "node scripts/phaseSWALLET1_wallet_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-swallet1-wallet";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: ${PROJECT} is not a demo- project`); process.exit(2); }
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const W = require("../lib/seller/sellerWallet");

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
const get = async (p) => (await db.doc(p).get()).data();
const NOW = Date.UTC(2026, 8, 24, 6, 0, 0);
const DAY = 86400000;

async function seller(id, details) {
  await db.doc(`sellers/${id}`).set({ shopName: id });
  if (details) await db.doc(`seller_payout_details/${id}`).set({ sellerId: id, ...details });
}
async function payout(id, sellerId, net, ageDays = 1, extra = {}) {
  await db.doc(`seller_payouts/${id}`).set({ sellerId, orderId: id, orderNumber: id.toUpperCase(), netAmount: net, status: "pending",
    createdAt: Timestamp.fromMillis(NOW - ageDays * DAY), ...extra });
}
const BANK = { payoutMethod: "bank", accountHolder: "Kaveri", bankName: "Example Bank", accountNumber: "123456784821", ifsc: "EXMP0001234" };

async function main() {
  console.log("=== PHASE SWALLET1 — wallet ===");
  await db.doc("settings/seller_wallet").delete();

  // w1
  await seller("sA", BANK);
  const nets = [551.1, 304.2, 0.1, 19.99, 127.37];
  for (let i = 0; i < nets.length; i++) await payout(`a${i}`, "sA", nets[i]);
  await payout("a-paid", "sA", 999, 1, { status: "paid" });
  const expectP = nets.reduce((s, n) => s + Math.round(n * 100), 0);
  const v1 = await W.requestWithdrawalCore(db, "sA", "req-aaaa-0001", NOW);
  const wId = v1.id;
  const w = await get(`seller_withdrawals/${wId}`);
  const rows = await Promise.all(nets.map((_, i) => get(`seller_payouts/a${i}`)));
  record("w1_exact_sum_and_payouts_requested", v1.kind === "requested" && v1.amountPaise === expectP && w.amountPaise === expectP &&
    w.payoutCount === 5 && rows.every((r) => r.status === "requested" && r.withdrawalId === wId) &&
    (await get("seller_payouts/a-paid")).status === "paid" && w.destination.accountLast4 === "4821" && !("accountNumber" in w.destination) &&
    w.destinationFull.accountNumber === "123456784821" && w.destinationFull.payoutMethod === "bank" && w.destinationFull.ifsc === "EXMP0001234",
    JSON.stringify({ v1, w }));
  record("w1b_wallet_marks_open_withdrawal", (await get("seller_wallets/sA")).openWithdrawal === wId, "");

  // w2
  const replay = await W.requestWithdrawalCore(db, "sA", "req-aaaa-0001", NOW + 1000);
  await payout("a-new", "sA", 200);
  const second = await W.requestWithdrawalCore(db, "sA", "req-aaaa-0002", NOW + 2000);
  record("w2_replay_already_and_second_refused", replay.kind === "already" && replay.amountPaise === expectP && second.reason === "withdrawal_open",
    JSON.stringify({ replay, second }));
  await seller("sC", BANK);
  for (let i = 0; i < 4; i++) await payout(`c${i}`, "sC", 150);
  const [c1, c2] = await Promise.all([
    W.requestWithdrawalCore(db, "sC", "req-cccc-0001", NOW), W.requestWithdrawalCore(db, "sC", "req-cccc-0002", NOW),
  ]);
  const cw = await db.collection("seller_withdrawals").where("sellerId", "==", "sC").get();
  record("w2b_concurrent_taps_make_one_withdrawal", cw.size === 1 && [c1, c2].filter((v) => v.kind === "requested").length === 1 &&
    cw.docs[0].data().amountPaise === 60000, JSON.stringify({ c1, c2, n: cw.size }));

  // w3
  await seller("sMin", BANK); await payout("m1", "sMin", 99.99);
  await seller("sNone", BANK);
  await seller("sNoDest", null); await payout("nd1", "sNoDest", 500);
  const below = await W.requestWithdrawalCore(db, "sMin", "req-mmmm-0001", NOW);
  const none = await W.requestWithdrawalCore(db, "sNone", "req-nnnn-0001", NOW);
  const nodest = await W.requestWithdrawalCore(db, "sNoDest", "req-dddd-0001", NOW);
  const notSeller = await W.requestWithdrawalCore(db, "ghost", "req-gggg-0001", NOW);
  const badId = await W.requestWithdrawalCore(db, "sMin", "x", NOW);
  record("w3_refusals", below.reason === "below_minimum" && none.reason === "nothing_to_withdraw" && nodest.reason === "no_destination" &&
    notSeller.reason === "not_a_seller" && badId.reason === "bad_request_id" && (await get("seller_payouts/m1")).status === "pending",
    JSON.stringify({ below, none, nodest, notSeller, badId }));

  // w4
  const ch = await W.requestPayoutChangeCore(db, "sA", { payoutMethod: "upi", upiId: "Kaveri@OKBANK", accountHolder: "Kaveri" }, NOW);
  const dup = await W.requestPayoutChangeCore(db, "sA", { payoutMethod: "upi", upiId: "k2@okbank" }, NOW);
  const blocked = await W.markWithdrawalPaidCore(db, "adm", wId, "UTR998877", "bank", NOW);
  const noReason = await W.reviewPayoutChangeCore(db, { adminUid: "adm" }, ch.id, false, "", NOW);
  const approved = await W.reviewPayoutChangeCore(db, { adminUid: "adm" }, ch.id, true, null, NOW);
  const det = await get("seller_payout_details/sA");
  // sA's approved change moved seller_payout_details to UPI, but wId itself
  // was requested against the ORIGINAL bank details -- its own destination
  // must stay frozen (ADMR-77): paying with the NEW (now-current) method is
  // refused, paying with the ORIGINAL (frozen) method succeeds and records
  // the ORIGINAL account, never the one seller_payout_details holds now.
  const wrongMethod = await W.markWithdrawalPaidCore(db, "adm", wId, "UTR998877", "upi", NOW);
  const paidV = await W.markWithdrawalPaidCore(db, "adm", wId, "UTR998877", "bank", NOW);
  const again = await W.markWithdrawalPaidCore(db, "adm", wId, "UTR998877", "bank", NOW + 5);
  const wPaid = await get(`seller_withdrawals/${wId}`);
  const pRows = await Promise.all(nets.map((_, i) => get(`seller_payouts/a${i}`)));
  record("w4a_change_blocks_payment_and_is_single", ch.kind === "requested" && dup.reason === "already_pending" &&
    blocked.reason === "payout_change_pending" && noReason.reason === "reason_required", JSON.stringify({ ch, dup, blocked, noReason }));
  record("w4b_approval_updates_details", approved.kind === "approved" && det.payoutMethod === "upi" && det.upiId === "kaveri@okbank" &&
    det.accountNumber === null && det.verifiedBy === "adm" && (await get("seller_wallets/sA")).payoutChangePending === null, JSON.stringify(det));
  record("w4c_paid_to_frozen_destination", wrongMethod.reason === "method_mismatch" && paidV.kind === "paid" && again.kind === "already" &&
    wPaid.status === "paid" && wPaid.paidTo.accountLast4 === "4821" && !("upiId" in wPaid.paidTo) &&
    wPaid.destinationFull.accountNumber === "123456784821" && wPaid.paymentReference === "UTR998877" &&
    pRows.every((r) => r.status === "paid" && r.paymentReference === "UTR998877" && r.paidBy === "adm" && r.payoutMethod === "bank") &&
    (await get("seller_wallets/sA")).openWithdrawal === null, JSON.stringify({ wrongMethod, paidV, again, wPaid }));

  // w5
  const w5 = await W.requestWithdrawalCore(db, "sA", "req-aaaa-0005", NOW);
  const rejNoReason = await W.closeWithdrawalCore(db, { adminUid: "adm" }, w5.id, "", NOW);
  const rej = await W.closeWithdrawalCore(db, { adminUid: "adm" }, w5.id, "Account name does not match", NOW);
  const back = await get("seller_payouts/a-new");
  const payAfterReject = await W.markWithdrawalPaidCore(db, "adm", w5.id, "UTR000001", "upi", NOW);
  const w5b = await W.requestWithdrawalCore(db, "sA", "req-aaaa-0006", NOW);
  record("w5_reject_returns_money_to_balance", w5.kind === "requested" && w5.amountPaise === 20000 && rejNoReason.reason === "reason_required" &&
    rej.kind === "rejected" && back.status === "pending" && !("withdrawalId" in back) && payAfterReject.reason === "not_requested" &&
    w5b.kind === "requested" && w5b.amountPaise === 20000, JSON.stringify({ w5, rej, back, w5b }));

  // w6
  const foreign = await W.closeWithdrawalCore(db, { sellerId: "sC" }, w5b.id, null, NOW);
  const cancel = await W.closeWithdrawalCore(db, { sellerId: "sA" }, w5b.id, null, NOW);
  record("w6_seller_cancels_own_only", foreign.reason === "not_yours" && cancel.kind === "cancelled" &&
    (await get("seller_payouts/a-new")).status === "pending" && (await get(`seller_withdrawals/${w5b.id}`)).status === "cancelled",
    JSON.stringify({ foreign, cancel }));

  // w7
  await db.doc("settings/seller_wallet").set({ holdDays: 3, minWithdrawal: 50 });
  await seller("sH", BANK);
  await payout("h-old", "sH", 100, 5); await payout("h-new", "sH", 400, 1);
  const sum = await W.walletSummaryCore(db, "sH", NOW);
  const wh = await W.requestWithdrawalCore(db, "sH", "req-hhhh-0001", NOW);
  record("w7_hold_days_keep_recent_payouts_back", sum.availablePaise === 10000 && sum.heldPaise === 40000 && sum.minWithdrawalPaise === 5000 &&
    wh.kind === "requested" && wh.amountPaise === 10000 && (await get("seller_payouts/h-new")).status === "pending",
    JSON.stringify({ sum, wh }));
  await db.doc("settings/seller_wallet").delete();

  // w8
  const bad = [
    W.validatePayoutDetails({ ...BANK, ifsc: "EXMP1001234" }), W.validatePayoutDetails({ ...BANK, accountNumber: "12ab" }),
    W.validatePayoutDetails({ payoutMethod: "upi", upiId: "no-at-sign" }), W.validatePayoutDetails({ payoutMethod: "cash" }),
  ];
  const upi = W.validatePayoutDetails({ payoutMethod: "upi", upiId: " Ka.Veri@OkBank ", accountNumber: "123456789" });
  const bank = W.validatePayoutDetails({ ...BANK, ifsc: "exmp0001234", accountNumber: "1234 5678 4821" });
  record("w8_validation", bad.every((b) => !b.ok) && upi.ok && upi.value.upiId === "ka.veri@okbank" && upi.value.accountNumber === null &&
    bank.ok && bank.value.ifsc === "EXMP0001234" && bank.value.accountNumber === "123456784821",
    JSON.stringify({ bad, upi, bank }));

  // w9
  await seller("sS", BANK);
  await payout("s1", "sS", 10.1); await payout("s2", "sS", 20.2);
  const s = await W.walletSummaryCore(db, "sS", NOW);
  const sw = await W.requestWithdrawalCore(db, "sS", "req-ssss-0001", NOW);
  const after = await W.walletSummaryCore(db, "sS", NOW);
  record("w9_summary_matches_withdrawal", s.availablePaise === 3030 && s.hasDestination === true && sw.reason === "below_minimum" &&
    after.availablePaise === 3030 && after.openWithdrawalId === null, JSON.stringify({ s, sw, after }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE SWALLET1 wallet: FAILED"); process.exit(1); }
  console.log("PHASE SWALLET1 wallet: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
