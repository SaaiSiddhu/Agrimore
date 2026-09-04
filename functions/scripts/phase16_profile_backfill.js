// ============================================================
//  Phase 16, Workstream 1 — profile-completion backfill census
// ============================================================
//
// DRY-RUN BY DEFAULT. Requires an explicit --apply flag to write anything.
// Reads every users/{uid} document and classifies it:
//   - has name + email + phone (all non-empty)      -> would be grandfathered
//     (profileCompleted: true, per owner decision 3 — an existing user with
//     a usable profile must not be locked out by this phase)
//   - missing one or more of those                  -> stays incomplete
//     (profileCompleted stays false / unset, exactly what UserModel.fromMap
//     already defaults it to for a document with no such field)
//
// This is purely additive: it only ever sets profileCompleted (+
// profileCompletedAt when grandfathering) on documents that don't already
// have profileCompleted === true. It never deletes, blanks, or overwrites
// any other existing field.
//
// Run with:   node scripts/phase16_profile_backfill.js            (dry run)
//             node scripts/phase16_profile_backfill.js --apply    (writes)

const admin = require("firebase-admin");

const APPLY = process.argv.includes("--apply");

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

  console.log(`=== Phase 16 profile backfill — ${APPLY ? "APPLY MODE (will write)" : "DRY RUN (no writes)"} ===`);

  let total = 0;
  let alreadyComplete = 0;
  let grandfathered = 0;
  let incomplete = 0;
  const byRole = {};

  let batch = db.batch();
  let batchCount = 0;
  let batchesCommitted = 0;

  const snap = await db.collection("users").get();

  for (const doc of snap.docs) {
    total++;
    const data = doc.data();
    const role = typeof data.role === "string" && data.role ? data.role : "(none)";
    byRole[role] = (byRole[role] || 0) + 1;

    if (data.profileCompleted === true) {
      alreadyComplete++;
      continue;
    }

    const hasName = typeof data.name === "string" && data.name.trim().length > 0;
    const hasEmail = typeof data.email === "string" && data.email.trim().length > 0;
    const hasPhone = typeof data.phone === "string" && data.phone.trim().length > 0;

    if (hasName && hasEmail && hasPhone) {
      grandfathered++;
      if (APPLY) {
        batch.update(doc.ref, {
          profileCompleted: true,
          profileCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batchCount++;
        if (batchCount >= 400) {
          await batch.commit();
          batchesCommitted++;
          batch = db.batch();
          batchCount = 0;
        }
      }
    } else {
      incomplete++;
    }
  }

  if (APPLY && batchCount > 0) {
    await batch.commit();
    batchesCommitted++;
  }

  console.log("");
  console.log("=== CENSUS ===");
  console.log(`Total users documents:         ${total}`);
  console.log(`Already profileCompleted=true:  ${alreadyComplete}`);
  console.log(`Grandfathered (name+email+phone): ${grandfathered}${APPLY ? " (written)" : " (would be written)"}`);
  console.log(`Incomplete (stays false):       ${incomplete}`);
  console.log("");
  console.log("=== BY ROLE ===");
  for (const [role, count] of Object.entries(byRole)) {
    console.log(`  ${role}: ${count}`);
  }
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
