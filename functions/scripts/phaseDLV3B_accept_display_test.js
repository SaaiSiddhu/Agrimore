// Phase DLV-3B — acceptDeliveryOffer writes the rider card the customer sees.
//
//  a01 the order gets deliveryPartner {id, name, phone, vehicleType,
//      vehicleNumber, photoUrl, rating} of the rider who accepted
//  a02 no KYC, bank or position field is ever copied onto the order (the
//      customer reads the order; the live position has its own document)
//  a03 missing optional fields become null, a missing name a neutral label
//  a04 a refused accept (offer expired) writes no rider card
//
// Run with:
//   firebase emulators:exec --only firestore "node scripts/phaseDLV3B_accept_display_test.js"
// Requires: npm run build. Honours FIRESTORE_EMULATOR_HOST.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "demo-dlv3b" });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");
const { acceptOfferCore } = require("../lib/delivery/dispatchCallables");

const results = [];
function record(label, pass, detail) {
  results.push({ label, pass });
  console.log(`${pass ? "PASSED" : "FAILED"} — ${label}${pass ? "" : ` :: ${detail}`}`);
}
const T0 = Date.now();

async function seed(orderId, riderId, partner, { expiresInMs = 30000 } = {}) {
  await db.collection("users").doc(riderId).set({ role: "delivery_partner" });
  await db.collection("delivery_partners").doc(riderId).set({ status: "approved", isOnline: true, ...partner });
  await db.collection("orders").doc(orderId).set({
    userId: "c1", sellerId: "s1", orderNumber: orderId.toUpperCase(),
    orderStatus: "ready_for_pickup", status: "ready_for_pickup", total: 300, paymentMethod: "cod",
  });
  await db.collection("delivery_requests").doc(`${orderId}_${riderId}`).set({
    orderId, riderId, partnerId: riderId, status: "offered", wave: 1,
    expiresAt: Timestamp.fromMillis(T0 + expiresInMs),
  });
}

async function main() {
  console.log("=== PHASE DLV-3B — rider card on accept ===");
  await seed("dlv3b-o1", "dlv3b-r1", {
    name: "Ravi Kumar", phone: "9000000001", vehicleType: "bike", vehicleNumber: "TN59AB1234",
    photoUrl: "https://example.invalid/ravi.jpg", rating: 4.6,
    // Things that must never reach the customer:
    aadhaarNumber: "123412341234", aadhaarFrontImage: "https://example.invalid/a.jpg",
    selfieImage: "https://example.invalid/selfie.jpg", licenseNumber: "TN5820230012345",
    bankAccountNumber: "001122334455", ifscCode: "SBIN0001234", upiId: "ravi@upi",
    currentLat: 9.9, currentLng: 78.1,
  });
  const v = await acceptOfferCore(db, "dlv3b-r1", "dlv3b-o1", T0 + 1000);
  const o = (await db.collection("orders").doc("dlv3b-o1").get()).data();
  const dp = o.deliveryPartner || {};
  record("a01_rider_card_written",
    v.kind === "accepted" && dp.id === "dlv3b-r1" && dp.name === "Ravi Kumar" && dp.phone === "9000000001" &&
    dp.vehicleType === "bike" && dp.vehicleNumber === "TN59AB1234" && dp.photoUrl === "https://example.invalid/ravi.jpg" &&
    dp.rating === 4.6 && o.orderStatus === "delivery_accepted",
    JSON.stringify({ v, dp }));
  const allowed = ["id", "name", "phone", "vehicleType", "vehicleNumber", "photoUrl", "rating"];
  const extra = Object.keys(dp).filter((k) => !allowed.includes(k));
  const flat = JSON.stringify(o);
  record("a02_no_kyc_bank_or_position_copied",
    extra.length === 0 && !/aadhaar|selfie|license|bank|ifsc|upi|currentLat|currentLng|123412341234|001122334455/i.test(flat),
    `extra=${extra} order=${flat.slice(0, 300)}`);

  await seed("dlv3b-o2", "dlv3b-r2", {});
  await acceptOfferCore(db, "dlv3b-r2", "dlv3b-o2", T0 + 1000);
  const dp2 = (await db.collection("orders").doc("dlv3b-o2").get()).data().deliveryPartner || {};
  record("a03_missing_fields_are_null_and_name_neutral",
    dp2.name === "Delivery partner" && dp2.phone === null && dp2.photoUrl === null && dp2.rating === null && dp2.vehicleNumber === null,
    JSON.stringify(dp2));

  await seed("dlv3b-o3", "dlv3b-r3", { name: "Late Rider" }, { expiresInMs: 1000 });
  const late = await acceptOfferCore(db, "dlv3b-r3", "dlv3b-o3", T0 + 5000);
  const o3 = (await db.collection("orders").doc("dlv3b-o3").get()).data();
  record("a04_refused_accept_writes_no_card",
    late.kind === "refused" && o3.deliveryPartner === undefined && !o3.deliveryPartnerId,
    JSON.stringify({ late, dp: o3.deliveryPartner }));

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length) { console.log("PHASE DLV-3B accept: FAILED"); process.exit(1); }
  console.log("PHASE DLV-3B accept: ALL PASSED");
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });
