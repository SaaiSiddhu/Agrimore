// ============================================================
//  Phase SELLER-DELETE-1 — deleting a seller account removes seller data
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only storage,firestore,auth "node scripts/phaseSDEL1_seller_delete_test.js"
// Every service is pinned to its emulator below; the guard refuses to run
// otherwise, so auth.deleteUser / bucket deletes can never reach production.

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";
process.env.STORAGE_EMULATOR_HOST = "http://127.0.0.1:9199";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

for (const k of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_STORAGE_EMULATOR_HOST"]) {
  if (!String(process.env[k] || "").startsWith("127.0.0.1")) {
    console.error(`REFUSING: ${k} is not the local emulator`);
    process.exit(2);
  }
}

const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp({ projectId: "agrimore-66a4e", storageBucket: "agrimore-66a4e.appspot.com" });
const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { deleteUserData } = require("../lib/customer/deleteUserData");
const wrapped = test.wrap(deleteUserData);

async function main() {
  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const results = {};
  const check = async (name, fn) => {
    try { await fn(); results[name] = "PASSED"; } catch (e) { results[name] = `FAILED — ${e.message}`; }
    console.log(`${name}: ${results[name]}`);
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const call = async (uid) => {
    try { return { ok: true, r: await wrapped({}, { auth: { uid, token: {} } }) }; }
    catch (e) { return { ok: false, code: e.code, message: e.message }; }
  };
  const exists = async (path) => (await db.doc(path).get()).exists;
  const file = (p) => bucket.file(p).save(Buffer.from("x"), { contentType: "image/jpeg" });

  const S = "sdel1-seller";
  await admin.auth().createUser({ uid: S, phoneNumber: "+919000000001" });
  await db.doc(`users/${S}`).set({ role: "seller", name: "Ravi" });
  await db.doc(`users/${S}/settings/notifications`).set({ orders: true });
  await db.doc(`sellers/${S}`).set({ status: "approved", shopName: "Ravi Stores" });
  await db.doc(`seller_payout_details/${S}`).set({ accountNumber: "123456789012", ifsc: "SBIN0001" });
  await db.doc(`sellerRequests/${S}`).set({ status: "approved" });
  await db.doc(`ai_connections/${S}`).set({ provider: "gemini" });
  await db.doc(`seller_stats_daily/${S}_20260922`).set({ sellerId: S, day: "20260922", gross: 10 });
  await db.doc("products/sdel1-p").set({ name: "Rice", sellerId: S, isActive: true });
  await db.doc("products/sdel1-other/reviews/r1").set({ userId: S, userName: "Ravi", userAvatar: "https://a", rating: 4, createdAt: new Date() });
  await db.doc("orders/sdel1-o1").set({ sellerId: S, userId: "buyer", orderStatus: "processing", total: 100 });
  await db.doc("seller_payouts/sdel1-o0_s").set({ sellerId: S, status: "pending", netAmount: 90 });
  await file(`seller_documents/${S}/idProof_1.jpg`);
  await file(`seller_documents/${S}/shopPhoto_1.jpg`);
  await file(`sellers/${S}/storefront/logo_1.jpg`);
  await file("sellers/sdel1-other/storefront/logo_1.jpg");

  await check("d1_refused_while_orders_are_open", async () => {
    const r = await call(S);
    expect(!r.ok && r.code === "failed-precondition" && /fulfil/.test(r.message), JSON.stringify(r));
    expect(await exists(`sellers/${S}`), "deleted despite refusal");
  });

  await check("d2_refused_while_a_settlement_is_owed", async () => {
    await db.doc("orders/sdel1-o1").update({ orderStatus: "delivered" });
    const r = await call(S);
    expect(!r.ok && r.code === "failed-precondition" && /90\.00/.test(r.message), JSON.stringify(r));
  });

  await check("d3_deletes_seller_data_and_kyc_files", async () => {
    await db.doc("seller_payouts/sdel1-o0_s").update({ status: "paid", paymentReference: "UTR1" });
    const r = await call(S);
    expect(r.ok, JSON.stringify(r));
    for (const p of [`sellers/${S}`, `seller_payout_details/${S}`, `sellerRequests/${S}`, `ai_connections/${S}`,
      `seller_stats_daily/${S}_20260922`, `users/${S}/settings/notifications`, `users/${S}`]) {
      expect(!(await exists(p)), `${p} still exists`);
    }
    const [kyc] = await bucket.getFiles({ prefix: `seller_documents/${S}/` });
    const [store] = await bucket.getFiles({ prefix: `sellers/${S}/storefront/` });
    expect(kyc.length === 0 && store.length === 0, `files left: ${kyc.length + store.length}`);
  });

  await check("d4_other_sellers_files_untouched", async () => {
    const [other] = await bucket.getFiles({ prefix: "sellers/sdel1-other/storefront/" });
    expect(other.length === 1, `other seller's files: ${other.length}`);
  });

  await check("d5_products_hidden_not_deleted", async () => {
    const p = (await db.doc("products/sdel1-p").get()).data();
    expect(p && p.isActive === false && p.sellerDeleted === true, JSON.stringify(p));
  });

  await check("d6_reviews_anonymised_rating_kept", async () => {
    const r = (await db.doc("products/sdel1-other/reviews/r1").get()).data();
    expect(r.userName === "Deleted user" && r.userAvatar === "" && r.rating === 4, JSON.stringify(r));
  });

  await check("d7_financial_records_kept", async () => {
    expect(await exists("orders/sdel1-o1"), "order removed");
    expect(await exists("seller_payouts/sdel1-o0_s"), "settlement removed");
  });

  await check("d8_audit_and_auth", async () => {
    const a = (await db.doc(`account_deletion_audit/${S}`).get()).data();
    expect(a && a.wasSeller === true && a.hiddenProductsCount === 1 && a.deletedFilesCount === 3 && a.anonymizedReviewsCount === 1,
      JSON.stringify(a));
    let gone = false;
    try { await admin.auth().getUser(S); } catch (e) { gone = e.code === "auth/user-not-found"; }
    expect(gone, "auth user still exists");
  });

  await check("d9_retry_is_idempotent", async () => {
    const r = await call(S);
    expect(r.ok, JSON.stringify(r));
  });

  console.log("\n=== PHASE SELLER-DELETE-1 SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-DELETE-1: FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-DELETE-1: ALL PASSED");
  test.cleanup();
}
main().catch((e) => { console.error("harness error", e); process.exit(1); });
