// ============================================================
//  Rider pay — pure rules (Phase DLV-4A, OWNER_DECISION D-DLV-PAY)
// ============================================================
//
// A rider is paid per delivered order: a base amount, a rate per km of the
// store → customer road distance, and pay for waiting at the store beyond a
// free allowance. Admin sets the rates in settings/rider_pay; anything
// missing or out of range falls back to the defaults below, never to a
// number the settings doc merely claims (the same stance as
// calculateSellerPayout's resolvePayoutRate).
//
// Deliberately NOT the customer's delivery charge: that is often 0 (free
// delivery) and, without a seller fee schedule, supplied by the client
// (orderPricing.ts only caps it).
//
// No Firestore here — covered by phaseDLV4A_pay_test.js.

export type Point = { lat: number; lng: number };

export interface RiderPayRates {
  basePay: number;
  perKm: number;
  waitingPerMin: number;
  waitingFreeMin: number;
  /** D-DLV-COD: a rider holding this much cash or more gets no COD offers. */
  codCashLimit: number;
  /** Distance pay stops here (a mis-geocoded address must not pay 400 km). */
  maxKm: number;
}

/** Seeded by the owner's decision; admin can change them any time. */
export const DEFAULT_RIDER_PAY_RATES: RiderPayRates = {
  basePay: 25,
  perKm: 6,
  waitingPerMin: 1,
  waitingFreeMin: 10,
  codCashLimit: 2000,
  maxKm: 25,
};

/** Accepted range for each rate; outside it the default is used. */
const BOUNDS: Record<keyof RiderPayRates, [number, number]> = {
  basePay: [0, 500],
  perKm: [0, 100],
  waitingPerMin: [0, 20],
  waitingFreeMin: [0, 120],
  codCashLimit: [0, 100000],
  maxKm: [1, 100],
};

/** Waiting pay is counted for at most this long. */
export const MAX_WAIT_MIN = 60;

/** The road is longer than the straight line; same factor as the ETA (D-DLV-ETA). */
export const ROAD_FACTOR = 1.35;

/** Distances within this of the store count as "at the store" for a route origin. */
const AT_STORE_METERS = 300;

export function sanitizeRates(raw: unknown): { rates: RiderPayRates; rejected: string[] } {
  const src = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const rates = { ...DEFAULT_RIDER_PAY_RATES };
  const rejected: string[] = [];
  for (const key of Object.keys(BOUNDS) as (keyof RiderPayRates)[]) {
    if (!(key in src)) continue;
    const v = src[key];
    const [lo, hi] = BOUNDS[key];
    if (typeof v === "number" && Number.isFinite(v) && v >= lo && v <= hi) rates[key] = v;
    else rejected.push(key);
  }
  return { rates, rejected };
}

const rupees = (x: number) => Math.round(x * 100) / 100;

