// Phase BUSINESS-NETWORK-1 (slice 1) — proves two things against the real
// engines, never a passing compile alone:
//   A. the new firestore.rules `follows/{followId}` block, via
//      @firebase/rules-unit-testing (mirrors phase31_collection_coverage_test.js's
//      pattern exactly).
//   B. the new notifyFollowersOnNewProduct trigger, via GENUINE external
//      Firestore writes against the functions emulator (mirrors
//      phase41_fieldvalue_trigger_fix_test.js's pattern exactly -- never
//      test.wrap(), which does not reproduce the real trigger-dispatch path).
//
// Run with:
//   firebase emulators:exec --only firestore,functions,auth \
//     "node scripts/phase47_seller_follow_test.js"
// Requires: functions already built (npm run build).
const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");

function unprivilegedClaims(email) {
  return {
    email,
    role: "user",
    admin: false,
    seller: false,
    sellerApproved: false,
    delivery_partner: false,
    deliveryApproved: false,
    employee: false,
    employeeApproved: false,
  };
}

function adminClaims(email) {
  return { ...unprivilegedClaims(email), role: "admin", admin: true };
}

// ============================================================
// SECTION A — firestore.rules: follows/{followId}
// ============================================================
async function runRulesSection() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};
  const record = (k, p) => p.then(
    () => { results[k] = "PASSED"; console.log(`${k}: PASSED`); },
    (e) => { results[k] = `FAILED — ${e.message}`; console.log(`${k}: FAILED — ${e.message}`); }
  );

  try {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("follows").doc("p47-follower_p47-seller").set({
        followerId: "p47-follower", sellerId: "p47-seller", createdAt: new Date(),
      });
    });

    const followerDb = testEnv.authenticatedContext("p47-follower", unprivilegedClaims("follower@phase47-test.example")).firestore();
    const sellerDb = testEnv.authenticatedContext("p47-seller", unprivilegedClaims("seller@phase47-test.example")).firestore();
    const strangerDb = testEnv.authenticatedContext("p47-stranger", unprivilegedClaims("stranger@phase47-test.example")).firestore();
    const adminDb = testEnv.authenticatedContext("p47-admin", adminClaims("admin@phase47-test.example")).firestore();

    await record("f1a_positive_follower_can_read_own_follow_doc",
      assertSucceeds(followerDb.collection("follows").doc("p47-follower_p47-seller").get()));
    await record("f1b_positive_followed_seller_can_read_the_follow_doc",
      assertSucceeds(sellerDb.collection("follows").doc("p47-follower_p47-seller").get()));
    await record("f1c_negative_stranger_cannot_read_someone_elses_follow_doc",
      assertFails(strangerDb.collection("follows").doc("p47-follower_p47-seller").get()));
    await record("f1d_positive_admin_can_read_any_follow_doc",
      assertSucceeds(adminDb.collection("follows").doc("p47-follower_p47-seller").get()));
    await record("f1e_positive_can_create_a_self_attributed_follow",
      assertSucceeds(strangerDb.collection("follows").doc("p47-stranger_p47-seller").set({ followerId: "p47-stranger", sellerId: "p47-seller" })));
    await record("f1f_negative_cannot_create_a_follow_attributed_to_someone_else",
      assertFails(strangerDb.collection("follows").doc("p47-follower_p47-seller2").set({ followerId: "p47-follower", sellerId: "p47-seller2" })));
    await record("f1g_negative_cannot_follow_yourself",
      assertFails(sellerDb.collection("follows").doc("p47-seller_p47-seller").set({ followerId: "p47-seller", sellerId: "p47-seller" })));
    await record("f1h_negative_cannot_update_a_follow_doc",
      assertFails(followerDb.collection("follows").doc("p47-follower_p47-seller").update({ sellerId: "p47-hacked" })));
    await record("f1i_positive_follower_can_delete_own_follow_unfollow",
      assertSucceeds(strangerDb.collection("follows").doc("p47-stranger_p47-seller").delete()));
    await record("f1j_negative_stranger_cannot_delete_someone_elses_follow",
      assertFails(strangerDb.collection("follows").doc("p47-follower_p47-seller").delete()));
    await record("f1k_positive_admin_can_delete_any_follow",
      assertSucceeds(adminDb.collection("follows").doc("p47-follower_p47-seller").delete()));

    console.log("\n=== PHASE 47 SECTION A (rules) SUMMARY ===");
    const total = Object.keys(results).length;
    const passed = Object.values(results).filter((v) => v === "PASSED").length;
    for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
    console.log(`\n${passed}/${total} scenarios passed`);
    return passed === total;
  } finally {
    await testEnv.cleanup();
  }
}

// ============================================================
// SECTION B — notifyFollowersOnNewProduct trigger (genuine writes)
// ============================================================
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitFor(label, checkFn, { timeoutMs = 15000, intervalMs = 300 } = {}) {
  const deadline = Date.now() + timeoutMs;
  let lastResult;
  while (Date.now() < deadline) {
    lastResult = await checkFn();
    if (lastResult && lastResult.done) return lastResult;
    await sleep(intervalMs);
  }
  console.log(`FAILED — timed out waiting for: ${label}`);
  console.log("Last observed state:", JSON.stringify(lastResult, null, 2));
  return lastResult;
}

