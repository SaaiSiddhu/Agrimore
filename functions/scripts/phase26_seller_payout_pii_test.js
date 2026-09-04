// Phase FIX-2 — proves seller payout data is no longer readable by the world.
//
// Finding N-2 (P0): `firestore.rules` `match /sellers/{sellerId}` is
// `allow read: if true` — deliberately public, because the marketplace
// storefront shows seller profiles to logged-out visitors. apps/admin's
// approval flow copied `bankName`, `accountNumber` and `ifsc` out of
// `sellerRequests` into that same publicly readable document, so every approved
// seller's bank account number and IFSC could be read by anyone who knew the
// project id, over the REST API, with no authentication at all.
//
// Payout data now lives in the top-level `seller_payout_details/{sellerId}`:
// read owner-or-admin, write admin-only.
//
// The load-bearing scenario here is scenario 1 — an UNAUTHENTICATED read. Every
// other access check in this repository's rules suites starts from
// `authenticatedContext(uid)`; the N-2 exposure was specifically reachable with
// no credential whatsoever, so it has to be tested from
// `unauthenticatedContext()` or it is not being tested at all.
//
// Scenario 7 is a regression control in the opposite direction: `sellers/{id}`
// must STILL be world-readable. Tightening it would have "fixed" N-2 by
// breaking the logged-out storefront, and a suite that only asserts denials
// would have called that a pass.
//
// Run with:
//   firebase emulators:exec --only firestore \
//     "node scripts/phase26_seller_payout_pii_test.js"
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const SELLER = "phase26-seller-1";
const OTHER = "phase26-other-user";
const ADMIN = "phase26-admin";

// roleClaims.ts's buildClaims() always returns the full claim set; mirroring it
// keeps these contexts shaped like real production tokens.
const sellerToken = { role: "seller", admin: false, seller: true, sellerApproved: true };
const otherToken = { role: "user", admin: false, seller: false };
const adminToken = { role: "admin", admin: true };

