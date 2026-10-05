import { FieldPath, Timestamp } from "firebase-admin/firestore";

const CURSOR_COLLECTION = "payment_reconciliation_cursors";
const CURSOR_ID = "associate_onboarding";

interface Cursor { version: number; createdAt: Timestamp; orderId: string }
function parseCursor(data: FirebaseFirestore.DocumentData | undefined): Cursor | null {
  if (!data) return null;
  if (!Number.isSafeInteger(data.version) || data.version < 1 ||
      data.version >= Number.MAX_SAFE_INTEGER ||
      !(data.createdAt instanceof Timestamp) ||
      typeof data.orderId !== "string" || !/^[A-Za-z0-9_-]{1,200}$/.test(data.orderId)) {
    throw new Error("Invalid payment reconciliation cursor");
  }
  return data as Cursor;
}

/** Across-run fairness without increasing the bounded provider-read budget. */
export async function readStaleOnboardingPage(
  db: FirebaseFirestore.Firestore, purpose: string,
  floor: Timestamp, cutoff: Timestamp, limit: number
): Promise<{ snapshot: FirebaseFirestore.QuerySnapshot; version: number }> {
  const cursor = parseCursor((await db.collection(CURSOR_COLLECTION).doc(CURSOR_ID).get()).data());
  const base = db.collection("razorpay_orders")
    .where("purpose", "==", purpose)
    .where("createdAt", ">=", floor).where("createdAt", "<=", cutoff)
    .orderBy("createdAt", "asc").orderBy(FieldPath.documentId(), "asc").limit(limit);
  const withinWindow = cursor && cursor.createdAt.toMillis() >= floor.toMillis() &&
    cursor.createdAt.toMillis() <= cutoff.toMillis();
  let snapshot = await (withinWindow ? base.startAfter(cursor.createdAt, cursor.orderId) : base).get();
  // Revisit earlier unpaid rows after every full sweep: a provider capture may
  // arrive after an earlier pass. An empty tail does not increase paid reads.
  if (snapshot.empty && withinWindow) snapshot = await base.get();
  return { snapshot, version: cursor?.version ?? 0 };
}

/** Overlapping runs cannot move a newer checkpoint back to an older page. */
export async function advanceStaleOnboardingCursor(
  db: FirebaseFirestore.Firestore, version: number,
  last: FirebaseFirestore.QueryDocumentSnapshot
): Promise<boolean> {
  const createdAt = last.get("createdAt");
  if (!(createdAt instanceof Timestamp)) throw new Error("Invalid reconciliation order timestamp");
  const ref = db.collection(CURSOR_COLLECTION).doc(CURSOR_ID);
  return db.runTransaction(async tx => {
    const current = parseCursor((await tx.get(ref)).data());
    if ((current?.version ?? 0) !== version) return false;
    tx.set(ref, { version: version + 1, createdAt, orderId: last.id, updatedAt: Timestamp.now() });
    return true;
  });
}
