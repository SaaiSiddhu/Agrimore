// ============================================================
//  Rider branch of deleteUserData (Phase DLV-A2)
// ============================================================
//
// deleteUserData (customer/deleteUserData.ts) had customer, associate and
// seller branches but none for delivery partners: a rider's deletion left
// the Aadhaar number, bank details and KYC photos behind, and nothing
// stopped it while the rider still carried an order, held customers' cash
// or was owed pay. Same three tiers as the other branches:
//
// REFUSE (stable reasons in details.reason; nothing is touched):
//   rider_active_order  an order is assigned and not finished
//   rider_cash_held     COD cash not yet deposited (rider_accounts.cashHeld)
//   rider_pay_owed      unsettled earnings, or a statement pending / on hold
//
// HARD DELETE: delivery_partners/{uid} (Aadhaar, licence, bank/UPI, address),
//   rider_incident_limits/{uid}, rider_bank_change_requests (riderId == uid;
//   they carry account numbers), delivery_requests (riderId == uid; offers),
//   delivery_tasks/{id}/live/rider for the rider's legs (positions), and the
//   Storage folder delivery_documents/{uid}/ (KYC photos).
//
// ANONYMISE: orders where deliveryPartnerId == uid keep the rider's id and
//   name (the customer's record of who delivered) but lose the rider's phone
//   and last position in the deliveryPartner snapshot.
//
// KEEP (financial / safety records, keyed by uid, no free-text PII):
//   rider_earnings, rider_payouts, rider_cash_ledger, rider_accounts, and
//   rider_incidents. Whether incident records (which hold a position) should
//   be kept, trimmed or deleted is an open retention decision; they are kept
//   unchanged until the owner decides.

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { holdsRider, RIDER_ACTIVE_ORDER_STATUSES } from "./dispatch";

type Db = FirebaseFirestore.Firestore;

export type RiderDeletionRefusal = { reason: "rider_active_order" | "rider_cash_held" | "rider_pay_owed"; message: string };

const OWED_STATUSES = new Set(["pending", "on_hold"]);
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);

/** Null when a rider (or a non-rider) may delete; otherwise why not. */
export async function riderDeletionRefusal(db: Db, uid: string): Promise<RiderDeletionRefusal | null> {
  const [active, account, statements] = await Promise.all([
    db.collection("orders").where("deliveryPartnerId", "==", uid)
      .where("orderStatus", "in", RIDER_ACTIVE_ORDER_STATUSES).limit(20).get(),
    db.collection("rider_accounts").doc(uid).get(),
    db.collection("rider_payouts").where("riderId", "==", uid).get(),
  ]);
  if (active.docs.some((d) => holdsRider(d.data()))) {
    return { reason: "rider_active_order",
      message: "You still have an order assigned. Deliver it or ask Agrimore to reassign it before deleting your account." };
  }
  const a = account.data() ?? {};
  if (num(a.cashHeld) > 0.005) {
    return { reason: "rider_cash_held",
      message: `You still hold Rs ${num(a.cashHeld).toFixed(2)} of customers' cash. Deposit it with Agrimore before deleting your account.` };
  }
  const owedStatement = statements.docs.some((d) => OWED_STATUSES.has(String(d.data().status ?? "")));
  if (num(a.earningsUnsettled) > 0.005 || owedStatement) {
    return { reason: "rider_pay_owed",
      message: "Agrimore still owes you delivery pay. Wait until your statement is paid before deleting your account." };
  }
  return null;
}

async function deleteInChunks(refs: FirebaseFirestore.DocumentReference[], db: Db): Promise<void> {
  for (let i = 0; i < refs.length; i += 450) {
    const batch = db.batch();
    refs.slice(i, i + 450).forEach((r) => batch.delete(r));
    await batch.commit();
  }
}

export type RiderDeletionResult = { wasRider: boolean; hardDeleted: number; anonymizedOrders: number; deletedFiles: number };

/**
 * Removes a rider's personal data. Run only after [riderDeletionRefusal]
 * returned null, and BEFORE users/{uid} is deleted (users/{uid} is
 * deleteUserData's idempotency marker). Safe to run for a non-rider.
 */
export async function deleteRiderData(db: Db, uid: string,
  deleteFolder: ((prefix: string) => Promise<number>) | null
): Promise<RiderDeletionResult> {
  const [partner, bankReqs, offers, tasks, orders] = await Promise.all([
    db.collection("delivery_partners").doc(uid).get(),
    db.collection("rider_bank_change_requests").where("riderId", "==", uid).get(),
    db.collection("delivery_requests").where("riderId", "==", uid).get(),
    db.collection("delivery_tasks").where("riderId", "==", uid).get(),
    db.collection("orders").where("deliveryPartnerId", "==", uid).get(),
  ]);
  const wasRider = partner.exists;
  // KYC files FIRST, and only for a rider: if this fails nothing else has
  // been removed yet, so a retry still finds delivery_partners/{uid} and
  // deletes them (a non-rider never touches Storage here).
  const deletedFiles = wasRider && deleteFolder ? await deleteFolder(`delivery_documents/${uid}/`) : 0;
  const refs = [
    db.collection("delivery_partners").doc(uid),
    db.collection("rider_incident_limits").doc(uid),
    ...bankReqs.docs.map((d) => d.ref),
    ...offers.docs.map((d) => d.ref),
    ...tasks.docs.map((d) => d.ref.collection("live").doc("rider")),
  ];
  await deleteInChunks(refs, db);

  for (let i = 0; i < orders.docs.length; i += 450) {
    const batch = db.batch();
    for (const d of orders.docs.slice(i, i + 450)) {
      const snap = d.data().deliveryPartner;
      batch.update(d.ref, {
        ...(snap && typeof snap === "object" ? {
          "deliveryPartner.phone": FieldValue.delete(),
          "deliveryPartner.currentLat": FieldValue.delete(),
          "deliveryPartner.currentLng": FieldValue.delete(),
        } : {}),
        deliveryPartnerDeleted: true,
      });
    }
    await batch.commit();
  }

  return { wasRider, hardDeleted: refs.length, anonymizedOrders: orders.size, deletedFiles };
}

/** Deletes every object under [prefix]; returns how many there were. */
export async function deleteStorageFolder(prefix: string): Promise<number> {
  const [files] = await admin.storage().bucket().getFiles({ prefix });
  await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
  return files.length;
}
