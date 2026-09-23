// ============================================================
//  Rider pay rates and the COD cash limit — the two reads dispatch.ts needs
//  (Phase DLV-4A). Kept apart from riderMoney.ts so dispatch does not import
//  the payout/bank callables and their dependencies.
// ============================================================
import { RiderPayRates, sanitizeRates } from "./riderPay";

type Db = FirebaseFirestore.Firestore;

/** settings/rider_pay, sanitised; a bad value is logged and replaced by its default. */
export async function loadRiderPayRates(db: Db): Promise<RiderPayRates> {
  let raw: unknown = {};
  try {
    raw = (await db.collection("settings").doc("rider_pay").get()).data() ?? {};
  } catch (e) {
    console.warn(`[riderRates] settings/rider_pay unreadable — defaults: ${(e as Error)?.message ?? e}`);
  }
  const { rates, rejected } = sanitizeRates(raw);
  if (rejected.length) console.warn(`[riderRates] settings/rider_pay rejected ${rejected.join(",")} — using defaults for them`);
  return rates;
}

/** Riders at or over the cash limit: no COD offers until a deposit (D-DLV-COD). */
export async function ridersAtCashLimit(db: Db, limit: number): Promise<Set<string>> {
  const snap = await db.collection("rider_accounts").where("cashHeld", ">=", limit).get();
  return new Set(snap.docs.map((d) => d.id));
}
