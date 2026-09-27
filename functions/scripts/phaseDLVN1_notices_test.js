// Phase DLV-N1 — rider inbox notices (functions/src/delivery/riderNotices.ts),
// written to users/{riderId}/notifications with deterministic ids.
//  n01 presence sweep: an offline rider gets an inbox row (the push alone could be missed)
//  n02 admin assignment: the new rider and the rider it was taken from each get one
//  n03 weekly statements: a "statement ready" row that does not say money was sent
//  n04 markRiderPayoutPaid over HTTP: "Money sent" with amount, destination, reference; a replay adds nothing
//  n05 reviewRiderBankChange reject over HTTP: the reason reaches the rider
//  n06 updateDeliveryException resolve over HTTP: the rider is told what to do
//  n07 updateRiderIncident acknowledge over HTTP
//  n08 nothing lands in anyone else's inbox
// Run with: firebase emulators:exec --only firestore,functions,auth --project demo-agrimore-dlvn1 \
//             "node scripts/phaseDLVN1_notices_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlvn1";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const { sweepSilentRiders, notifyRiderAssignment } = require("../lib/delivery/riderPresence");
const { buildAllStatements } = require("../lib/delivery/riderMoney");
const { statementCutoff } = require("../lib/delivery/riderPay");
const PW = "dlvn1-pass-1"; // emulator-only test account
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
const inbox = async (uid) => (await db.collection(`users/${uid}/notifications`).get()).docs.map((d) => ({ id: d.id, ...d.data() }));

