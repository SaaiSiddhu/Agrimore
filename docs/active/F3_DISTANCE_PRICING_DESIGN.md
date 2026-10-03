# F3 seller delivery pricing — approved design and implementation record

**Status:** approved pricing contract implemented for standard/RFQ checkout, Product Credit hold settlement, and seller distance-fee configuration; production quota confirmation, tax policy, and deployment remain open.
**Date:** 2026-10-02
**Scope:** customer delivery charge for each seller's portion of an order. Rider earnings, tax, and seller payout policy are separate concerns.

## Current implementation

- The owner decision `D-DELIVERY-FEE` says each seller may choose a flat, subtotal-slab, or distance-based fee for that seller's own orders.
- `functions/src/customer/deliveryFeeSchedule.ts` validates `flat`, `slab`, and owner-approved `distance` schedules. Distance schedule errors fail closed; legacy flat/slab parsing remains unchanged.
- Standard `createOrder` applies per-seller schedules across multi-seller carts and requires a matching one-use server quote whenever any seller has a schedule. Product Credit quote/hold now validates and binds to that same quote; RFQ conversion also consumes it atomically.
- `apps/seller/lib/services/distance_service.dart` calculates straight-line (Haversine) distance and uses ₹4.75/km plus a ₹15 minimum for estimated rider earnings. That is client-side rider-earnings logic, not an authoritative customer delivery-fee policy.
- Seller onboarding already collects optional seller latitude/longitude and a delivery radius; customer addresses have optional latitude/longitude. The server checkout currently has no authoritative route-distance source.

**Implementation update (2026-10-02):** standard mobile checkout now requests an authenticated server quote before payment. `quoteDeliveryFees` covers configured flat, slab, and distance schedules; distance routes use Google Routes with `TRAFFIC_UNAWARE`. `createOrder` revalidates the quote snapshot and consumes it atomically with order creation.

## Design boundary

Keep delivery charges in integer paise internally and serialize as rupees only at existing API/document boundaries. The delivery quote should be computed from server-validated seller and customer coordinates and the seller's validated fee schedule. Client-submitted distance, fee, seller coordinates, and route output must never set the payable amount.

For a multi-seller cart, calculate one delivery fee per seller group and sum those fees. Do not ratio-split a single cart fee: that would not reflect the owner's per-seller decision. Apply each seller's delivery-radius policy before order creation. Missing or invalid required coordinates, a route-provider error, or an out-of-radius destination must produce a clear, non-ordering failure unless the owner explicitly selects another fallback policy.

Do not call a route provider from inside a retryable Firestore transaction. A later implementation should acquire a short-lived server-created quote before the order transaction, then atomically validate/consume its identity and snapshot alongside product, seller-policy, payment, and idempotency checks. Persist the applied distance, fee, formula version, and provider/source identifier with each seller order so later changes do not rewrite historical orders. Avoid persisting route polylines or extra precise location data unless a separate product requirement needs them.

Tax stays separate and remains a release blocker until its source and calculation policy are decided. A delivery fee proposal must not silently define tax treatment.

## Decisions requested

### Fee formula

1. **Base + per kilometre (recommended):** seller configures a starting fee and a rupee-per-kilometre rate. The owner still needs to choose rounding, any free radius, maximum service distance, and whether the existing ₹1,000 cap remains.
2. **Fee per started-kilometre slab:** seller configures distance thresholds and fees, with the server selecting the matching band. This is predictable at checkout but creates more seller setup and boundary cases.
3. **Seller-defined distance bands:** seller configures both distance ranges and the fee for each range; this is the most flexible, but needs stronger validation and user-friendly seller tooling.

### Distance source

1. **Server road route (recommended):** use a route provider's non-traffic driving distance; suitable for a delivery charge. It needs billing/quota controls, server-side credentials, request timeouts, and a defined refusal path when a route cannot be returned.
2. **Straight-line distance:** use Haversine between validated coordinates. Cheap and deterministic, but it underestimates road travel and can misprice around rivers, highways, or sparse roads. It must not reuse the rider-earnings UI as authority.
3. **Seller-entered zones:** no route API call at checkout, but requires sellers to define and maintain geographic zones and a boundary behavior.

## Research basis

Google's Routes API can return `routes.distanceMeters`; `TRAFFIC_UNAWARE` avoids live-traffic price movement and is the lower-latency option in Google's documented routing preferences. Google's official pricing page lists a monthly free-use allowance for Routes Essentials, followed by usage-based billing; India has a different free-use allowance. Confirm the actual billing account and quotas before deployment. Sources: [Routes API](https://developers.google.com/maps/documentation/routes/compute_route_directions), [routing preferences](https://developers.google.com/maps/documentation/routes/reference/rest/v2/RoutingPreference), [pricing](https://developers.google.com/maps/billing-and-pricing/pricing), [India pricing categories](https://developers.google.com/maps/billing-and-pricing/pricing-categories).

## Recommendation and release gates

Approved direction: **base + per kilometre using server road distance without live traffic**, one fee per seller order, seller/customer coordinates required, seller radius enforced, and the existing ₹1,000 hard fee cap retained. The standard mobile path has server quote/order parity and replay checks. Confirm provider quotas and budget alerts, and complete seller configuration plus alternate-order-path integration before enabling distance schedules broadly. Tax remains separate.

## Owner selections

