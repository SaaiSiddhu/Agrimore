// ============================================================
//  Phase ADMR-69 — real-emulator pagination verification
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseADMR69_pagination_emulator_test.js"
//
// SCOPE, disclosed precisely: proves the FIRESTORE-LEVEL contract
// PaginatedQueryList's own cursor logic (.limit(pageSize) then
// .startAfterDocument(lastDoc), same orderBy) depends on, directly
// against a real emulator -- refuting the exact fake_cloud_firestore bug
// (agrimore-fake-cloud-firestore-second-page-empty) that has made this
// specific behavior untestable in every widget test all session. Does
// NOT drive the actual Dart widget class -- that would need a
// flutter integration_test on a real device/simulator, a genuinely new
// testing infrastructure not attempted here.

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const PAGE_SIZE = 10;

async function seedCase(id, { updatedAt, includeUpdatedAt = true }) {
  const doc = {
    caseId: id,
    title: `case ${id}`,
    category: "c",
    primaryActor: { type: "customer", id: "probe-cust" },
    status: "open",
    waitingReason: null,
    assignedTo: null,
    createdBy: "probe-admin",
    createdAt: admin.firestore.Timestamp.now(),
    resolutionSummary: null,
    resolvedAt: null,
    resolvedBy: null,
    reopenedAt: null,
    reopenedBy: null,
    reopenReason: null,
    linkedRecords: [],
    version: 1,
  };
  if (includeUpdatedAt) doc.updatedAt = updatedAt;
  await db.collection("support_cases").doc(id).set(doc);
}

// The IDENTICAL query shape PaginatedQueryList's own source builds.
function baseQuery() {
  return db.collection("support_cases").where("status", "==", "open").orderBy("updatedAt", "desc");
}

async function fetchPage(cursor) {
  let q = baseQuery().limit(PAGE_SIZE);
  if (cursor) q = q.startAfter(cursor);
  return q.get();
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  // ── p01: genuinely more records than one page ──
  {
    const base = new Date("2026-09-01T00:00:00Z").getTime();
    for (let i = 0; i < 25; i++) {
      await seedCase(`p01_${String(i).padStart(2, "0")}`, {
        updatedAt: admin.firestore.Timestamp.fromMillis(base + i * 1000),
      });
    }
    const page1 = await fetchPage(null);
    const page2 = await fetchPage(page1.docs[page1.docs.length - 1]);
    const page3 = await fetchPage(page2.docs[page2.docs.length - 1]);
    const page4 = await fetchPage(page3.docs[page3.docs.length - 1]);

    const allIds = [...page1.docs, ...page2.docs, ...page3.docs].map((d) => d.id);
    const uniqueIds = new Set(allIds);

    check(
      "p01_more_than_one_page_splits_correctly_no_gaps_no_dupes",
      page1.size === 10 && page2.size === 10 && page3.size === 5 && page4.size === 0 &&
        allIds.length === 25 && uniqueIds.size === 25,
      JSON.stringify({ page1: page1.size, page2: page2.size, page3: page3.size, page4: page4.size, unique: uniqueIds.size })
    );

    // The exact bug that made this untestable in fake_cloud_firestore: a
    // real second .get() after startAfterDocument must return real data,
    // not silently come back empty.
    check(
      "p01b_second_page_is_never_silently_empty_the_fake_harness_bug",
      page2.size > 0,
      `page2.size=${page2.size}`
    );

    // Descending order actually holds within and across pages.
    const page1Times = page1.docs.map((d) => d.data().updatedAt.toMillis());
    const page2Times = page2.docs.map((d) => d.data().updatedAt.toMillis());
    const sortedDesc = (arr) => arr.every((v, i) => i === 0 || arr[i - 1] >= v);
    check(
      "p01c_descending_order_holds_within_and_across_pages",
      sortedDesc(page1Times) && sortedDesc(page2Times) &&
        page1Times[page1Times.length - 1] >= page2Times[0],
      JSON.stringify({ page1Times, page2Times })
    );

    // A retry of the SAME initial fetch (cursor=null) is stable -- no
    // stale-request corruption, same first page every time.
    const page1Retry = await fetchPage(null);
    check(
      "p01d_a_retried_initial_fetch_returns_the_same_first_page",
      JSON.stringify(page1.docs.map((d) => d.id)) === JSON.stringify(page1Retry.docs.map((d) => d.id)),
      JSON.stringify({ first: page1.docs.map((d) => d.id), retry: page1Retry.docs.map((d) => d.id) })
    );
  }

  // ── p02: tied updatedAt values, a page boundary falls inside the tie group ──
  {
    const tiedAt = admin.firestore.Timestamp.fromMillis(new Date("2026-09-05T00:00:00Z").getTime());
    // 15 documents sharing the EXACT same updatedAt -- with PAGE_SIZE=10,
    // a real page boundary must fall in the middle of this tie group at
    // least once during a full traversal.
    for (let i = 0; i < 15; i++) {
      await seedCase(`p02_${String(i).padStart(2, "0")}`, { updatedAt: tiedAt });
    }

    // Page through everything now in the collection (p01's 25 + p02's 15 =
    // 40) far enough to collect every p02 doc, then verify completeness.
    let cursor = null;
    const collected = [];
    for (let i = 0; i < 6; i++) {
      const page = await fetchPage(cursor);
      if (page.empty) break;
      collected.push(...page.docs);
      cursor = page.docs[page.docs.length - 1];
    }
    const collectedP02Ids = new Set(collected.filter((d) => d.id.startsWith("p02_")).map((d) => d.id));
    const expectedP02Ids = new Set(Array.from({ length: 15 }, (_, i) => `p02_${String(i).padStart(2, "0")}`));
    const setsEqual =
      collectedP02Ids.size === expectedP02Ids.size && [...expectedP02Ids].every((id) => collectedP02Ids.has(id));

    check(
      "p02_tied_timestamps_across_a_page_boundary_yield_a_complete_no_duplicate_traversal",
      setsEqual && collected.length === new Set(collected.map((d) => d.id)).size,
      JSON.stringify({
        collectedCount: collectedP02Ids.size,
        expectedCount: expectedP02Ids.size,
        totalCollectedAcrossAllPages: collected.length,
        totalUnique: new Set(collected.map((d) => d.id)).size,
      })
    );
  }

  // ── p03: a document missing the orderBy field entirely ──
  {
    await seedCase("p03_no_updatedat", { includeUpdatedAt: false });

    let cursor = null;
    let sawIt = false;
    for (let i = 0; i < 10; i++) {
      const page = await fetchPage(cursor);
      if (page.empty) break;
      if (page.docs.some((d) => d.id === "p03_no_updatedat")) sawIt = true;
      cursor = page.docs[page.docs.length - 1];
    }
    check(
      "p03_a_record_missing_the_orderby_field_is_excluded_not_shown_with_a_null_position",
      !sawIt,
      `sawIt=${sawIt} -- real Firestore behavior: a doc missing the orderBy field never matches an orderBy query at all, confirmed directly rather than assumed`
    );
  }

  const failed = Object.entries(results).filter(([, v]) => v !== "PASSED");
  console.log(`\n${Object.keys(results).length - failed.length}/${Object.keys(results).length} scenarios passed`);
  if (failed.length) {
    console.log("FAILURES:", failed.map(([k]) => k).join(", "));
    console.log("PHASE ADMR-69 (pagination): FAILED");
    process.exitCode = 1;
  } else {
    console.log("PHASE ADMR-69 (pagination): ALL PASSED");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
