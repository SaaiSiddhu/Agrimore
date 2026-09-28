// ============================================================
//  Shared local-emulator configuration (ADMR-76)
// ============================================================
//
// One source of truth for the project id, Storage bucket and every
// emulator host/port, so a Node test script and the actual compiled admin
// app (apps/admin/lib/firebase_options.dart, apps/admin/lib/main.dart's own
// ADMR-75 dart-defines) can never silently disagree the way they did
// before this phase: every prior Storage-touching script in this
// directory (ADMR-65/71/72/74) hardcoded `agrimore-66a4e.appspot.com`,
// which does not match the REAL compiled app's own bucket
// (`agrimore-66a4e.firebasestorage.app`, confirmed by reading
// firebase_options.dart directly) -- invisible until a genuinely different
// client (a real browser session) touched the same emulator instance.
//
// Every port below matches this repo's own firebase.json defaults; a
// script may still override FIRESTORE_EMULATOR_HOST's own PORT via its own
// env var when Docker holds 8080 (the established workaround this session
// uses throughout), but the PROJECT ID and BUCKET NAME are never
// overridable -- there is exactly one correct value for each, and
// silently drifting from it is the defect this module exists to prevent.

const PROJECT_ID = "agrimore-66a4e";
const STORAGE_BUCKET = "agrimore-66a4e.firebasestorage.app";

/** Sets the standard FIREBASE_*_EMULATOR_HOST / GCLOUD_PROJECT env vars.
 * Call this BEFORE requiring firebase-admin or any compiled function. */
function applyEmulatorEnv({
  firestorePort = 8080,
  authPort = 9099,
  storagePort = 9199,
  functionsPort = 5001,
  host = "127.0.0.1",
} = {}) {
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || `${host}:${firestorePort}`;
  process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || `${host}:${authPort}`;
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || `${host}:${storagePort}`;
  process.env.STORAGE_EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST || `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}`;
  process.env.GCLOUD_PROJECT = PROJECT_ID;
}

/** The one firebase-admin initializeApp() config every script should use. */
function adminAppConfig() {
  return { projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET };
}

module.exports = { PROJECT_ID, STORAGE_BUCKET, applyEmulatorEnv, adminAppConfig };
