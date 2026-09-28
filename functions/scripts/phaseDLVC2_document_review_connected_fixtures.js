// Phase DLVC2 — fixtures for the FIRST genuinely connected document-review
// acceptance journey: real Firebase emulators (Auth+Firestore+Storage), the
// real RiderProfileScreen widget tree bound to the real
// CallableRiderDocumentReviewBackend (no injected fake), a real Firestore
// snapshot driving the pending/approved/rejected states, a real Storage
// upload for the staged replacement photo.
//
// Sign-in deliberately never touches the real phone-OTP UI (this
// repository's own recorded near-miss, agrimore-near-miss-real-otp-via-
// partial-emulator-isolation, says to always use the harness-bypass
// pattern instead) -- a custom token minted by this script signs
// FirebaseAuth in directly, reaching zero OTP code. Mirrors
// phaseDLVR2_active_delivery_fixtures.js's own seed shape exactly.
//
// One mode:
//   node phaseDLVC2_document_review_connected_fixtures.js seed <outFile>
//     Creates a rider and an admin user, mints a custom sign-in token for
//     each; writes {riderId, adminUid, tokenRider, tokenAdmin, projectId}
//     as JSON to <outFile>.
//
// Run with (Firestore AND Auth emulators, both needed for real sign-in):
//   firebase emulators:exec --only firestore,auth,storage \
//     "node scripts/phaseDLVC2_document_review_connected_fixtures.js seed <outFile>"
// Honours FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST.
const fs = require("fs");

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";

const admin = require("firebase-admin");
// Deliberately the REAL project id, NOT a nominal demo-* one -- matches
// phaseDLVR2_active_delivery_fixtures.js's own documented reason: this
// fixture is read back by a SEPARATE real app client (the Flutter app under
// test, initialized via firebase_options.dart's real agrimore-66a4e
// config), and single-project-mode does not coalesce Firestore documents
// across project-id paths.
const PROJECT_ID = "agrimore-66a4e";
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const RIDER_ID = "dlvc2-rider-1";
const ADMIN_UID = "dlvc2-admin";

async function seed(outFile) {
  await auth.createUser({ uid: RIDER_ID, phoneNumber: "+919876500001" }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${RIDER_ID}`).set({ role: "delivery_partner" });
  await db.doc(`delivery_partners/${RIDER_ID}`).set({
    status: "approved",
    name: "DLVC2 Rider",
    vehicleType: "bike",
    vehicleNumber: "TN59CD5678",
    kycDocuments: { aadhaarFront: `delivery_documents/${RIDER_ID}/aadhaarFront` },
  });

  await auth.createUser({ uid: ADMIN_UID, phoneNumber: "+919999900001" }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${ADMIN_UID}`).set({ role: "admin" });

  // Custom claims mirror phaseDLVR2's own established shape --
  // delivery_partner:true for the rider (not itself required by
  // riderDocumentReview.ts, which only checks request.auth.uid, but kept
  // for parity with every other rider fixture in this codebase and in case
  // a future rules change needs it), admin:true for the admin (this IS
  // required -- resolveIsAdmin's fast path, functions/src/admin/
  // complianceGate.ts:152).
  const tokenRider = await auth.createCustomToken(RIDER_ID, { delivery_partner: true, role: "delivery_partner" });
  const tokenAdmin = await auth.createCustomToken(ADMIN_UID, { admin: true, role: "admin" });

  const out = { riderId: RIDER_ID, adminUid: ADMIN_UID, tokenRider, tokenAdmin, projectId: PROJECT_ID };
  fs.writeFileSync(outFile, JSON.stringify(out, null, 2));
  console.log(`SEEDED — fixtures written to ${outFile}`);
}

async function main() {
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === "seed") {
    await seed(rest[0] || "/tmp/dlvc2_fixtures.json");
  } else {
    throw new Error(`unknown mode ${mode} -- expected "seed <outFile>"`);
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
