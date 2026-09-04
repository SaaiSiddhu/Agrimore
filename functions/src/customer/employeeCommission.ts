// ============================================================
//  EMPLOYEE COMMISSION — Order Delivered Trigger
// ============================================================
//
// Fires when an order transitions into the delivered status. Credits the
// attributed associate's wallet via a server-side transaction — mirrors the
// commission-on-delivery pattern in ./sellerNotifications.ts#calculateSellerPayout,
// but pays the associate (via wallets/wallet_transactions) instead of creating
// a seller_payouts document.
//
// Phase 16D-1, Workstream 2: commission now pays on ANY delivered-equivalent
// order carrying a resolved `employeeUid` — not just `orderMode === "B2B"`
// ones. The whole point of the ₹500 Registration & Onboarding Fee (Phase
// 16A) is retail (B2C) sales; as originally shipped, an associate who paid
// that fee could never earn anything, because this trigger returned early
// on every B2C order regardless of attribution. `employeeUid` presence is
// now the ONLY eligibility gate; `orderMode` is read only to pick which
// configured rate applies (see resolveCommissionRate() below).
//
// IMPORTANT, CONFIRMED BLOCKER (see the Phase 16D-1 completion report,
// Section L, for the full write-up): as of this phase,
// functions/src/customer/createOrder.ts NEVER writes a non-null
// `employeeUid` for a B2C order — `employeeCode` is forced to `""` for
// B2C at the top of that function, and `employeeUid` is written as
// `orderMode === "B2B" ? employeeUid : null`. This means the eligibility
// widening below is necessary but NOT sufficient: no real, live B2C order
// can reach this trigger with a resolved `employeeUid` until a future
// phase adds a server-validated retail-attribution mechanism to
// createOrder.ts (explicitly out of THIS phase's scope — see Decision D5
// in the phase prompt: "associate-placed orders are not in this phase").
// This trigger's own logic is still correct and tested in isolation
// (seeding an orders/{id} document directly, the same way Phase 16A's own
// suites seed Firestore documents to test trigger logic) — it is simply
// unreachable via the live client flow today.
//
// Phase 16D-1, Workstream 3: the previous hardcoded `?? 5` percent
// fallback is REMOVED. An order whose commission rate cannot be resolved
// from either the associate's own override or the mode-configured rate in
// settings/commission now pays NOTHING and writes a commission_exceptions
// record — silently inventing a percentage on real money is worse than
// paying nothing and flagging it for an admin to configure.
//
// Security invariant: wallet crediting NEVER happens client-side. This
// function is the only writer of wallet_transactions for commission and the
// only incrementer of wallets/{employeeUid}.balance for this purpose.

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Matches OrderModel.isDelivered exactly (packages/agrimore_core/lib/models/order_model.dart),
// which treats 'delivered' and 'completed' as equivalent terminal states — NOT just the
// order_status.dart enum's 'delivered' value. apps/admin's order_management_screen.dart has a
// live bulk-action that sets orderStatus to the literal string 'completed'
// (admin_service.dart:189 already branches on both), so watching only 'delivered' would silently
// skip commission for orders closed that way.
const DELIVERED_EQUIVALENT_STATUSES = new Set(["delivered", "completed"]);

function isDeliveredEquivalent(status: unknown): boolean {
  return typeof status === "string" && DELIVERED_EQUIVALENT_STATUSES.has(status.toLowerCase());
}

