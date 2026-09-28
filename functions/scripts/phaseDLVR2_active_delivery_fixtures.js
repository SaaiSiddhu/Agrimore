// Phase DLVR2 — fixtures for the FIRST genuinely connected active-delivery
// acceptance journey: real Firebase emulators (Auth+Firestore), the real
// ActiveOrderScreen widget tree, real Firestore snapshots -- not an
// injected fake stream, and not the real phone-OTP UI (this repository's
// own recorded near-miss says never drive that in a test; a minted custom
// token signs the app in instead, reaching zero OTP code).
//
// Two modes:
//   node phaseDLVR2_active_delivery_fixtures.js seed <outFile>
//     Creates Rider A, Rider B, an admin user, and one assigned order in
//     realistic shape; mints a custom sign-in token for each rider; writes
//     {riderA, riderB, orderId, tokenA, tokenB} as JSON to <outFile>.
//   node phaseDLVR2_active_delivery_fixtures.js reassign <orderId> <newRiderIdOrNull>
//     The admin-style action this phase's own journey exercises mid-test:
//     a direct, already-authorized Admin-SDK write changing the order's
//     deliveryPartnerId -- there is no dedicated admin-reassignment
//     callable anywhere in functions/src/admin (confirmed by grep before
//     writing this), so this mirrors exactly what firestore.rules' own
//     isAdmin() branch already authorizes without restriction: the actual
//     mechanism this schema provides for such an action today.
//
// Run with (Firestore AND Auth emulators, both needed for real sign-in):
//   firebase emulators:exec --only firestore,auth "node scripts/phaseDLVR2_active_delivery_fixtures.js seed <outFile>"
// Honours FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST.
const fs = require("fs");

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";

const admin = require("firebase-admin");
// Deliberately the REAL project id, NOT a nominal demo-* one: this fixture
// is read back by a SEPARATE real app client (the Flutter app under test,
// initialized via firebase_options.dart's real agrimore-66a4e config), not
// just by this same script -- confirmed by direct emulator evidence that
// "single project mode" does NOT coalesce Firestore documents across
// project-id paths (a nominal demo-dlvr2-active-delivery write was reachable
// under that exact project path but returned a rules "Null value error"
// (resource == null) when read back under agrimore-66a4e). Matches this
// codebase's own established convention for cross-boundary Admin-writes/
// client-reads fixtures (phaseSDEL1_seller_delete_test.js and others).
const PROJECT_ID = "agrimore-66a4e";
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const RIDER_A = "dlvr2-rider-a";
const RIDER_B = "dlvr2-rider-b";
const ADMIN_UID = "dlvr2-admin";
const ORDER_ID = "dlvr2-order-1";
const STORE = { lat: 9.9252, lng: 78.1198 };
const HOME = { lat: 9.8982, lng: 78.1198 };

async function seedRider(uid) {
  await auth.createUser({ uid, phoneNumber: `+91${uid.slice(-9).padStart(9, "9")}` }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${uid}`).set({ role: "delivery_partner" });
  await db.doc(`delivery_partners/${uid}`).set({
    status: "approved",
    name: uid === RIDER_A ? "Rider A" : "Rider B",
    vehicleType: "bike",
    vehicleNumber: "TN59AB1234",
  });
}

async function seed(outFile) {
  await seedRider(RIDER_A);
  await seedRider(RIDER_B);
  await auth.createUser({ uid: ADMIN_UID, phoneNumber: "+919999900000" }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${ADMIN_UID}`).set({ role: "admin" });

  // A realistic in-progress order, assigned to Rider A, matching the exact
  // orderStatus values DeliveryTaskStatus.riderActiveOrderStatuses expects
  // (out_for_delivery) so it genuinely appears in the app's own real
  // activeOrders query -- not a shortcut, the same production contract
  // firestoreActiveWork() reads.
  await db.doc(`orders/${ORDER_ID}`).set({
    userId: "dlvr2-customer",
    sellerId: "dlvr2-seller",
    orderNumber: "AGM-DLVR2-1",
    total: 350,
    paymentMethod: "cod",
    paymentStatus: "pending",
    orderStatus: "out_for_delivery",
    status: "out_for_delivery",
    deliveryPartnerId: RIDER_A,
    items: [
      { productName: "Tomatoes 1kg", quantity: 2, price: 40 },
      { productName: "Rice 5kg", quantity: 1, price: 270 },
    ],
    deliveryAddress: {
      name: "Meenakshi Sundaram",
      phone: "+919876543210",
      addressLine1: "44, West Masi Street",
      city: "Madurai",
      zipcode: "625001",
      latitude: HOME.lat,
      longitude: HOME.lng,
    },
    createdAt: admin.firestore.Timestamp.now(),
  });
  // delivery_tasks' own field is riderId, NOT deliveryPartnerId (that name
  // is orders' own field) -- confirmed against the real sync function,
  // functions/src/delivery/syncDeliveryTask.ts:98 (`riderId: str(order.
  // deliveryPartnerId)`), and against firestore.rules' own delivery_tasks
  // read rule (`resource.data.riderId == request.auth.uid`). Using the
  // wrong field here silently denied the rider's own route/live-tracking
  // read -- found via a genuine permission-denied surfaced by this exact
  // connected test, not a documentation guess.
  await db.doc(`delivery_tasks/${ORDER_ID}`).set({
    orderId: ORDER_ID,
    pickup: STORE,
    drop: HOME,
    riderId: RIDER_A,
  });
  await db.doc(`sellers/dlvr2-seller`).set({ shopName: "Fresh Fields Madurai" });

  // Custom claims mirror this codebase's own established rules-test shape
  // (phaseDLV4A_rules_test.js CLAIMS.delivery/.admin) -- delivery_partner:
  // true / admin: true are the exact claims firestore.rules' own
  // isDeliveryPartner()/isAdmin() check first.
  const tokenA = await auth.createCustomToken(RIDER_A, { delivery_partner: true, role: "delivery_partner" });
  const tokenB = await auth.createCustomToken(RIDER_B, { delivery_partner: true, role: "delivery_partner" });
  const tokenAdmin = await auth.createCustomToken(ADMIN_UID, { admin: true, role: "admin" });

  const out = {
    riderA: RIDER_A, riderB: RIDER_B, orderId: ORDER_ID, tokenA, tokenB, tokenAdmin, adminUid: ADMIN_UID, projectId: PROJECT_ID,
  };
  fs.writeFileSync(outFile, JSON.stringify(out, null, 2));
  console.log(`SEEDED — fixtures written to ${outFile}`);
}

async function reassign(orderId, newRiderIdOrNull) {
  const newRiderId = newRiderIdOrNull === "null" ? null : newRiderIdOrNull;
  await db.doc(`orders/${orderId}`).update({ deliveryPartnerId: newRiderId });
  if (newRiderId) {
    await db.doc(`delivery_tasks/${orderId}`).update({ riderId: newRiderId });
  }
  console.log(`REASSIGNED — orders/${orderId}.deliveryPartnerId -> ${newRiderId}`);
}

async function main() {
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === "seed") {
    await seed(rest[0] || "/tmp/dlvr2_fixtures.json");
  } else if (mode === "reassign") {
    await reassign(rest[0], rest[1]);
  } else {
    throw new Error(`unknown mode ${mode} -- expected "seed <outFile>" or "reassign <orderId> <newRiderIdOrNull>"`);
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
