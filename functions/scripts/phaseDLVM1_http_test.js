// Phase DLV-M1 — the money callables over GENUINE HTTP.
//  h01 markRiderPayoutPaid: a rider is refused; admin pays and gets the bound
//      destination; a replay with the same reference is alreadyPaid
//  h02 recordRiderCashDeposit: the same requestId twice records once
//  h03 riderMoneySummary: a rider gets only the COD cash limit; a customer is refused
// Run with: firebase emulators:exec --only firestore,functions,auth --project demo-agrimore-dlvm1 \
//             "node scripts/phaseDLVM1_http_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlvm1";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const PW = "dlvm1-pass-1"; // emulator-only test account
const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
async function account(email, claims) {
  let u; try { u = await admin.auth().getUserByEmail(email); } catch { u = await admin.auth().createUser({ email, password: PW }); }
  if (claims) await admin.auth().setCustomUserClaims(u.uid, claims);
  const t = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password: PW, returnSecureToken: true }) }).then((r) => r.json());
  return { uid: u.uid, token: t.idToken };
}
async function call(name, token, data) {
  const res = await fetch(`${FN}/${name}`, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify({ data }) });
  const j = await res.json().catch(() => ({}));
  return { status: res.status, result: j.result, error: j.error };
}
async function main() {
  const rider = await account("dlvm1-r1@preview.test", { delivery_partner: true });
  const cust = await account("dlvm1-c1@preview.test", null);
  const boss = await account("dlvm1-admin@preview.test", { admin: true, role: "admin" });
  await db.doc(`users/${boss.uid}`).set({ role: "admin" });
  await db.doc(`delivery_partners/${rider.uid}`).set({ status: "approved", upiId: "rider1@okaxis" });
  await db.doc(`rider_accounts/${rider.uid}`).set({ riderId: rider.uid, cashHeldPaise: 50000, cashHeld: 500, earningsUnsettledPaise: 0, earningsUnsettled: 0 });
  await db.doc(`rider_payouts/${rider.uid}_2026-W39`).set({ riderId: rider.uid, weekKey: "2026-W39", amount: 812.4, amountPaise: 81240, status: "pending" });
  await db.doc("settings/rider_pay").set({ codCashLimit: 3000 });

  const pid = `${rider.uid}_2026-W39`;
  const byRider = await call("markRiderPayoutPaid", rider.token, { payoutId: pid, reference: "UTR555555", method: "upi" });
  const paid = await call("markRiderPayoutPaid", boss.token, { payoutId: pid, reference: "UTR555555", method: "upi" });
  const replay = await call("markRiderPayoutPaid", boss.token, { payoutId: pid, reference: "UTR555555", method: "upi" });
  const doc = (await db.doc(`rider_payouts/${pid}`).get()).data();
  record("h01_admin_only_bound_destination_replay_safe", byRider.error?.status === "PERMISSION_DENIED" && paid.result?.alreadyPaid === false &&
    replay.result?.alreadyPaid === true && doc.status === "paid" && doc.paidTo?.upiId === "rider1@okaxis" && doc.paidBy === boss.uid,
    JSON.stringify({ byRider, paid, replay }));

  const d1 = await call("recordRiderCashDeposit", boss.token, { riderId: rider.uid, amount: 120.5, reference: "RCPT-77", requestId: "dep_http_000001" });
  const d2 = await call("recordRiderCashDeposit", boss.token, { riderId: rider.uid, amount: 120.5, reference: "RCPT-77", requestId: "dep_http_000001" });
  const acc = (await db.doc(`rider_accounts/${rider.uid}`).get()).data();
  record("h02_same_request_id_records_once", d1.result?.alreadyRecorded === false && d2.result?.alreadyRecorded === true && acc.cashHeldPaise === 37950,
    JSON.stringify({ d1, d2, acc }));

  const s1 = await call("riderMoneySummary", rider.token, {});
  const s2 = await call("riderMoneySummary", cust.token, {});
  record("h03_summary_rider_only_limit_only", s1.result?.codCashLimit === 3000 && Object.keys(s1.result || {}).length === 1 &&
    s2.error?.status === "PERMISSION_DENIED", JSON.stringify({ s1, s2 }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