async function runTriggerSection() {
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  process.env.GCLOUD_PROJECT = "agrimore-66a4e";
  const admin = require("firebase-admin");
  admin.initializeApp({ projectId: "agrimore-66a4e" });
  const db = admin.firestore();

  let failures = 0;
  function check(label, condition, extra) {
    if (condition) {
      console.log(`PASSED — ${label}`);
    } else {
      failures++;
      console.log(`FAILED — ${label}`);
      if (extra !== undefined) console.log("  detail:", JSON.stringify(extra, null, 2));
    }
  }

  console.log("\n=== PHASE 47 SECTION B (trigger) ===");

  const sellerId = "p47t-seller";
  const followerId = "p47t-follower";
  const nonFollowerId = "p47t-nonfollower";
  const productId = "p47t-product-1";

  // Deliberately NO fcmTokens/fcmToken on either user doc: uniqueTokens()
  // then returns [] and the FCM-send loop never executes, so this probe
  // never reaches admin.messaging().send() at all -- sidestepping the same,
  // already-disclosed "no cloudmessaging.messages.create IAM permission in
  // this local emulator project" gap phase41_fieldvalue_trigger_fix_test.js's
  // own module comment documents for the identical send() call shape. This
  // proves the deterministic Firestore-write half of the trigger fully;
  // the actual FCM delivery cannot be exercised end-to-end in this
  // environment, disclosed rather than faked.
  await db.collection("users").doc(followerId).set({ uid: followerId, role: "user" });
  await db.collection("users").doc(nonFollowerId).set({ uid: nonFollowerId, role: "user" });
  await db.collection("sellers").doc(sellerId).set({ shopName: "Phase 47 Test Farm", status: "approved" });
  await db.collection("follows").doc(`${followerId}_${sellerId}`).set({
    followerId, sellerId, createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection("products").doc(productId).set({
    name: "Phase 47 Test Product",
    sellerId,
    categoryId: "general",
  });

  await waitFor(
    "notifyFollowersOnNewProduct: in-app notification written for the follower",
    async () => {
      const snap = await db
        .collection("users").doc(followerId).collection("notifications")
        .where("type", "==", "new_product")
        .where("data.productId", "==", productId)
        .get();
      if (snap.empty) return { done: false };
      return { done: true, doc: snap.docs[0].data() };
    }
  ).then((result) => {
    check(
      "follower got an in-app notification with real createdAt Timestamp and correct sellerId",
      !!(result && result.done && result.doc &&
         result.doc.createdAt && typeof result.doc.createdAt.toMillis === "function" &&
         result.doc.data && result.doc.data.sellerId === sellerId &&
         result.doc.title === "Phase 47 Test Farm"),
      result && result.doc
    );
  });

  // Give the trigger a moment to have finished any (non-)work for the
  // non-follower before asserting its absence -- the positive wait above
  // already guarantees the trigger has run to completion for this product.
  const nonFollowerSnap = await db
    .collection("users").doc(nonFollowerId).collection("notifications")
    .where("type", "==", "new_product")
    .get();
  check(
    "a user who does NOT follow the seller got no notification",
    nonFollowerSnap.empty,
    nonFollowerSnap.docs.map((d) => d.data())
  );

  // Followerless seller: the trigger's own early-return (`if
  // (followersSnap.empty) return null`) must not throw and must not write
  // anything for anyone.
  const followerlessSellerId = "p47t-followerless-seller";
  const followerlessProductId = "p47t-product-2";
  await db.collection("sellers").doc(followerlessSellerId).set({ shopName: "No Followers Farm", status: "approved" });
  await db.collection("products").doc(followerlessProductId).set({
    name: "Phase 47 Test Product 2",
    sellerId: followerlessSellerId,
    categoryId: "general",
  });
  await sleep(3000);
  const [followerNotifForProduct2, nonFollowerNotifForProduct2] = await Promise.all([
    db.collection("users").doc(followerId).collection("notifications")
      .where("data.productId", "==", followerlessProductId).get(),
    db.collection("users").doc(nonFollowerId).collection("notifications")
      .where("data.productId", "==", followerlessProductId).get(),
  ]);
  check(
    "a followerless seller's new product triggers no notification for either known test user (early-return path)",
    followerNotifForProduct2.empty && nonFollowerNotifForProduct2.empty,
    { followerDocs: followerNotifForProduct2.docs.map((d) => d.data()), nonFollowerDocs: nonFollowerNotifForProduct2.docs.map((d) => d.data()) }
  );

  return failures === 0;
}

async function main() {
  const rulesPassed = await runRulesSection();
  const triggerPassed = await runTriggerSection();

  console.log(`\n=== PHASE 47 OVERALL: ${rulesPassed && triggerPassed ? "ALL PASSED" : "FAILED"} ===`);
  process.exit(rulesPassed && triggerPassed ? 0 : 1);
}

main().catch((error) => {
  console.error("PHASE 47: harness error", error);
  process.exit(1);
});