export function haversineKm(a: Point, b: Point): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const dLat = r(b.lat - a.lat);
  const dLng = r(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

export type KmSource = "route" | "straight_line" | "none";

/**
 * The store → customer distance to pay for. The road distance from the
 * Routes API when the task's route really runs from the store (a via_pickup
 * route's second leg, or a to_drop route computed at the store); otherwise
 * the straight line × 1.35; with no points at all, nothing.
 */
export function tripKm(task: { pickup?: Point | null; drop?: Point | null; route?: unknown } | null | undefined): { km: number; source: KmSource } {
  const pickup = validPoint(task?.pickup);
  const drop = validPoint(task?.drop);
  const route = (task?.route ?? null) as { plan?: unknown; legs?: unknown; origin?: unknown } | null;
  const legs = Array.isArray(route?.legs) ? (route!.legs as { distanceMeters?: unknown }[]) : [];
  const meters = (l: { distanceMeters?: unknown } | undefined) =>
    typeof l?.distanceMeters === "number" && Number.isFinite(l.distanceMeters) && l.distanceMeters > 0 ? l.distanceMeters : null;
  if (route?.plan === "via_pickup" && legs.length >= 2 && meters(legs[1]) !== null) {
    return { km: meters(legs[1])! / 1000, source: "route" };
  }
  const origin = validPoint(route?.origin);
  if (route?.plan === "to_drop" && legs.length >= 1 && meters(legs[0]) !== null && origin && pickup &&
      haversineKm(origin, pickup) * 1000 <= AT_STORE_METERS) {
    return { km: meters(legs[0])! / 1000, source: "route" };
  }
  if (pickup && drop) return { km: haversineKm(pickup, drop) * ROAD_FACTOR, source: "straight_line" };
  return { km: 0, source: "none" };
}

function validPoint(p: unknown): Point | null {
  const q = p as { lat?: unknown; lng?: unknown } | null | undefined;
  return typeof q?.lat === "number" && typeof q?.lng === "number" && Number.isFinite(q.lat) && Number.isFinite(q.lng)
    ? { lat: q.lat, lng: q.lng } : null;
}

/** Minutes spent at the store beyond the free allowance, capped. */
export function billableWaitMinutes(arrivedMs: number | null, pickedUpMs: number | null, rates: RiderPayRates): number {
  if (arrivedMs === null || pickedUpMs === null || pickedUpMs <= arrivedMs) return 0;
  const waited = Math.min((pickedUpMs - arrivedMs) / 60000, MAX_WAIT_MIN);
  return Math.max(0, Math.floor(waited - rates.waitingFreeMin));
}

export type PayLine = { type: "trip_base" | "distance" | "waiting"; amount: number; km?: number; minutes?: number };

/** One order's pay: base + distance + waiting, in rupees (2 dp). */
export function riderPay(rates: RiderPayRates, km: number, waitMinutes: number): { lines: PayLine[]; total: number } {
  const paidKm = Math.round(Math.min(Math.max(km, 0), rates.maxKm) * 100) / 100;
  const lines: PayLine[] = [
    { type: "trip_base", amount: rupees(rates.basePay) },
    { type: "distance", amount: rupees(paidKm * rates.perKm), km: paidKm },
  ];
  if (waitMinutes > 0) lines.push({ type: "waiting", amount: rupees(waitMinutes * rates.waitingPerMin), minutes: waitMinutes });
  return { lines, total: rupees(lines.reduce((s, l) => s + l.amount, 0)) };
}

/**
 * The weekly statement split (D-DLV-COD + D-DLV-PAYOUT): cash the rider
 * holds is netted against what they earned; any cash left over stays held.
 */
export function settle(earned: number, cashHeld: number): { netted: number; payout: number; cashAfter: number } {
  const e = Math.max(0, rupees(earned));
  const c = Math.max(0, rupees(cashHeld));
  const netted = Math.min(e, c);
  return { netted: rupees(netted), payout: rupees(e - netted), cashAfter: rupees(c - netted) };
}

/**
 * The statement week, in India time: statements are cut every Monday 00:00
 * IST and cover everything before it. Key like "2026-W39" for the week that
 * ENDED at the cutoff.
 */
const IST_OFFSET_MS = 330 * 60 * 1000;
export function statementCutoff(nowMs: number): { cutoffMs: number; weekKey: string } {
  const ist = new Date(nowMs + IST_OFFSET_MS);
  const day = ist.getUTCDay(); // 0 Sun … 1 Mon
  const sinceMonday = (day + 6) % 7;
  const mondayIst = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate() - sinceMonday);
  const cutoffMs = mondayIst - IST_OFFSET_MS;
  // ISO week of the Sunday before the cutoff (the last day covered).
  const sunday = new Date(mondayIst - 86400000);
  const thursday = new Date(sunday.getTime() - ((sunday.getUTCDay() + 6) % 7) * 86400000 + 3 * 86400000);
  const yearStart = Date.UTC(thursday.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((thursday.getTime() - yearStart) / 86400000 + 1) / 7);
  return { cutoffMs, weekKey: `${thursday.getUTCFullYear()}-W${String(week).padStart(2, "0")}` };
}

// ── bank details (D-DLV-BANK) ──

export type BankDetails = { accountHolderName: string | null; bankAccountNumber: string | null; ifscCode: string | null; upiId: string | null };

/** Validates a rider's bank-change request; the error names the field. */
export function validateBankDetails(raw: unknown): { ok: true; value: BankDetails } | { ok: false; error: string } {
  const d = (raw ?? {}) as Record<string, unknown>;
  const s = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);
  const name = s(d.accountHolderName);
  const acct = s(d.bankAccountNumber)?.replace(/\s+/g, "") ?? null;
  const ifsc = s(d.ifscCode)?.toUpperCase() ?? null;
  const upi = s(d.upiId)?.toLowerCase() ?? null;
  const anyBank = !!(name || acct || ifsc);
  if (anyBank) {
    if (!name || name.length < 2 || name.length > 100) return { ok: false, error: "accountHolderName" };
    if (!acct || !/^\d{9,18}$/.test(acct)) return { ok: false, error: "bankAccountNumber" };
    if (!ifsc || !/^[A-Z]{4}0[A-Z0-9]{6}$/.test(ifsc)) return { ok: false, error: "ifscCode" };
  }
  if (upi !== null && !/^[a-z0-9._-]{2,256}@[a-z]{2,64}$/.test(upi)) return { ok: false, error: "upiId" };
  if (!anyBank && !upi) return { ok: false, error: "empty" };
  return { ok: true, value: { accountHolderName: name, bankAccountNumber: acct, ifscCode: ifsc, upiId: upi } };
}

/** Whether a rider has somewhere to be paid. */
export function hasPayoutDestination(p: Record<string, unknown> | undefined): boolean {
  const s = (v: unknown) => typeof v === "string" && v.trim().length > 0;
  return !!p && ((s(p.bankAccountNumber) && s(p.ifscCode)) || s(p.upiId));
}
