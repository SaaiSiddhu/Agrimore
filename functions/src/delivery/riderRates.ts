// ============================================================
//  Rider pay rates and the COD cash limit — the two reads dispatch.ts needs
//  (Phase DLV-4A). Kept apart from riderMoney.ts so dispatch does not import
//  the payout/bank callables and their dependencies.
// ============================================================
import { RiderPayRates, sanitizeRates } from "./riderPay";
import { readRiderCashPaise } from "./riderCashBalance";

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

/** Candidate-only cash reads, including malformed balances that cannot receive COD. */
export async function ridersAtCashLimit(db: Db, limit: number, riderIds: readonly string[]): Promise<Set<string>> {
  const ids = [...new Set(riderIds)];
  const excluded = new Set<string>();
  // Direct reads avoid filtering on a stale rupee display or scanning unrelated accounts.
  // Keep each request bounded; no new composite query/index is introduced.
  for (let offset = 0; offset < ids.length; offset += 100) {
    const refs = ids.slice(offset, offset + 100).map((id) => db.collection("rider_accounts").doc(id));
    const accounts = await db.getAll(...refs);
    for (const account of accounts) {
      const held = readRiderCashPaise(account.data());
      if (held === null || !Number.isFinite(limit) || limit < 0 || held >= limit * 100) excluded.add(account.id);
    }
  }
  return excluded;
}
