// ============================================================
//  Scheduled: advanceDeliveryDispatch (Phase DLV-2A)
// ============================================================
//
// Every minute: expire offers past their 30 s life, then move every due
// dispatch forward — the next wave, a D-DLV-NO-TAKER retry (every 2 min, with
// the order flagged needsAdmin), or closing it because the order was assigned
// by any route (acceptDeliveryOffer, the legacy client claim, the admin
// assignment screen) or is no longer ready for pickup. See dispatch.ts.
//
// Offer expiry is enforced by acceptDeliveryOffer itself (it refuses an offer
// past expiresAt), so the one-minute granularity only delays the NEXT wave,
// never lets a stale offer be accepted.

import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { runDispatchTick } from "./dispatch";

export const advanceDeliveryDispatch = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Kolkata",
    memory: "256MiB",
  },
  async () => {
    const r = await runDispatchTick(admin.firestore(), Date.now());
    if (r.expired || r.due) {
      console.log(`[advanceDeliveryDispatch] expired=${r.expired} due=${r.due} advanced=${r.advanced}`);
    }
  }
);
