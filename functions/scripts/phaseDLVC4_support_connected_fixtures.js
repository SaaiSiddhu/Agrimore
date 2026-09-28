// Phase DLVC4 — fixtures for the FIRST genuinely connected support-ticket
// acceptance journey (closure brief C2 5.2, section 7): real Firebase
// emulators (Auth+Firestore+Storage+Functions), the real HelpSupportScreen/
// SubmitSupportRequestScreen/SupportRequestStatusScreen/MySupportRequestsScreen
// widget tree bound to the real CallableRiderSupportBackend (no injected fake
// backend), the real submitSupportRequest/updateSupportRequest onCall
// callables. Mirrors phaseDLVC2_document_review_connected_fixtures.js's own
// seed shape exactly.
//
// Sign-in deliberately never touches the real phone-OTP UI (this
// repository's own recorded near-miss, agrimore-near-miss-real-otp-via-
// partial-emulator-isolation, says to always use the harness-bypass pattern
// instead) -- a custom token minted by this script signs FirebaseAuth in
// directly, reaching zero OTP code.
//
// A second rider (riderId2) is seeded for the cross-rider-denial / account-
// switch scenarios -- it needs only an Auth user and a token, never a
// delivery_partners profile doc: submitSupportRequestCore only requires that
// doc for a NEW submission, and this rider never submits one, only attempts
// to read/list rider 1's own tickets (a pure ownership-rule check).
//
// One mode:
//   node phaseDLVC4_support_connected_fixtures.js seed <outFile>
//     Creates two riders and an admin user, mints a custom sign-in token for
//     each; writes {riderId, riderId2, adminUid, tokenRider, tokenRider2,
//     tokenAdmin, projectId} as JSON to <outFile>.
//
// Run with (Firestore, Auth, Storage AND Functions emulators):
//   firebase emulators:exec --only firestore,auth,storage,functions \
//     "node scripts/phaseDLVC4_support_connected_fixtures.js seed <outFile>"
// Honours FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST.
const fs = require("fs");

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";

const admin = require("firebase-admin");
// Deliberately the REAL project id, NOT a nominal demo-* one -- matches
// phaseDLVC2/phaseDLVR2's own documented reason: this fixture is read back
// by a SEPARATE real app client (the Flutter app under test, initialized via
// firebase_options.dart's real agrimore-66a4e config), and single-project-
// mode does not coalesce Firestore documents across project-id paths.
const PROJECT_ID = "agrimore-66a4e";
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const RIDER_ID = "dlvc4-rider-1";
const RIDER_ID_2 = "dlvc4-rider-2";
const ADMIN_UID = "dlvc4-admin";

async function seed(outFile) {
  await auth.createUser({ uid: RIDER_ID, phoneNumber: "+919876500101" }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${RIDER_ID}`).set({ role: "delivery_partner" });
  await db.doc(`delivery_partners/${RIDER_ID}`).set({
    status: "approved",
    name: "DLVC4 Rider One",
    vehicleType: "bike",
    vehicleNumber: "TN59EF9012",
  });

  await auth.createUser({ uid: RIDER_ID_2, phoneNumber: "+919876500102" }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${RIDER_ID_2}`).set({ role: "delivery_partner" });
  // No delivery_partners doc for rider 2 -- this fixture never has rider 2
  // submit a ticket of their own, only attempt to read/list rider 1's.

  await auth.createUser({ uid: ADMIN_UID, phoneNumber: "+919999900002" }).catch((e) => {
    if (e.code !== "auth/uid-already-exists") throw e;
  });
  await db.doc(`users/${ADMIN_UID}`).set({ role: "admin" });

  const tokenRider = await auth.createCustomToken(RIDER_ID, { delivery_partner: true, role: "delivery_partner" });
  const tokenRider2 = await auth.createCustomToken(RIDER_ID_2, { delivery_partner: true, role: "delivery_partner" });
  const tokenAdmin = await auth.createCustomToken(ADMIN_UID, { admin: true, role: "admin" });

  const out = {
    riderId: RIDER_ID,
    riderId2: RIDER_ID_2,
    adminUid: ADMIN_UID,
    tokenRider,
    tokenRider2,
    tokenAdmin,
    projectId: PROJECT_ID,
  };
  fs.writeFileSync(outFile, JSON.stringify(out, null, 2));
  console.log(`SEEDED — fixtures written to ${outFile}`);
}

async function main() {
  const [mode, ...rest] = process.argv.slice(2);
  if (mode === "seed") {
    await seed(rest[0] || "/tmp/dlvc4_fixtures.json");
  } else {
    throw new Error(`unknown mode ${mode} -- expected "seed <outFile>"`);
  }
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
