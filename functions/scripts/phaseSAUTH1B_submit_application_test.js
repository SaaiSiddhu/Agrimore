// ============================================================
//  Phase SELLER-AUTH-1b — submitSellerApplication callable
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore,storage "node scripts/phaseSAUTH1B_submit_application_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e", storageBucket: "agrimore-66a4e.appspot.com" });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const { submitSellerApplication, validateSellerApplication } = require("../lib/seller/sellerApplication");

function complete(uid, extra = {}) {
  return {
    userId: uid,
    status: "draft",
    name: "Ravi Kumar",
    shopName: "Ravi Stores",
    businessCategory: "vegetables",
    gstin: "",
    shopAddress: "12, Market Street, Anna Nagar",
    city: "Madurai",
    state: "Tamil Nadu",
    pincode: "625020",
    deliveryRadiusKm: 10,
    documents: {
      idProof: `seller_documents/${uid}/id_proof.jpg`,
      shopPhoto: `seller_documents/${uid}/shop_photo.jpg`,
    },
    payoutMethod: "bank",
    accountHolder: "Ravi Kumar",
    bankName: "State Bank of India",
    accountNumber: "123456789012",
    ifsc: "SBIN0001234",
    acceptedTerms: true,
    ...extra,
  };
}

async function call(uid, data = {}) {
  try {
    const res = await submitSellerApplication.run({ auth: uid ? { uid, token: {} } : undefined, data });
    return { ok: true, res };
  } catch (e) {
    return { ok: false, code: e.code, details: e.details };
  }
}

async function upload(path) {
  await bucket.file(path).save(Buffer.from("fake-jpeg"), { contentType: "image/jpeg" });
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  // ── pure validator ─────────────────────────────────────────────────────────
  check("v1_complete_application_has_no_problems",
    validateSellerApplication(complete("u1"), "u1").length === 0,
    JSON.stringify(validateSellerApplication(complete("u1"), "u1")));
  {
    const p = validateSellerApplication(complete("u1", { ifsc: "SBIN1234", pincode: "025020", gstin: "BADGST" }), "u1");
    check("v2_bad_ifsc_pincode_gstin_reported",
      p.includes("ifsc") && p.includes("pincode") && p.includes("gstin"), JSON.stringify(p));
  }
  {
    const p = validateSellerApplication(complete("u1", { documents: { idProof: "seller_documents/OTHER/x.jpg", shopPhoto: "x.jpg" } }), "u1");
    check("v3_documents_must_be_in_callers_own_folder",
      p.includes("documents.idProof") && p.includes("documents.shopPhoto"), JSON.stringify(p));
  }
  {
    const p = validateSellerApplication(complete("u1", { payoutMethod: "upi", upiId: "ravi@okaxis" }), "u1");
    check("v4_upi_payout_accepted", p.length === 0, JSON.stringify(p));
  }
  {
    const p = validateSellerApplication(complete("u1", { deliveryRadiusKm: 500, acceptedTerms: false }), "u1");
    check("v5_radius_cap_and_terms", p.includes("deliveryRadiusKm") && p.includes("acceptedTerms"), JSON.stringify(p));
  }
  check("v6_valid_gstin_accepted",
    validateSellerApplication(complete("u1", { gstin: "33ABCDE1234F1Z5" }), "u1").length === 0, "");

  // ── callable ───────────────────────────────────────────────────────────────
  {
    const r = await call(null);
    check("c1_unauthenticated_rejected", !r.ok && r.code === "unauthenticated", JSON.stringify(r));
  }
  {
    const r = await call("nobody");
    check("c2_no_application_not_found", !r.ok && r.code === "not-found", JSON.stringify(r));
  }
  {
    await db.collection("sellerRequests").doc("inc").set({ userId: "inc", status: "draft", shopName: "X" });
    const r = await call("inc");
    const doc = await db.collection("sellerRequests").doc("inc").get();
    check("c3_incomplete_rejected_with_problem_list_and_stays_draft",
      !r.ok && r.code === "invalid-argument" && Array.isArray(r.details?.problems) && r.details.problems.length > 3 &&
        doc.data().status === "draft",
      `code=${r.code} problems=${r.details?.problems?.length} status=${doc.data().status}`);
  }
  {
    await db.collection("sellerRequests").doc("nofiles").set(complete("nofiles"));
    const r = await call("nofiles");
    check("c4_documents_must_really_exist_in_storage",
      !r.ok && r.code === "invalid-argument" && r.details?.problems?.includes("documents.idProof"),
      JSON.stringify(r));
  }
  {
    const uid = "good";
    await db.collection("sellerRequests").doc(uid).set(complete(uid));
    await upload(`seller_documents/${uid}/id_proof.jpg`);
    await upload(`seller_documents/${uid}/shop_photo.jpg`);
    const r = await call(uid);
    const req = await db.collection("sellerRequests").doc(uid).get();
    const user = await db.collection("users").doc(uid).get();
    check("c5_complete_application_becomes_pending",
      r.ok && r.res.status === "pending" && req.data().status === "pending" &&
        req.data().appliedAt && user.data()?.sellerStatus === "pending",
      `ok=${r.ok} status=${req.data().status} user=${user.data()?.sellerStatus}`);

    const again = await call(uid);
    check("c6_resubmit_is_idempotent", again.ok && again.res.alreadySubmitted === true, JSON.stringify(again));
  }
  {
    await db.collection("sellerRequests").doc("appr").set(complete("appr", { status: "approved" }));
    const r = await call("appr");
    check("c7_approved_application_cannot_be_resubmitted", !r.ok && r.code === "failed-precondition", JSON.stringify(r));
  }
  {
    await db.collection("sellerRequests").doc("mismatch").set(complete("someoneElse"));
    const r = await call("mismatch");
    check("c8_userId_mismatch_denied", !r.ok && r.code === "permission-denied", JSON.stringify(r));
  }

  console.log("\n=== PHASE SELLER-AUTH-1b (callable) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-AUTH-1b (callable): FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-AUTH-1b (callable): ALL PASSED");
}

main().catch((e) => { console.error("harness error", e); process.exit(1); });