// ------------------------------------------------------------
// Rate resolution — Phase 16D-1, Workstream 3
// ------------------------------------------------------------
// Mirrors functions/src/employee/onboardingConfig.ts's fail-closed loader
// shape: a rate that is present but not a finite, positive, in-range
// number is UNRESOLVED — never "use it anyway", and never a hardcoded
// guess. Resolution order:
//   1. employees/{uid}.commissionRate, when usable (> 0, <= ceiling)
//   2. settings/commission's configured per-mode rate — `employeeRetailRate`
//      for B2C (NEW in this phase), `employeeDefaultRate` for B2B (the
//      PRE-EXISTING key, kept unchanged so nothing already configured for
//      B2B breaks)
//   3. UNRESOLVED — pays nothing, writes a commission_exceptions record
//
// Decision (rate 0 semantics): a rate of exactly 0 — from EITHER the
// employee override or the settings document — is treated as
// "unconfigured", not "explicitly zero commission". This matters because
// `commissionRate: 0` is the literal default apps/marketplace/lib/screens/
// employee/employee_apply_screen.dart writes for every newly self-applied
// associate (see Phase 16A's rules test scenario 8) — treating 0 as a
// deliberate "pay nothing" would silently and PERMANENTLY zero out every
// associate's very first commission-eligible order (via the
// `commissionAmount <= 0` "mark commissionPaid:true, amount:0" branch)
// before an admin ever had a chance to configure a real rate, and
// `commissionPaid` would then never allow a retry.
//
// Decision (sanity ceiling): 100%. A legitimate commission structure pays
// the associate a FRACTION of the order value; a configured rate at or
// above 100% would mean AgriMore pays out as much as, or more than, what
// the customer paid — never a legitimate configuration, and far more
// likely to be a data-entry error (e.g. "50" typed as "500", or a decimal
// fraction like 0.5 intended to mean 50% but stored as 50 meaning 5000%
// by an upstream bug) than a real business decision. Refused outright,
// NOT clamped — clamping a clearly-wrong value down to the ceiling would
// still silently mint real money at an unintended rate.
export const MAX_COMMISSION_RATE_PERCENT = 100;

export type CommissionRateResolution =
  | { resolved: true; rate: number; source: "employee_override" | "configured_mode_rate" }
  | {
      resolved: false;
      reason: "no_rate_configured" | "rate_not_a_number" | "rate_not_positive" | "rate_exceeds_ceiling";
    };

function isUsableRate(value: unknown): value is number {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    value > 0 &&
    value <= MAX_COMMISSION_RATE_PERCENT
  );
}

export function resolveCommissionRate(params: {
  employeeOverride: unknown;
  settings: FirebaseFirestore.DocumentData | undefined;
  orderMode: "B2C" | "B2B";
}): CommissionRateResolution {
  const { employeeOverride, settings, orderMode } = params;

  // 1. Employee-specific override wins, when usable.
  if (typeof employeeOverride === "number" && Number.isFinite(employeeOverride)) {
    if (isUsableRate(employeeOverride)) {
      return { resolved: true, rate: employeeOverride, source: "employee_override" };
    }
    if (employeeOverride > MAX_COMMISSION_RATE_PERCENT) {
      return { resolved: false, reason: "rate_exceeds_ceiling" };
    }
    // A present-but-zero/negative override falls through to the
    // configured mode rate rather than failing outright — see the
    // "rate 0 semantics" decision above.
  }

  // 2. Configured per-mode rate in settings/commission.
  const key = orderMode === "B2B" ? "employeeDefaultRate" : "employeeRetailRate";
  const configuredRaw = settings ? settings[key] : undefined;

  if (configuredRaw === undefined || configuredRaw === null) {
    return { resolved: false, reason: "no_rate_configured" };
  }
  if (typeof configuredRaw !== "number" || !Number.isFinite(configuredRaw)) {
    return { resolved: false, reason: "rate_not_a_number" };
  }
  if (configuredRaw > MAX_COMMISSION_RATE_PERCENT) {
    return { resolved: false, reason: "rate_exceeds_ceiling" };
  }
  if (configuredRaw <= 0) {
    return { resolved: false, reason: "rate_not_positive" };
  }

  return { resolved: true, rate: configuredRaw, source: "configured_mode_rate" };
}

