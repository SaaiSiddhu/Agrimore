// Phase DLV-A2 — a rider's account: contact edits and deletion, over GENUINE
// HTTP (functions emulator) with the real Storage emulator.
//
//  c01 updateRiderContact: bad values refused with problem keys; good ones saved
//  c02 a non-rider cannot use it
//  d01 deleteUserData refuses while an order is assigned (reason rider_active_order)
//  d02 … while customers' cash is held (rider_cash_held)
//  d03 … while pay is owed (rider_pay_owed: unsettled earnings or a pending statement)
//  d04 deletion: KYC files, profile, bank-change requests, offers and live
//      points gone; earnings/statements/cash ledger/incidents kept; the
//      rider's phone and position stripped from past orders; Auth user gone;
//      audit record says wasRider with counts only
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth,storage --project demo-agrimore-dlva2 \
//     "node scripts/phaseDLVA2_rider_account_http_test.js"
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
const PROJECT = process.env.GCLOUD_PROJECT || "demo-agrimore-dlva2";
if (!PROJECT.startsWith("demo-")) { console.error(`REFUSING: project ${PROJECT} is not a demo- project`); process.exit(2); }
const FN = `http://127.0.0.1:${process.env.FUNCTIONS_PORT || 5001}/${PROJECT}/us-central1`;
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const results = [];
const record = (label, pass, detail) => { results.push(pass); console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`); };
async function signUp(email) {
  const r = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, password: "dlva2-pass-1", returnSecureToken: true }),
  }).then((x) => x.json());
  return { uid: r.localId, token: r.idToken };
}
async function call(name, token, data) {
  const res = await fetch(`${FN}/${name}`, { method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify({ data }) });
  const j = await res.json().catch(() => ({}));
  return { status: res.status, result: j.result, error: j.error };
}
const exists = async (p) => (await db.doc(p).get()).exists;

async function main() {
  console.log("=== PHASE DLV-A2 — rider account over HTTP ===");
  const r = await signUp("dlva2-rider@preview.test");
  const cust = await signUp("dlva2-customer@preview.test");
  await db.doc(`users/${r.uid}`).set({ role: "delivery_partner", name: "Ravi", email: "dlva2-rider@preview.test" });
  await db.doc(`users/${cust.uid}`).set({ role: "user", name: "C" });
  await db.doc(`delivery_partners/${r.uid}`).set({ status: "approved", name: "Ravi", phone: "9876543210", aadhaarNumber: "234567890123",
    bankAccountNumber: "123456789012", ifscCode: "SBIN0001234", address: "old", city: "Madurai", pincode: "625020" });

  // ── contact ──
  let c = await call("updateRiderContact", r.token, { altPhone: "9876543210", address: "x", city: "M", pincode: "1" });
  record("c01a_bad_contact_refused_with_keys", c.error?.details?.reason === "invalid" &&
    ["altPhone", "address", "city", "pincode"].every((k) => c.error.details.problems.includes(k)), JSON.stringify(c));
  c = await call("updateRiderContact", r.token, { altPhone: "+91 91234 56789", address: "14, New Street", city: "Chennai", pincode: "600001" });
  const p1 = (await db.doc(`delivery_partners/${r.uid}`).get()).data();
  record("c01b_good_contact_saved_and_nothing_else", c.result?.success === true && p1.altPhone === "9123456789" &&
    p1.city === "Chennai" && p1.name === "Ravi" && p1.status === "approved", JSON.stringify(p1));
  c = await call("updateRiderContact", cust.token, { address: "14, New Street", city: "Chennai", pincode: "600001" });
  record("c02_non_rider_refused", c.error?.details?.reason === "not_a_rider" && !(await exists(`delivery_partners/${cust.uid}`)), JSON.stringify(c));

  // ── deletion refusals ──
  await db.doc("orders/a2-active").set({ deliveryPartnerId: r.uid, orderStatus: "picked_up", userId: cust.uid });
  let d = await call("deleteUserData", r.token, {});
  record("d01_refused_while_order_assigned", d.error?.details?.reason === "rider_active_order" && await exists(`delivery_partners/${r.uid}`), JSON.stringify(d.error));
  await db.doc("orders/a2-active").update({ orderStatus: "delivered", status: "delivered",
    deliveryPartner: { id: r.uid, name: "Ravi", phone: "9876543210", currentLat: 9.9, currentLng: 78.1 } });
  await db.doc(`rider_accounts/${r.uid}`).set({ riderId: r.uid, cashHeld: 250, earningsUnsettled: 0 });
  d = await call("deleteUserData", r.token, {});
  record("d02_refused_while_cash_held", d.error?.details?.reason === "rider_cash_held", JSON.stringify(d.error));
  await db.doc(`rider_accounts/${r.uid}`).set({ riderId: r.uid, cashHeld: 0, earningsUnsettled: 0 });
  await db.doc(`rider_payouts/${r.uid}_2026-W39`).set({ riderId: r.uid, status: "on_hold", amount: 120 });
  d = await call("deleteUserData", r.token, {});
  record("d03_refused_while_pay_owed", d.error?.details?.reason === "rider_pay_owed", JSON.stringify(d.error));
  await db.doc(`rider_payouts/${r.uid}_2026-W39`).update({ status: "paid", paymentReference: "UTR1" });

  // ── deletion ──
  for (const f of ["aadhaarFront", "aadhaarBack", "selfie", "license"]) {
    await bucket.file(`delivery_documents/${r.uid}/${f}`).save(Buffer.from([0xff, 0xd8, 0xff]), { contentType: "image/jpeg" });
  }
  await db.doc(`rider_bank_change_requests/a2-req`).set({ riderId: r.uid, bankAccountNumber: "999999999999", status: "pending" });
  await db.doc(`delivery_requests/a2-order_${r.uid}`).set({ riderId: r.uid, orderId: "a2-order", status: "expired" });
  await db.doc("delivery_tasks/a2-active").set({ riderId: r.uid, status: "delivered" });
  await db.doc("delivery_tasks/a2-active/live/rider").set({ lat: 9.9, lng: 78.1 });
  await db.doc(`rider_earnings/a2-active`).set({ riderId: r.uid, total: 30 });
  await db.doc(`rider_cash_ledger/a2-l1`).set({ riderId: r.uid, type: "deposit", amount: 250 });
  await db.doc(`rider_incidents/${r.uid}_x`).set({ riderId: r.uid, status: "resolved" });
  await db.doc(`rider_incident_limits/${r.uid}`).set({ recent: [] });
  d = await call("deleteUserData", r.token, {});
  const [files] = await bucket.getFiles({ prefix: `delivery_documents/${r.uid}/` });
  const order = (await db.doc("orders/a2-active").get()).data();
  const audit = (await db.doc(`account_deletion_audit/${r.uid}`).get()).data() || {};
  let authGone = false;
  try { await admin.auth().getUser(r.uid); } catch { authGone = true; }
  record("d04a_personal_data_removed", !d.error && files.length === 0 && !(await exists(`delivery_partners/${r.uid}`)) &&
    !(await exists("rider_bank_change_requests/a2-req")) && !(await exists(`delivery_requests/a2-order_${r.uid}`)) &&
    !(await exists("delivery_tasks/a2-active/live/rider")) && !(await exists(`rider_incident_limits/${r.uid}`)) &&
    !(await exists(`users/${r.uid}`)) && authGone, JSON.stringify({ err: d.error, files: files.length }));
  record("d04b_financial_and_safety_records_kept", await exists("rider_earnings/a2-active") && await exists(`rider_payouts/${r.uid}_2026-W39`) &&
    await exists("rider_cash_ledger/a2-l1") && await exists(`rider_accounts/${r.uid}`) && await exists(`rider_incidents/${r.uid}_x`), "");
  record("d04c_past_order_keeps_name_loses_phone_and_position", order.deliveryPartner.name === "Ravi" && order.deliveryPartner.id === r.uid &&
    order.deliveryPartner.phone === undefined && order.deliveryPartner.currentLat === undefined && order.deliveryPartnerDeleted === true, JSON.stringify(order.deliveryPartner));
  record("d04d_audit_counts_only", audit.wasRider === true && audit.deletedFilesCount === 4 && audit.riderAnonymizedOrdersCount === 1 &&
    !JSON.stringify(audit).includes("9876543210") && !JSON.stringify(audit).includes("Ravi"), JSON.stringify(audit));

  const failed = results.filter((x) => !x).length;
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed) { console.log("PHASE DLV-A2: FAILED"); process.exit(1); }
  console.log("PHASE DLV-A2: ALL PASSED"); process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