- Formula: **base fee + per kilometre — approved 2026-10-02**.
- Distance source: **server-computed non-traffic road route — approved 2026-10-02**. Google Routes API is the proposed provider, reusing its existing server-only secret; no client receives the key.
- Per seller order, seller radius enforced, buyer/seller coordinates required, existing ₹1,000 maximum retained: **approved as part of the recommended design on 2026-10-02**.
- Seller supplies the base amount and per-kilometre rate; require both and reject a computed charge above ₹1,000. Store the settings as integer paise. **Approved design:** use exact route metres, prorate by metre, and round the total to the nearest paise; no free-distance band; enforce the seller's configured radius against road distance; reject out-of-radius orders.
- Provider API quota/budget limits: **must be confirmed/configured before deployment**; no cloud quota or billing settings changed.
- Tax source and formula: **open; separate release blocker**.

## Implemented standard-checkout contract

- Distance settings are `{type: "distance", baseFeePaise, ratePerKmPaise}`. Both fields must be safe integer paise, the rate must be positive, and the computed seller fee cannot exceed ₹1,000. The fee is base + exact route metres × per-kilometre rate / 1,000, rounded to nearest paise.
- The callable authenticates the buyer, reads the buyer-owned saved address and seller-owned schedule/location/radius, caps distance sellers at ten, applies a per-user fixed-window quote limit, sends a minimal field mask (`routes.distanceMeters`), applies a seven-second timeout, rejects missing coordinates and out-of-radius routes, and returns no provider body or route geometry. It validates every distance seller's policy before issuing at most ten concurrent route calls, keeping worst-case lookup time within one provider timeout window; a single quote can therefore issue up to ten billable route requests.
- Every configured fee shape gets a short-lived quote so the amount shown and charged can match flat/slab/distance seller fees. The quote binds the user, saved address and coordinates, normalized cart, order mode, seller set, schedule fingerprints, distance snapshots, original legacy fee, and final fee. It stores no raw coordinates.
- `createOrder` validates the quote against current seller schedules, shop location/radius, submitted address coordinates, cart, order mode, expiry, and unconsumed state inside its order transaction; it consumes the quote in that same transaction. Completed checkout-request retries recover the original order before quote validation; a quote cannot fund a second order.
- Mixed carts calculate each configured seller's own fee. The legacy client fee is allocated only among seller groups without a schedule. The ₹1,000 overall delivery cap still applies. Tax remains separate.
- Marketplace checkout restores the Firestore address document ID, obtains the server quote before routing to payment, and passes the quote identity and legacy fee through standard and native-recovery payloads. No client-side Routes key exists.

Focused verification on 2026-10-03: `npm run build`; 12 fee-math checks; 32 Firestore-emulator checks for authenticated quote creation, minimal route request, radius and coordinate failures, rate limiting, concurrent multi-seller routing, flat and mixed schedules, standard, Product Credit, and RFQ quote consumption, Product Credit hold/quote mismatch, address mismatch/edit, and replay rejection; existing flat/slab schedule regression suite (9 checks); existing Product Credit hold lifecycle suite (13 scenarios); and 25 seller delivery-validation unit tests. Emulator tests use synthetic documents and a mocked Routes response.

## Remaining release work

- Fresh continuation evidence on 2026-10-03: the distance/credit/RFQ suite now passes 37 checks. It includes captured prepaid payment with an expired credit hold and expired delivery quote, proving specific refusal and no changes to payment consumption, stock, hold, quote, balances, orders or credit ledger; a valid prepaid credit checkout is the positive control. Removing quote expiry in an in-memory test module makes both quote-expiry checks fail. No money-path guard was relaxed.
- Native deadline continuation: the quote response returns the exact stored `deliveryQuoteExpiresAtMs`; checkout routing freezes it into the native journal. Invalid/expired/missing deadlines prevent starting a quoted prepaid charge or reopening an unconfirmed saved order, including expiry during gateway creation or recovery. Capture lookup runs before the reopening guard, so captured money is never hidden by quote expiry. Device time is advisory; server validation remains authoritative. Full marketplace 1,798/1,798, focused native 82/82 and distance emulator 38/38 passed. Existing quoted journals without metadata cannot reopen unpaid checkout; inspect capture and retain the journal for resolution. Backend must return the deadline before compatible quoted native checkout rollout.
- **Captured-payment recovery after expiry is a release blocker.** Quote TTL is ten minutes; hold TTL is thirty minutes. Safe refusal does not fulfill or refund a captured checkout. The mobile journal retains its frozen request/payment intent, but a durable server-owned resolution for unfulfillable captured checkout is still required before shipping distance pricing or mobile credit redemption. See `MOBILE_FOUNDATION_PROGRESS.md`; do not requote/change payable or charge again against an unresolved payment.

- Seller profile UI now supports base/rate entry, paise precision validation, and an explicit current-shop-location action. The seller's configured delivery radius is shown and validated. Malformed distance schedules fail closed at checkout.
- Accepted RFQ mobile orders obtain a quote based on the accepted server-locked quantity/price, and the RFQ transaction validates and consumes that quote. Product Credit quote/hold reads the same validated server distance map, binds any new hold to the quote identity, and `createOrder` rejects a different quote before changing either hold or quote state. Product Credit does not itself call Google Routes.
- The current marketplace checkout requests a delivery quote before payment and passes it into order creation; the marketplace currently has no customer-facing Product Credit redemption selector/call to `quoteOrderWithCredit`. The backend path is ready for such a caller, but this work does not claim that the mobile UI applies Product Credit.
- Confirm the actual Google Maps billing account, per-minute quotas, and budget alerts before enabling distance schedules in production. No billing, quota, secret, production data, or deployment settings were changed.
- Backfill numeric inventory before enforcing fail-closed stock validation as separately selected by the owner. Tax remains an independent release blocker.
