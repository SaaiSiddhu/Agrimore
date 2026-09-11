// ============================================================
//  Callable: claimScratchCard — Phase FIX-N50
// ============================================================
//
// Closes security.md finding N-50: `users/{uid}.walletBalance` had zero
// coverage in firestore.rules' `ownerCannotChangePrivilegedFields()`, so any
// authenticated user could set their OWN walletBalance to any value
// directly -- because `rewards_screen.dart`'s claim flow was the ONLY
// mechanism that ever credited it, and did so with three separate,
// non-transactional client writes (mark the card scratched, read-then-write
// a client-computed balance, log a transaction). Adding the field to the
// denylist alone would have broken that flow with no replacement, per the
// finding's own text -- this callable is the replacement: the entire claim
// (mark scratched + credit + log) now happens atomically, server-side, with
// the card's own admin-seeded `amount` field as the only source of truth
// for how much to credit. The client no longer writes walletBalance at all.
//
// scratchCards/{cardId} is never client-created (firestore.rules:
// `allow create: if false`, admin-seeded only) and its own `amount` field
// is not client-writable either (`allow update` is value-guarded to
// `isScratched` only) -- so `amount`, read here via the Admin SDK, is
// trustworthy input, unlike anything this callable takes from `request.data`.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

interface ClaimScratchCardData {
  cardId?: string;
}

export const claimScratchCard = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;

    const data = request.data as ClaimScratchCardData;
    const cardId = typeof data?.cardId === "string" ? data.cardId.trim() : "";
    if (!cardId) {
      throw new HttpsError("invalid-argument", "cardId is required");
    }

    const db = admin.firestore();
    const cardRef = db.collection("users").doc(uid).collection("scratchCards").doc(cardId);
    const userRef = db.collection("users").doc(uid);
    const txLogRef = db.collection("users").doc(uid).collection("transactions").doc();

    const result = await db.runTransaction(async (tx) => {
      const [cardSnap, userSnap] = await Promise.all([tx.get(cardRef), tx.get(userRef)]);

      if (!cardSnap.exists) {
        throw new HttpsError("not-found", "Scratch card not found");
      }
      if (!userSnap.exists) {
        throw new HttpsError("failed-precondition", "Your account could not be found");
      }

      const cardData = cardSnap.data() || {};

      // Idempotency guard: re-invoking on an already-claimed card must never
      // credit twice -- the exact class of bug the old client-side flow had
      // no guard against at all (a double-tap, or a retried request after a
      // flaky response, could double-credit).
      if (cardData.isScratched === true) {
        return { alreadyClaimed: true, amount: 0 };
      }

      const amountRaw = cardData.amount;
      const amount =
        typeof amountRaw === "number" && Number.isFinite(amountRaw) && amountRaw > 0 ? amountRaw : 0;

      tx.update(cardRef, { isScratched: true });

      if (amount > 0) {
        tx.update(userRef, {
          walletBalance: admin.firestore.FieldValue.increment(amount),
        });
        tx.set(txLogRef, {
          type: "credit",
          title: "Scratch Card Reward 🎁",
          amount,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "success",
        });
      }

      return { alreadyClaimed: false, amount };
    });

    return { success: true, ...result };
  }
);
