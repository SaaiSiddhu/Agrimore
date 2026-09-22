// ============================================================
//  Product salePrice backfill script
// ============================================================
//
// DRY-RUN BY DEFAULT. Requires an explicit --apply flag to write anything.
//
// Background:
// In the production Firestore catalog, many products have `price` and `discountPrice`
// fields rather than `salePrice`. The mobile Flutter app's ProductModel gracefully
// falls back (`salePrice: map['salePrice'] ?? map['price'] ?? 0.0`).
//
// While functions/src/customer/orderPricing.ts has been updated to also support
// `salePrice ?? price ?? discountPrice`, running this backfill script explicitly
// synchronizes `salePrice` on existing products in Firestore.
//
// Run with:
//   node scripts/phase_product_price_backfill.js            (dry run)
//   node scripts/phase_product_price_backfill.js --apply    (writes)

const admin = require("firebase-admin");

const APPLY = process.argv.includes("--apply");

async function main() {
  try {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || "agrimore-66a4e",
    });
  } catch (e) {
    console.error("❌ Could not initialize Admin SDK — Application Default Credentials");
    console.error("   are likely unavailable in this environment.");
    console.error(`   ${e.message}`);
    process.exit(1);
  }

  const db = admin.firestore();

  console.log(`=== Product salePrice backfill — ${APPLY ? "APPLY MODE (will write)" : "DRY RUN (no writes)"} ===`);

  let total = 0;
  let alreadyHasSalePrice = 0;
  let canBackfill = 0;
  let missingPrice = 0;

  let batch = db.batch();
  let batchCount = 0;
  let batchesCommitted = 0;

  const snap = await db.collection("products").get();

  for (const doc of snap.docs) {
    total++;
    const data = doc.data();

    const currentSalePrice = Number(data.salePrice);
    if (typeof data.salePrice !== "undefined" && data.salePrice !== null && !isNaN(currentSalePrice) && currentSalePrice >= 0) {
      alreadyHasSalePrice++;
      continue;
    }

    const candidate = data.price ?? data.discountPrice ?? data.discountedPrice;
    const numCandidate = Number(candidate);

    if (candidate !== undefined && candidate !== null && !isNaN(numCandidate) && numCandidate >= 0) {
      canBackfill++;
      console.log(`[Backfill] Product ${doc.id} (${data.name || "unnamed"}): setting salePrice = ${numCandidate} (from ${candidate})`);
      if (APPLY) {
        batch.update(doc.ref, { salePrice: numCandidate });
        batchCount++;

        if (batchCount === 450) {
          await batch.commit();
          batchesCommitted++;
          batch = db.batch();
          batchCount = 0;
        }
      }
    } else {
      missingPrice++;
      console.warn(`⚠️ Product ${doc.id} (${data.name || "unnamed"}): no valid price/discountPrice found to backfill salePrice.`);
    }
  }

  if (APPLY && batchCount > 0) {
    await batch.commit();
    batchesCommitted++;
  }

  console.log("\n--- Summary ---");
  console.log(`Total products scanned: ${total}`);
  console.log(`Already has valid salePrice: ${alreadyHasSalePrice}`);
  console.log(`Backfillable (missing salePrice, has price): ${canBackfill}`);
  console.log(`Missing any price field: ${missingPrice}`);
  if (APPLY) {
    console.log(`Batches committed: ${batchesCommitted}`);
    console.log("✅ Backfill successfully applied to Firestore.");
  } else {
    console.log("ℹ️  Dry run completed. Run with --apply to commit changes.");
  }
}

main().catch((err) => {
  console.error("Backfill failed:", err);
  process.exit(1);
});
