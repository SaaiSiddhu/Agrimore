// ============================================================
//  Callable: updateRiderContact (Phase DLV-A2)
// ============================================================
//
// The fields a rider may change themselves: alternate phone, address, city,
// PIN code. DLV-0's owner allowlist keeps clients from writing
// delivery_partners beyond location/online, so the change goes through
// here, validated like registration (riderApplication.ts). Name, phone,
// vehicle, licence, Aadhaar and documents are NOT editable here: a pending
// or rejected rider resubmits the application; an approved rider asks
// Agrimore support (an admin edits through the rider review). Bank and UPI
// details use the reviewed bank-change flow (riderMoney.ts).
//
// Generation: v2 onCall. Modular Firestore imports (emulator-safe).
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { normPhone } from "./riderApplication";

if (admin.apps.length === 0) admin.initializeApp();

const PHONE = /^[6-9]\d{9}$/;
const PINCODE = /^[1-9]\d{5}$/;

export type ContactUpdate = { altPhone: string | null; address: string; city: string; pincode: string };

/** Problem keys (as registration's) or the cleaned update. Pure. */
export function validateContact(d: Record<string, unknown>, phone: string | null):
  { problems: string[]; update: ContactUpdate | null } {
  const problems: string[] = [];
  const s = (v: unknown) => (typeof v === "string" ? v.trim() : "");
  const altRaw = s(d.altPhone);
  const alt = altRaw === "" ? null : normPhone(altRaw);
  if (alt !== null && (!PHONE.test(alt) || alt === phone)) problems.push("altPhone");
  const address = s(d.address);
  if (address.length < 5 || address.length > 300) problems.push("address");
  const city = s(d.city);
  if (city.length < 2 || city.length > 60) problems.push("city");
  const pincode = s(d.pincode);
  if (!PINCODE.test(pincode)) problems.push("pincode");
  return problems.length ? { problems, update: null } : { problems, update: { altPhone: alt, address, city, pincode } };
}

export async function updateRiderContactCore(db: FirebaseFirestore.Firestore, uid: string, data: unknown):
  Promise<{ kind: "updated" } | { kind: "refused"; reason: "not_a_rider" | "invalid"; problems?: string[] }> {
  const ref = db.collection("delivery_partners").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) return { kind: "refused", reason: "not_a_rider" };
  const phone = typeof snap.data()!.phone === "string" ? normPhone(snap.data()!.phone) : null;
  const v = validateContact((data ?? {}) as Record<string, unknown>, phone);
  if (!v.update) return { kind: "refused", reason: "invalid", problems: v.problems };
  await ref.update({ ...v.update, contactUpdatedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
  return { kind: "updated" };
}

export const updateRiderContact = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const v = await updateRiderContactCore(admin.firestore(), request.auth.uid, request.data);
  if (v.kind === "refused") {
    throw new HttpsError(v.reason === "not_a_rider" ? "permission-denied" : "invalid-argument",
      v.reason === "not_a_rider" ? "Only delivery partners can update these details" : "Some details are invalid",
      { reason: v.reason, problems: v.problems ?? [] });
  }
  return { success: true };
});
