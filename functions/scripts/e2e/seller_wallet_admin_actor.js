// SELLER-WALLET-1 end-to-end — plays the admin during the seller-app journey,
// through the SAME callables the admin app's Seller Payouts screen calls
// (markSellerWithdrawalPaid, reviewSellerPayoutChange), over HTTP to the
// LOCAL functions emulator with an Auth-emulator ID token.
//
// 1. waits for the seller's bank/UPI change request → approves it
// 2. waits for the seller's withdrawal → marks it paid with a test UTR
// Refuses unless every host is a local emulator.
const local = (v) => typeof v === "string" && /^(127\.0\.0\.1|localhost):\d+$/.test(v);
const FS = process.env.FIRESTORE_EMULATOR_HOST, AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST, FN = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
if (!local(FS) || !local(AUTH) || !local(FN)) { console.error("REFUSING: emulator hosts must be local"); process.exit(2); }
const admin = require("firebase-admin");
const PROJECT = process.env.GCLOUD_PROJECT || "agrimore-66a4e";
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const SELLER = "e2e-seller";
const TIMEOUT_MS = Number(process.env.ACTOR_TIMEOUT_MS || 600000);

async function idToken() {
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: "e2e-admin@example.com", password: "e2e-pass-123456", returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error(`admin sign-in failed: ${JSON.stringify(j).slice(0, 200)}`);
  return j.idToken;
}
async function call(name, data) {
  const r = await fetch(`http://${FN}/${PROJECT}/us-central1/${name}`, {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${await idToken()}` },
    body: JSON.stringify({ data }),
  });
  const j = await r.json();
  console.log(`${name} → ${r.status} ${JSON.stringify(j).slice(0, 300)}`);
  if (r.status !== 200) throw new Error(`${name} failed`);
  return j.result;
}
async function waitFor(label, query) {
  const until = Date.now() + TIMEOUT_MS;
  while (Date.now() < until) {
    const s = await query.get();
    if (!s.empty) return s.docs[0];
    await new Promise((r) => setTimeout(r, 1500));
  }
  throw new Error(`timed out waiting for ${label}`);
}

async function main() {
  const change = await waitFor("a payout change", db.collection("seller_payout_change_requests").where("sellerId", "==", SELLER).where("status", "==", "pending"));
  console.log(`seller asked to change payout details to ${change.data().payoutMethod} ${change.data().upiId || ""}`);
  await new Promise((r) => setTimeout(r, 4000)); // let the phone show "waiting for review"
  await call("reviewSellerPayoutChange", { requestId: change.id, approve: true });
  const w = await waitFor("a withdrawal", db.collection("seller_withdrawals").where("sellerId", "==", SELLER).where("status", "==", "requested"));
  console.log(`seller requested ₹${(w.data().amountPaise / 100).toFixed(2)} (${w.data().payoutCount} orders)`);
  await new Promise((r) => setTimeout(r, 4000));
  await call("markSellerWithdrawalPaid", { withdrawalId: w.id, reference: "UTRTEST123456", method: "upi" });
  const paid = (await db.doc(`seller_withdrawals/${w.id}`).get()).data();
  const payouts = await db.collection("seller_payouts").where("withdrawalId", "==", w.id).get();
  const notes = await db.collection(`users/${SELLER}/notifications`).get();
  console.log(JSON.stringify({ withdrawal: paid.status, paidTo: paid.paidTo, payoutsPaid: payouts.docs.every((d) => d.data().status === "paid"),
    notifications: notes.docs.map((d) => d.data().title) }));
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