export const payEmployeeCommissionOnDelivery = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    // Only fire on the transition INTO a delivered-equivalent status, not on
    // every write while already delivered/completed.
    if (isDeliveredEquivalent(before.orderStatus) || !isDeliveredEquivalent(after.orderStatus)) {
      return null;
    }

    // Eligibility is now `employeeUid` presence alone — see the module
    // comment above. An order with no attributed associate returns early
    // here, before any Firestore read, which is the correct, cheap no-op
    // for ordinary (unattributed) traffic.
    const employeeUid = after.employeeUid as string | undefined;
    if (!employeeUid) {
      return null;
    }

    if (after.commissionPaid === true) {
      console.log(`⚠️ Commission already paid for order ${orderId} — skipping`);
      return null;
    }

    // Decision (suspended/deleted associate edge case): PAY regardless of
    // the associate's CURRENT employees/{uid} status or even whether that
    // document still exists. The commission is owed for a sale that
    // already happened and was already delivered — the associate's status
    // at THIS later moment doesn't retroactively un-earn it, the same way
    // a terminated employee in most real-world systems is still owed
    // wages for work already performed. A deleted employee doc simply
    // means no employee-level rate override is available (falls through
    // to the configured mode rate below); it does not block payment.
    const orderMode: "B2C" | "B2B" = after.orderMode === "B2B" ? "B2B" : "B2C";

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const employeeRef = db.collection("employees").doc(employeeUid);
    const walletRef = db.collection("wallets").doc(employeeUid);
    const walletTransactionRef = db.collection("wallet_transactions").doc();
    const settingsRef = db.collection("settings").doc("commission");

    try {
      await db.runTransaction(async (tx) => {
        const [orderSnap, employeeSnap, walletSnap, settingsSnap] = await Promise.all([
          tx.get(orderRef),
          tx.get(employeeRef),
          tx.get(walletRef),
          tx.get(settingsRef),
        ]);

        // Re-check idempotency inside the transaction to guard against
        // concurrent/retried trigger invocations (S9).
        if (orderSnap.data()?.commissionPaid === true) {
          console.log(`⚠️ Commission already paid for order ${orderId} (checked in tx) — skipping`);
          return;
        }

        const resolution = resolveCommissionRate({
          employeeOverride: employeeSnap.data()?.commissionRate,
          settings: settingsSnap.data(),
          orderMode,
        });

        if (!resolution.resolved) {
          console.error(
            `❌ Could not resolve a commission rate for order ${orderId} (employee=${employeeUid}, mode=${orderMode}, reason=${resolution.reason}) — leaving commissionPaid=false so this order is retryable once configured`
          );
          // Deliberately does NOT set commissionPaid:true — an
          // unresolvable rate must leave the order retryable, not
          // silently marked as "handled" with nothing paid. See the
          // module comment: silently inventing a percentage on real
          // money is worse than paying nothing and flagging it.
          tx.set(db.collection("commission_exceptions").doc(), {
            orderId,
            orderNumber: after.orderNumber || null,
            employeeUid,
            orderMode,
            total: (after.total as number | undefined) ?? null,
            reason: resolution.reason,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        const commissionRate = resolution.rate;
        const rateSource = resolution.source;

        const grossAmount = (after.total as number | undefined) ?? 0;
        const commissionAmount = Math.round(grossAmount * (commissionRate / 100) * 100) / 100;

        if (commissionAmount <= 0) {
          // A validly-resolved (necessarily > 0) rate applied to a
          // zero-or-negative order total — a genuine, rare edge case
          // (e.g. a fully-discounted order), not an unresolved rate. This
          // order really does owe nothing further, so it's fine to mark
          // it handled.
          tx.update(orderRef, {
            commissionPaid: true,
            commissionAmount: 0,
            commissionPaidAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        const currentBalance = (walletSnap.data()?.balance as number | undefined) ?? 0;
        const balanceAfter = currentBalance + commissionAmount;

        tx.set(
          walletRef,
          {
            userId: employeeUid,
            balance: admin.firestore.FieldValue.increment(commissionAmount),
            lifetimeEarnings: admin.firestore.FieldValue.increment(commissionAmount),
            isActive: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: walletSnap.exists
              ? walletSnap.data()?.createdAt
              : admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Phase 16D-1, Workstream 2c: orderMode + the resolved rate/source
        // recorded in metadata so retail and B2B earnings are
        // distinguishable in the wallet ledger and in any future
        // statement — not just inferable from the order itself.
        tx.set(walletTransactionRef, {
          walletId: employeeUid,
          userId: employeeUid,
          type: "credit",
          source: "commission",
          amount: commissionAmount,
          coins: 0,
          balanceAfter,
          coinsAfter: walletSnap.data()?.coins ?? 0,
          orderId,
          description: `Commission on ${orderMode} order ${after.orderNumber || orderId}`,
          referenceId: orderId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: null,
          metadata: {
            commissionRate,
            grossAmount,
            orderMode,
            rateSource,
          },
        });

        tx.update(orderRef, {
          commissionPaid: true,
          commissionAmount,
          commissionPaidAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log(`✅ Employee commission processed: employee=${employeeUid}, order=${orderId}`);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`❌ Failed to pay employee commission for order ${orderId}: ${message}`);
      throw error;
    }

    return null;
  });