async function main() {
  const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
  const testEnv = await initializeTestEnvironment({
    projectId: "agrimore-66a4e",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });

  const results = {};
  let allPassed = true;
  const record = (key, passed, detail) => {
    results[key] = passed;
    console.log(`${key}: ${passed ? "PASSED" : "FAILED"} — ${detail}`);
    if (!passed) allPassed = false;
  };

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection("users").doc(SELLER).set({ role: "seller", sellerStatus: "approved" });
      await db.collection("users").doc(OTHER).set({ role: "user" });
      await db.collection("users").doc(ADMIN).set({ role: "admin" });

      // The public profile — deliberately WITHOUT payout fields, which is the
      // whole point of the phase.
      await db.collection("sellers").doc(SELLER).set({
        userId: SELLER,
        status: "approved",
        name: "Phase26 Seller",
        shopName: "Phase26 Shop",
        shopAddress: "1 Test Street",
      });

      // The payout document, in its own collection.
      await db.collection("seller_payout_details").doc(SELLER).set({
        sellerId: SELLER,
        bankName: "Test Bank",
        accountNumber: "000000000000",
        ifsc: "TEST0000001",
      });
    });

    const anon = testEnv.unauthenticatedContext();
    const owner = testEnv.authenticatedContext(SELLER, sellerToken);
    const other = testEnv.authenticatedContext(OTHER, otherToken);
    const admin = testEnv.authenticatedContext(ADMIN, adminToken);

    const payoutRef = (ctx) => ctx.firestore().collection("seller_payout_details").doc(SELLER);
    const sellerRef = (ctx) => ctx.firestore().collection("sellers").doc(SELLER);

    // 1 — THE FINDING. No credential at all.
    try {
      await assertFails(payoutRef(anon).get());
      record("scenario1_N2_unauthenticated_read_of_payout_details_denied", true,
        "anonymous read refused by the rules engine");
    } catch (e) {
      record("scenario1_N2_unauthenticated_read_of_payout_details_denied", false,
        `anonymous read SUCCEEDED — N-2 is still open: ${e.message}`);
    }

    // 2 — a signed-in user who is neither the owner nor an admin.
    try {
      await assertFails(payoutRef(other).get());
      record("scenario2_other_signed_in_user_read_denied", true, "refused");
    } catch (e) {
      record("scenario2_other_signed_in_user_read_denied", false, `SUCCEEDED: ${e.message}`);
    }

    // 3 — the owner can still see their own bank details (the seller app's
    // Bank Details card depends on this).
    try {
      await assertSucceeds(payoutRef(owner).get());
      record("scenario3_owner_read_allowed", true, "owner read allowed");
    } catch (e) {
      record("scenario3_owner_read_allowed", false, `owner was DENIED: ${e.message}`);
    }

    // 4 — an admin can read any seller's payout details (support/payout ops).
    try {
      await assertSucceeds(payoutRef(admin).get());
      record("scenario4_admin_read_allowed", true, "admin read allowed");
    } catch (e) {
      record("scenario4_admin_read_allowed", false, `admin was DENIED: ${e.message}`);
    }

    // 5 — write is admin-only: the seller must NOT be able to rewrite their own
    // payout account. A seller who can set their own accountNumber can redirect
    // their payouts, and so can anyone who takes over their session.
    try {
      await assertFails(payoutRef(owner).set({ accountNumber: "999999999999" }, { merge: true }));
      record("scenario5_owner_write_denied", true, "owner write refused (admin-only)");
    } catch (e) {
      record("scenario5_owner_write_denied", false, `owner WROTE their own payout account: ${e.message}`);
    }

    // 6 — the admin approval flow must still work.
    try {
      await assertSucceeds(
        payoutRef(admin).set({ bankName: "Updated Bank" }, { merge: true })
      );
      record("scenario6_admin_write_allowed", true, "admin write allowed");
    } catch (e) {
      record("scenario6_admin_write_allowed", false, `admin was DENIED: ${e.message}`);
    }

    // 7 — REGRESSION CONTROL, the opposite direction. sellers/{id} must stay
    // world-readable; the logged-out storefront depends on it. Without this,
    // tightening `sellers` to owner-only would have passed scenarios 1-6 while
    // breaking every anonymous visitor.
    try {
      await assertSucceeds(sellerRef(anon).get());
      record("scenario7_control_public_seller_profile_still_readable", true,
        "anonymous read of sellers/{id} still allowed");
    } catch (e) {
      record("scenario7_control_public_seller_profile_still_readable", false,
        `the public storefront read BROKE: ${e.message}`);
    }

    // 8 — SOURCE GUARD, and the only scenario here that can actually catch a
    // regression of N-2.
    //
    // Every rules scenario above tests the ACCESS MODEL of the new collection.
    // None of them can catch the original defect coming back, because the
    // original defect was not a permissive rule — `sellers/{id}` being world-
    // readable is intended. The defect was that the admin approval flow WROTE
    // payout fields into that public document. A rules suite cannot see that; it
    // can only see the documents the suite itself seeded. (An earlier version of
    // this scenario asserted that the seeded `sellers/{id}` had no payout
    // fields, which asserted something about the fixture, not about the code.)
    //
    // So this reads the approval source and fails if a payout field name
    // reappears inside the `sellers` write. Same class as
    // phase19_client_secret_guard / phase23_deploy_bundle_guard: a static check
    // that guards a property no runtime test can observe.
    try {
      const approvalPath = path.join(
        __dirname, "..", "..",
        "apps/admin/lib/screens/admin/sellers/seller_requests_management_screen.dart"
      );
      const src = fs.readFileSync(approvalPath, "utf8");
      // The batch.set targeting sellerRef, up to its closing SetOptions.
      const m = /batch\.set\(\s*sellerRef,\s*\{([\s\S]*?)\},\s*SetOptions/m.exec(src);
      if (!m) {
        record("scenario8_source_guard_no_payout_fields_written_to_public_sellers", false,
          "could not locate the sellerRef batch.set block — the guard cannot verify anything, treat as FAIL");
      } else {
        const block = m[1];
        const leaked = ["bankName", "accountNumber", "ifsc", "panNumber", "upiId"]
          .filter((k) => block.includes(k));
        record("scenario8_source_guard_no_payout_fields_written_to_public_sellers",
          leaked.length === 0,
          leaked.length === 0
            ? "the sellers write carries no payout field names"
            : `REGRESSION — payout fields written to the world-readable sellers doc: ${leaked.join(", ")}`);
      }
    } catch (e) {
      record("scenario8_source_guard_no_payout_fields_written_to_public_sellers", false, e.message);
    }
  } finally {
    await testEnv.cleanup();
  }

  console.log("\n=== SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter(Boolean).length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (!allPassed) {
    console.error("PHASE 26: FAILED");
    process.exit(1);
  }
  console.log("PHASE 26: ALL PASSED");
  process.exit(0);
}

main().catch((e) => {
  console.error("PHASE 26: harness error", e);
  process.exit(1);
});
