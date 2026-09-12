// ============================================================
//  Phase CAT-2 — banner placement backfill census
// ============================================================
//
// DRY-RUN BY DEFAULT. Requires an explicit --apply flag to write anything.
//
// NOT required for correctness: BannerModel.fromFirestore already defaults
// a missing `placement` field to 'HOME_HERO' when reading, so every banner
// written before this phase already renders on Home exactly as it did
// before, with or without this script ever running. This script only makes
// that fact explicit and queryable in Firestore itself (e.g. for a future
// admin filter using a real `where('placement', ...)` clause instead of
// client-side filtering), and is purely additive: it only ever sets
// `placement` on documents that don't already have it, never overwrites an
// existing value, never touches any other field.
//
// Run with:   node scripts/phaseCAT2_banner_placement_backfill.js            (dry run)
//             node scripts/phaseCAT2_banner_placement_backfill.js --apply    (writes)

const admin = require("firebase-admin");

const APPLY = process.argv.includes("--apply");
const HOME_HERO = "HOME_HERO";

async function main() {
  try {
    admin.initializeApp();
  } catch (e) {
    console.error("❌ Could not initialize Admin SDK — Application Default Credentials");
    console.error("   are likely unavailable in this environment.");
    console.error(`   ${e.message}`);
    process.exit(1);
  }

  const db = admin.firestore();

  console.log(`=== Phase CAT-2 banner placement backfill — ${APPLY ? "APPLY MODE (will write)" : "DRY RUN (no writes)"} ===`);

  let total = 0;
  let alreadySet = 0;
  let backfilled = 0;

  let batch = db.batch();
  let batchCount = 0;
  let batchesCommitted = 0;

  const snap = await db.collection("banners").get();

  for (const doc of snap.docs) {
    total++;
    const data = doc.data();

    if (typeof data.placement === "string" && data.placement.trim().length > 0) {
      alreadySet++;
      continue;
    }

    backfilled++;
    if (APPLY) {
      batch.update(doc.ref, { placement: HOME_HERO });
      batchCount++;
      if (batchCount >= 400) {
        await batch.commit();
        batchesCommitted++;
        batch = db.batch();
        batchCount = 0;
      }
    }
  }

  if (APPLY && batchCount > 0) {
    await batch.commit();
    batchesCommitted++;
  }

  console.log("");
  console.log("=== CENSUS ===");
  console.log(`Total banners documents:        ${total}`);
  console.log(`Already had a placement value:  ${alreadySet}`);
  console.log(`Backfilled to HOME_HERO:        ${backfilled}${APPLY ? " (written)" : " (would be written)"}`);
  if (APPLY) {
    console.log("");
    console.log(`Committed ${batchesCommitted} batch(es).`);
  } else {
    console.log("");
    console.log("Dry run only — no writes performed. Re-run with --apply to write.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Backfill failed:", e);
    process.exit(1);
  });