async function main() {
  const r1 = await account("dlvn1-r1@preview.test", { delivery_partner: true });
  const r2 = await account("dlvn1-r2@preview.test", { delivery_partner: true });
  const boss = await account("dlvn1-admin@preview.test", { admin: true, role: "admin" });
  await db.doc(`users/${boss.uid}`).set({ role: "admin" });
  for (const r of [r1, r2]) await db.doc(`users/${r.uid}`).set({ role: "delivery_partner" });
  const NOW = Date.now();

  // n01
  await db.doc(`delivery_partners/${r1.uid}`).set({ status: "approved", isOnline: true, upiId: "r1@okaxis",
    lastLocationUpdate: Timestamp.fromMillis(NOW - 20 * 60000), lastStatusUpdate: Timestamp.fromMillis(NOW - 20 * 60000) });
  const off = await sweepSilentRiders(db, NOW);
  let box = await inbox(r1.uid);
  record("n01_offline_recorded", off.includes(r1.uid) && box.some((n) => n.type === "rider_offline" && n.unread === true && n.audience === "rider"),
    JSON.stringify({ off, box }));

  // n02
  const before = { deliveryPartnerId: r2.uid, orderNumber: "ORD-77" };
  const after = { deliveryPartnerId: r1.uid, orderNumber: "ORD-77", deliveryAcceptedVia: "admin" };
  await notifyRiderAssignment(db, "o77", before, after);
  await notifyRiderAssignment(db, "o77", before, after); // a retried trigger
  box = await inbox(r1.uid);
  const box2 = await inbox(r2.uid);
  record("n02_assigned_and_unassigned_once", box.filter((n) => n.id === "assigned_o77").length === 1 &&
    box.find((n) => n.id === "assigned_o77").body.includes("ORD-77") && box2.filter((n) => n.id === "unassigned_o77").length === 1,
    JSON.stringify({ box, box2 }));

  // n03
  const { cutoffMs, weekKey } = statementCutoff(NOW);
  await db.doc(`rider_accounts/${r1.uid}`).set({ riderId: r1.uid, cashHeldPaise: 0, cashHeld: 0, earningsUnsettledPaise: 125550, earningsUnsettled: 1255.5 });
  await db.doc("rider_earnings/n03-o1").set({ riderId: r1.uid, total: 1255.5, totalPaise: 125550, statementId: null, createdAt: Timestamp.fromMillis(cutoffMs - 3600000) });
  await buildAllStatements(db, NOW);
  const pid = `${r1.uid}_${weekKey}`;
  box = await inbox(r1.uid);
  const st = box.find((n) => n.id === `statement_${pid}`);
  record("n03_statement_ready_not_money_sent", !!st && st.type === "statement_ready" && st.body.includes("₹1,255.50") &&
    st.body.includes("will be sent") && !/^Money sent|sent to (UPI|bank)/.test(st.body) && st.data.payoutId === pid, JSON.stringify(st ?? box));

  // n04
  const paid = await call("markRiderPayoutPaid", boss.token, { payoutId: pid, reference: "UTR909090", method: "upi" });
  await call("markRiderPayoutPaid", boss.token, { payoutId: pid, reference: "UTR909090", method: "upi" });
  box = await inbox(r1.uid);
  const sent = box.filter((n) => n.id === `payout_sent_${pid}`);
  record("n04_money_sent_with_destination_once", paid.result?.alreadyPaid === false && sent.length === 1 &&
    sent[0].body === "₹1,255.50 sent to UPI r1@okaxis. Reference UTR909090.", JSON.stringify({ paid, sent }));

  // n05
  const req = await db.collection("rider_bank_change_requests").add({ riderId: r1.uid, status: "pending", upiId: "new@okaxis", createdAt: Timestamp.now() });
  await db.doc(`rider_accounts/${r1.uid}`).set({ bankChangePending: req.id }, { merge: true });
  const rej = await call("reviewRiderBankChange", boss.token, { requestId: req.id, approve: false, reason: "UPI name does not match" });
  box = await inbox(r1.uid);
  const bn = box.find((n) => n.id === `bank_change_${req.id}`);
  record("n05_rejection_reason_reaches_rider", rej.result?.status === "rejected" && bn?.type === "bank_change_rejected" &&
    bn.body.includes("UPI name does not match"), JSON.stringify({ rej, bn }));
  // n05b (DLVBANK1): the notice carries the SPECIFIC request's own id, not
  // just a type -- what makes exact-request routing possible on the client.
  record("n05b_notice_carries_its_own_requestId", bn?.data?.requestId === req.id, JSON.stringify(bn));

  // n06
  await db.doc("orders/n06").set({ deliveryPartnerId: r1.uid, orderNumber: "ORD-606", orderStatus: "out_for_delivery", status: "out_for_delivery", paymentMethod: "cod", total: 200, userId: "c1" });
  const rep = await call("reportDeliveryException", r1.token, { orderId: "n06", requestId: "n06-req-0001", reason: "customer_unreachable", note: "No answer" });
  const exId = rep.result?.exceptionId;
  await call("updateDeliveryException", boss.token, { exceptionId: exId, action: "acknowledge" });
  const res = await call("updateDeliveryException", boss.token, { exceptionId: exId, action: "resolve", disposition: "returned_to_seller", resolution: "Customer cancelled on the phone." });
  box = await inbox(r1.uid);
  const pn = box.find((n) => n.id === `problem_${exId}`);
  record("n06_problem_resolution_tells_rider_what_to_do", res.result?.status === "resolved" && pn?.title === "Order #ORD-606: problem handled" &&
    pn.body === "Take the order back to the store.", JSON.stringify({ rep, res, pn }));

  // n07
  await db.doc("rider_incidents/n07").set({ incidentId: "n07", riderId: r1.uid, kind: "accident", status: "reported", createdAt: Timestamp.now() });
  const ack = await call("updateRiderIncident", boss.token, { incidentId: "n07", action: "acknowledge" });
  box = await inbox(r1.uid);
  record("n07_incident_acknowledged", ack.result?.status === "acknowledged" && box.some((n) => n.id === "incident_n07_ack"), JSON.stringify({ ack }));

  // n08
  const r2box = await inbox(r2.uid);
  const bossBox = (await inbox(boss.uid)).filter((n) => n.audience === "rider"); // admin order notices are not rider notices
  record("n08_no_notice_elsewhere", r2box.length === 1 && bossBox.length === 0, JSON.stringify({ r2box, bossBox }));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
