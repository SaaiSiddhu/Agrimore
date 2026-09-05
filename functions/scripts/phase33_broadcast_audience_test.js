// Phase FIX-10 — proves sendBroadcastNotification actually reaches a
// singular-fcmToken-only user (finding N-16) and that the paginated user
// scan (finding N-17) still produces the exact same totals a single
// unbounded read would have. Marketplace's own fix (an explicit post-login
// FCM token save, WS1) is a Dart change with no Node-side behavior to
// exercise here — verified instead by flutter analyze (0 errors) and by
// reading apps/marketplace/lib/providers/auth_provider.dart's four new
// call sites directly.
//
// admin.messaging().send() is monkey-patched — this suite must NEVER place
// a real call to Firebase Cloud Messaging. admin.messaging is a function
// re-invoked on every call site in the source (not cached at require time),
// so overriding it works regardless of when the override happens relative
// to require().
//
// Run with: firebase emulators:exec --only firestore
//             "node scripts/phase33_broadcast_audience_test.js"
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
if (admin.apps.length === 0) admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const sentTokens = [];
// Patching admin.messaging directly did not take effect: `messaging` is not
// an own property of the admin namespace object (confirmed via
// Object.getOwnPropertyDescriptor) — it is inherited, and the compiled
// source's own require of firebase-admin does not observe an own-property
// override made from a different reference to the same nominal module.
// Messaging.prototype.send IS shared across every reference to the class
// regardless of which variable holds the namespace object, so patching
// there is what actually intercepts the call.
const Messaging = admin.messaging().constructor;
Messaging.prototype.send = async function (msg) {
  sentTokens.push(msg.token);
  return "phase33-mocked-message-id";
};

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { sendBroadcastNotification } = require("../lib/admin/notifications");
const wrapped = test.wrap(sendBroadcastNotification);

async function call(payload, auth) {
  try {
    return { ok: true, result: await wrapped(payload, { auth }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

const ADMIN_AUTH = { uid: "phase33-admin", token: { admin: true } };
const BROADCAST_PAYLOAD = { title: "Phase 33 test", body: "hello" };

async function clearUsers(ids) {
  const batch = db.batch();
  for (const id of ids) batch.delete(db.collection("users").doc(id));
  await batch.commit();
}

async function main() {
  const results = {};
  let allPassed = true;
  const record = (k, p, d) => { results[k] = p; console.log(`${k}: ${p ? "PASSED" : "FAILED"} — ${d}`); if (!p) allPassed = false; };

  console.log("=== PHASE FIX-10 — broadcast audience and pagination ===");

  // WS2 — THE FINDING. A user whose token exists ONLY as the singular
  // fcmToken field (no array at all) must still be reached.
  {
    const ids = ["phase33-ws2-array-only", "phase33-ws2-singular-only", "phase33-ws2-both"];
    await clearUsers(ids);
    await db.collection("users").doc(ids[0]).set({ fcmTokens: ["tok-array-only"] });
    await db.collection("users").doc(ids[1]).set({ fcmToken: "tok-singular-only" });
    await db.collection("users").doc(ids[2]).set({ fcmToken: "tok-both-a", fcmTokens: ["tok-both-a", "tok-both-b"] });

    sentTokens.length = 0;
    const r = await call(BROADCAST_PAYLOAD, ADMIN_AUTH);
    const reached = (t) => sentTokens.includes(t);
    record("ws2_singular_only_user_is_reached_by_broadcast",
      r.ok && reached("tok-array-only") && reached("tok-singular-only") && reached("tok-both-a") && reached("tok-both-b"),
      `ok=${r.ok} sentTokens=${JSON.stringify(sentTokens)}`);
    await clearUsers(ids);
  }

  // WS3 — pagination must not change the totals a single unbounded read
  // would have produced. Page size forced to 2 (env override, unset in
  // production) so 5 seeded users span 3 pages (2 + 2 + 1) without needing
  // hundreds of documents.
  {
    process.env.BROADCAST_PAGE_SIZE_OVERRIDE = "2";
    const ids = ["phase33-ws3-u1", "phase33-ws3-u2", "phase33-ws3-u3", "phase33-ws3-u4", "phase33-ws3-u5"];
    await clearUsers(ids);
    for (const id of ids) await db.collection("users").doc(id).set({ fcmTokens: [`tok-${id}`] });

    sentTokens.length = 0;
    const r = await call(BROADCAST_PAYLOAD, ADMIN_AUTH);
    record("ws3_paginated_scan_reaches_every_user_across_multiple_pages",
      r.ok && r.result?.totalUsers === 5 && r.result?.totalTokens === 5 && r.result?.successCount === 5 && sentTokens.length === 5,
      `ok=${r.ok} totalUsers=${r.result?.totalUsers} totalTokens=${r.result?.totalTokens} successCount=${r.result?.successCount} sentTokens.length=${sentTokens.length}`);
    delete process.env.BROADCAST_PAGE_SIZE_OVERRIDE;
    await clearUsers(ids);
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) { console.error("PHASE 33: FAILED"); process.exit(1); }
  console.log("PHASE 33: ALL PASSED");
  process.exit(0);
}

main().catch((e) => { console.error("PHASE 33: harness error", e); process.exit(1); });
