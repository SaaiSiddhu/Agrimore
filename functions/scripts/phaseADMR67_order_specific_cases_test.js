// ============================================================
//  Phase ADMR-67 — order-specific support case relationships
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseADMR67_order_specific_cases_test.js"

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const {
  createSupportCase, linkSupportCaseRecord, unlinkSupportCaseRecord,
} = require("../lib/admin/supportCases");

const ADMIN1 = { uid: "oc-admin1", token: { admin: true, role: "admin" } };

async function call(fn, auth, data) {
  try {
    return { ok: true, res: await fn.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message, details: e.details };
  }
}

async function seed() {
  await db.doc("users/oc-admin1").set({ role: "admin" });
  await db.doc("users/oc-cust-real").set({ role: "user" });
  await db.doc("orders/oc-order-a").set({ orderNumber: "ORD-A" });
  await db.doc("orders/oc-order-b").set({ orderNumber: "ORD-B" });
}

async function casesLinkedToOrder(orderId) {
  const snap = await db.collection("support_cases")
    .where("linkedRecords", "array-contains", { type: "order", id: orderId })
    .orderBy("updatedAt", "desc")
    .get();
  return snap.docs;
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  await seed();

  // ── atomic initialLink at creation ──
  let orderACaseId;
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "Order A issue", category: "delivery_issue",
      primaryActor: { type: "customer", id: "oc-cust-real" },
      initialLink: { type: "order", id: "oc-order-a" },
      requestId: "oc-create-01",
    });
    orderACaseId = r.ok ? r.res.caseId : null;
    const doc = orderACaseId ? (await db.doc(`support_cases/${orderACaseId}`).get()).data() : null;
    const events = await db.collection("support_case_events").where("caseId", "==", orderACaseId).get();
    check(
      "o01_initial_link_recorded_atomically_at_creation",
      r.ok && doc?.linkedRecords?.length === 1 && doc.linkedRecords[0].type === "order" &&
        doc.linkedRecords[0].id === "oc-order-a" &&
        events.docs.some((d) => d.data().type === "created" && d.data().details?.initialLink?.id === "oc-order-a"),
      JSON.stringify({ r, doc })
    );
  }
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "t", category: "c", primaryActor: { type: "customer", id: "oc-cust-real" },
      initialLink: { type: "order", id: "does-not-exist" }, requestId: "oc-create-02",
    });
    check(
      "o02_initial_link_target_must_actually_exist",
      !r.ok && r.code === "invalid-argument" && r.details?.reason === "initial_link_target_not_found",
      JSON.stringify(r)
    );
  }
  {
    const r = await call(createSupportCase, ADMIN1, {
      title: "t", category: "c", primaryActor: { type: "customer", id: "oc-cust-real" },
      initialLink: { type: "not_a_real_type", id: "x" }, requestId: "oc-create-03",
    });
    check("o03_malformed_initial_link_refused", !r.ok && r.details?.reason === "bad_request", JSON.stringify(r));
  }
  {
    // A retry with the same requestId + same initialLink is a true replay,
    // never a second linkedRecords entry.
    const r2 = await call(createSupportCase, ADMIN1, {
      title: "Order A issue", category: "delivery_issue",
      primaryActor: { type: "customer", id: "oc-cust-real" },
      initialLink: { type: "order", id: "oc-order-a" },
      requestId: "oc-create-01",
    });
    const doc = (await db.doc(`support_cases/${orderACaseId}`).get()).data();
    check(
      "o04_replay_with_same_initial_link_never_duplicates_the_link",
      r2.ok && r2.res.alreadyApplied === true && r2.res.caseId === orderACaseId && doc.linkedRecords.length === 1,
      JSON.stringify({ r2, doc })
    );
  }

  // ── cross-order isolation: the real reason this phase exists ──
  {
    // A second case, linked to order B, from the SAME customer as order A's
    // own case above -- must never appear under order A's own query.
    const rB = await call(createSupportCase, ADMIN1, {
      title: "Order B issue", category: "product_issue",
      primaryActor: { type: "customer", id: "oc-cust-real" },
      initialLink: { type: "order", id: "oc-order-b" },
      requestId: "oc-create-orderb",
    });
    const forA = await casesLinkedToOrder("oc-order-a");
    const forB = await casesLinkedToOrder("oc-order-b");
    check(
      "o05_order_a_and_order_b_cases_never_leak_into_each_others_view_despite_same_customer",
      rB.ok && forA.length === 1 && forA[0].id === orderACaseId &&
        forB.length === 1 && forB[0].id === rB.res.caseId,
      JSON.stringify({ forA: forA.map((d) => d.id), forB: forB.map((d) => d.id) })
    );
  }

  // ── a case linked to two orders appears under both ──
  {
    const linkToB = await call(linkSupportCaseRecord, ADMIN1, {
      caseId: orderACaseId, link: { type: "order", id: "oc-order-b" }, expectedVersion: 1,
    });
    const forA = await casesLinkedToOrder("oc-order-a");
    const forB = await casesLinkedToOrder("oc-order-b");
    check(
      "o06_a_case_linked_to_two_orders_appears_under_both",
      linkToB.ok && forA.some((d) => d.id === orderACaseId) && forB.some((d) => d.id === orderACaseId),
      JSON.stringify({ linkToB, forA: forA.map((d) => d.id), forB: forB.map((d) => d.id) })
    );
  }

  // ── unlinking removes it from that order's own view immediately ──
  {
    const unlink = await call(unlinkSupportCaseRecord, ADMIN1, {
      caseId: orderACaseId, link: { type: "order", id: "oc-order-b" }, expectedVersion: 2,
    });
    const forB = await casesLinkedToOrder("oc-order-b");
    const forA = await casesLinkedToOrder("oc-order-a");
    check(
      "o07_unlinking_an_order_removes_it_from_that_orders_own_view",
      unlink.ok && !forB.some((d) => d.id === orderACaseId) && forA.some((d) => d.id === orderACaseId),
      JSON.stringify({ unlink, forB: forB.map((d) => d.id), forA: forA.map((d) => d.id) })
    );
  }

  const failed = Object.entries(results).filter(([, v]) => v !== "PASSED");
  console.log(`\n${Object.keys(results).length - failed.length}/${Object.keys(results).length} scenarios passed`);
  if (failed.length) {
    console.log("FAILURES:", failed.map(([k]) => k).join(", "));
    console.log("PHASE ADMR-67 (order-specific cases): FAILED");
    process.exitCode = 1;
  } else {
    console.log("PHASE ADMR-67 (order-specific cases): ALL PASSED");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
