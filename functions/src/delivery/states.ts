// ============================================================
//  Delivery leg states — TypeScript mirror (Phase DLV-1A)
// ============================================================
//
// Mirrors packages/agrimore_core/lib/models/delivery/delivery_task_status.dart.
// Both are tested against packages/agrimore_core/test/fixtures/
// delivery_status_table.json (phaseDLV1A_delivery_states_test.js here,
// delivery_enums_test.dart there) — change all three together.
//
// Works in WIRE values (the strings stored in delivery_tasks.status).

export const TASK_STATUSES = [
  "searching",
  "assigned",
  "at_pickup",
  "picked_up",
  "en_route",
  "at_drop",
  "delivered",
  "failed_attempt",
  "returning_to_seller",
  "returned",
  "cancelled",
] as const;

export type TaskStatus = typeof TASK_STATUSES[number];

const TERMINAL: ReadonlySet<TaskStatus> = new Set<TaskStatus>(["delivered", "returned", "cancelled"]);

const TRANSITIONS: Readonly<Record<TaskStatus, ReadonlySet<TaskStatus>>> = {
  searching: new Set<TaskStatus>(["assigned", "cancelled"]),
  // Back to searching = the rider released it ("Seller Not Ready").
  assigned: new Set<TaskStatus>(["at_pickup", "picked_up", "searching", "cancelled"]),
  at_pickup: new Set<TaskStatus>(["picked_up", "searching", "cancelled"]),
  // After pickup a cancellation is a return, not a cancel.
  picked_up: new Set<TaskStatus>(["en_route", "at_drop", "delivered", "failed_attempt", "returning_to_seller"]),
  en_route: new Set<TaskStatus>(["at_drop", "delivered", "failed_attempt", "returning_to_seller"]),
  at_drop: new Set<TaskStatus>(["delivered", "failed_attempt", "returning_to_seller"]),
  failed_attempt: new Set<TaskStatus>(["en_route", "at_drop", "delivered", "returning_to_seller"]),
  returning_to_seller: new Set<TaskStatus>(["returned"]),
  delivered: new Set<TaskStatus>(),
  returned: new Set<TaskStatus>(),
  cancelled: new Set<TaskStatus>(),
};

// Rank for "the more advanced of two non-terminal values" — the enum's
// declaration order, identical to the Dart enum index.
const RANK: Readonly<Record<TaskStatus, number>> = TASK_STATUSES.reduce(
  (acc, s, i) => ({ ...acc, [s]: i }),
  {} as Record<TaskStatus, number>
);

export function taskStatusFromWire(value: unknown): TaskStatus | null {
  if (typeof value !== "string") return null;
  const v = value.trim().toLowerCase();
  return (TASK_STATUSES as readonly string[]).includes(v) ? (v as TaskStatus) : null;
}

export function isTerminal(s: TaskStatus): boolean {
  return TERMINAL.has(s);
}

export function canTransition(from: TaskStatus, to: TaskStatus): boolean {
  return TRANSITIONS[from].has(to);
}

// Legacy order statuses, lower-cased — every spelling found in apps/,
// packages/ and functions/src/ at 71630df.
const LEGACY_DELIVERED = new Set(["delivered", "completed"]);
const LEGACY_CANCELLED = new Set(["cancelled", "canceled", "rejected", "refunded"]);
const LEGACY_RETURNED = new Set(["returned"]);
const LEGACY_ACTIVE: Readonly<Record<string, TaskStatus>> = {
  delivery_accepted: "assigned",
  arrived_at_store: "at_pickup",
  reached_pickup: "at_pickup",
  picked_up: "picked_up",
  parcel_picked: "picked_up",
  out_for_delivery: "en_route",
  outfordelivery: "en_route",
};

/**
 * The leg state implied by an order's two status fields (seller/admin panels
 * write only `status`, the customer cancel path only `orderStatus` — the same
 * reason confirmDelivery.ts reads both). A terminal value in either wins:
 * returned, then delivered (agreeing with confirmDelivery's "already
 * delivered"), then cancelled. Otherwise the more advanced of the two.
 * Null = the order has no rider leg yet.
 */
export function taskStatusFromOrder(order: {
  orderStatus?: unknown;
  status?: unknown;
  deliveryPartnerId?: unknown;
}): TaskStatus | null {
  const values = [order.orderStatus, order.status]
    .filter((v): v is string => typeof v === "string")
    .map((v) => v.trim().toLowerCase());
  const hasPartner = typeof order.deliveryPartnerId === "string" && order.deliveryPartnerId.length > 0;

  if (values.some((v) => LEGACY_RETURNED.has(v))) return "returned";
  if (values.some((v) => LEGACY_DELIVERED.has(v))) return "delivered";
  if (values.some((v) => LEGACY_CANCELLED.has(v))) return "cancelled";

  let best: TaskStatus | null = null;
  for (const v of values) {
    let s: TaskStatus | null;
    if (v === "ready_for_pickup") s = hasPartner ? "assigned" : "searching";
    else if (v === "shipped") s = hasPartner ? "en_route" : null;
    else s = LEGACY_ACTIVE[v] ?? null;
    if (s && (best === null || RANK[s] > RANK[best])) best = s;
  }
  return best;
}
